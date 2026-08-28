import Foundation

/// Device/output health only. It deliberately contains no decoder tags,
/// catalog values, or queue policy; a frontend may present it for diagnosis.
public struct PlaybackDiagnostics: Sendable, Codable, Equatable {
    public var generation: Int
    public var bufferedFrames: Int
    public var capacityFrames: Int
    public var framesRequested: Int64
    public var framesSupplied: Int64
    public var framesWritten: Int64
    public var underrunCount: Int64
    public var isOutputRunning: Bool
    public var sampleRate: Int

    public init(
        generation: Int = 0,
        bufferedFrames: Int = 0,
        capacityFrames: Int = 0,
        framesRequested: Int64 = 0,
        framesSupplied: Int64 = 0,
        framesWritten: Int64 = 0,
        underrunCount: Int64 = 0,
        isOutputRunning: Bool = false,
        sampleRate: Int = 44_100
    ) {
        self.generation = generation
        self.bufferedFrames = bufferedFrames
        self.capacityFrames = capacityFrames
        self.framesRequested = framesRequested
        self.framesSupplied = framesSupplied
        self.framesWritten = framesWritten
        self.underrunCount = underrunCount
        self.isOutputRunning = isOutputRunning
        self.sampleRate = sampleRate
    }
}

/// Decoder and transport facts suitable for a frontend's diagnostics panel.
/// This intentionally omits presentation fields such as title or “now
/// playing”; catalog and queue ownership remain in the host application.
public struct PlaybackStatistics: Sendable, Codable, Equatable {
    public var decoderFamily: String?
    public var trackIndex: Int?
    public var decoderSampleRate: Int
    public var outputSampleRate: Int
    public var decodedFrames: Int64
    public var audiblePositionFrames: Int64
    public var tempo: Double

    public init(
        decoderFamily: String? = nil,
        trackIndex: Int? = nil,
        decoderSampleRate: Int = 0,
        outputSampleRate: Int = 0,
        decodedFrames: Int64 = 0,
        audiblePositionFrames: Int64 = 0,
        tempo: Double = 1
    ) {
        self.decoderFamily = decoderFamily
        self.trackIndex = trackIndex
        self.decoderSampleRate = decoderSampleRate
        self.outputSampleRate = outputSampleRate
        self.decodedFrames = decodedFrames
        self.audiblePositionFrames = audiblePositionFrames
        self.tempo = tempo
    }
}

public struct PlaybackStatus: Sendable, Codable, Equatable {
    public var isPlaying: Bool
    public var elapsedSeconds: Double
    public var reachedEnd: Bool
    public var errorMessage: String?
    public var diagnostics: PlaybackDiagnostics
    public var statistics: PlaybackStatistics

    public init(
        isPlaying: Bool,
        elapsedSeconds: Double,
        reachedEnd: Bool,
        errorMessage: String? = nil,
        diagnostics: PlaybackDiagnostics = .init(),
        statistics: PlaybackStatistics = .init()
    ) {
        self.isPlaying = isPlaying
        self.elapsedSeconds = elapsedSeconds
        self.reachedEnd = reachedEnd
        self.errorMessage = errorMessage
        self.diagnostics = diagnostics
        self.statistics = statistics
    }
}

public enum PlaybackSessionError: LocalizedError {
    case notLoaded

    public var errorDescription: String? {
        "No track is loaded."
    }
}

/// The transport home. Owns the decoder, the ring buffer, and the audio
/// device, and serializes all control on one queue. Position is
/// decoder-authoritative (absolute decoded frames), so seeks and long-play
/// reconfiguration never lose the timeline.
final class PlaybackSession: @unchecked Sendable {
    private let queue = DispatchQueue(label: "VGMBoy.playback-session", qos: .userInitiated)
    private let sampleRate = 44_100
    private let chunkFrameCount = 4096
    private let output: AudioOutput
    private var decoder: (any AudioDecoder)?
    private var capFrames: Int64 = 0
    private var fadeFrames: Int64 = 0
    private var currentTrackIndex = 0
    private var decoderFamily: String?
    private var currentTempo = 1.0
    private var reachedEnd = false
    private var errorMessage: String?
    private var isLoaded = false
    private var generation = 0
    private var refillTimer: DispatchSourceTimer?
    private var lastProgressStatusUptime: TimeInterval = 0
    private var statusHandler: (@Sendable (PlaybackStatus) -> Void)?
    private var completionHandler: (@Sendable () -> Void)?

