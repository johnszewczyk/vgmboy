import Foundation
import PlaybackRequestCore
import VGMBoyKit

/// A naked playable item supplied by a frontend after any archive materialization.
/// It contains identity needed for status publication, but no catalog or UI model.
public struct PlaybackTransportTrack: Equatable, Sendable {
    public let id: String
    public let path: String
    public let trackIndex: Int

    public init(id: String, path: String, trackIndex: Int = 0) {
        self.id = id
        self.path = path
        self.trackIndex = max(0, trackIndex)
    }
}

public struct PlaybackTransportStatus: Equatable, Sendable {
    public let currentTrackID: String?
    public let isPlaying: Bool
    public let elapsedSeconds: TimeInterval
    public let reachedEnd: Bool
    public let trackLoaded: Bool

    public init(
        currentTrackID: String?,
        isPlaying: Bool,
        elapsedSeconds: TimeInterval,
        reachedEnd: Bool,
        trackLoaded: Bool
    ) {
        self.currentTrackID = currentTrackID
        self.isPlaying = isPlaying
        self.elapsedSeconds = elapsedSeconds
        self.reachedEnd = reachedEnd
        self.trackLoaded = trackLoaded
    }
}

public struct PlaybackTransportDiagnostics: Equatable, Sendable {
    public let decoderFamily: String?
    public let decoderSampleRate: Int
    public let decodedFrames: Int64
    public let audiblePositionFrames: Int64
    public let tempo: Double
    public let bufferedFrames: Int64
    public let ringBufferFrames: Int64
    public let underrunCount: Int64
    public let sampleRate: Int
    public let outputIsRunning: Bool

    public init(
        decoderFamily: String?,
        decoderSampleRate: Int,
        decodedFrames: Int64,
        audiblePositionFrames: Int64,
        tempo: Double,
        bufferedFrames: Int64,
        ringBufferFrames: Int64,
        underrunCount: Int64,
        sampleRate: Int,
        outputIsRunning: Bool
    ) {
        self.decoderFamily = decoderFamily
        self.decoderSampleRate = decoderSampleRate
        self.decodedFrames = decodedFrames
        self.audiblePositionFrames = audiblePositionFrames
        self.tempo = tempo
        self.bufferedFrames = bufferedFrames
        self.ringBufferFrames = ringBufferFrames
        self.underrunCount = underrunCount
        self.sampleRate = sampleRate
        self.outputIsRunning = outputIsRunning
    }
}

/// One-shot gate for the native completion event. Playback status can remain
/// at `reachedEnd` while a frontend is deciding what to do next; completion
/// must still be delivered only once for the generation that actually ended.
public struct PlaybackNaturalEndGate: Sendable {
    private var publishedGeneration: Int?

    public init() {}

    public mutating func reset() {
        publishedGeneration = nil
    }

    public mutating func shouldPublish(generation: Int, currentGeneration: Int?) -> Bool {
        guard let currentGeneration,
              generation == currentGeneration,
              publishedGeneration != generation else { return false }
        publishedGeneration = generation
        return true
    }
}

/// The single native transport façade shared by CocoaSpice and SPCBoyWK.
///
/// Frontends provide a naked playable path and stable identity. This type owns
/// command serialization, request invalidation, the in-process VGMBoy
/// controller, timing reconfiguration, output controls, and native status.
/// Queue navigation, catalog rows, archive extraction, and presentation stay
/// outside this boundary.
public final class PlaybackTransportCoordinator: @unchecked Sendable {
    public typealias StatusHandler = @Sendable (PlaybackTransportStatus) -> Void
    public typealias NaturalEndHandler = @Sendable (PlaybackTransportStatus) -> Void

