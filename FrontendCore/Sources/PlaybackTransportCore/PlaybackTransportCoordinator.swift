import Foundation
import PlaybackQueueCore
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

/// Native continuation input after a frontend has resolved archive
/// materialization and timing policy. The shared transport deliberately sees
/// only the playable path and the finite VGMBoy load parameters.
public struct PlaybackContinuationStart: Equatable, Sendable {
    public let track: PlaybackTransportTrack
    public let payload: PlaybackControlPayload
    public let requestID: Int

    public init(
        track: PlaybackTransportTrack,
        payload: PlaybackControlPayload,
        requestID: Int
    ) {
        self.track = track
        self.payload = payload
        self.requestID = requestID
    }
}

public struct PlaybackTransportStatus: Equatable, Sendable {
    public let currentTrackID: String?
    public let generation: Int
    /// Monotonic order for status replies and broadcasts from this transport.
    /// Frontends use it to discard a delayed native event that would otherwise
    /// roll a visible clock back to an older paused/stopped state.
    public let statusSequence: UInt64
    public let isPlaying: Bool
    public let elapsedSeconds: TimeInterval
    public let reachedEnd: Bool
    public let trackLoaded: Bool
    /// Native output and decoder facts. These remain presentation-free so
    /// every frontend can render an honest diagnostics view from the same
    /// event that drives elapsed playback time.
    public let outputIsRunning: Bool
    public let errorMessage: String?
    public let bufferedFrames: Int
    public let ringBufferFrames: Int
    public let underrunCount: Int64
    public let framesRequested: Int64
    public let framesSupplied: Int64
    public let decoderFamily: String?
    public let trackIndex: Int?
    public let decoderSampleRate: Int
    public let outputSampleRate: Int
    public let decodedFrames: Int64
    public let audiblePositionFrames: Int64
    public let tempo: Double

