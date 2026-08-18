import Foundation

public struct PlaybackStatus: Sendable {
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
    private var decoder: GMEDecoder?
    private var capFrames: Int64 = 0
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
            let decoder = try GMEDecoder(path: path, sampleRate: sampleRate)
            try decoder.startTrack(trackIndex)
            decoder.setTempo(tempo)

            if plan.usesNativeEnding {
                if let metadata = try? decoder.metadata(for: trackIndex),
                   metadata.playMs > 0 {
                    decoder.configureFade(playMs: metadata.playMs, fadeMs: max(0, metadata.fadeMs))
                }
                capFrames = 0
            } else {
                decoder.configureFade(
                    playMs: plan.preFadeSeconds * 1000,
                    fadeMs: plan.fadeSeconds * 1000
                )
                capFrames = Int64(plan.totalSeconds) * Int64(sampleRate)
            }

            self.decoder = decoder
            currentTrackIndex = trackIndex
            reachedEnd = false
            isLoaded = true
            output.ringBuffer.clear()
            try prime(to: output.primeFrameCount)
            let metadata = try decoder.metadata(for: trackIndex)
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
            let frames = decoder.readFrames(chunkFrameCount)
            if output.ringBuffer.write(left: frames.left, right: frames.right) == 0 {
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
            let frames = decoder.readFrames(chunkFrameCount)
            if output.ringBuffer.write(left: frames.left, right: frames.right) == 0 {
                break
            }
        }
    }

    private func releaseCurrent() {
        stopRefillTimer()
        decoder = nil
        capFrames = 0
        reachedEnd = false
        isLoaded = false
        output.ringBuffer.clear()
        output.pause()
    }
}