import Foundation

/// Public in-process facade over a single playback session. It deliberately
/// has no queue, playlist, catalog, or persistence knowledge: a host supplies
/// a track path and receives status/end events to apply its own policy.
public final class PlaybackController: @unchecked Sendable {
    public typealias EventHandler = @Sendable (PlaybackControlEvent) -> Void

    private struct LoadedTrack {
        var path: String
        var trackIndex: Int
        var tempo: Double
    }

    private let lock = NSLock()
    private let session: PlaybackSession
    private var mode: PlaybackMode = .fileDefault
    private var explicitPlayMilliseconds: Int?
    private var explicitFadeMilliseconds: Int?
    private var equalizer = EqualizerConfiguration()
    private var loaded: LoadedTrack?
    private var subscribers: [UUID: EventHandler] = [:]

    public init() {
        session = PlaybackSession()
        session.setStatusHandler { [weak self] status in
            self?.emit(PlaybackControlEvent(kind: .status, status: status))
        }
        session.setCompletionHandler { [weak self] in
            guard let self else { return }
            self.emit(PlaybackControlEvent(kind: .ended, status: self.session.status()))
        }
    }

    public var controlSurface: PlaybackControlSurface { PlaybackControlSurface() }

    public func diagnostics() -> PlaybackDiagnostics { session.status().diagnostics }

    @discardableResult
    public func subscribe(_ handler: @escaping EventHandler) -> UUID {
        let token = UUID()
        lock.lock()
        subscribers[token] = handler
        lock.unlock()
        handler(PlaybackControlEvent(kind: .ready, status: session.status()))
        return token
    }

    public func unsubscribe(_ token: UUID) {
        lock.lock()
        subscribers[token] = nil
        lock.unlock()
    }

    /// Executes a core command locally. `subscribe` is represented by the
    /// callback API above because an in-process call has no durable stream to
    /// attach to; `shutdown` is intentionally not an app-lifecycle command.
    public func perform(_ request: PlaybackControlRequest) -> PlaybackControlEvent {
        do {
            let event = try execute(request)
            emit(event)
            return event
        } catch {
            let event = PlaybackControlEvent(
                requestID: request.requestID,
                kind: .error,
                status: session.status(),
                message: error.localizedDescription
            )
            emit(event)
            return event
        }
    }

    private func execute(_ request: PlaybackControlRequest) throws -> PlaybackControlEvent {
        guard request.version == PlaybackControlProtocol.version else {
            throw PlaybackControlError.invalidPayload("Unsupported control API version \(request.version).")
        }
        switch request.command {
        case .inspect:
            guard let path = request.payload.path, !path.isEmpty else {
                throw PlaybackControlError.invalidPayload("Inspect requires a path.")
            }
            return PlaybackControlEvent(requestID: request.requestID, kind: .response, inspection: try AudioInspector.inspect(path: path))
        case .load:
            try load(request.payload)
        case .play:
            try session.play()
        case .pause:
            session.pause()
        case .stop:
            session.stop()
            lock.lock(); loaded = nil; lock.unlock()
        case .seek:
            guard let milliseconds = request.payload.positionMilliseconds, milliseconds >= 0 else {
                throw PlaybackControlError.invalidPayload("Seek requires a non-negative position in milliseconds.")
            }
            try session.seek(to: Double(milliseconds) / 1_000)
        case .setTempo:
            guard let tempo = request.payload.tempo, tempo.isFinite, tempo > 0 else {
                throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
            }
            try session.setTempo(tempo)
            lock.lock()
            if loaded != nil { loaded?.tempo = tempo }
            lock.unlock()
        case .setPlaybackMode:
            try configurePlaybackMode(request.payload)
        case .setEqualizer:
            guard let equalizer = request.payload.equalizer else {
                throw PlaybackControlError.invalidPayload("set_equalizer requires an equalizer configuration.")
            }
            try session.setEqualizer(equalizer)
            lock.lock(); self.equalizer = equalizer; lock.unlock()
        case .setOutputVolume:
            guard let volume = request.payload.outputVolume else {
                throw PlaybackControlError.invalidPayload("set_output_volume requires a volume.")
            }
            try session.setOutputVolume(volume)
        case .setMonoEnabled:
            guard let enabled = request.payload.monoEnabled else {
                throw PlaybackControlError.invalidPayload("set_mono_enabled requires a boolean.")
            }
            session.setMonoEnabled(enabled)
        case .status:
            break
        case .subscribe, .shutdown:
            throw PlaybackControlError.unsupportedCommand(request.command)
        }
        return PlaybackControlEvent(requestID: request.requestID, kind: .response, status: session.status())
    }

