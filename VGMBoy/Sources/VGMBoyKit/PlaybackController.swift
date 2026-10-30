import Foundation
import VGMBoyArchiveCore

/// Public in-process facade over a single playback session. It deliberately
/// has no queue, playlist, catalog, or persistence knowledge: a host supplies
/// a track path and receives status/end events to apply its own policy.
public final class PlaybackController: @unchecked Sendable {
    public typealias EventHandler = @Sendable (PlaybackControlEvent) -> Void

    private struct LoadedTrack {
        var path: String
        var archiveEntry: String?
        var trackIndex: Int
        var tempo: Double
        var sourceData: Data?
        var loop: PlaybackLoopMetadata?
    }

    private let lock = NSLock()
    private let session: PlaybackSession
    private var activeArchiveMaterializer: ArchiveMaterializer?
    private var mode: PlaybackMode = .fileDefault
    private var explicitPlayMilliseconds: Int?
    private var explicitFadeMilliseconds: Int?
    private var explicitUnknownDurationMilliseconds: Int?
    private var equalizer = EqualizerConfiguration()
    private var loaded: LoadedTrack?
    private var subscribers: [UUID: EventHandler] = [:]

    public init() {
        session = PlaybackSession()
        session.setStatusHandler { [weak self] status in
            self?.emit(PlaybackControlEvent(kind: .status, status: status))
        }
        session.setCompletionStatusHandler { [weak self] status in
            self?.emit(PlaybackControlEvent(kind: .ended, status: status))
        }
    }

    public var controlSurface: PlaybackControlSurface { PlaybackControlSurface() }

    public func diagnostics() -> PlaybackDiagnostics { session.status().diagnostics }
    public func spectrum() -> (left: [Float], right: [Float]) { session.spectrum() }

    public func status() -> PlaybackStatus { session.status() }

    /// Applies all output preferences as one transport operation. The shared
    /// transport calls this instead of emitting one status event per control.
    public func configureAudio(_ preferences: PlaybackPreferences) throws {
        try session.configureAudio(
            volume: preferences.outputVolume,
            equalizer: preferences.equalizer,
            monoEnabled: preferences.monoEnabled
        )
        lock.lock()
        equalizer = preferences.equalizer
        lock.unlock()
    }

    /// Render a finite AAC file without interrupting the controller's live
    /// session. Hosts should call this from their own background task.
    public func exportAAC(
        _ request: AACExportRequest,
        cancellation: AACExportCancellation? = nil,
        progress: (@Sendable (AACExportProgress) -> Void)? = nil
    ) throws -> AACExportResult {
        guard let archiveEntry = request.archiveEntry, !archiveEntry.isEmpty else {
            return try AACExporter.export(request, cancellation: cancellation, progress: progress)
        }
        guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
            throw PlaybackControlError.invalidPayload("VGMBoy does not admit archive member \(archiveEntry).")
        }
        let materializer = ArchiveMaterializer()
        defer { materializer.release() }
        let prepared = try materializer.materializeSource(
            archivePath: request.sourcePath,
            entry: archiveEntry,
            requirement: requirement
        )
        var resolvedRequest = request
        resolvedRequest.sourcePath = prepared.url.path
        resolvedRequest.archiveEntry = nil
        if prepared.isUAC {
            resolvedRequest.readEmbeddedLoopTags = false
            resolvedRequest.loop = prepared.authoredLoop.map { loop in
                PlaybackLoopMetadata(startSample: loop.startSamples, endSample: loop.endSamples,
                                     sampleRateHz: loop.sampleRateHz, repeatCount: loop.repeatCount,
                                     source: loop.source ?? "uac-manifest")
            }
        }
        return try AACExporter.export(resolvedRequest, cancellation: cancellation, progress: progress)
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

    /// Loads a small in-memory source without changing the JSON control
    /// protocol. Used for seekable UAC members whose decoder accepts bytes.
    public func loadInMemory(sourceData: Data, payload: PlaybackControlPayload) -> PlaybackControlEvent {
        do {
            try load(payload, sourceData: sourceData)
            let event = PlaybackControlEvent(kind: .response, status: session.status())
            emit(event)
            return event
        } catch {
            let event = PlaybackControlEvent(kind: .error, status: session.status(), message: error.localizedDescription)
            emit(event)
            return event
        }
    }

