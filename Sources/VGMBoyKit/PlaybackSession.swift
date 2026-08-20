import Foundation

public struct PlaybackStatus: Sendable, Codable, Equatable {
    public var isPlaying: Bool
    public var elapsedSeconds: Double
    public var reachedEnd: Bool
    public var system: String
    public var trackIndex: Int
    public var trackCount: Int
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
public final class PlaybackSession: @unchecked Sendable {
    private let queue = DispatchQueue(label: "VGMBoy.playback-session", qos: .userInitiated)
    private let sampleRate = 44_100
    private let chunkFrameCount = 4096
    private let output: AudioOutput
    private var decoder: (any AudioDecoder)?
    private var capFrames: Int64 = 0
    private var fadeFrames: Int64 = 0
    private var currentTrackIndex = 0
    private var reachedEnd = false
    private var isLoaded = false
    private var generation = 0
    private var refillTimer: DispatchSourceTimer?
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
    ) throws -> TrackMetadata {
        try queue.sync {
            releaseCurrent()
            generation += 1
            guard let family = FormatRegistry.family(for: path) else {
                throw DecoderFactoryError.unsupportedFamily(
                    (path as NSString).pathExtension
                )
            }
            let decoder = try DecoderFactory.make(family: family, path: path, sampleRate: sampleRate)
            try decoder.startTrack(trackIndex)
            decoder.setTempo(tempo)

            let metadata = try decoder.metadata(for: trackIndex)
            if plan.usesNativeEnding {
                if metadata.hasTiming {
                    decoder.configureNativeEnding(
                        playMs: metadata.naturalPlayMs,
                        fadeMs: max(0, metadata.fadeMs)
                    )
                    capFrames = 0
                } else {
                    decoder.configureNativeEnding(playMs: 0, fadeMs: 0)
                    capFrames = Int64(plan.preFadeSeconds) * Int64(sampleRate)
                }
                fadeFrames = 0
            } else {
                decoder.configureFade(
                    playMs: plan.preFadeSeconds * 1000,
                    fadeMs: plan.fadeSeconds * 1000
                )
                capFrames = Int64(plan.totalSeconds) * Int64(sampleRate)
                fadeFrames = decoder.appliesFadeInternally
                    ? 0
                    : Int64(plan.fadeSeconds) * Int64(sampleRate)
            }

            self.decoder = decoder
            currentTrackIndex = trackIndex
            reachedEnd = false
            isLoaded = true
            output.ringBuffer.clear()
            try prime(to: output.primeFrameCount)
            publishStatus()
            return metadata
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
            output.ringBuffer.clear()
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
            output.ringBuffer.clear()
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

    public func stop() {
        queue.sync {
            stopRefillTimer()
            output.pause()
            reachedEnd = false
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
        let elapsed = decoder.map { Double($0.absolutePlayedFrames) / Double(sampleRate) } ?? 0
        return PlaybackStatus(
            isPlaying: output.isRunning,
            elapsedSeconds: elapsed,
            reachedEnd: reachedEnd,
            system: decoder?.systemName ?? "",
            trackIndex: currentTrackIndex,
            trackCount: decoder?.trackCount ?? 0
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
        let highWater = Int(Double(output.ringBuffer.capacityFrames) * 0.75)
        while output.ringBuffer.bufferedFrames < highWater {
            if decoder.trackEnded || (capFrames > 0 && decoder.absolutePlayedFrames >= capFrames) {
                reachedEnd = true
                break
            }
            let chunkStart = decoder.absolutePlayedFrames
            let frames = decoder.readFrames(chunkFrameCount)
            let faded = applyFadeIfNeeded(decoder, chunkStart: chunkStart, left: frames.left, right: frames.right)
            if output.ringBuffer.write(left: faded.left, right: faded.right) == 0 {
                break
            }
        }
        if reachedEnd {
            if output.ringBuffer.bufferedFrames == 0 {
                finishReachedEnd()
            } else {
                publishStatus()
            }
        }
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
        while output.ringBuffer.bufferedFrames < targetBufferedFrames {
            if decoder.trackEnded || (capFrames > 0 && decoder.absolutePlayedFrames >= capFrames) {
                reachedEnd = true
                break
            }
            let chunkStart = decoder.absolutePlayedFrames
            let frames = decoder.readFrames(chunkFrameCount)
            let faded = applyFadeIfNeeded(decoder, chunkStart: chunkStart, left: frames.left, right: frames.right)
            if output.ringBuffer.write(left: faded.left, right: faded.right) == 0 {
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
        decoder?.close()
        decoder = nil
        capFrames = 0
        fadeFrames = 0
        reachedEnd = false
        isLoaded = false
        output.ringBuffer.clear()
        output.pause()
    }
}