    private let controller = PlaybackController()
    private let queue: PlaybackSerialExecutor
    private let requestLock = NSLock()
    private var latestPlaybackRequest = 0
    private var currentTrack: PlaybackTransportTrack?
    private var currentPlaybackPlan = PlaybackTimingPlan(
        preFadeSeconds: PlaybackTimingPreferences.defaultUnknownDurationSeconds,
        fadeSeconds: PlaybackTimingPreferences.defaultFadeSeconds,
        usesNativeEnding: false,
        isLongPlay: false
    )
    private var statusHandler: StatusHandler?
    private var naturalEndHandler: NaturalEndHandler?
    private var currentPlaybackGeneration: Int?
    private var naturalEndGate = PlaybackNaturalEndGate()
    private let controlSurface: PlaybackControlSurface

    public init(label: String) {
        queue = PlaybackSerialExecutor(label: label, qos: .userInitiated)
        controlSurface = controller.controlSurface
        _ = controller.subscribe { [weak self] event in
            guard let self, let status = event.status else { return }
            self.publish(status: status, naturalEnd: event.kind == .ended)
        }
    }

    public func setStatusHandler(_ handler: StatusHandler?) {
        queue.async { self.statusHandler = handler }
    }

    /// Installs the single completion event used by frontends to advance
    /// their queue. VGMBoy emits one `.ended` event after the output drains;
    /// this coordinator delivers it at most once for the active native
    /// playback generation.
    public func setNaturalEndHandler(_ handler: NaturalEndHandler?) {
        queue.async { self.naturalEndHandler = handler }
    }

    public func supports(_ command: PlaybackControlCommand) -> Bool {
        controlSurface.supports(command)
    }

    public func reservePlaybackRequest() -> Int {
        requestLock.lock()
        defer { requestLock.unlock() }
        latestPlaybackRequest += 1
        return latestPlaybackRequest
    }

    public func invalidatePlaybackRequests() {
        requestLock.lock()
        latestPlaybackRequest &+= 1
        requestLock.unlock()
    }

    public func isCurrentPlaybackRequest(_ requestID: Int) -> Bool {
        requestLock.lock()
        defer { requestLock.unlock() }
        return requestID == latestPlaybackRequest
    }

    public func play(
        track: PlaybackTransportTrack,
        plan: PlaybackTimingPlan,
        tempo: PlaybackTempo,
        requestID: Int
    ) async throws {
        try await run {
            guard self.isLatest(requestID) else { throw CancellationError() }
            try self.load(track: track, plan: plan, tempo: tempo, resumeAt: 0, autoplay: true)
        }
    }

    public func reconfigureCurrentTrack(plan: PlaybackTimingPlan, tempo: PlaybackTempo) async throws {
        try await run {
            guard let track = self.currentTrack else { throw PlaybackSessionError.notLoaded }
            let status = self.controller.perform(.init(command: .status)).status
            try self.load(
                track: track,
                plan: plan,
                tempo: tempo,
                resumeAt: status?.elapsedSeconds ?? 0,
                autoplay: status?.isPlaying ?? false
            )
        }
    }

    public func setTempo(_ tempo: PlaybackTempo) async throws {
        try await run {
            guard let track = self.currentTrack,
                  FormatRegistry.family(for: track.path)?.supportsTempo == true else { return }
            try self.requireSuccess(self.controller.perform(.init(
                command: .setTempo,
                payload: .init(tempo: tempo.multiplier)
            )))
        }
    }

    public func setPlaying(_ shouldPlay: Bool) async -> Bool {
        await run {
            let event = self.controller.perform(.init(command: shouldPlay ? .play : .pause))
            return event.status?.isPlaying ?? false
        }
    }

    public func restoreOutputGain() async {
        await run {
            _ = self.controller.perform(.init(
                command: .rampOutputGain,
                payload: .init(outputGain: 1, rampMilliseconds: 10)
            ))
        }
    }

    public func stop() async {
        await run {
            _ = self.controller.perform(.init(command: .stop))
            self.currentTrack = nil
            self.currentPlaybackGeneration = nil
            self.naturalEndGate.reset()
        }
    }