    public init() {
        output = AudioOutput()
    }

    public func setStatusHandler(_ handler: (@Sendable (PlaybackStatus) -> Void)?) {
        queue.async { self.statusHandler = handler }
    }

    public func setCompletionHandler(_ handler: (@Sendable () -> Void)?) {
        queue.async { self.completionHandler = handler }
    }

    public func load(
        path: String,
        trackIndex: Int,
        plan: PlaybackPlan,
        tempo: Double
    ) throws {
        try queue.sync {
            releaseCurrent()
            generation += 1
            guard let family = FormatRegistry.family(for: path) else {
                throw DecoderFactoryError.unsupportedFamily(
                    (path as NSString).pathExtension
                )
            }
            let decoder = try DecoderFactory.make(path: path, sampleRate: sampleRate)
            try decoder.startTrack(trackIndex)
            decoder.setTempo(tempo)

            let metadata = try decoder.metadata(for: trackIndex)
            if plan.usesNativeEnding {
                if metadata.hasTiming {
                    let fadeMilliseconds = max(0, metadata.fadeMs)
                    if decoder.appliesFadeInternally {
                        decoder.configureNativeEnding(
                            playMs: metadata.naturalPlayMs,
                            fadeMs: fadeMilliseconds
                        )
                        capFrames = 0
                        fadeFrames = 0
                    } else {
                        // Some cores (notably Highly Complete/mGBA) expose
                        // authored timing but do not own the fade DSP. Keep
                        // the tagged play length, then apply the shared
                        // output fade at the session boundary.
                        decoder.configureFade(
                            playMs: metadata.naturalPlayMs,
                            fadeMs: fadeMilliseconds
                        )
                        capFrames = Int64(metadata.naturalPlayMs + fadeMilliseconds) * Int64(sampleRate) / 1_000
                        fadeFrames = Int64(fadeMilliseconds) * Int64(sampleRate) / 1_000
                    }
                } else {
                    decoder.configureNativeEnding(playMs: 0, fadeMs: 0)
                    capFrames = Int64(plan.preFadeSeconds) * Int64(sampleRate)
                    fadeFrames = 0
                }
            } else {
                let naturalPlayMilliseconds = plan.usesDecoderNaturalDuration && metadata.naturalPlayMs > 0
                    ? metadata.naturalPlayMs
                    : plan.preFadeSeconds * 1_000
                decoder.configureFade(
                    playMs: naturalPlayMilliseconds,
                    fadeMs: plan.fadeSeconds * 1000
                )
                capFrames = Int64(naturalPlayMilliseconds + plan.fadeSeconds * 1_000) * Int64(sampleRate) / 1_000
                fadeFrames = decoder.appliesFadeInternally
                    ? 0
                    : Int64(plan.fadeSeconds) * Int64(sampleRate)
            }

            self.decoder = decoder
            currentTrackIndex = trackIndex
            decoderFamily = family.id
            currentTempo = tempo
            reachedEnd = false
            errorMessage = nil
            isLoaded = true
            output.clearBuffer()
            output.resetDiagnostics()
            try prime(to: output.primeFrameCount)
            publishStatus()
        }
    }

    public func play() throws {
        try queue.sync {
            guard isLoaded else { throw PlaybackSessionError.notLoaded }
            guard !output.isRunning else { return }
            reachedEnd = false
            try output.start()
            startRefillTimer()
            publishStatus()
        }
    }

    public func pause() {
        queue.sync {
            stopRefillTimer()
            output.pause()
            publishStatus()
        }
    }

