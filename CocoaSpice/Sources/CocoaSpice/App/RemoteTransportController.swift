import Foundation
import MediaPlayer

struct RemoteTransportNowPlaying: Equatable, Sendable {
    static let minimumElapsedUpdateInterval: TimeInterval = 1

    let title: String
    let albumTitle: String
    let elapsedSeconds: TimeInterval
    let durationSeconds: TimeInterval
    let isPlaying: Bool

    /// MediaRemote is an Objective-C framework boundary. Keep the payload a
    /// finite, non-negative value snapshot before handing it to Foundation;
    /// decoder or transport corruption must not become NaN/Inf metadata.
    var sanitizedForMediaRemote: Self {
        Self(
            title: title,
            albumTitle: albumTitle,
            elapsedSeconds: Self.sanitizeTime(elapsedSeconds),
            durationSeconds: Self.sanitizeTime(durationSeconds),
            isPlaying: isPlaying
        )
    }

    static func shouldPublish(previous: Self?, next: Self) -> Bool {
        guard let previous else { return true }
        guard previous.title == next.title,
              previous.albumTitle == next.albumTitle,
              previous.durationSeconds == next.durationSeconds,
              previous.isPlaying == next.isPlaying else {
            return true
        }
        return abs(next.elapsedSeconds - previous.elapsedSeconds) >= minimumElapsedUpdateInterval
    }

    private static func sanitizeTime(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }
}

@MainActor
final class RemoteTransportController {
    private var isConfigured = false
    private var lastPublishedNowPlaying: RemoteTransportNowPlaying?

    func configure(
        previous: @escaping @MainActor () -> Void,
        play: @escaping @MainActor () -> Void,
        pause: @escaping @MainActor () -> Void,
        togglePlayPause: @escaping @MainActor () -> Void,
        next: @escaping @MainActor () -> Void
    ) {
        guard !isConfigured else { return }
        isConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true

        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in previous() }
            return .success
        }

        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in next() }
            return .success
        }
    }

    func updateNowPlaying(_ nowPlaying: RemoteTransportNowPlaying) {
        let snapshot = nowPlaying.sanitizedForMediaRemote
        guard RemoteTransportNowPlaying.shouldPublish(
            previous: lastPublishedNowPlaying,
            next: snapshot
        ) else { return }
        lastPublishedNowPlaying = snapshot

        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = snapshot.title
        info[MPMediaItemPropertyAlbumTitle] = snapshot.albumTitle
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: snapshot.elapsedSeconds)
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: snapshot.durationSeconds)
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: snapshot.isPlaying ? 1.0 : 0.0)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = snapshot.isPlaying ? .playing : .paused
    }
}
