import Foundation
import PlaybackQueueCore
import PlaybackRequestCore
import VGMBoyKit

/// A source selected by the frontend. VGMBoy receives either a direct path or
/// an archive/member pair and owns the preparation needed by the decoder.
/// Bounded in-memory bytes remain available to capable decoders.
public struct PlaybackTransportTrack: Equatable, Sendable {
    public let id: String
    public let path: String
    public let trackIndex: Int
    public let sourceData: Data?
    public let loop: PlaybackLoopMetadata?
    public let archivePath: String?
    public let archiveEntry: String?

    public init(
        id: String,
        path: String,
        trackIndex: Int = 0,
        sourceData: Data? = nil,
        loop: PlaybackLoopMetadata? = nil,
        archivePath: String? = nil,
        archiveEntry: String? = nil
    ) {
        self.id = id
        self.path = path
        self.trackIndex = max(0, trackIndex)
        self.sourceData = sourceData
        self.loop = loop
        self.archivePath = archivePath
        self.archiveEntry = archiveEntry
    }
}

/// Native continuation input after the frontend applies timing policy. The
/// selected source may be a direct path, an archive/member pair, or
/// decoder-supported member bytes.
public struct PlaybackContinuationStart: Equatable, Sendable {
    public let track: PlaybackTransportTrack
    public let payload: PlaybackControlPayload
    public let requestID: Int
    public let startMilliseconds: Int
    public let expectedPreviousGeneration: Int?
    public let queuedSkipToken: String?

    public init(
        track: PlaybackTransportTrack,
        payload: PlaybackControlPayload,
        requestID: Int,
        startMilliseconds: Int = 0,
        expectedPreviousGeneration: Int? = nil,
        queuedSkipToken: String? = nil
    ) {
        self.track = track
        self.payload = payload
        self.requestID = requestID
        self.startMilliseconds = max(0, startMilliseconds)
        self.expectedPreviousGeneration = expectedPreviousGeneration
        self.queuedSkipToken = queuedSkipToken
    }
}

/// Typed frontend request for starting playback. It carries stable identity,
/// optional archive/member identity, and timing/tempo intent. VGMBoy prepares
/// the source before dispatching it to the decoder.
public struct PlaybackTransportStartRequest: Codable, Equatable, Sendable {
    public let trackID: String
    public let sourcePath: String
    public let archivePath: String?
    public let archiveEntry: String?
    public let trackIndex: Int
    public let startMilliseconds: Int
    public let playMilliseconds: Int
    public let fadeMilliseconds: Int
    public let tempo: PlaybackTempo
    public let longPlayEnabled: Bool
    public let timedOverride: Bool
    public let unknownDurationMilliseconds: Int
    public let loop: PlaybackLoopMetadata?
    public let expectedPreviousGeneration: Int?
    public let queuedSkipToken: String?

    public init(
        trackID: String,
        sourcePath: String,
        archivePath: String? = nil,
        archiveEntry: String? = nil,
        trackIndex: Int = 0,
        startMilliseconds: Int = 0,
        playMilliseconds: Int = 0,
        fadeMilliseconds: Int = 0,
        tempo: PlaybackTempo = .defaultValue,
        longPlayEnabled: Bool = false,
        timedOverride: Bool = false,
        unknownDurationMilliseconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000,
        loop: PlaybackLoopMetadata? = nil,
        expectedPreviousGeneration: Int? = nil,
        queuedSkipToken: String? = nil
    ) {
        self.trackID = trackID
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.archiveEntry = archiveEntry
        self.trackIndex = max(0, trackIndex)
        self.startMilliseconds = max(0, startMilliseconds)
        self.playMilliseconds = max(0, playMilliseconds)
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.tempo = PlaybackTempo(numerator: tempo.numerator, denominator: tempo.denominator)
        self.longPlayEnabled = longPlayEnabled
        self.timedOverride = timedOverride
        self.unknownDurationMilliseconds = max(1_000, unknownDurationMilliseconds)
        self.loop = loop
        self.expectedPreviousGeneration = expectedPreviousGeneration
        self.queuedSkipToken = queuedSkipToken
    }