    private func load(_ payload: PlaybackControlPayload) throws {
        guard let path = payload.path, !path.isEmpty else {
            throw PlaybackControlError.invalidPayload("Load requires a path.")
        }
        let trackIndex = payload.trackIndex ?? 0
        let tempo = payload.tempo ?? 1
        guard tempo.isFinite, tempo > 0 else {
            throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
        }
        if payload.playbackMode != nil || payload.playMilliseconds != nil || payload.fadeMilliseconds != nil {
            try configurePlaybackMode(payload, reloadCurrent: false)
        }
        let inspection = try AudioInspector.inspect(path: path)
        guard inspection.tracks.indices.contains(trackIndex),
              let family = FormatRegistry.family(for: path) else {
            throw PlaybackControlError.invalidPayload("Track index is not available for this file.")
        }
        let plan = makePlan(family: family, metadata: inspection.tracks[trackIndex])
        _ = try session.load(path: path, trackIndex: trackIndex, plan: plan, tempo: tempo)
        lock.lock(); loaded = LoadedTrack(path: path, trackIndex: trackIndex, tempo: tempo); lock.unlock()
    }

    private func configurePlaybackMode(_ payload: PlaybackControlPayload, reloadCurrent: Bool = true) throws {
        guard let requestedMode = payload.playbackMode else {
            throw PlaybackControlError.invalidPayload("set_playback_mode requires a playback mode.")
        }
        if let play = payload.playMilliseconds, play <= 0 { throw PlaybackControlError.invalidPayload("Play length must be positive.") }
        if let fade = payload.fadeMilliseconds, fade < 0 { throw PlaybackControlError.invalidPayload("Fade length cannot be negative.") }
        lock.lock()
        mode = requestedMode
        explicitPlayMilliseconds = payload.playMilliseconds
        explicitFadeMilliseconds = payload.fadeMilliseconds
        let current = loaded
        lock.unlock()
        guard reloadCurrent, let current else { return }
        let previousStatus = session.status()
        try load(PlaybackControlPayload(path: current.path, trackIndex: current.trackIndex, tempo: current.tempo))
        if previousStatus.elapsedSeconds > 0 { try session.seek(to: previousStatus.elapsedSeconds) }
        if previousStatus.isPlaying { try session.play() }
    }

    private func makePlan(family: DecoderFamily, metadata: TrackMetadata) -> PlaybackPlan {
        lock.lock()
        let mode = self.mode
        let play = explicitPlayMilliseconds ?? 150_000
        let fade = explicitFadeMilliseconds ?? metadata.fadeMs
        lock.unlock()
        switch mode {
        case .fileDefault:
            return TimingPolicy.plan(
                supportsLongPlay: family.supportsLongPlay, metadata: metadata,
                longPlayEnabled: false, manualSeconds: play / 1_000,
                fadeSeconds: max(0, fade / 1_000), hasNaturalEnding: family.hasNaturalEnding
            )
        case .longPlay:
            return TimingPolicy.plan(
                supportsLongPlay: family.supportsLongPlay, metadata: metadata,
                longPlayEnabled: true, manualSeconds: max(1, play / 1_000),
                fadeSeconds: max(0, fade / 1_000), hasNaturalEnding: family.hasNaturalEnding
            )
        case .timed:
            return PlaybackPlan(preFadeSeconds: max(1, play / 1_000), fadeSeconds: max(0, fade / 1_000), isLongPlay: false, usesNativeEnding: false)
        }
    }

    private func emit(_ event: PlaybackControlEvent) {
        lock.lock()
        let handlers = Array(subscribers.values)
        lock.unlock()
        handlers.forEach { $0(event) }
    }
}