    public func seek(to seconds: Double) throws {
        try queue.sync {
            guard let decoder else { return }
            let wasPlaying = output.isRunning
            if wasPlaying { output.pause() }
            stopRefillTimer()
            reachedEnd = false
            decoder.seek(milliseconds: Int(seconds * 1000))
            output.clearBuffer()
            try prime(to: output.primeFrameCount)
            if wasPlaying {
                try output.start()
                startRefillTimer()
            }
            publishStatus()
        }
    }

    public func setTempo(_ tempo: Double) throws {
        try queue.sync {
            guard let decoder else { throw PlaybackSessionError.notLoaded }
            guard tempo.isFinite, tempo > 0 else {
                throw PlaybackControlError.invalidPayload("Tempo must be a positive finite value.")
            }
            let wasPlaying = output.isRunning
            if wasPlaying { output.pause() }
            stopRefillTimer()
            decoder.setTempo(tempo)
            output.clearBuffer()
            try prime(to: output.primeFrameCount)
            if wasPlaying {
                try output.start()
                startRefillTimer()
            }
            publishStatus()
        }
    }

    public func setEqualizer(_ configuration: EqualizerConfiguration) throws {
        guard configuration.isValid else {
            throw PlaybackControlError.invalidPayload("Equalizer requires exactly 10 finite gains.")
        }
        queue.sync {
            output.setEqualizer(configuration)
        }
    }

    public func setOutputVolume(_ volume: Float) throws {
        guard volume.isFinite, (0...1).contains(volume) else {
            throw PlaybackControlError.invalidPayload("Output volume must be finite and between 0 and 1.")
        }
        queue.sync { output.setVolume(volume) }
    }

    public func setMonoEnabled(_ enabled: Bool) {
        queue.sync { output.setMonoEnabled(enabled) }
    }

    public func rampOutputGain(to gain: Float, durationMilliseconds: Int) throws {
        guard gain.isFinite, (0...1).contains(gain), durationMilliseconds > 0 else {
            throw PlaybackControlError.invalidPayload("Output ramp requires a gain between zero and one and a positive duration.")
        }
        queue.sync { output.rampTransportGain(to: gain, durationMilliseconds: durationMilliseconds) }
    }

    public func stop() {
        queue.sync {
            releaseCurrent()
            publishStatus()
        }
    }

    public func status() -> PlaybackStatus {
        queue.sync {
            makeStatus()
        }
    }

    private func makeStatus() -> PlaybackStatus {
        var diagnostics = output.diagnostics()
        diagnostics.generation = generation
        // Decoder position is intentionally ahead of audible time while the
        // producer primes/refills the ring. Report consumed PCM, not decoded
        // PCM, so a freshly loaded track still reads 0:00 and seek remains
        // anchored at the requested audible offset.
        let elapsed = decoder.map {
            Double(max(0, $0.absolutePlayedFrames - Int64(diagnostics.bufferedFrames))) / Double(sampleRate)
        } ?? 0
        let decodedFrames = decoder?.absolutePlayedFrames ?? 0
        let statistics = PlaybackStatistics(
            decoderFamily: decoderFamily,
            trackIndex: isLoaded ? currentTrackIndex : nil,
            decoderSampleRate: decoder?.sampleRate ?? 0,
            outputSampleRate: diagnostics.sampleRate,
            decodedFrames: decodedFrames,
            audiblePositionFrames: max(0, decodedFrames - Int64(diagnostics.bufferedFrames)),
            tempo: currentTempo
        )
        return PlaybackStatus(
            isPlaying: output.isRunning,
            elapsedSeconds: elapsed,
            reachedEnd: reachedEnd,
            errorMessage: errorMessage,
            diagnostics: diagnostics,
            statistics: statistics
        )
    }

    private func publishStatus() {
        let status = makeStatus()
        let handler = statusHandler
        DispatchQueue.main.async {
            handler?(status)
        }
    }

