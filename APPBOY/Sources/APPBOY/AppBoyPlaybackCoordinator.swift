import AVFoundation
import Foundation
import MediaPlayer

@MainActor
final class AppBoyPlaybackCoordinator {
    static let equalizerFrequencies: [Float] = [
        31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000
    ]

    var onStateChanged: ((AppBoyPlaybackStateSnapshot) -> Void)?
    var onNaturalEnd: ((Int, String) -> Void)?
    var onRemoteCommand: ((String, Double?) -> Void)?

    private enum BackendMode {
        case none
        case engine
        case streamPlayer
    }

    // Primary local / synthesized audio graph (10-band EQ + Mono + Long Play + Speed)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var engineGraphAttached = false
    private var engineSampleRate: Double = 0.0
    private var engineProcessingFormat: AVAudioFormat?
    private let chunkFrameCount: AVAudioFrameCount = 4_096
    private let targetQueuedBuffers: Int = 6

    private var audioFile: AVAudioFile?
    private var fileLengthFrames: AVAudioFramePosition = 0
    private var fileSampleRate: Double = 44_100.0
    private var naturalFileDurationSeconds: Double = 0.0
    private var scheduleToken: Int = 0
    private var queuedBufferCount: Int = 0
    private var nextVirtualFrameToSchedule: AVAudioFramePosition = 0
    private var playbackAnchorFrame: AVAudioFramePosition = 0
    private var pausedElapsedSeconds: Double = 0.0
    private var didScheduleFinalFrame = false
    private var engineTickTask: Task<Void, Never>?

    // Fallback AVPlayer for remote HTTP(S) streams
    private let streamPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var engineConfigObserver: NSObjectProtocol?

    private var backendMode: BackendMode = .none
    private(set) var generation: Int = 0
    private var currentTrack: AppBoyTrack?
    private var transportState: String = "stopped"
    private var configuredRate: Double = 1.0
    private var configuredVolume: Float = 1.0
    private var equalizerEnabled: Bool = false
    private var equalizerBandsDB: [Double] = Array(repeating: 0.0, count: 10)
    private var monoEnabled: Bool = false
    private var longPlayEnabled: Bool = false
    private var manualPlayTimeSeconds: Double = 180.0
    private var fadeOutEnabled: Bool = true
    private var fadeOutSeconds: Double = 5.0
    private var targetDurationSeconds: Double = 0.0
    private var wasPlayingBeforeInterruption = false
    private var remoteCommandsConfigured = false