    public func beginFadedSkip(duration: TimeInterval) async -> Int? {
        await run {
            guard self.currentTrack != nil else { return nil }
            let status = self.controller.perform(.init(command: .status)).status
            guard status?.isPlaying == true else { return nil }
            let milliseconds = max(1, Int((duration * 1_000).rounded(.up)))
            let event = self.controller.perform(.init(
                command: .rampOutputGain,
                payload: .init(outputGain: 0, rampMilliseconds: milliseconds)
            ))
            guard event.kind != .error else { return nil }
            return status?.diagnostics.generation
        }
    }

    public func isCurrentGeneration(_ generation: Int) async -> Bool {
        await run {
            guard self.currentTrack != nil else { return false }
            return self.controller.perform(.init(command: .status)).status?.diagnostics.generation == generation
        }
    }

    public func status() async -> PlaybackTransportStatus {
        await run { self.status(self.controller.perform(.init(command: .status)).status) }
    }

    public func statusSync() -> PlaybackTransportStatus {
        queue.sync { status(controller.perform(.init(command: .status)).status) }
    }

    public func diagnostics() -> PlaybackTransportDiagnostics {
        queue.sync {
            let status = controller.perform(.init(command: .status)).status
            let diagnostics = controller.diagnostics()
            let statistics = status?.statistics
            return PlaybackTransportDiagnostics(
                decoderFamily: statistics?.decoderFamily,
                decoderSampleRate: statistics?.decoderSampleRate ?? 0,
                decodedFrames: statistics?.decodedFrames ?? 0,
                audiblePositionFrames: statistics?.audiblePositionFrames ?? 0,
                tempo: statistics?.tempo ?? 1,
                bufferedFrames: Int64(diagnostics.bufferedFrames),
                ringBufferFrames: Int64(diagnostics.capacityFrames),
                underrunCount: diagnostics.underrunCount,
                sampleRate: diagnostics.sampleRate,
                outputIsRunning: diagnostics.isOutputRunning
            )
        }
    }

    public func currentTrackID() async -> String? {
        await run { self.currentTrack?.id }
    }

    public func seek(to seconds: TimeInterval) async throws {
        try await run {
            try self.requireSuccess(self.controller.perform(.init(
                command: .seek,
                payload: .init(positionMilliseconds: Int(max(0, seconds) * 1_000))
            )))
        }
    }

    public func setAppVolume(_ volume: Float) {
        performOutputControl(.setOutputVolume, payload: .init(outputVolume: PlaybackPreferences.clampedVolume(volume)))
    }

    public func setMonoEnabled(_ enabled: Bool) {
        performOutputControl(.setMonoEnabled, payload: .init(monoEnabled: enabled))
    }

    public func setEqualizer(enabled: Bool, bandGains: [Float]) {
        let preferences = PlaybackPreferences(equalizerEnabled: enabled, equalizerBandGains: bandGains)
        performOutputControl(.setEqualizer, payload: .init(equalizer: preferences.equalizer))
    }

    public func exportAAC(
        sourcePath: String,
        trackIndex: Int,
        plan: PlaybackTimingPlan,
        outputDirectory: URL,
        filenameStem: String
    ) throws -> URL {
        let event = controller.perform(.init(
            command: .exportAAC,
            payload: .init(
                path: sourcePath,
                trackIndex: trackIndex,
                playMilliseconds: plan.preFadeSeconds * 1_000,
                fadeMilliseconds: plan.fadeSeconds * 1_000,
                exportDirectory: outputDirectory.path,
                exportFilenameStem: filenameStem
            )
        ))
        guard event.kind != .error, let path = event.message else {
            throw NSError(
                domain: "VGMBoyKit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: event.message ?? "VGMBoy AAC export failed."]
            )
        }
        return URL(fileURLWithPath: path)
    }