    private func startRefillTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            self?.refill()
        }
        refillTimer = timer
        timer.resume()
    }

    private func stopRefillTimer() {
        refillTimer?.cancel()
        refillTimer = nil
    }

    private func refill() {
        guard let decoder else { return }
        let highWater = Int(Double(output.capacityFrames) * 0.75)
        while output.bufferedFrames < highWater {
            if decoder.trackEnded || (capFrames > 0 && decoder.absolutePlayedFrames >= capFrames) {
                reachedEnd = true
                break
            }
            let chunkStart = decoder.absolutePlayedFrames
            let frames: (left: [Float], right: [Float])
            do {
                frames = try decoder.readFrames(chunkFrameCount)
            } catch {
                stopRefillTimer()
                output.pause()
                errorMessage = error.localizedDescription
                publishStatus()
                return
            }
            let faded = applyFadeIfNeeded(decoder, chunkStart: chunkStart, left: frames.left, right: frames.right)
            if output.write(left: faded.left, right: faded.right) == 0 {
                break
            }
        }
        if reachedEnd {
            if output.bufferedFrames == 0 {
                finishReachedEnd()
            } else {
                publishStatus()
            }
        } else {
            publishProgressStatusIfDue()
        }
    }

    /// Progress is a presentation signal, not an audio callback contract.
    /// Keep it comfortably below the 50 Hz refill cadence so native hosts can
    /// render elapsed time and diagnostics without polling or flooding their
    /// UI bridges.
    private func publishProgressStatusIfDue() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastProgressStatusUptime >= 0.25 else { return }
        lastProgressStatusUptime = now
        publishStatus()
    }

    private func finishReachedEnd() {
        stopRefillTimer()
        output.pause()
        publishStatus()
        let handler = completionHandler
        DispatchQueue.main.async {
            handler?()
        }
    }

    private func prime(to targetBufferedFrames: Int) throws {
        guard let decoder else { return }
        while output.bufferedFrames < targetBufferedFrames {
            if decoder.trackEnded || (capFrames > 0 && decoder.absolutePlayedFrames >= capFrames) {
                reachedEnd = true
                break
            }
            let chunkStart = decoder.absolutePlayedFrames
            let frames = try decoder.readFrames(chunkFrameCount)
            let faded = applyFadeIfNeeded(decoder, chunkStart: chunkStart, left: frames.left, right: frames.right)
            if output.write(left: faded.left, right: faded.right) == 0 {
                break
            }
        }
    }

    /// Applies a linear fade-out across the final `fadeFrames` before the cap.
    /// Only for decoders that cannot fade internally; the decoder's own
    /// position must be sampled before the read so gains line up with the
    /// real (not padded) frames.
    private func applyFadeIfNeeded(_ decoder: any AudioDecoder, chunkStart: Int64, left: [Float], right: [Float]) -> (left: [Float], right: [Float]) {
        guard !decoder.appliesFadeInternally, fadeFrames > 0, capFrames > 0 else { return (left, right) }
        let fadeStart = capFrames - fadeFrames
        var fadedLeft = left
        var fadedRight = right
        for index in 0..<left.count {
            let position = chunkStart + Int64(index)
            guard position >= fadeStart else { continue }
            let gain = Self.fadeGain(position: position, capFrames: capFrames, fadeFrames: fadeFrames)
            fadedLeft[index] = gain * left[index]
            fadedRight[index] = gain * right[index]
        }
        return (fadedLeft, fadedRight)
    }

    static func fadeGain(position: Int64, capFrames: Int64, fadeFrames: Int64) -> Float {
        guard fadeFrames > 0 else { return 1 }
        let remaining = capFrames - position
        let gain = Double(remaining) / Double(fadeFrames)
        return Float(min(1, max(0, gain)))
    }

    private func releaseCurrent() {
        stopRefillTimer()
        // Preserve queued PCM while AudioOutput ramps it to silence.  Clearing
        // first makes the source node jump from the last nonzero sample to a
        // zero-filled buffer before the transport envelope can act.
        output.pause()
        decoder?.close()
        decoder = nil
        decoderFamily = nil
        currentTempo = 1
        capFrames = 0
        fadeFrames = 0
        reachedEnd = false
        errorMessage = nil
        isLoaded = false
        output.clearBuffer()
    }
}