    init() {
        configureAudioSession()
        configureEqualizerBandsMetadata()
        configureObservers()
        configureRemoteCommands()
        startEngineProgressLoop()
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            // Audio session activation may be deferred when launched in background; retried on start/resume.
        }
    }

    func applyPreferences(_ prefs: AppBoyPreferencesSnapshot) {
        configuredVolume = Float(min(max(prefs.appVolume, 0.0), 1.0))
        let desiredRate = prefs.playbackSpeedEnabled ? min(max(prefs.playbackSpeedRate, 0.5), 2.0) : 1.0
        let rateChanged = abs(desiredRate - configuredRate) > 0.0005
        configuredRate = desiredRate

        equalizerEnabled = prefs.equalizerEnabled
        equalizerBandsDB = Self.sanitizedBands(prefs.equalizerBandsDB)

        let monoChanged = (monoEnabled != prefs.monoEnabled)
        monoEnabled = prefs.monoEnabled

        let longPlayChanged = (longPlayEnabled != prefs.longPlayEnabled)
            || (abs(manualPlayTimeSeconds - prefs.manualPlayTimeSeconds) > 0.01)
        let fadeChanged = (fadeOutEnabled != prefs.fadeOutEnabled)
            || (abs(fadeOutSeconds - prefs.fadeOutSeconds) > 0.01)

        longPlayEnabled = prefs.longPlayEnabled
        manualPlayTimeSeconds = prefs.manualPlayTimeSeconds
        fadeOutEnabled = prefs.fadeOutEnabled
        fadeOutSeconds = prefs.fadeOutSeconds

        syncEngineParameters()
        streamPlayer.volume = configuredVolume
        if backendMode == .streamPlayer && transportState == "playing" && rateChanged {
            streamPlayer.rate = Float(configuredRate)
        }

        if backendMode == .engine, currentTrack != nil {
            let newTarget = longPlayEnabled ? manualPlayTimeSeconds : naturalFileDurationSeconds
            let durationChanged = abs(newTarget - targetDurationSeconds) > 0.01
            if durationChanged || monoChanged || fadeChanged {
                let currentPos = currentEngineElapsedSeconds()
                targetDurationSeconds = newTarget
                if transportState == "playing" && currentPos >= newTarget {
                    completeNaturalEnd(forGeneration: generation)
                    return
                }
                if transportState == "playing" || transportState == "paused" {
                    reanchorEngine(at: min(currentPos, max(0.0, newTarget - 0.05)))
                }
            }
            let snap = currentSnapshot(errorMessage: nil)
            publishNowPlaying(for: snap)
            onStateChanged?(snap)
        } else if rateChanged || longPlayChanged {
            let snap = currentSnapshot(errorMessage: nil)
            publishNowPlaying(for: snap)
            onStateChanged?(snap)
        }
    }

    func start(
        track: AppBoyTrack,
        preferences prefs: AppBoyPreferencesSnapshot
    ) -> AppBoyPlaybackStateSnapshot {
        generation += 1
        let activeGen = generation
        configureAudioSession()

        currentTrack = track
        configuredVolume = Float(min(max(prefs.appVolume, 0.0), 1.0))
        configuredRate = prefs.playbackSpeedEnabled ? min(max(prefs.playbackSpeedRate, 0.5), 2.0) : 1.0
        equalizerEnabled = prefs.equalizerEnabled
        equalizerBandsDB = Self.sanitizedBands(prefs.equalizerBandsDB)
        monoEnabled = prefs.monoEnabled
        longPlayEnabled = prefs.longPlayEnabled
        manualPlayTimeSeconds = prefs.manualPlayTimeSeconds
        fadeOutEnabled = prefs.fadeOutEnabled
        fadeOutSeconds = prefs.fadeOutSeconds

        teardownActiveBackends()

        do {
            let resolvedURL = try AppBoyChiptuneSynth.resolvePlayableURL(
                for: track.streamURI,
                trackId: track.id,
                naturalDurationSeconds: track.durationSeconds
            )

            if resolvedURL.isFileURL {
                try startEnginePlayback(fileURL: resolvedURL, fallbackDuration: track.durationSeconds)
            } else {
                startStreamPlayback(url: resolvedURL, generation: activeGen, track: track)
            }

            let snap = currentSnapshot(errorMessage: nil)
            publishNowPlaying(for: snap)
            onStateChanged?(snap)
            return snap
        } catch {
            backendMode = .none
            transportState = "error"
            let snap = currentSnapshot(errorMessage: error.localizedDescription)
            publishNowPlaying(for: snap)
            onStateChanged?(snap)
            return snap
        }
    }

    func pause(expectedGeneration: Int?) -> AppBoyPlaybackStateSnapshot {
        if let expectedGeneration, expectedGeneration != generation {
            return currentSnapshot(errorMessage: nil)
        }
        guard currentTrack != nil else { return currentSnapshot(errorMessage: nil) }
        switch backendMode {
        case .engine:
            pausedElapsedSeconds = currentEngineElapsedSeconds()
            playerNode.pause()
        case .streamPlayer:
            streamPlayer.pause()
        case .none:
            break
        }
        transportState = "paused"
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func resume(expectedGeneration: Int?) -> AppBoyPlaybackStateSnapshot {
        if let expectedGeneration, expectedGeneration != generation {
            return currentSnapshot(errorMessage: nil)
        }
        guard currentTrack != nil else { return currentSnapshot(errorMessage: nil) }
        configureAudioSession()

        switch backendMode {
        case .engine:
            do {
                if !engine.isRunning {
                    try engine.start()
                }
                syncEngineParameters()
                if queuedBufferCount == 0 && !didScheduleFinalFrame {
                    reanchorEngine(at: pausedElapsedSeconds)
                }
                playerNode.play()
                transportState = "playing"
            } catch {
                transportState = "error"
                let snap = currentSnapshot(errorMessage: error.localizedDescription)
                publishNowPlaying(for: snap)
                onStateChanged?(snap)
                return snap
            }
        case .streamPlayer:
            streamPlayer.volume = configuredVolume
            streamPlayer.playImmediately(atRate: Float(configuredRate))
            transportState = "playing"
        case .none:
            break
        }

        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func stop(expectedGeneration: Int?) -> AppBoyPlaybackStateSnapshot {
        if let expectedGeneration, expectedGeneration != generation {
            return currentSnapshot(errorMessage: nil)
        }
        scheduleToken += 1
        switch backendMode {
        case .engine:
            playerNode.stop()
            queuedBufferCount = 0
            playbackAnchorFrame = 0
            nextVirtualFrameToSchedule = 0
            pausedElapsedSeconds = 0.0
            didScheduleFinalFrame = false
        case .streamPlayer:
            streamPlayer.pause()
            streamPlayer.seek(to: .zero)
        case .none:
            break
        }
        transportState = "stopped"
        let snap = AppBoyPlaybackStateSnapshot(
            generation: generation,
            trackId: currentTrack?.id,
            transportState: "stopped",
            elapsedSeconds: 0.0,
            durationSeconds: targetDurationSeconds,
            playbackRate: configuredRate,
            errorMessage: nil
        )
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func seek(to seconds: Double, expectedGeneration: Int?) async -> AppBoyPlaybackStateSnapshot {
        if let expectedGeneration, expectedGeneration != generation {
            return currentSnapshot(errorMessage: nil)
        }
        guard currentTrack != nil else { return currentSnapshot(errorMessage: nil) }
        let clamped = max(0.0, min(seconds, max(targetDurationSeconds - 0.02, 0.0)))

        switch backendMode {
        case .engine:
            reanchorEngine(at: clamped)
        case .streamPlayer:
            let time = CMTime(seconds: clamped, preferredTimescale: 600)
            _ = await streamPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        case .none:
            break
        }

        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func setRate(_ rate: Double) -> AppBoyPlaybackStateSnapshot {
        configuredRate = min(max(rate, 0.5), 2.0)
        syncEngineParameters()
        if backendMode == .streamPlayer && transportState == "playing" {
            streamPlayer.rate = Float(configuredRate)
        }
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func setVolume(_ volume: Double) -> AppBoyPlaybackStateSnapshot {
        configuredVolume = Float(min(max(volume, 0.0), 1.0))
        syncEngineParameters()
        streamPlayer.volume = configuredVolume
        return currentSnapshot(errorMessage: nil)
    }

    func setEqualizer(enabled: Bool, bandsDB: [Double]) -> AppBoyPlaybackStateSnapshot {
        equalizerEnabled = enabled
        equalizerBandsDB = Self.sanitizedBands(bandsDB)
        syncEngineParameters()
        return currentSnapshot(errorMessage: nil)
    }

    func currentSnapshot(errorMessage: String?) -> AppBoyPlaybackStateSnapshot {
        let elapsed: Double
        var duration = targetDurationSeconds

        switch backendMode {
        case .engine:
            elapsed = currentEngineElapsedSeconds()
        case .streamPlayer:
            let rawSeconds = streamPlayer.currentTime().seconds
            elapsed = rawSeconds.isFinite && rawSeconds >= 0 ? rawSeconds : 0.0
            if let itemSeconds = streamPlayer.currentItem?.duration.seconds, itemSeconds.isFinite && itemSeconds > 0 {
                duration = longPlayEnabled ? manualPlayTimeSeconds : itemSeconds
            }
        case .none:
            elapsed = 0.0
        }

        return AppBoyPlaybackStateSnapshot(
            generation: generation,
            trackId: currentTrack?.id,
            transportState: transportState,
            elapsedSeconds: min(elapsed, max(duration, elapsed)),
            durationSeconds: duration,
            playbackRate: configuredRate,
            errorMessage: errorMessage
        )
    }

    // MARK: - AVAudioEngine Local & Synthesized Pipeline

    private func configureEqualizerBandsMetadata() {
        for (index, freq) in Self.equalizerFrequencies.enumerated() where index < eqNode.bands.count {
            let band = eqNode.bands[index]
            band.filterType = .parametric
            band.frequency = freq
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = true
        }
        eqNode.bypass = true
    }

    private func ensureEngineGraph(sampleRate: Double) throws {
        if !engineGraphAttached {
            engine.attach(playerNode)
            engine.attach(timePitchNode)
            engine.attach(eqNode)
            engineGraphAttached = true
        }

        if abs(engineSampleRate - sampleRate) > 0.5 || engineProcessingFormat == nil {
            if engine.isRunning {
                engine.stop()
            }
            guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
                throw NSError(domain: "APPBOY.Audio", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Unsupported audio sample rate (\(Int(sampleRate)) Hz)."
                ])
            }
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(timePitchNode)
            engine.disconnectNodeOutput(eqNode)

            engine.connect(playerNode, to: timePitchNode, format: stereoFormat)
            engine.connect(timePitchNode, to: eqNode, format: stereoFormat)
            engine.connect(eqNode, to: engine.mainMixerNode, format: stereoFormat)

            engineSampleRate = sampleRate
            engineProcessingFormat = stereoFormat
        }

        syncEngineParameters()
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    private func syncEngineParameters() {
        timePitchNode.rate = Float(configuredRate)
        timePitchNode.pitch = 0.0
        timePitchNode.bypass = abs(configuredRate - 1.0) < 0.001

        eqNode.bypass = !equalizerEnabled
        var maxPositiveBoostDB = 0.0
        for index in 0..<min(eqNode.bands.count, equalizerBandsDB.count) {
            let gainDB = equalizerBandsDB[index]
            if equalizerEnabled && gainDB > maxPositiveBoostDB {
                maxPositiveBoostDB = gainDB
            }
            let band = eqNode.bands[index]
            band.gain = Float(gainDB)
            band.bypass = !equalizerEnabled || abs(gainDB) < 0.01
        }

        // Non-clipping headroom compensation matching SB2's audio rule.
        let headroomLinear = equalizerEnabled && maxPositiveBoostDB > 0.0
            ? Float(pow(10.0, -maxPositiveBoostDB / 20.0))
            : 1.0
        if engineGraphAttached {
            engine.mainMixerNode.outputVolume = configuredVolume * headroomLinear
        }
    }

    private func startEnginePlayback(fileURL: URL, fallbackDuration: Double) throws {
        let file = try AVAudioFile(forReading: fileURL)
        let sr = file.processingFormat.sampleRate
        guard file.length > 0, sr > 0 else {
            throw NSError(domain: "APPBOY.Audio", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Audio file contains no playable frames."
            ])
        }

        try ensureEngineGraph(sampleRate: sr)

        backendMode = .engine
        audioFile = file
        fileLengthFrames = file.length
        fileSampleRate = sr
        let computedNatural = Double(file.length) / sr
        naturalFileDurationSeconds = computedNatural > 0.1 ? computedNatural : max(1.0, fallbackDuration)
        targetDurationSeconds = longPlayEnabled ? manualPlayTimeSeconds : naturalFileDurationSeconds

        scheduleToken += 1
        playbackAnchorFrame = 0
        nextVirtualFrameToSchedule = 0
        pausedElapsedSeconds = 0.0
        queuedBufferCount = 0
        didScheduleFinalFrame = false

        refillEngineBuffers(token: scheduleToken)
        playerNode.play()
        transportState = "playing"
    }

    private func reanchorEngine(at seconds: Double) {
        guard backendMode == .engine, audioFile != nil, fileSampleRate > 0 else { return }
        let wasPlaying = (transportState == "playing")
        scheduleToken += 1
        let activeToken = scheduleToken

        playerNode.stop()
        let startFrame = max(0, AVAudioFramePosition((seconds * fileSampleRate).rounded()))
        playbackAnchorFrame = startFrame
        nextVirtualFrameToSchedule = startFrame
        pausedElapsedSeconds = seconds
        queuedBufferCount = 0
        didScheduleFinalFrame = false

        refillEngineBuffers(token: activeToken)
        if wasPlaying {
            if !engine.isRunning {
                try? engine.start()
            }
            playerNode.play()
        }
    }

    private func refillEngineBuffers(token: Int) {
        guard token == scheduleToken,
              backendMode == .engine,
              !didScheduleFinalFrame else { return }

        while queuedBufferCount < targetQueuedBuffers && !didScheduleFinalFrame {
            guard let buffer = readNextStereoChunk() else {
                didScheduleFinalFrame = true
                break
            }
            queuedBufferCount += 1
            let capturedToken = token
            playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleBufferPlayedBack(token: capturedToken)
                }
            }
        }
    }

    private func handleBufferPlayedBack(token: Int) {
        guard token == scheduleToken, backendMode == .engine else { return }
        queuedBufferCount = max(0, queuedBufferCount - 1)
        if !didScheduleFinalFrame {
            refillEngineBuffers(token: token)
        } else if queuedBufferCount == 0 && transportState == "playing" {
            completeNaturalEnd(forGeneration: generation)
        }
    }

    private func readNextStereoChunk() -> AVAudioPCMBuffer? {
        guard let file = audioFile,
              let stereoFormat = engineProcessingFormat,
              fileLengthFrames > 0,
              fileSampleRate > 0 else { return nil }

        let totalTargetFrames = max(
            AVAudioFramePosition(1),
            AVAudioFramePosition((targetDurationSeconds * fileSampleRate).rounded())
        )
        if nextVirtualFrameToSchedule >= totalTargetFrames {
            didScheduleFinalFrame = true
            return nil
        }

        let remainingFrames = totalTargetFrames - nextVirtualFrameToSchedule
        let framesToProduce = AVAudioFrameCount(min(AVAudioFramePosition(chunkFrameCount), remainingFrames))
        guard framesToProduce > 0,
              let outBuffer = AVAudioPCMBuffer(pcmFormat: stereoFormat, frameCapacity: framesToProduce),
              let dstChannels = outBuffer.floatChannelData else {
            return nil
        }
        outBuffer.frameLength = framesToProduce
        let dstL = dstChannels[0]
        let dstR = dstChannels[1]

        let effectiveFadeSeconds = min(fadeOutSeconds, targetDurationSeconds * 0.35)
        let fadeFrames: AVAudioFramePosition = (fadeOutEnabled && effectiveFadeSeconds > 0.05)
            ? AVAudioFramePosition((effectiveFadeSeconds * fileSampleRate).rounded())
            : 0
        let fadeStartFrame = totalTargetFrames - fadeFrames

        let srcFormat = file.processingFormat
        let srcChannelCount = Int(srcFormat.channelCount)
        var filled: AVAudioFrameCount = 0

        while filled < framesToProduce {
            let virtualCursor = nextVirtualFrameToSchedule + AVAudioFramePosition(filled)
            let fileOffset: AVAudioFramePosition
            if longPlayEnabled {
                fileOffset = virtualCursor % fileLengthFrames
            } else if virtualCursor < fileLengthFrames {
                fileOffset = virtualCursor
            } else {
                // Past single-shot file length: zero remaining frames and finish.
                let zeroCount = Int(framesToProduce - filled)
                let startIdx = Int(filled)
                for i in 0..<zeroCount {
                    dstL[startIdx + i] = 0
                    dstR[startIdx + i] = 0
                }
                filled = framesToProduce
                break
            }

            let availableInFile = fileLengthFrames - fileOffset
            let stepCount = AVAudioFrameCount(min(AVAudioFramePosition(framesToProduce - filled), availableInFile))
            guard stepCount > 0,
                  let tempBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: stepCount) else {
                break
            }

            do {
                if file.framePosition != fileOffset {
                    file.framePosition = fileOffset
                }
                try file.read(into: tempBuf, frameCount: stepCount)
            } catch {
                break
            }

            let actualRead = tempBuf.frameLength
            if actualRead == 0 { break }
            guard let srcChannels = tempBuf.floatChannelData else { break }

            let outBase = Int(filled)
            let count = Int(actualRead)
            if srcChannelCount == 1 {
                let srcM = srcChannels[0]
                for i in 0..<count {
                    let s = srcM[i]
                    dstL[outBase + i] = s
                    dstR[outBase + i] = s
                }
            } else {
                let srcL = srcChannels[0]
                let srcR = srcChannels[1]
                if monoEnabled {
                    for i in 0..<count {
                        let m = 0.5 * (srcL[i] + srcR[i])
                        dstL[outBase + i] = m
                        dstR[outBase + i] = m
                    }
                } else {
                    for i in 0..<count {
                        dstL[outBase + i] = srcL[i]
                        dstR[outBase + i] = srcR[i]
                    }
                }
            }

            if fadeFrames > 0 {
                for i in 0..<count {
                    let vFrame = virtualCursor + AVAudioFramePosition(i)
                    if vFrame >= fadeStartFrame {
                        let gain = Float(max(0.0, Double(totalTargetFrames - vFrame) / Double(fadeFrames)))
                        dstL[outBase + i] *= gain
                        dstR[outBase + i] *= gain
                    }
                }
            }

            filled += actualRead
        }

        if filled == 0 {
            didScheduleFinalFrame = true
            return nil
        }

        outBuffer.frameLength = filled
        nextVirtualFrameToSchedule += AVAudioFramePosition(filled)
        if nextVirtualFrameToSchedule >= totalTargetFrames {
            didScheduleFinalFrame = true
        }
        return outBuffer
    }

    private func currentEngineElapsedSeconds() -> Double {
        guard backendMode == .engine, fileSampleRate > 0 else { return 0.0 }
        if transportState == "stopped" { return 0.0 }
        if transportState == "paused" { return pausedElapsedSeconds }
        if let nodeTime = playerNode.lastRenderTime,
           nodeTime.isSampleTimeValid,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let currentFrame = playbackAnchorFrame + max(0, playerTime.sampleTime)
            let secs = Double(currentFrame) / fileSampleRate
            pausedElapsedSeconds = min(targetDurationSeconds, max(0.0, secs))
            return pausedElapsedSeconds
        }
        return pausedElapsedSeconds
    }

    private func startEngineProgressLoop() {
        engineTickTask?.cancel()
        engineTickTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self,
                      self.backendMode == .engine,
                      self.currentTrack != nil,
                      self.transportState == "playing" else {
                    continue
                }
                if !self.didScheduleFinalFrame && self.queuedBufferCount < self.targetQueuedBuffers {
                    self.refillEngineBuffers(token: self.scheduleToken)
                }
                let snap = self.currentSnapshot(errorMessage: nil)
                if self.targetDurationSeconds > 0 && snap.elapsedSeconds >= self.targetDurationSeconds {
                    self.completeNaturalEnd(forGeneration: self.generation)
                    continue
                }
                self.publishNowPlaying(for: snap)
                self.onStateChanged?(snap)
            }
        }
    }

    private func completeNaturalEnd(forGeneration completedGen: Int) {
        guard completedGen == generation, let trackId = currentTrack?.id else { return }
        scheduleToken += 1
        if backendMode == .engine {
            playerNode.stop()
            queuedBufferCount = 0
            pausedElapsedSeconds = 0.0
        } else if backendMode == .streamPlayer {
            streamPlayer.pause()
        }
        transportState = "stopped"
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        onNaturalEnd?(completedGen, trackId)
    }

    private func teardownActiveBackends() {
        scheduleToken += 1
        if engineGraphAttached {
            playerNode.stop()
        }
        audioFile = nil
        queuedBufferCount = 0
        didScheduleFinalFrame = false
        pausedElapsedSeconds = 0.0

        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }
        endObserver = nil
        failedObserver = nil
        streamPlayer.pause()
        streamPlayer.replaceCurrentItem(with: nil)
        backendMode = .none
    }

    // MARK: - Remote HTTP(S) Stream Fallback

    private func startStreamPlayback(url: URL, generation itemGen: Int, track: AppBoyTrack) {
        backendMode = .streamPlayer
        naturalFileDurationSeconds = track.durationSeconds
        targetDurationSeconds = longPlayEnabled ? manualPlayTimeSeconds : track.durationSeconds

        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .timeDomain
        installStreamObservers(for: item, generation: itemGen, trackId: track.id)

        streamPlayer.replaceCurrentItem(with: item)
        streamPlayer.volume = configuredVolume
        streamPlayer.playImmediately(atRate: Float(configuredRate))
        transportState = "playing"
    }

    private func installStreamObservers(for item: AVPlayerItem, generation itemGen: Int, trackId: String) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == itemGen, self.backendMode == .streamPlayer else { return }
                if self.longPlayEnabled && self.streamPlayer.currentTime().seconds + 0.5 < self.targetDurationSeconds {
                    self.streamPlayer.seek(to: .zero)
                    self.streamPlayer.playImmediately(atRate: Float(self.configuredRate))
                    return
                }
                self.completeNaturalEnd(forGeneration: itemGen)
            }
        }

        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] note in
            let errText = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
                ?? "Stream playback failed."
            Task { @MainActor [weak self] in
                guard let self, self.generation == itemGen else { return }
                self.transportState = "error"
                let snap = self.currentSnapshot(errorMessage: errText)
                self.publishNowPlaying(for: snap)
                self.onStateChanged?(snap)
            }
        }
    }

    // MARK: - Session, Route & Remote Command Observers

    private func configureObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = streamPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.backendMode == .streamPlayer,
                      self.currentTrack != nil,
                      self.transportState == "playing" else { return }
                let snap = self.currentSnapshot(errorMessage: nil)
                if self.targetDurationSeconds > 0 && snap.elapsedSeconds >= self.targetDurationSeconds {
                    self.completeNaturalEnd(forGeneration: self.generation)
                    return
                }
                self.publishNowPlaying(for: snap)
                self.onStateChanged?(snap)
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self,
                      let typeRaw,
                      let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
                switch type {
                case .began:
                    self.wasPlayingBeforeInterruption = (self.transportState == "playing")
                    if self.wasPlayingBeforeInterruption {
                        _ = self.pause(expectedGeneration: nil)
                    }
                case .ended:
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
                    if self.wasPlayingBeforeInterruption && options.contains(.shouldResume) {
                        _ = self.resume(expectedGeneration: nil)
                    }
                    self.wasPlayingBeforeInterruption = false
                @unknown default:
                    break
                }
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self,
                      let reasonRaw,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
                      reason == .oldDeviceUnavailable,
                      self.transportState == "playing" else { return }
                _ = self.pause(expectedGeneration: nil)
            }
        }

        engineConfigObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.backendMode == .engine, self.transportState == "playing" else { return }
                let pos = self.pausedElapsedSeconds
                try? self.ensureEngineGraph(sampleRate: self.fileSampleRate)
                self.reanchorEngine(at: pos)
            }
        }
    }

    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onRemoteCommand?("play", nil) }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onRemoteCommand?("pause", nil) }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onRemoteCommand?("playPause", nil) }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onRemoteCommand?("next", nil) }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onRemoteCommand?("previous", nil) }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let targetTime = posEvent.positionTime
            Task { @MainActor [weak self] in self?.onRemoteCommand?("seek", targetTime) }
            return .success
        }
    }

    private func publishNowPlaying(for snapshot: AppBoyPlaybackStateSnapshot) {
        guard let track = currentTrack, snapshot.transportState != "stopped" else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: "\(track.albumTitle) · \(track.consoleName)",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.transportState == "playing" ? snapshot.playbackRate : 0.0
        ]
        if snapshot.durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = snapshot.durationSeconds
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func sanitizedBands(_ raw: [Double]) -> [Double] {
        var bands = raw
        if bands.count < 10 {
            bands.append(contentsOf: Array(repeating: 0.0, count: 10 - bands.count))
        } else if bands.count > 10 {
            bands = Array(bands.prefix(10))
        }
        return bands.map { val in
            guard val.isFinite else { return 0.0 }
            let clamped = min(max(val, -12.0), 12.0)
            return (clamped * 2.0).rounded() / 2.0
        }
    }
}
