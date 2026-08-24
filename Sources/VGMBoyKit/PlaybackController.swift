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

    /// Render a finite AAC file without interrupting the controller's live
    /// session. Hosts should call this from their own background task.
    public func exportAAC(_ request: AACExportRequest) throws -> AACExportResult {
        try AACExporter.export(request)
    }

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
        case .rampOutputGain:
            guard let gain = request.payload.outputGain,
                  let duration = request.payload.rampMilliseconds else {
                throw PlaybackControlError.invalidPayload("ramp_output_gain requires a gain and duration.")
            }
            try session.rampOutputGain(to: gain, durationMilliseconds: duration)
        case .setMonoEnabled:
            guard let enabled = request.payload.monoEnabled else {
                throw PlaybackControlError.invalidPayload("set_mono_enabled requires a boolean.")
            }
            session.setMonoEnabled(enabled)
        case .exportAAC:
            guard let path = request.payload.path,
                  let directory = request.payload.exportDirectory,
                  let filenameStem = request.payload.exportFilenameStem,
                  let playMilliseconds = request.payload.playMilliseconds,
                  let fadeMilliseconds = request.payload.fadeMilliseconds else {
                throw PlaybackControlError.invalidPayload("export_aac requires a path, folder, filename, play length, and fade length.")
            }
            let result = try exportAAC(AACExportRequest(
                sourcePath: path,
                trackIndex: request.payload.trackIndex ?? 0,
                outputDirectory: URL(fileURLWithPath: directory),
                filenameStem: filenameStem,
                playMilliseconds: playMilliseconds,
                fadeMilliseconds: fadeMilliseconds
            ))
            return PlaybackControlEvent(requestID: request.requestID, kind: .response, status: session.status(), message: result.outputURL.path)
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
        guard trackIndex >= 0, let family = FormatRegistry.family(for: path) else {
            throw PlaybackControlError.invalidPayload("Track index must be non-negative and the file format must be supported.")
        }
        let plan = makePlan(family: family)
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

    private func makePlan(family: DecoderFamily) -> PlaybackPlan {
        lock.lock()
        let mode = self.mode
        let play = explicitPlayMilliseconds
        let fade = explicitFadeMilliseconds ?? 6_000
        lock.unlock()
        return Self.plan(mode: mode, playMilliseconds: play, fadeMilliseconds: fade, family: family)
    }

    /// Converts a public playback request into one consistent decode window.
    /// A requested fade must select the bounded path so every decoder either
    /// applies its own fade or receives the session's shared output fade.
    static func plan(
        mode: PlaybackMode,
        playMilliseconds: Int?,
        fadeMilliseconds: Int,
        family: DecoderFamily
    ) -> PlaybackPlan {
        let play = max(1, (playMilliseconds ?? 150_000) / 1_000)
        let fade = max(0, fadeMilliseconds / 1_000)
        switch mode {
        case .fileDefault:
            return PlaybackPlan(
                preFadeSeconds: play,
                fadeSeconds: fade,
                isLongPlay: false,
                usesNativeEnding: family.hasNaturalEnding && fade == 0,
                usesDecoderNaturalDuration: playMilliseconds == nil
            )
        case .longPlay:
            guard family.supportsLongPlay else { return fileDefaultPlan(play: play, fade: fade, family: family) }
            return PlaybackPlan(preFadeSeconds: play, fadeSeconds: fade, isLongPlay: true, usesNativeEnding: false)
        case .timed:
            return PlaybackPlan(preFadeSeconds: play, fadeSeconds: fade, isLongPlay: false, usesNativeEnding: false)
        }
    }

    private static func fileDefaultPlan(play: Int, fade: Int, family: DecoderFamily) -> PlaybackPlan {
        PlaybackPlan(
            preFadeSeconds: play,
            fadeSeconds: fade,
            isLongPlay: false,
            usesNativeEnding: family.hasNaturalEnding && fade == 0,
            usesDecoderNaturalDuration: false
        )
    }

    private func emit(_ event: PlaybackControlEvent) {
        lock.lock()
        let handlers = Array(subscribers.values)
        lock.unlock()
        handlers.forEach { $0(event) }
    }
}