    public init(
        currentTrackID: String?,
        generation: Int = 0,
        statusSequence: UInt64 = 0,
        isPlaying: Bool,
        elapsedSeconds: TimeInterval,
        reachedEnd: Bool,
        trackLoaded: Bool,
        outputIsRunning: Bool = false,
        errorMessage: String? = nil,
        bufferedFrames: Int = 0,
        ringBufferFrames: Int = 0,
        underrunCount: Int64 = 0,
        framesRequested: Int64 = 0,
        framesSupplied: Int64 = 0,
        decoderFamily: String? = nil,
        trackIndex: Int? = nil,
        decoderSampleRate: Int = 0,
        outputSampleRate: Int = 0,
        decodedFrames: Int64 = 0,
        audiblePositionFrames: Int64 = 0,
        tempo: Double = 1
    ) {
        self.currentTrackID = currentTrackID
        self.generation = generation
        self.statusSequence = statusSequence
        self.isPlaying = isPlaying
        self.elapsedSeconds = elapsedSeconds
        self.reachedEnd = reachedEnd
        self.trackLoaded = trackLoaded
        self.outputIsRunning = outputIsRunning
        self.errorMessage = errorMessage
        self.bufferedFrames = bufferedFrames
        self.ringBufferFrames = ringBufferFrames
        self.underrunCount = underrunCount
        self.framesRequested = framesRequested
        self.framesSupplied = framesSupplied
        self.decoderFamily = decoderFamily
        self.trackIndex = trackIndex
        self.decoderSampleRate = decoderSampleRate
        self.outputSampleRate = outputSampleRate
        self.decodedFrames = decodedFrames
        self.audiblePositionFrames = audiblePositionFrames
        self.tempo = tempo
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
/// Queue selection, catalog rows, archive extraction, and presentation stay
/// outside this boundary; the shared queue policy is consulted only for the
/// generation-checked completion retirement operation.
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
    private var nextStatusSequence: UInt64 = 0
    private var naturalEndGate = PlaybackNaturalEndGate()
    private let continuationCoordinator = PlaybackContinuationCoordinator()
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
            self.retirePlaybackLocked()
        }
    }

    /// Claims, retires, and computes the one continuation decision for a completed
    /// native session. The generation check and one-shot claim live beside the
    /// VGMBoy controller so a frontend cannot accidentally make a decision for
    /// a stale session or maintain a second continuation gate. The native
    /// session is retired in the same queue-confined operation; frontends only
    /// clear presentation state and honor the typed action that is returned.
    public func retireCompletedPlayback(
        generation: Int,
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        retireCompletedPlayback(.init(
            generation: generation,
            state: state,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        ))
    }

    /// Executes the complete typed completion lifecycle: validate the native
    /// generation, claim the one-shot continuation, compute the shared queue
    /// action, and retire the native session before returning that action.
    public func retireCompletedPlayback(
        _ request: PlaybackContinuationRequest
    ) -> PlaybackContinuationDecision? {
        queue.sync { self.retireCompletedPlaybackLocked(request) }
    }

    /// Native-frontends may let the coordinator sample the active generation
    /// and retire the session in the same serialized operation. This keeps a
    /// status poll and completion retirement from becoming two competing
    /// lifecycle decisions.
    public func retireCompletedPlayback(
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        queue.sync {
            guard let generation = self.controller.perform(.init(command: .status)).status?.diagnostics.generation else {
                return nil
            }
            let request = PlaybackContinuationRequest(
                generation: generation,
                state: state,
                playlistIDs: playlistIDs,
                repeatMode: repeatMode
            )
            return self.retireCompletedPlaybackLocked(request)
        }
    }

    /// Starts an already-resolved continuation after the caller has retired
    /// completion and prepared any archive-backed playable path. Archive
    /// extraction and cache leases stay in the adapter; the native load/play
    /// operation remains serialized here.
    public func startContinuation(_ start: PlaybackContinuationStart) async throws {
        try await run {
            guard self.isLatest(start.requestID) else { throw CancellationError() }
            self.naturalEndGate.reset()
            self.continuationCoordinator.reset()
            let event = self.controller.perform(.init(command: .load, payload: start.payload))
            try self.requireSuccess(event)
            try self.requireSuccess(self.controller.perform(.init(command: .play)))
            self.currentTrack = start.track
            self.currentPlaybackGeneration = event.status?.diagnostics.generation
        }
    }

    private func completionDecisionLocked(
        generation: Int,
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        guard currentTrack != nil,
              controller.perform(.init(command: .status)).status?.diagnostics.generation == generation else { return nil }
        return continuationCoordinator.decision(
            generation: generation,
            state: state,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        )
    }

    private func retireCompletedPlaybackLocked(
        _ request: PlaybackContinuationRequest
    ) -> PlaybackContinuationDecision? {
        guard let decision = completionDecisionLocked(
            generation: request.generation,
            state: request.state,
            playlistIDs: request.playlistIDs,
            repeatMode: request.repeatMode
        ) else { return nil }
        retirePlaybackLocked()
        return decision
    }

    private func retirePlaybackLocked() {
        _ = controller.perform(.init(command: .stop))
        currentTrack = nil
        currentPlaybackGeneration = nil
        naturalEndGate.reset()
        continuationCoordinator.reset()
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
        filenameStem: String,
        cancellation: AACExportCancellation? = nil,
        progress: (@Sendable (AACExportProgress) -> Void)? = nil
    ) throws -> URL {
        try exportAAC(.init(
            sourcePath: sourcePath,
            trackIndex: trackIndex,
            outputDirectory: outputDirectory,
            filenameStem: filenameStem,
            playMilliseconds: plan.preFadeSeconds * 1_000,
            fadeMilliseconds: plan.fadeSeconds * 1_000
        ), cancellation: cancellation, progress: progress)
    }

    public func exportAAC(
        _ request: AACExportRequest,
        cancellation: AACExportCancellation? = nil,
        progress: (@Sendable (AACExportProgress) -> Void)? = nil
    ) throws -> URL {
        try queue.sync {
            let result = try controller.exportAAC(request, cancellation: cancellation, progress: progress)
            return result.outputURL
        }
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
                continuationCoordinator.reset()
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
        continuationCoordinator.reset()
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
        nextStatusSequence &+= 1
        let diagnostics = status?.diagnostics
        let statistics = status?.statistics
        return PlaybackTransportStatus(
            currentTrackID: currentTrack?.id,
            generation: diagnostics?.generation ?? 0,
            statusSequence: nextStatusSequence,
            isPlaying: status?.isPlaying ?? false,
            elapsedSeconds: status?.elapsedSeconds ?? 0,
            reachedEnd: status?.reachedEnd ?? false,
            trackLoaded: currentTrack != nil,
            outputIsRunning: diagnostics?.isOutputRunning ?? false,
            errorMessage: status?.errorMessage,
            bufferedFrames: diagnostics?.bufferedFrames ?? 0,
            ringBufferFrames: diagnostics?.capacityFrames ?? 0,
            underrunCount: diagnostics?.underrunCount ?? 0,
            framesRequested: diagnostics?.framesRequested ?? 0,
            framesSupplied: diagnostics?.framesSupplied ?? 0,
            decoderFamily: statistics?.decoderFamily,
            trackIndex: statistics?.trackIndex,
            decoderSampleRate: statistics?.decoderSampleRate ?? 0,
            outputSampleRate: statistics?.outputSampleRate ?? diagnostics?.sampleRate ?? 0,
            decodedFrames: statistics?.decodedFrames ?? 0,
            audiblePositionFrames: statistics?.audiblePositionFrames ?? 0,
            tempo: statistics?.tempo ?? 1
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
