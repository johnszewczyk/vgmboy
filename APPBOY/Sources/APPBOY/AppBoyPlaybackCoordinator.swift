import AVFoundation
import Foundation
import MediaPlayer

@MainActor
final class AppBoyPlaybackCoordinator {
    var onStateChanged: ((AppBoyPlaybackStateSnapshot) -> Void)?
    var onNaturalEnd: ((Int, String) -> Void)?
    var onRemoteCommand: ((String, Double?) -> Void)?

    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var failedObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    private(set) var generation: Int = 0
    private var currentTrack: AppBoyTrack?
    private var transportState: String = "stopped"
    private var configuredRate: Double = 1.0
    private var configuredVolume: Float = 1.0
    private var targetDurationSeconds: Double = 0.0
    private var wasPlayingBeforeInterruption = false
    private var remoteCommandsConfigured = false

    init() {
        configureAudioSession()
        configureObservers()
        configureRemoteCommands()
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
            try session.setActive(true)
        } catch {
            // Audio session activation may be deferred when launched in background; retry on start.
        }
    }

    func start(
        track: AppBoyTrack,
        playbackRate: Double,
        volume: Double,
        overrideDurationSeconds: Double?
    ) -> AppBoyPlaybackStateSnapshot {
        generation += 1
        let activeGen = generation
        configureAudioSession()

        currentTrack = track
        configuredRate = min(max(playbackRate, 0.5), 2.0)
        configuredVolume = Float(min(max(volume, 0.0), 1.0))
        targetDurationSeconds = overrideDurationSeconds ?? track.durationSeconds

        do {
            let resolvedURL = try AppBoyChiptuneSynth.resolvePlayableURL(
                for: track.streamURI,
                trackId: track.id,
                durationSeconds: targetDurationSeconds
            )
            let item = AVPlayerItem(url: resolvedURL)
            item.audioTimePitchAlgorithm = .timeDomain
            installItemObservers(for: item, generation: activeGen, trackId: track.id)

            player.replaceCurrentItem(with: item)
            player.volume = configuredVolume
            player.playImmediately(atRate: Float(configuredRate))
            transportState = "playing"
            let snap = currentSnapshot(errorMessage: nil)
            publishNowPlaying(for: snap)
            onStateChanged?(snap)
            return snap
        } catch {
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
        player.pause()
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
        player.volume = configuredVolume
        player.playImmediately(atRate: Float(configuredRate))
        transportState = "playing"
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func stop(expectedGeneration: Int?) -> AppBoyPlaybackStateSnapshot {
        if let expectedGeneration, expectedGeneration != generation {
            return currentSnapshot(errorMessage: nil)
        }
        player.pause()
        player.seek(to: .zero)
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
        let clamped = max(0.0, min(seconds, max(targetDurationSeconds, 0.1)))
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        _ = await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func setRate(_ rate: Double) -> AppBoyPlaybackStateSnapshot {
        configuredRate = min(max(rate, 0.5), 2.0)
        if transportState == "playing" {
            player.rate = Float(configuredRate)
        }
        let snap = currentSnapshot(errorMessage: nil)
        publishNowPlaying(for: snap)
        onStateChanged?(snap)
        return snap
    }

    func setVolume(_ volume: Double) -> AppBoyPlaybackStateSnapshot {
        configuredVolume = Float(min(max(volume, 0.0), 1.0))
        player.volume = configuredVolume
        return currentSnapshot(errorMessage: nil)
    }

    func currentSnapshot(errorMessage: String?) -> AppBoyPlaybackStateSnapshot {
        let rawSeconds = player.currentTime().seconds
        let elapsed = rawSeconds.isFinite && rawSeconds >= 0 ? rawSeconds : 0.0
        var duration = targetDurationSeconds
        if let itemSeconds = player.currentItem?.duration.seconds, itemSeconds.isFinite && itemSeconds > 0 {
            duration = itemSeconds
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

    private func installItemObservers(for item: AVPlayerItem, generation itemGen: Int, trackId: String) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failedObserver { NotificationCenter.default.removeObserver(failedObserver) }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == itemGen else { return }
                self.transportState = "stopped"
                let snap = self.currentSnapshot(errorMessage: nil)
                self.publishNowPlaying(for: snap)
                self.onStateChanged?(snap)
                self.onNaturalEnd?(itemGen, trackId)
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

    private func configureObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.currentTrack != nil, self.transportState == "playing" else { return }
                let snap = self.currentSnapshot(errorMessage: nil)
                if self.targetDurationSeconds > 0 && snap.elapsedSeconds >= self.targetDurationSeconds {
                    let completedGen = self.generation
                    if let trackId = self.currentTrack?.id {
                        self.player.pause()
                        self.transportState = "stopped"
                        self.publishNowPlaying(for: self.currentSnapshot(errorMessage: nil))
                        self.onNaturalEnd?(completedGen, trackId)
                    }
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
            MPMediaItemPropertyAlbumTitle: "\(track.albumTitle) (\(track.consoleName))",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.transportState == "playing" ? snapshot.playbackRate : 0.0
        ]
        if snapshot.durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = snapshot.durationSeconds
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