    /// Shared low-level command access for a host bridge. The command is still
    /// serialized here; hosts do not retain their own PlaybackController.
    public func perform(_ request: PlaybackControlRequest) -> PlaybackControlEvent {
        queue.sync {
            let event = controller.perform(request)
            guard event.kind != .error else { return event }
            switch request.command {
            case .load:
                if let path = request.payload.path, !path.isEmpty {
                    self.naturalEndGate.reset()
                    currentTrack = PlaybackTransportTrack(
                        id: path,
                        path: path,
                        trackIndex: request.payload.trackIndex ?? 0
                    )
                }
            case .stop, .shutdown:
                currentTrack = nil
                currentPlaybackGeneration = nil
                naturalEndGate.reset()
            default:
                break
            }
            if request.command == .load {
                currentPlaybackGeneration = event.status?.diagnostics.generation
            }
            return event
        }
    }

    private func load(
        track: PlaybackTransportTrack,
        plan: PlaybackTimingPlan,
        tempo: PlaybackTempo,
        resumeAt: TimeInterval,
        autoplay: Bool
    ) throws {
        let timing = try PlaybackTimingRequest.standard(
            path: track.path,
            longPlayEnabled: plan.isLongPlay,
            manualPlayMilliseconds: plan.preFadeSeconds * 1_000,
            fadeMilliseconds: plan.fadeSeconds * 1_000,
            unknownDurationMilliseconds: plan.unknownDurationSeconds * 1_000
        )
        naturalEndGate.reset()
        let event = controller.perform(.init(
            command: .load,
            payload: .init(
                path: track.path,
                trackIndex: track.trackIndex,
                tempo: tempo.multiplier,
                playbackMode: timing.playbackMode,
                playMilliseconds: timing.playMilliseconds,
                fadeMilliseconds: timing.fadeMilliseconds,
                unknownDurationMilliseconds: timing.unknownDurationMilliseconds
            )
        ))
        try requireSuccess(event)
        currentPlaybackGeneration = event.status?.diagnostics.generation
        if resumeAt > 0 {
            try requireSuccess(controller.perform(.init(
                command: .seek,
                payload: .init(positionMilliseconds: Int(resumeAt * 1_000))
            )))
        }
        if autoplay { try requireSuccess(controller.perform(.init(command: .play))) }
        currentTrack = track
        currentPlaybackPlan = plan
    }

    private func performOutputControl(_ command: PlaybackControlCommand, payload: PlaybackControlPayload) {
        guard controlSurface.supports(command) else {
            assertionFailure("VGMBoyKit does not expose \(command.rawValue).")
            return
        }
        queue.async {
            let event = self.controller.perform(.init(command: command, payload: payload))
            if event.kind == .error {
                assertionFailure(event.message ?? "VGMBoyKit rejected \(command.rawValue).")
            }
        }
    }

    private func status(_ status: VGMBoyKit.PlaybackStatus?) -> PlaybackTransportStatus {
        PlaybackTransportStatus(
            currentTrackID: currentTrack?.id,
            isPlaying: status?.isPlaying ?? false,
            elapsedSeconds: status?.elapsedSeconds ?? 0,
            reachedEnd: status?.reachedEnd ?? false,
            trackLoaded: currentTrack != nil
        )
    }

    private func publish(status: VGMBoyKit.PlaybackStatus, naturalEnd: Bool) {
        queue.async {
            let snapshot = self.status(status)
            self.statusHandler?(snapshot)
            guard naturalEnd,
                  self.naturalEndGate.shouldPublish(
                      generation: status.diagnostics.generation,
                      currentGeneration: self.currentPlaybackGeneration
                  ) else { return }
            self.naturalEndHandler?(snapshot)
        }
    }

    private func isLatest(_ requestID: Int) -> Bool {
        requestLock.lock()
        defer { requestLock.unlock() }
        return requestID == latestPlaybackRequest
    }

    private func requireSuccess(_ event: PlaybackControlEvent) throws {
        if event.kind == .error {
            throw NSError(
                domain: "VGMBoyKit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: event.message ?? "VGMBoy playback command failed."]
            )
        }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }
}
