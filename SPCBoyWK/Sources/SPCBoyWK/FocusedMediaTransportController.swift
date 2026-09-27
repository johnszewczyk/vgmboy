import Foundation
import MediaPlayer

struct RemoteTransportNowPlaying: Equatable, Sendable {
    let title: String
    let artist: String
    let albumTitle: String
    let elapsedSeconds: TimeInterval
    let durationSeconds: TimeInterval
    let isPlaying: Bool

    init?(payload: [String: Any]) {
        guard let title = payload["title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        self.artist = payload["artist"] as? String ?? ""
        self.albumTitle = payload["albumTitle"] as? String ?? ""
        self.elapsedSeconds = max(0, payload["elapsedSeconds"] as? TimeInterval ?? 0)
        self.durationSeconds = max(0, payload["durationSeconds"] as? TimeInterval ?? 0)
        self.isPlaying = payload["isPlaying"] as? Bool ?? false
    }
}

@MainActor
final class FocusedMediaTransportController {
    private var isConfigured = false
    private var lastPublishedNowPlaying: RemoteTransportNowPlaying?
    private let dispatch: @MainActor (String) -> Void

    init(dispatch: @escaping @MainActor (String) -> Void) {
        self.dispatch = dispatch
    }

    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()
        install(commandCenter.previousTrackCommand, action: "previous")
        install(commandCenter.playCommand, action: "play")
        install(commandCenter.pauseCommand, action: "pause")
        install(commandCenter.togglePlayPauseCommand, action: "playPause")
        install(commandCenter.nextTrackCommand, action: "next")
    }

    func updateNowPlaying(_ nowPlaying: RemoteTransportNowPlaying?) {
        guard nowPlaying != lastPublishedNowPlaying else { return }
        lastPublishedNowPlaying = nowPlaying

        guard let nowPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlaying.title,
            MPMediaItemPropertyArtist: nowPlaying.artist,
            MPMediaItemPropertyAlbumTitle: nowPlaying.albumTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: nowPlaying.elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: nowPlaying.isPlaying ? 1.0 : 0.0
        ]
        if nowPlaying.durationSeconds > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = nowPlaying.durationSeconds
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = nowPlaying.isPlaying ? .playing : .paused
    }

    private func install(_ command: MPRemoteCommand, action: String) {
        command.isEnabled = true
        command.addTarget { [dispatch] _ in
            Task { @MainActor in dispatch(action) }
            return .success
        }
    }
}