    private enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case sourcePath = "path"
        case archivePath
        case archiveEntry
        case trackIndex
        case startMilliseconds
        case playMilliseconds
        case fadeMilliseconds
        case tempo
        case longPlayEnabled
        case timedOverride
        case unknownDurationMilliseconds
        case loop
        case expectedPreviousGeneration
        case queuedSkipToken
    }

    /// Builds the common transport input while preserving archive/member
    /// identity for VGMBoy's source-preparation boundary. Frontends cannot
    /// substitute a pre-extracted cache path for the selected source.
    public func continuationStart(
        requestID: Int
    ) throws -> PlaybackContinuationStart {
        let archiveSourcePath = archivePath.flatMap { $0.isEmpty ? nil : $0 }
        let archiveMember = archiveEntry.flatMap { $0.isEmpty ? nil : $0 }
        let usesArchiveMember = archiveSourcePath != nil && archiveMember != nil
        let playbackPath = usesArchiveMember ? archiveSourcePath! : sourcePath
        guard !trackID.isEmpty, !sourcePath.isEmpty, !playbackPath.isEmpty else {
            throw PlaybackControlError.invalidPayload("Playback start requires a track ID and file path.")
        }
        let timingPath = usesArchiveMember ? archiveMember! : playbackPath
        let timing: PlaybackTimingRequest
        if timedOverride {
            timing = try .timed(
                playMilliseconds: playMilliseconds,
                fadeMilliseconds: fadeMilliseconds
            )
        } else {
            timing = try .standard(
                path: timingPath,
                longPlayEnabled: longPlayEnabled,
                manualPlayMilliseconds: playMilliseconds,
                fadeMilliseconds: fadeMilliseconds,
                unknownDurationMilliseconds: unknownDurationMilliseconds
            )
        }
        let normalizedTempo = PlaybackTempo(numerator: tempo.numerator, denominator: tempo.denominator)
        return PlaybackContinuationStart(
            track: .init(
                id: trackID,
                path: playbackPath,
                trackIndex: trackIndex,
                loop: loop,
                archivePath: usesArchiveMember ? archiveSourcePath : nil,
                archiveEntry: usesArchiveMember ? archiveMember : nil
            ),
            payload: .init(
                path: playbackPath,
                archiveEntry: usesArchiveMember ? archiveMember : nil,
                trackIndex: trackIndex,
                tempo: normalizedTempo.multiplier,
                playbackMode: timing.playbackMode,
                playMilliseconds: timing.playMilliseconds,
                fadeMilliseconds: timing.fadeMilliseconds,
                unknownDurationMilliseconds: timing.unknownDurationMilliseconds,
                loop: loop
            ),
            requestID: requestID,
            startMilliseconds: startMilliseconds,
            expectedPreviousGeneration: expectedPreviousGeneration,
            queuedSkipToken: queuedSkipToken
        )
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

/// The shared native transport façade used by CocoaSpice and WebKit frontends.
///
/// Frontends provide a direct path or archive/member identity plus stable
/// identity. This type owns command serialization, request invalidation, the
/// in-process VGMBoy controller, source preparation, timing reconfiguration,
/// output controls, and native status. Queue selection, catalog rows, and
/// presentation stay outside this boundary; shared queue policy is consulted
/// only for generation-checked completion retirement.
public final class PlaybackTransportCoordinator: @unchecked Sendable {
    private final class OperationCancellation: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false
        func cancel() { lock.lock(); cancelled = true; lock.unlock() }
        var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    }

    private struct ReconfigurationWork: Sendable {
        let epoch: UInt64
        let generation: Int
        let trackStartGeneration: Int
        let requestID: Int
        let track: PlaybackTransportTrack
        let settings: PlaybackControlPayload
        let source: PlaybackController.ReconfigurationSource
        let playbackPlan: PlaybackTimingPlan?
        let candidateID: UInt64?
        let isCancelled: @Sendable () -> Bool
    }
    private enum ReconfigurationPreparation {
        case completed(PlaybackTransportStatus)
        case prepare(ReconfigurationWork)
        case waitForCandidate(UInt64, Int, Int)
    }
    private struct ReconfigurationCandidate {
        let id: UInt64
        let epoch: UInt64
        let requestID: Int
    }
    public let queuedSkipLifecycle = PlaybackQueuedSkipLifecycle()
    public typealias StatusHandler = @Sendable (PlaybackTransportStatus) -> Void
    public typealias NaturalEndHandler = @Sendable (PlaybackTransportStatus) -> Void

    private let controller = PlaybackController()
    private let queue: PlaybackSerialExecutor
    private let prepareSource: @Sendable (PlaybackController, PlaybackContinuationStart) throws -> PlaybackController.PreparedSource
    private let preparationSlots = DispatchSemaphore(value: 2)
    private let exportSlot = DispatchSemaphore(value: 1)
    private let requestLock = NSLock()
    private var latestPlaybackRequest = 0
    private var settingsRevisionCounter = 0
    private var seekRevisionCounter = 0
    private var rampRevisionCounter = 0
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
    private var queuedSkipClaimGeneration: Int?
    private var queuedSkipClaims = Set<String>()
    private var currentTrackStartGeneration: Int?
    private var latestSettingsRevision: Int?
    private var pendingReconfiguration: ReconfigurationWork? // Transport queue only.
    private var reconfigurationEpoch: UInt64 = 0 // Protected by requestLock.
    private var nextReconfigurationCandidate: UInt64 = 0 // Protected by requestLock.
    private var reconfigurationCandidate: ReconfigurationCandidate? // Protected by requestLock.
    private var latestSeekRevision: Int?
    private var latestRampRevision: Int?
    private var nextStatusSequence: UInt64 = 0
    private var naturalEndGate = PlaybackNaturalEndGate()
    private let continuationCoordinator = PlaybackContinuationCoordinator()
    private let controlSurface: PlaybackControlSurface

    public convenience init(label: String) {
        self.init(label: label) { controller, start in
            try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
        }
    }

    init(label: String, prepareSource: @escaping @Sendable (PlaybackController, PlaybackContinuationStart) throws -> PlaybackController.PreparedSource) {
        queue = PlaybackSerialExecutor(label: label, qos: .userInitiated)
        self.prepareSource = prepareSource
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

    /// Reserve in the host's message-receipt order. Unlike a renderer-local
    /// counter, this survives WebView recreation while this transport lives.
    public func reserveSettingsRevision() -> Int {
        requestLock.lock()
        defer { requestLock.unlock() }
        settingsRevisionCounter += 1
        return settingsRevisionCounter
    }

    /// Reserve before dispatch so concurrent seeks retain host receipt order.
    public func reserveSeekRevision() -> Int {
        requestLock.lock()
        defer { requestLock.unlock() }
        seekRevisionCounter += 1
        return seekRevisionCounter
    }

    /// Reserve before dispatch so fade and restore commands retain host receipt order.
    public func reserveRampRevision() -> Int {
        requestLock.lock()
        defer { requestLock.unlock() }
        rampRevisionCounter += 1
        return rampRevisionCounter
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
        guard isLatest(requestID) else { throw CancellationError() }
        let timing = try PlaybackTimingRequest.standard(
            path: track.archiveEntry ?? track.path,
            longPlayEnabled: plan.isLongPlay,
            manualPlayMilliseconds: try timingMilliseconds(plan.preFadeSeconds),
            fadeMilliseconds: try timingMilliseconds(plan.fadeSeconds),
            unknownDurationMilliseconds: try timingMilliseconds(plan.unknownDurationSeconds)
        )
        let payload = PlaybackControlPayload(
            path: track.archivePath ?? track.path, archiveEntry: track.archiveEntry,
            trackIndex: track.trackIndex, tempo: tempo.multiplier, playbackMode: timing.playbackMode,
            playMilliseconds: timing.playMilliseconds, fadeMilliseconds: timing.fadeMilliseconds,
            unknownDurationMilliseconds: timing.unknownDurationMilliseconds, loop: track.loop
        )
        try await startContinuation(.init(track: track, payload: payload, requestID: requestID), playbackPlan: plan)
    }

    public func reconfigureCurrentTrack(plan: PlaybackTimingPlan, tempo: PlaybackTempo) async throws {
        let cancellation = OperationCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await Task.detached(priority: .userInitiated) {
                _ = try self.reconfigure(expectedGeneration: nil, settingsRevision: nil, playbackPlan: plan,
                                         isCancelled: { cancellation.isCancelled }) { track in
                    let timing = try PlaybackTimingRequest.standard(
                        path: track.archiveEntry ?? track.path,
                        longPlayEnabled: plan.isLongPlay,
                        manualPlayMilliseconds: try self.timingMilliseconds(plan.preFadeSeconds),
                        fadeMilliseconds: try self.timingMilliseconds(plan.fadeSeconds),
                        unknownDurationMilliseconds: try self.timingMilliseconds(plan.unknownDurationSeconds)
                    )
                    return .init(tempo: tempo.multiplier, playbackMode: timing.playbackMode,
                                 playMilliseconds: timing.playMilliseconds, fadeMilliseconds: timing.fadeMilliseconds,
                                 unknownDurationMilliseconds: timing.unknownDurationMilliseconds)
                }
            }.value
        } onCancel: { cancellation.cancel() }
    }

    /// Applies a complete bridge settings snapshot with a serialized commit.
    public func reconfigureSync(_ request: PlaybackTransportReconfigurationRequest) throws -> PlaybackTransportStatus {
        try reconfigure(expectedGeneration: request.expectedGeneration, settingsRevision: request.settingsRevision) { _ in
            var payload = request.playbackModePayload
            payload.tempo = request.tempo.multiplier
            return payload
        }
    }

    /// Updates tempo while retaining the current timing settings. Preparation
    /// shares the same bounded, guarded handoff as a complete settings update.
    public func setTempoSync(_ request: PlaybackTransportTempoRequest) throws -> PlaybackTransportStatus {
        try reconfigure(expectedGeneration: nil, settingsRevision: nil, preservePendingTiming: true) { _ in
            try self.controller.tempoReconfigurationSettings(request.tempo.multiplier)
        }
    }

    private func reconfigure(expectedGeneration: Int?, settingsRevision: Int?, playbackPlan: PlaybackTimingPlan? = nil,
                             ignoreUnsupportedTempo: Bool = false, preservePendingTiming: Bool = false,
                             lowLevelRequest: PlaybackControlRequest? = nil,
                             captureEvent: ((PlaybackControlEvent) -> Void)? = nil,
                             isCancelled: @escaping @Sendable () -> Bool = { false },
                             payloadForTrack: (PlaybackTransportTrack) throws -> PlaybackControlPayload) throws -> PlaybackTransportStatus {
        var requiredGeneration = expectedGeneration
        while true {
            guard !isCancelled() else { throw CancellationError() }
            let preparation: ReconfigurationPreparation = try queue.sync {
                guard !isCancelled() else { throw CancellationError() }
                if let expected = requiredGeneration {
                    guard let start = currentTrackStartGeneration, let current = currentPlaybackGeneration,
                          expected >= start, expected <= current else { throw CancellationError() }
                }
                if let lowLevelRequest, currentTrack == nil {
                    let event = performLocked(lowLevelRequest)
                    captureEvent?(event)
                    return .completed(status(event.status))
                }
                if let revision = settingsRevision {
                    guard requiredGeneration != nil, revision >= 0,
                          latestSettingsRevision.map({ revision > $0 }) ?? true else { throw CancellationError() }
                }
                if ignoreUnsupportedTempo {
                    guard let track = currentTrack,
                          FormatRegistry.family(for: track.archiveEntry ?? track.path)?.supportsTempo == true else {
                        return .completed(status(controller.status()))
                    }
                }
                guard let track = currentTrack, let generation = currentPlaybackGeneration,
                      let trackStart = currentTrackStartGeneration else { throw PlaybackSessionError.notLoaded }
                var payload = try payloadForTrack(track)
                if FormatRegistry.family(for: track.archiveEntry ?? track.path)?.supportsTempo != true {
                    payload.tempo = 1
                }
                // Rejected settings must not consume a revision or supersede an
                // already preparing, valid request. Pending timing has already
                // passed this same validation; tempo is validated in this payload.
                _ = try PlaybackController.validatePlaybackMode(payload)
                if let settingsRevision { latestSettingsRevision = settingsRevision }
                var acceptedPlan = playbackPlan
                requestLock.lock()
                let requestID = latestPlaybackRequest
                let currentCandidate = reconfigurationCandidate.flatMap {
                    $0.epoch == reconfigurationEpoch && $0.requestID == requestID ? $0 : nil
                }
                if lowLevelRequest != nil, let currentCandidate {
                    requestLock.unlock()
                    return .waitForCandidate(currentCandidate.id, requestID, generation)
                }
                let canSpeculate = lowLevelRequest != nil && pendingReconfiguration.map {
                    $0.epoch == reconfigurationEpoch && $0.requestID == requestID &&
                    $0.generation == generation && $0.trackStartGeneration == trackStart && !$0.isCancelled()
                } == true
                if canSpeculate, let lowLevelRequest {
                    requestLock.unlock()
                    guard try controller.reconfigurationRequiresReload(payload) else {
                        let event = performLocked(lowLevelRequest)
                        captureEvent?(event)
                        return .completed(status(event.status))
                    }
                    let source = try controller.reconfigurationSource(for: payload)
                    requestLock.lock()
                    guard latestPlaybackRequest == requestID,
                          pendingReconfiguration?.epoch == reconfigurationEpoch else {
                        requestLock.unlock()
                        throw CancellationError()
                    }
                    nextReconfigurationCandidate &+= 1
                    let candidate = ReconfigurationCandidate(id: nextReconfigurationCandidate,
                        epoch: reconfigurationEpoch, requestID: requestID)
                    reconfigurationCandidate = candidate
                    requestLock.unlock()
                    return .prepare(ReconfigurationWork(epoch: candidate.epoch, generation: generation,
                        trackStartGeneration: trackStart, requestID: requestID, track: track,
                        settings: payload, source: source, playbackPlan: nil, candidateID: candidate.id,
                        isCancelled: isCancelled))
                }
                if preservePendingTiming, let pending = pendingReconfiguration,
                   pending.generation == generation, pending.trackStartGeneration == trackStart,
                   pending.epoch == reconfigurationEpoch, pending.requestID == requestID, !pending.isCancelled() {
                    let tempo = payload.tempo
                    payload = pending.settings
                    payload.tempo = tempo
                    acceptedPlan = pending.playbackPlan
                }
                reconfigurationEpoch &+= 1
                let epoch = reconfigurationEpoch
                reconfigurationCandidate = nil
                requestLock.unlock()
                pendingReconfiguration = nil
                guard !isCancelled() else { throw CancellationError() }
                guard try controller.reconfigurationRequiresReload(payload) else {
                    guard !isCancelled() else { throw CancellationError() }
                    let result = try reconfigureLocked(payload: payload)
                    if let lowLevelRequest {
                        captureEvent?(.init(requestID: lowLevelRequest.requestID, kind: .response, status: controller.status()))
                    }
                    if let acceptedPlan { currentPlaybackPlan = acceptedPlan }
                    return .completed(result)
                }
                let source = try controller.reconfigurationSource(for: payload)
                let work = ReconfigurationWork(epoch: epoch, generation: generation,
                    trackStartGeneration: trackStart, requestID: requestID, track: track,
                    settings: payload, source: source, playbackPlan: acceptedPlan, candidateID: nil,
                    isCancelled: isCancelled)
                pendingReconfiguration = work
                return .prepare(work)
            }
            if case .waitForCandidate(let id, let requestID, let generation) = preparation {
                while isCandidatePending(id) && !isCancelled() { Thread.sleep(forTimeInterval: 0.05) }
                guard !isCancelled(), isLatest(requestID) else { throw CancellationError() }
                requiredGeneration = requiredGeneration ?? generation
                continue
            }
            guard case .prepare(let work) = preparation else {
                if case .completed(let status) = preparation { return status }
                throw CancellationError()
            }
            let prepared: PlaybackController.PreparedSource
            do {
                prepared = try prepareReconfigurationOutsideTransport(work)
            } catch {
                queue.sync {
                    if let candidateID = work.candidateID {
                        clearCandidate(candidateID)
                    } else if pendingReconfiguration?.epoch == work.epoch {
                        pendingReconfiguration = nil
                    }
                }
                throw error
            }
            while true {
                let result: PlaybackTransportStatus? = try queue.sync {
                    guard self.isCurrentReconfiguration(work), self.currentPlaybackGeneration == work.generation,
                          self.currentTrackStartGeneration == work.trackStartGeneration else {
                        if let candidateID = work.candidateID { self.clearCandidate(candidateID) }
                        else if self.pendingReconfiguration?.epoch == work.epoch { self.pendingReconfiguration = nil }
                        throw CancellationError()
                    }
                    if work.candidateID == nil && self.hasCandidate(for: work) { return nil }
                    if work.candidateID == nil && self.pendingReconfiguration?.epoch == work.epoch {
                        self.pendingReconfiguration = nil
                    }
                    let event = self.controller.reconfigurePrepared(prepared, settings: work.settings) {
                        self.isCurrentReconfiguration(work)
                    }
                    if event.kind == .error {
                        if let lowLevelRequest {
                            captureEvent?(.init(requestID: lowLevelRequest.requestID, kind: .error,
                                                status: event.status, message: event.message))
                        }
                        if event.status?.diagnostics.generation != work.generation {
                            self.retirePlaybackLocked()
                        } else if let candidateID = work.candidateID {
                            self.clearCandidate(candidateID)
                        }
                        if work.isCancelled() { throw CancellationError() }
                        try self.requireSuccess(event)
                    }
                    if let candidateID = work.candidateID {
                        self.requestLock.lock()
                        guard self.reconfigurationCandidate?.id == candidateID,
                              self.reconfigurationEpoch == work.epoch, self.latestPlaybackRequest == work.requestID else {
                            self.requestLock.unlock()
                            self.retirePlaybackLocked()
                            throw CancellationError()
                        }
                        self.reconfigurationEpoch &+= 1
                        self.reconfigurationCandidate = nil
                        self.requestLock.unlock()
                        self.pendingReconfiguration = nil
                    }
                    let generation = event.status?.diagnostics.generation
                    if generation != work.generation {
                        self.naturalEndGate.reset()
                        self.continuationCoordinator.reset()
                    }
                    self.currentPlaybackGeneration = generation
                    if let playbackPlan = work.playbackPlan { self.currentPlaybackPlan = playbackPlan }
                    if let lowLevelRequest {
                        captureEvent?(.init(requestID: lowLevelRequest.requestID, kind: .response, status: event.status))
                    }
                    return self.status(event.status)
                }
                if let result { return result }
                while hasCandidate(for: work) && isCurrentReconfiguration(work) {
                    Thread.sleep(forTimeInterval: 0.05)
                }
            }
        }
    }

    private func isCurrentReconfiguration(_ work: ReconfigurationWork) -> Bool {
        requestLock.lock(); defer { requestLock.unlock() }
        return !work.isCancelled() && reconfigurationEpoch == work.epoch && latestPlaybackRequest == work.requestID &&
            (work.candidateID.map { reconfigurationCandidate?.id == $0 } ?? true)
    }

    private func hasCandidate(for work: ReconfigurationWork) -> Bool {
        requestLock.lock(); defer { requestLock.unlock() }
        return reconfigurationCandidate.map { $0.epoch == work.epoch && $0.requestID == work.requestID } ?? false
    }

    private func isCandidatePending(_ id: UInt64) -> Bool {
        requestLock.lock(); defer { requestLock.unlock() }
        guard let candidate = reconfigurationCandidate else { return false }
        return candidate.id == id && candidate.epoch == reconfigurationEpoch && candidate.requestID == latestPlaybackRequest
    }

    private func clearCandidate(_ id: UInt64) {
        requestLock.lock(); defer { requestLock.unlock() }
        if reconfigurationCandidate?.id == id { reconfigurationCandidate = nil }
    }

    private func prepareReconfigurationOutsideTransport(_ work: ReconfigurationWork) throws -> PlaybackController.PreparedSource {
        while preparationSlots.wait(timeout: .now() + .milliseconds(100)) != .success {
            guard isCurrentReconfiguration(work) else { throw CancellationError() }
        }
        defer { preparationSlots.signal() }
        guard isCurrentReconfiguration(work) else { throw CancellationError() }
        let track = PlaybackTransportTrack(id: work.track.id, path: work.track.path,
            trackIndex: work.track.trackIndex, sourceData: work.source.sourceData, loop: work.track.loop,
            archivePath: work.track.archivePath, archiveEntry: work.track.archiveEntry)
        let start = PlaybackContinuationStart(track: track, payload: work.source.payload, requestID: work.requestID)
        do {
            let prepared = try prepareSource(controller, start)
            guard isCurrentReconfiguration(work) else { throw CancellationError() }
            return prepared
        } catch {
            guard isCurrentReconfiguration(work) else { throw CancellationError() }
            throw error
        }
    }

    private func reconfigureLocked(payload: PlaybackControlPayload) throws -> PlaybackTransportStatus {
        guard let track = currentTrack else { throw PlaybackSessionError.notLoaded }
        var effective = payload
        if FormatRegistry.family(for: track.archiveEntry ?? track.path)?.supportsTempo != true {
            effective.tempo = 1
        }
        let previousGeneration = currentPlaybackGeneration
        let event = controller.perform(.init(command: .setPlaybackMode, payload: effective))
        if event.kind == .error {
            if event.status?.diagnostics.generation != previousGeneration { retirePlaybackLocked() }
            try requireSuccess(event)
        }
        let generation = event.status?.diagnostics.generation
        if generation != previousGeneration {
            naturalEndGate.reset()
            continuationCoordinator.reset()
        }
        currentPlaybackGeneration = generation
        return status(event.status)
    }

    public func setTempo(_ tempo: PlaybackTempo) async throws {
        let cancellation = OperationCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await Task.detached(priority: .userInitiated) {
                _ = try self.reconfigure(expectedGeneration: nil, settingsRevision: nil,
                                         ignoreUnsupportedTempo: true, preservePendingTiming: true,
                                         isCancelled: { cancellation.isCancelled }) { _ in
                    try self.controller.tempoReconfigurationSettings(tempo.multiplier)
                }
            }.value
        } onCancel: { cancellation.cancel() }
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

    /// Apply a renderer envelope only while the requested session still owns
    /// playback. Legacy callers may omit the generation.
    public func rampOutputGainSync(_ request: PlaybackTransportRampGainRequest) throws -> PlaybackTransportStatus {
        try queue.sync {
            if let expected = request.expectedGeneration,
               expected != currentPlaybackGeneration {
                throw CancellationError()
            }
            if let revision = request.rampRevision {
                guard request.expectedGeneration != nil, revision > 0,
                      latestRampRevision.map({ revision > $0 }) ?? true else { throw CancellationError() }
                latestRampRevision = revision
            }
            let event = controller.perform(.init(command: .rampOutputGain, payload: request.payload))
            try requireSuccess(event)
            return status(event.status)
        }
    }

    /// A failed or canceled queued skip may restore only the session it faded.
    public func restoreQueuedSkipGainSync(_ request: PlaybackQueuedSkipRestoreRequest) throws -> PlaybackTransportStatus {
        guard request.expectedGeneration > 0, request.rampMilliseconds > 0 else {
            throw PlaybackControlError.invalidPayload("Invalid queued skip restoration.")
        }
        return try rampOutputGainSync(.init(outputGain: 1, rampMilliseconds: request.rampMilliseconds,
                                            expectedGeneration: request.expectedGeneration,
                                            rampRevision: request.rampRevision))
    }

    public func performSessionControlSync(
        _ command: PlaybackControlCommand,
        payload: PlaybackControlPayload = .init(),
        expectedGeneration: Int? = nil,
        seekRevision: Int? = nil
    ) throws -> PlaybackTransportStatus {
        guard command == .play || command == .pause || command == .seek else {
            throw PlaybackControlError.invalidPayload("Unsupported session control command.")
        }
        return try queue.sync {
            if let expectedGeneration, expectedGeneration != currentPlaybackGeneration {
                throw CancellationError()
            }
            if command == .seek, let seekRevision {
                guard seekRevision > 0, latestSeekRevision.map({ seekRevision > $0 }) ?? true else {
                    throw CancellationError()
                }
                latestSeekRevision = seekRevision
            }
            let event = performLocked(.init(command: command, payload: payload))
            try requireSuccess(event)
            return status(event.status)
        }
    }

    public func stop() async {
        let requestID = reservePlaybackRequest()
        await run {
            if self.isLatest(requestID) { self.retirePlaybackLocked() }
        }
    }

    /// Retire the old session only if this replacement still owns the newest
    /// start request. The check and stop run on the same transport queue.
    @discardableResult
    public func stopForPlaybackRequest(_ requestID: Int) async -> Bool {
        await run { self.stopForPlaybackRequestLocked(requestID) }
    }

    @discardableResult
    public func stopForPlaybackRequestSync(_ requestID: Int) -> Bool {
        queue.sync { stopForPlaybackRequestLocked(requestID) }
    }

    private func stopForPlaybackRequestLocked(_ requestID: Int) -> Bool {
        guard isLatest(requestID) else { return false }
        retirePlaybackLocked()
        return true
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

    /// Starts a continuation after the caller has retired completion. The
    /// request retains archive/member identity so VGMBoy prepares the source
    /// before its serialized native load/play operation.
    public func startContinuation(_ start: PlaybackContinuationStart) async throws {
        try await startContinuation(start, playbackPlan: nil)
    }

    private func startContinuation(_ start: PlaybackContinuationStart, playbackPlan: PlaybackTimingPlan?) async throws {
        let cancellation = OperationCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await run {
                guard !cancellation.isCancelled else { throw CancellationError() }
                try self.validateStartLocked(start)
            }
            let prepared = try await Task.detached(priority: .userInitiated) {
                try self.prepareOutsideTransport(start, isCancelled: { cancellation.isCancelled })
            }.value
            try Task.checkCancellation()
            try await run {
                try self.startContinuationLocked(start, prepared: prepared, isCancelled: { cancellation.isCancelled })
                if let playbackPlan { self.currentPlaybackPlan = playbackPlan }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Synchronous host-bridge entry for a fully typed start request. It uses
    /// the same serialized start sequence as async frontends and preserves the
    /// frontend's stable track ID for status and completion publication.
    public func start(_ start: PlaybackContinuationStart) throws {
        try queue.sync { try self.validateStartLocked(start) }
        let prepared = try prepareOutsideTransport(start)
        try queue.sync {
            try self.startContinuationLocked(start, prepared: prepared)
        }
    }

    /// Resolve the target only while the captured native session still owns
    /// playback. The later guarded start rechecks ownership after preparation.
    public func queuedSkipDecisionSync(_ request: PlaybackQueuedSkipDecisionRequest) -> PlaybackQueueAdjacentResponse? {
        queue.sync {
            if let expected = request.expectedGeneration {
                guard self.matchesCurrentTrackGeneration(expected) else { return nil }
            }
            if let requestID = request.requestID {
                guard !requestID.isEmpty, let generation = request.expectedGeneration else { return nil }
                if self.queuedSkipClaimGeneration != generation {
                    self.queuedSkipClaimGeneration = generation
                    self.queuedSkipClaims.removeAll()
                }
                guard self.queuedSkipClaims.insert(requestID).inserted else { return nil }
            }
            if let target = request.targetTrackID, !target.isEmpty {
                return PlaybackQueueAdjacentResponse(trackID: target)
            }
            return request.navigation?.response
        }
    }

    private func validateStartLocked(_ start: PlaybackContinuationStart) throws {
        guard isLatest(start.requestID),
              start.queuedSkipToken.map({ queuedSkipLifecycle.isCurrent($0) }) ?? true else { throw CancellationError() }
        if let expected = start.expectedPreviousGeneration {
            guard matchesCurrentTrackGeneration(expected) else { throw CancellationError() }
        }
    }

    /// Reconfiguration can reload the same track with a newer native generation.
    /// A replacement start advances the lower bound and rejects older lineages.
    private func matchesCurrentTrackGeneration(_ expected: Int) -> Bool {
        guard expected > 0, let start = currentTrackStartGeneration, let current = currentPlaybackGeneration else { return false }
        return expected >= start && expected <= current
    }

    private func prepareOutsideTransport(_ start: PlaybackContinuationStart,
                                         isCancelled: @escaping @Sendable () -> Bool = { false }) throws -> PlaybackController.PreparedSource {
        let isCurrent = {
            !isCancelled() && self.isLatest(start.requestID)
                && (start.queuedSkipToken.map { self.queuedSkipLifecycle.isCurrent($0) } ?? true)
        }
        while preparationSlots.wait(timeout: .now() + .milliseconds(100)) != .success {
            guard isCurrent() else { throw CancellationError() }
        }
        defer { preparationSlots.signal() }
        guard isCurrent() else { throw CancellationError() }
        do {
            let prepared = try prepareSource(controller, start)
            guard isCurrent() else { throw CancellationError() }
            return prepared
        } catch {
            guard isCurrent() else { throw CancellationError() }
            throw error
        }
    }

    private func startContinuationLocked(_ start: PlaybackContinuationStart, prepared: PlaybackController.PreparedSource,
                                         isCancelled: @escaping @Sendable () -> Bool = { false }) throws {
        let isCurrent: @Sendable () -> Bool = {
            !isCancelled() && self.isLatest(start.requestID)
                && (start.queuedSkipToken.map { self.queuedSkipLifecycle.isCurrent($0) } ?? true)
        }
        guard isCurrent() else { throw CancellationError() }
        try validateStartLocked(start)
        let event = controller.loadPreparedIfCurrent(prepared) {
            isCurrent() && (start.expectedPreviousGeneration.map { self.matchesCurrentTrackGeneration($0) } ?? true)
        }
        do {
            guard isCurrent() else { throw CancellationError() }
            try requireSuccess(event)
            naturalEndGate.reset()
            continuationCoordinator.reset()
            if start.startMilliseconds > 0 {
                try requireSuccess(controller.perform(.init(
                    command: .seek,
                    payload: .init(positionMilliseconds: start.startMilliseconds)
                )))
            }
            guard isCurrent() else { throw CancellationError() }
            try requireSuccess(controller.perform(.init(command: .play)))
            guard isCurrent() else { throw CancellationError() }
        } catch {
            if event.kind != .error || event.status?.diagnostics.generation != currentPlaybackGeneration {
                retirePlaybackLocked()
            }
            throw error
        }
        currentTrack = start.track
        currentPlaybackGeneration = event.status?.diagnostics.generation
        currentTrackStartGeneration = currentPlaybackGeneration
        latestSettingsRevision = nil
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
        invalidatePendingReconfigurationLocked()
        _ = controller.perform(.init(command: .stop))
        currentTrack = nil
        currentPlaybackGeneration = nil
        queuedSkipClaimGeneration = nil
        queuedSkipClaims.removeAll()
        currentTrackStartGeneration = nil
        latestSettingsRevision = nil
        naturalEndGate.reset()
        continuationCoordinator.reset()
    }

    public func beginFadedSkip(duration: TimeInterval) async -> Int? {
        guard duration.isFinite, duration <= Double(Int32.max) / 1_000 else { return nil }
        return await run {
            guard self.currentTrack != nil else { return nil }
            let status = self.controller.perform(.init(command: .status)).status
            guard status?.isPlaying == true else { return nil }
            let milliseconds = max(1, Int((max(0, duration) * 1_000).rounded(.up)))
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

    /// Snapshot reads must not emit a control response: frontends may refresh
    /// status from a status callback and would otherwise create a feedback loop.
    public func status() async -> PlaybackTransportStatus {
        await run { self.status(self.controller.status()) }
    }

    public func statusSync() -> PlaybackTransportStatus {
        queue.sync { status(controller.status()) }
    }

    public func spectrum() -> (left: [Float], right: [Float]) {
        controller.spectrum()
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
        guard seconds.isFinite, seconds <= Double(Int32.max) / 1_000 else {
            throw PlaybackControlError.invalidPayload("Seek is outside the supported millisecond range.")
        }
        let milliseconds = Int(max(0, seconds) * 1_000)
        try await run {
            try self.requireSuccess(self.controller.perform(.init(
                command: .seek,
                payload: .init(positionMilliseconds: milliseconds)
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

    /// Applies the complete audio-output snapshot in one serialized transport
    /// operation. Hosts provide a typed value rather than independently
    /// parsing, normalizing, and sequencing volume/EQ/mono bridge fields.
    public func configureAudio(
        _ request: PlaybackTransportAudioConfigurationRequest
    ) throws -> PlaybackTransportStatus {
        try queue.sync {
            let preferences = request.preferences
            try controller.configureAudio(preferences)
            return status(controller.status())
        }
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
            playMilliseconds: try timingMilliseconds(plan.preFadeSeconds),
            fadeMilliseconds: try timingMilliseconds(plan.fadeSeconds)
        ), cancellation: cancellation, progress: progress)
    }

    public func exportAAC(
        _ request: AACExportRequest,
        cancellation: AACExportCancellation? = nil,
        progress: (@Sendable (AACExportProgress) -> Void)? = nil
    ) throws -> URL {
        if cancellation?.isCancelled == true { throw AACExportError.cancelled }
        // Keep all exports serialized per coordinator, including legacy formats,
        // so parallel renders cannot race for the same output filename.
        while exportSlot.wait(timeout: .now() + .milliseconds(100)) != .success {
            if cancellation?.isCancelled == true { throw AACExportError.cancelled }
        }
        defer { exportSlot.signal() }
        if cancellation?.isCancelled == true { throw AACExportError.cancelled }
        if let prepared = AACExporter.prepareIndependentSPCExport(request) {
            return try prepared.export(cancellation: cancellation, progress: progress).outputURL
        }
        return try queue.sync {
            let result = try controller.exportAAC(request, cancellation: cancellation, progress: progress)
            return result.outputURL
        }
    }

    /// Shared low-level command access for a host bridge. The command is still
    /// serialized here; hosts do not retain their own PlaybackController.
    public func perform(_ request: PlaybackControlRequest) -> PlaybackControlEvent {
        if (request.command == .setTempo || request.command == .setPlaybackMode)
            && request.version == PlaybackControlProtocol.version {
            var result: PlaybackControlEvent?
            do {
                _ = try reconfigure(expectedGeneration: nil, settingsRevision: nil,
                                    lowLevelRequest: request, captureEvent: { result = $0 }) { _ in
                    if request.command == .setTempo {
                        return try self.controller.tempoReconfigurationSettings(request.payload.tempo)
                    }
                    _ = try PlaybackController.validatePlaybackMode(request.payload)
                    return request.payload
                }
                if let result { return result }
            } catch {
                if let result { return result }
                return queue.sync {
                    let current = controller.status()
                    publish(status: current, naturalEnd: false)
                    return PlaybackControlEvent(requestID: request.requestID, kind: .error,
                                                status: current, message: error.localizedDescription)
                }
            }
        }
        if request.command == .stop && request.version == PlaybackControlProtocol.version {
            let requestID = reservePlaybackRequest()
            return queue.sync {
                guard isLatest(requestID) else {
                    return PlaybackControlEvent(requestID: request.requestID, kind: .error,
                                                status: controller.status(), message: CancellationError().localizedDescription)
                }
                return performLocked(request)
            }
        }
        return queue.sync { performLocked(request) }
    }

    private func performLocked(_ request: PlaybackControlRequest) -> PlaybackControlEvent {
        let event = controller.perform(request)
        guard event.kind != .error else {
            if (request.command == .load || request.command == .setPlaybackMode || request.command == .setTempo),
               event.status?.diagnostics.generation != currentPlaybackGeneration {
                retirePlaybackLocked()
            }
            return event
        }
        if request.command == .setPlaybackMode || request.command == .setTempo
            || request.command == .load || request.command == .stop || request.command == .shutdown {
            invalidatePendingReconfigurationLocked()
        }
        switch request.command {
        case .load:
            if let path = request.payload.path, !path.isEmpty {
                self.naturalEndGate.reset()
                currentTrack = PlaybackTransportTrack(
                    id: path,
                    path: path,
                    trackIndex: request.payload.trackIndex ?? 0,
                    archiveEntry: request.payload.archiveEntry
                )
            }
        case .stop, .shutdown:
            currentTrack = nil
            currentPlaybackGeneration = nil
            queuedSkipClaimGeneration = nil
            queuedSkipClaims.removeAll()
            currentTrackStartGeneration = nil
            latestSettingsRevision = nil
            naturalEndGate.reset()
            continuationCoordinator.reset()
        default:
            break
        }
        if request.command == .load || request.command == .setPlaybackMode || request.command == .setTempo {
            let generation = event.status?.diagnostics.generation
            if generation != currentPlaybackGeneration {
                naturalEndGate.reset()
                continuationCoordinator.reset()
            }
            currentPlaybackGeneration = generation
            if request.command == .load {
                currentTrackStartGeneration = generation
                latestSettingsRevision = nil
            }
        }
        return event
    }

    /// Called on the transport queue when the current settings or session is
    /// retired, including changes that leave the native generation unchanged.
    private func invalidatePendingReconfigurationLocked() {
        requestLock.lock()
        reconfigurationEpoch &+= 1
        reconfigurationCandidate = nil
        requestLock.unlock()
        pendingReconfiguration = nil
    }

    private func timingMilliseconds(_ seconds: Int) throws -> Int {
        guard seconds >= 0, seconds <= Int(Int32.max) / 1_000 else {
            throw PlaybackControlError.invalidPayload("Playback timing exceeds the supported millisecond range.")
        }
        return seconds * 1_000
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
            if let generation = self.currentPlaybackGeneration {
                guard status.diagnostics.generation == generation else { return }
            } else if status.statistics.trackIndex != nil {
                return
            }
            if naturalEnd,
               !self.naturalEndGate.shouldPublish(
                   generation: status.diagnostics.generation,
                   currentGeneration: self.currentPlaybackGeneration
               ) { return }
            let snapshot = self.status(status)
            self.statusHandler?(snapshot)
            if naturalEnd { self.naturalEndHandler?(snapshot) }
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
