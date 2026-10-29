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
    public var trackCount: Int?
    public var decoderSampleRate: Int
    public var outputSampleRate: Int
    public var decodedFrames: Int64
    public var audiblePositionFrames: Int64
    public var tempo: Double

    public init(
        decoderFamily: String? = nil,
        trackIndex: Int? = nil,
        trackCount: Int? = nil,
        decoderSampleRate: Int = 0,
        outputSampleRate: Int = 0,
        decodedFrames: Int64 = 0,
        audiblePositionFrames: Int64 = 0,
        tempo: Double = 1
    ) {
        self.decoderFamily = decoderFamily
        self.trackIndex = trackIndex
        self.trackCount = trackCount
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
    private let makeDecoder: (String, Data?, Int) throws -> any AudioDecoder
    private var decoder: (any AudioDecoder)?
    private var capFrames: Int64 = 0
    private var fadeFrames: Int64 = 0
    private var currentTrackIndex = 0
    private var decoderFamily: String?
    private var currentTempo = 1.0
    private var initialLoop: PlaybackLoopMetadata?
    private var playbackLoop: PlaybackLoopMetadata?
    private var remainingLoopRepeats: Int?
    private var longPlayRepeatsVGMAtEnd = false
    private var longPlayVGMTrackFrames: Int64 = 0
    private var sessionFrames: Int64 = 0
    private var reachedEnd = false
    private var errorMessage: String?
    private var isLoaded = false
    private var generation = 0
    private var refillTimer: DispatchSourceTimer?
    private var lastProgressStatusUptime: TimeInterval = 0
    private var statusHandler: (@Sendable (PlaybackStatus) -> Void)?
    private var completionHandler: (@Sendable () -> Void)?
    private var completionStatusHandler: (@Sendable (PlaybackStatus) -> Void)?

    public init() {
        output = AudioOutput()
        makeDecoder = { try DecoderFactory.make(path: $0, sourceData: $1, sampleRate: $2) }
    }

    init(output: AudioOutput, makeDecoder: @escaping (String, Data?, Int) throws -> any AudioDecoder = {
        try DecoderFactory.make(path: $0, sourceData: $1, sampleRate: $2)
    }) {
        self.output = output
        self.makeDecoder = makeDecoder
    }

    func spectrum() -> (left: [Float], right: [Float]) { output.spectrum() }

    public func setStatusHandler(_ handler: (@Sendable (PlaybackStatus) -> Void)?) {
        queue.async { self.statusHandler = handler }
    }

    public func setCompletionHandler(_ handler: (@Sendable () -> Void)?) {
        queue.async { self.completionHandler = handler }
    }

    func setCompletionStatusHandler(_ handler: (@Sendable (PlaybackStatus) -> Void)?) {
        queue.async { self.completionStatusHandler = handler }
    }

    @discardableResult
    public func load(
        path: String,
        sourceData: Data? = nil,
        trackIndex: Int,
        plan: PlaybackPlan,
        tempo: Double,
        loop: PlaybackLoopMetadata? = nil
    ) throws -> PlaybackStatus {
        try queue.sync {
            // Preparation happens before this session turn. Capture the old
            // audible position only after its pause envelope has consumed PCM.
            stopRefillTimer()
            let wasPlaying = output.isRunning
            output.pause()
            var previousStatus = makeStatus()
            previousStatus.isPlaying = wasPlaying
            releaseCurrent()
            generation += 1
            var loadedSuccessfully = false
            defer {
                if !loadedSuccessfully {
                    releaseCurrent()
                    publishStatus()
                }
            }
            guard let family = FormatRegistry.family(for: path) else {
                throw DecoderFactoryError.unsupportedFamily(
                    (path as NSString).pathExtension
                )
            }
            let decoder = try makeDecoder(path, sourceData, sampleRate)
            // Adopt the native resource immediately so failed track setup or
            // metadata reads run the same explicit cleanup as failed priming.
            self.decoder = decoder
            try decoder.startTrack(trackIndex)
            let effectiveTempo = FormatRegistry.effectiveTempo(tempo, family: family)
            decoder.setTempo(effectiveTempo)

            let metadata = try decoder.metadata(for: trackIndex)
            let validLoop = loop.flatMap { $0.isValid ? $0 : nil }
            longPlayRepeatsVGMAtEnd = plan.isLongPlay && family.id == FormatRegistry.libvgmFamily.id && validLoop == nil
            longPlayVGMTrackFrames = longPlayRepeatsVGMAtEnd && metadata.naturalPlayMs > 0
                ? Int64((Double(metadata.naturalPlayMs) * Double(sampleRate) / 1_000 / effectiveTempo).rounded())
                : 0
            if validLoop != nil, !plan.isLongPlay, plan.usesDecoderNaturalDuration {
                // An authored loop is an explicit native ending. Leave the
                // decoder open-ended and let the session perform the sample
                // boundary jump. UAC-supplied metadata reaches this path
                // before any member tags and therefore always wins.
                decoder.configureNativeEnding(playMs: 0, fadeMs: 0)
                capFrames = 0
                fadeFrames = 0
            } else if plan.usesNativeEnding {
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
                    capFrames = Int64(plan.preFadeMilliseconds) * Int64(sampleRate) / 1_000
                    fadeFrames = 0
                }
            } else {
                let naturalPlayMilliseconds: Int
                if plan.isLongPlay && plan.preFadeMilliseconds == 0 {
                    // Zero Long Play is the explicit unbounded mode. A fade
                    // value must not turn that choice into a hidden cap.
                    naturalPlayMilliseconds = 0
                } else {
                    naturalPlayMilliseconds = plan.usesDecoderNaturalDuration && metadata.naturalPlayMs > 0
                        ? metadata.naturalPlayMs
                        : plan.preFadeMilliseconds
                }
                decoder.configureFade(
                    playMs: naturalPlayMilliseconds,
                    fadeMs: plan.fadeMilliseconds
                )
                if naturalPlayMilliseconds > 0 {
                    capFrames = Int64(naturalPlayMilliseconds + plan.fadeMilliseconds) * Int64(sampleRate) / 1_000
                    fadeFrames = decoder.appliesFadeInternally
                        ? 0
                        : Int64(plan.fadeMilliseconds) * Int64(sampleRate) / 1_000
                } else {
                    capFrames = 0
                    fadeFrames = 0
                }
            }

            initialLoop = validLoop
            playbackLoop = validLoop
            remainingLoopRepeats = validLoop?.repeatCount
            sessionFrames = 0
            currentTrackIndex = trackIndex
            decoderFamily = family.id
            currentTempo = effectiveTempo
            reachedEnd = false
            errorMessage = nil
            isLoaded = true
            output.clearBuffer()
            output.resetDiagnostics()
            try prime(to: output.primeFrameCount)
            loadedSuccessfully = true
            publishStatus()
            return previousStatus
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
            let requestedFrames = Int64(max(0, seconds) * Double(sampleRate))
            if let loop = initialLoop, let bounds = loopOutputBounds(loop) {
                let length = bounds.end - bounds.start
                let completed = requestedFrames >= bounds.end
                    ? (requestedFrames - bounds.start) / length : 0
                let repeats = loop.repeatCount.map { min(completed, Int64(max(0, $0))) } ?? completed
                let sourceFrames = requestedFrames - repeats * length
                playbackLoop = loop
                remainingLoopRepeats = loop.repeatCount.map { max(0, $0 - Int(repeats)) }
                decoder.seek(milliseconds: Int(sourceFrames * 1_000 / Int64(sampleRate)))
                sessionFrames = requestedFrames
            } else if longPlayRepeatsVGMAtEnd, longPlayVGMTrackFrames > 0 {
                let sourceFrames = requestedFrames % longPlayVGMTrackFrames
                decoder.seek(milliseconds: Int(sourceFrames * 1_000 / Int64(sampleRate)))
                sessionFrames = requestedFrames
            } else {
                decoder.seek(milliseconds: Int(seconds * 1_000))
                sessionFrames = decoder.absolutePlayedFrames
            }
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

    /// Applies the complete output snapshot under one session-queue turn.
    /// Individual output controls used to publish three intermediate status
    /// events when a frontend changed one setting. Besides causing visible
    /// readout churn, those events could overlap a start or replacement and
    /// make the renderer observe an in-between audio configuration.
    public func configureAudio(
        volume: Float,
        equalizer: EqualizerConfiguration,
        monoEnabled: Bool
    ) throws {
        guard volume.isFinite, (0...1).contains(volume) else {
            throw PlaybackControlError.invalidPayload("Output volume must be finite and between 0 and 1.")
        }
        guard equalizer.isValid else {
            throw PlaybackControlError.invalidPayload("Equalizer requires exactly 10 finite gains.")
        }
        queue.sync {
            output.setVolume(volume)
            output.setEqualizer(equalizer)
            output.setMonoEnabled(monoEnabled)
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
        let elapsed = Double(max(0, sessionFrames - Int64(diagnostics.bufferedFrames))) / Double(sampleRate)
        let decodedFrames = sessionFrames
        let statistics = PlaybackStatistics(
            decoderFamily: decoderFamily,
            trackIndex: isLoaded ? currentTrackIndex : nil,
            trackCount: decoder?.trackCount,
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
        guard decoder != nil else { return }
        let highWater = Int(Double(output.capacityFrames) * 0.75)
        do {
            try fillBuffer(to: highWater)
        } catch {
            stopRefillTimer()
            output.pause()
            errorMessage = error.localizedDescription
            publishStatus()
            return
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
        let statusHandler = completionStatusHandler
        let completedStatus = makeStatus()
        DispatchQueue.main.async {
            handler?()
            statusHandler?(completedStatus)
        }
    }

    private func prime(to targetBufferedFrames: Int) throws {
        try fillBuffer(to: targetBufferedFrames)
    }

    /// Priming and periodic refill must apply identical end, loop and fade
    /// rules; the callers retain their distinct error and publication behavior.
    private func fillBuffer(to targetBufferedFrames: Int) throws {
        guard let decoder else { return }
        while output.bufferedFrames < targetBufferedFrames {
            if capFrames > 0 && sessionFrames >= capFrames {
                reachedEnd = true
                break
            }
            if decoder.trackEnded {
                guard rewindVGMForLongPlayIfNeeded(decoder) else {
                    reachedEnd = true
                    break
                }
                continue
            }
            let chunkStart = sessionFrames
            // This session is the ring's only producer. The callback can only
            // free space, so a read bounded by the current free capacity must
            // fit without discarding a decoded suffix.
            let freeFrames = max(0, output.capacityFrames - output.bufferedFrames)
            guard freeFrames > 0 else { break }
            let requested = min(nextReadFrameCount(), freeFrames)
            let frames = try readPlaybackFrames(decoder: decoder, requested: requested)
            guard frames.left.count == frames.right.count, frames.left.count <= requested else {
                throw PlaybackControlError.invalidPayload("Decoder returned an invalid PCM frame count.")
            }
            guard !frames.left.isEmpty, !frames.right.isEmpty else {
                if decoder.trackEnded, longPlayRepeatsVGMAtEnd {
                    if decoder.absolutePlayedFrames == 0 {
                        longPlayRepeatsVGMAtEnd = false
                        reachedEnd = true
                        break
                    }
                    continue
                }
                if decoder.trackEnded {
                    reachedEnd = true
                }
                break
            }
            let faded = applyFadeIfNeeded(decoder, chunkStart: chunkStart, left: frames.left, right: frames.right)
            let written = output.write(left: faded.left, right: faded.right)
            sessionFrames += Int64(written)
            guard written == faded.left.count else {
                throw PlaybackControlError.invalidPayload("Playback output could not accept decoded PCM.")
            }
        }
    }

    private func nextReadFrameCount() -> Int {
        guard capFrames > 0 else { return chunkFrameCount }
        return Int(max(1, min(Int64(chunkFrameCount), capFrames - sessionFrames)))
    }

    private func rewindVGMForLongPlayIfNeeded(_ decoder: any AudioDecoder) -> Bool {
        guard longPlayRepeatsVGMAtEnd, decoder.trackEnded else { return false }
        decoder.seek(milliseconds: 0)
        return !decoder.trackEnded && decoder.absolutePlayedFrames == 0
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

    /// Reads up to the loop boundary and seeks back to its start when the
    /// boundary is reached. The decoder remains unaware of package metadata;
    /// this keeps UAC precedence and tag handling in one transport layer.
    private func readPlaybackFrames(
        decoder: any AudioDecoder,
        requested: Int
    ) throws -> (left: [Float], right: [Float]) {
        guard requested > 0 else { return ([], []) }
        guard let loop = playbackLoop,
              loop.isValid,
              loop.sampleRateHz > 0 else {
            return try decoder.readFrames(requested)
        }
        guard let bounds = loopOutputBounds(loop) else { return try decoder.readFrames(requested) }
        let startOutput = bounds.start
        let endOutput = bounds.end

        if decoder.absolutePlayedFrames >= endOutput {
            if let remaining = remainingLoopRepeats {
                guard remaining > 0 else {
                    playbackLoop = nil
                    return try decoder.readFrames(requested)
                }
                remainingLoopRepeats = remaining - 1
            }
            decoder.seek(milliseconds: Int((Double(startOutput) * 1_000 / Double(sampleRate)).rounded()))
        }

        let available = max(1, endOutput - decoder.absolutePlayedFrames)
        return try decoder.readFrames(min(requested, Int(min(Int64(requested), available))))
    }

    private func loopOutputBounds(_ loop: PlaybackLoopMetadata) -> (start: Int64, end: Int64)? {
        let scale = Double(sampleRate) / Double(loop.sampleRateHz) / currentTempo
        let start = Int64((Double(loop.startSample) * scale).rounded())
        let end = Int64((Double(loop.endSample) * scale).rounded())
        return end > start ? (start, end) : nil
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
        initialLoop = nil
        playbackLoop = nil
        remainingLoopRepeats = nil
        longPlayRepeatsVGMAtEnd = false
        longPlayVGMTrackFrames = 0
        sessionFrames = 0
        capFrames = 0
        fadeFrames = 0
        reachedEnd = false
        errorMessage = nil
        isLoaded = false
        output.clearBuffer()
    }
}