    /// Prepares a source, then asks the host whether the request still owns
    /// playback before retiring the current native session.
    public func loadIfCurrent(
        payload: PlaybackControlPayload,
        sourceData: Data? = nil,
        isCurrent: @escaping @Sendable () -> Bool
    ) -> PlaybackControlEvent {
        do {
            try load(payload, sourceData: sourceData, isCurrent: isCurrent)
            let event = PlaybackControlEvent(kind: .response, status: session.status())
            emit(event)
            return event
        } catch {
            let event = PlaybackControlEvent(kind: .error, status: session.status(), message: error.localizedDescription)
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
            lock.lock()
            loaded = nil
            let materializer = activeArchiveMaterializer
            activeArchiveMaterializer = nil
            lock.unlock()
            materializer?.release()
        case .seek:
            guard let milliseconds = request.payload.positionMilliseconds, milliseconds >= 0 else {
                throw PlaybackControlError.invalidPayload("Seek requires a non-negative position in milliseconds.")
            }
            try session.seek(to: Double(milliseconds) / 1_000)
        case .setTempo:
            guard let tempo = request.payload.tempo, tempo.isFinite, tempo > 0 else {
                throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
            }
            lock.lock()
            let current = loaded
            let currentMode = mode
            let currentPlay = explicitPlayMilliseconds
            let currentFade = explicitFadeMilliseconds
            let currentUnknown = explicitUnknownDurationMilliseconds
            lock.unlock()
            guard let current else { throw PlaybackSessionError.notLoaded }
            let family = FormatRegistry.family(for: current.archiveEntry ?? current.path)
            let effectiveTempo = FormatRegistry.effectiveTempo(tempo, family: family)
            if effectiveTempo != session.status().statistics.tempo {
                try configurePlaybackMode(.init(
                    tempo: effectiveTempo, playbackMode: currentMode,
                    playMilliseconds: currentPlay, fadeMilliseconds: currentFade,
                    unknownDurationMilliseconds: currentUnknown
                ))
            }
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
                archiveEntry: request.payload.archiveEntry,
                trackIndex: request.payload.trackIndex ?? 0,
                outputDirectory: URL(fileURLWithPath: directory),
                filenameStem: filenameStem,
                playMilliseconds: playMilliseconds,
                fadeMilliseconds: fadeMilliseconds,
                tempo: request.payload.tempo ?? 1
            ))
            return PlaybackControlEvent(requestID: request.requestID, kind: .response, status: session.status(), message: result.outputURL.path)
        case .status:
            break
        case .subscribe, .shutdown:
            throw PlaybackControlError.unsupportedCommand(request.command)
        }
        return PlaybackControlEvent(requestID: request.requestID, kind: .response, status: session.status())
    }

    @discardableResult
    private func load(_ payload: PlaybackControlPayload) throws -> PlaybackStatus {
        try load(payload, sourceData: nil)
    }

    @discardableResult
    private func load(_ payload: PlaybackControlPayload, sourceData: Data?, isCurrent: (() -> Bool)? = nil) throws -> PlaybackStatus {
        guard let path = payload.path, !path.isEmpty else {
            throw PlaybackControlError.invalidPayload("Load requires a path.")
        }
        let archiveEntry = payload.archiveEntry?.trimmingCharacters(in: .whitespacesAndNewlines)
        let playablePath: String
        var uacMember = false
        var uacLoop: PlaybackLoopMetadata?
        var nextArchiveMaterializer: ArchiveMaterializer?
        defer { nextArchiveMaterializer?.release() }
        if let archiveEntry, !archiveEntry.isEmpty {
            guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
                throw PlaybackControlError.invalidPayload("VGMBoy does not admit archive member \(archiveEntry).")
            }
            let materializer = ArchiveMaterializer()
            nextArchiveMaterializer = materializer
            let prepared = try materializer.materializeSource(
                archivePath: path,
                entry: archiveEntry,
                requirement: requirement
            )
            playablePath = prepared.url.path
            uacMember = prepared.isUAC
            if let loop = prepared.authoredLoop {
                uacLoop = PlaybackLoopMetadata(startSample: loop.startSamples, endSample: loop.endSamples,
                                               sampleRateHz: loop.sampleRateHz, repeatCount: loop.repeatCount,
                                               source: loop.source ?? "uac-manifest")
            }
        } else {
            nextArchiveMaterializer = nil
            playablePath = path
        }
        let trackIndex = payload.trackIndex ?? 0
        let tempo = payload.tempo ?? 1
        guard tempo.isFinite, tempo > 0 else {
            throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
        }
        guard trackIndex >= 0, let family = FormatRegistry.family(for: playablePath) else {
            throw PlaybackControlError.invalidPayload("Track index must be non-negative and the file format must be supported.")
        }
        // UAC member metadata is authoritative, including an absent loop.
        // Standalone files and other archives retain their existing override
        // and embedded-tag precedence.
        let loop = uacMember ? uacLoop : (payload.loop ?? (sourceData == nil
            ? PlaybackLoopTagReader.read(path: playablePath)
            : PlaybackLoopTagReader.read(data: sourceData ?? Data(), extensionName: URL(fileURLWithPath: playablePath).pathExtension)))
        guard isCurrent?() ?? true else { throw CancellationError() }
        if payload.playbackMode != nil || payload.playMilliseconds != nil || payload.fadeMilliseconds != nil || payload.unknownDurationMilliseconds != nil {
            try configurePlaybackMode(payload, reloadCurrent: false)
        }
        let plan = makePlan(family: family)
        let replacedStatus: PlaybackStatus
        do {
            replacedStatus = try session.load(path: playablePath, sourceData: sourceData, trackIndex: trackIndex, plan: plan, tempo: tempo, loop: loop)
        } catch {
            // Session load has already retired the previous decoder. Its
            // metadata and materializer must not outlive that failed session.
            lock.lock()
            let previousMaterializer = activeArchiveMaterializer
            activeArchiveMaterializer = nil
            loaded = nil
            lock.unlock()
            previousMaterializer?.release()
            throw error
        }
        lock.lock()
        let previousMaterializer = activeArchiveMaterializer
        activeArchiveMaterializer = nextArchiveMaterializer
        nextArchiveMaterializer = nil
        loaded = LoadedTrack(path: path, archiveEntry: archiveEntry, trackIndex: trackIndex, tempo: tempo, sourceData: sourceData, loop: loop)
        lock.unlock()
        previousMaterializer?.release()
        return replacedStatus
    }

    private func configurePlaybackMode(_ payload: PlaybackControlPayload, reloadCurrent: Bool = true) throws {
        guard let requestedMode = payload.playbackMode else {
            throw PlaybackControlError.invalidPayload("set_playback_mode requires a playback mode.")
        }
        if let play = payload.playMilliseconds,
           play < 0 || (requestedMode == .timed && play <= 0) {
            throw PlaybackControlError.invalidPayload("Play length must be non-negative for Long Play and positive for timed playback.")
        }
        if let fade = payload.fadeMilliseconds, fade < 0 { throw PlaybackControlError.invalidPayload("Fade length cannot be negative.") }
        if let unknown = payload.unknownDurationMilliseconds, unknown <= 0 {
            throw PlaybackControlError.invalidPayload("Unknown-duration fallback must be positive.")
        }
        let maximumMilliseconds = Int(Int32.max)
        let requestedPlay = payload.playMilliseconds ?? payload.unknownDurationMilliseconds ?? 150_000
        let requestedFade = payload.fadeMilliseconds ?? 6_000
        guard requestedPlay <= maximumMilliseconds,
              requestedFade <= maximumMilliseconds,
              (payload.unknownDurationMilliseconds ?? 0) <= maximumMilliseconds,
              requestedPlay <= maximumMilliseconds - requestedFade else {
            throw PlaybackControlError.invalidPayload("Playback timing exceeds the supported millisecond range.")
        }
        if let tempo = payload.tempo, !tempo.isFinite || tempo <= 0 {
            throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
        }
        lock.lock()
        let previousMode = mode
        let previousPlay = explicitPlayMilliseconds
        let previousFade = explicitFadeMilliseconds
        let previousUnknown = explicitUnknownDurationMilliseconds
        let unchangedTiming = previousMode == requestedMode
            && previousPlay == payload.playMilliseconds
            && previousFade == payload.fadeMilliseconds
            && previousUnknown == payload.unknownDurationMilliseconds
        mode = requestedMode
        explicitPlayMilliseconds = payload.playMilliseconds
        explicitFadeMilliseconds = payload.fadeMilliseconds
        explicitUnknownDurationMilliseconds = payload.unknownDurationMilliseconds
        let current = loaded
        lock.unlock()
        guard reloadCurrent, let current else { return }
        let previousStatus = session.status()
        let family = FormatRegistry.family(for: current.archiveEntry ?? current.path)
        let nextTempo = FormatRegistry.effectiveTempo(payload.tempo ?? current.tempo, family: family)
        if unchangedTiming && nextTempo == previousStatus.statistics.tempo { return }
        do {
            let replacedStatus = try load(
                PlaybackControlPayload(path: current.path, archiveEntry: current.archiveEntry, trackIndex: current.trackIndex, tempo: payload.tempo ?? current.tempo, loop: current.loop),
                sourceData: current.sourceData
            )
            let resumeSeconds = replacedStatus.elapsedSeconds * replacedStatus.statistics.tempo / nextTempo
            if resumeSeconds > 0 { try session.seek(to: resumeSeconds) }
            if replacedStatus.isPlaying { try session.play() }
        } catch {
            if session.status().diagnostics.generation == previousStatus.diagnostics.generation {
                // Preparation failed before replacing the active decoder.
                lock.lock()
                mode = previousMode
                explicitPlayMilliseconds = previousPlay
                explicitFadeMilliseconds = previousFade
                explicitUnknownDurationMilliseconds = previousUnknown
                lock.unlock()
            } else {
                // Replacement began; no partially loaded session remains active.
                session.stop()
                lock.lock()
                let materializer = activeArchiveMaterializer
                activeArchiveMaterializer = nil
                loaded = nil
                lock.unlock()
                materializer?.release()
            }
            throw error
        }
    }

    private func makePlan(family: DecoderFamily) -> PlaybackPlan {
        lock.lock()
        let mode = self.mode
        let play = explicitPlayMilliseconds
        let fade = explicitFadeMilliseconds ?? 6_000
        let unknown = explicitUnknownDurationMilliseconds
        lock.unlock()
        return Self.plan(
            mode: mode,
            playMilliseconds: play,
            fadeMilliseconds: fade,
            unknownDurationMilliseconds: unknown,
            family: family
        )
    }

    /// Converts a public playback request into one consistent decode window.
    /// A requested fade must select the bounded path so every decoder either
    /// applies its own fade or receives the session's shared output fade.
    static func plan(
        mode: PlaybackMode,
        playMilliseconds: Int?,
        fadeMilliseconds: Int,
        unknownDurationMilliseconds: Int? = nil,
        family: DecoderFamily
    ) -> PlaybackPlan {
        let play = max(0, playMilliseconds ?? unknownDurationMilliseconds ?? 150_000)
        let fade = max(0, fadeMilliseconds)
        switch mode {
        case .fileDefault:
            return PlaybackPlan(
                preFadeMilliseconds: play,
                fadeMilliseconds: fade,
                isLongPlay: false,
                usesNativeEnding: family.hasNaturalEnding && fade == 0,
                usesDecoderNaturalDuration: playMilliseconds == nil
            )
        case .longPlay:
            guard family.supportsLongPlay else { return fileDefaultPlan(play: play, fade: fade, family: family) }
            return PlaybackPlan(preFadeMilliseconds: play, fadeMilliseconds: fade, isLongPlay: true, usesNativeEnding: false)
        case .timed:
            return PlaybackPlan(preFadeMilliseconds: play, fadeMilliseconds: fade, isLongPlay: false, usesNativeEnding: false)
        }
    }

    private static func fileDefaultPlan(play: Int, fade: Int, family: DecoderFamily) -> PlaybackPlan {
        PlaybackPlan(
            preFadeMilliseconds: play,
            fadeMilliseconds: fade,
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
