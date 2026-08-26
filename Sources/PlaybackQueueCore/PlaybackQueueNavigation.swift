public enum PlaybackQueueDirection: String, Sendable, Codable {
    case previous
    case next
}

public enum PlaybackRepeatMode: String, Sendable, Codable {
    case off
    case playlist
    case song
}

public struct PlaybackQueueReplacementState: Equatable, Sendable, Codable {
    public let currentTrackID: String?
    public let selectedTrackID: String?

    public init(currentTrackID: String?, selectedTrackID: String?) {
        self.currentTrackID = currentTrackID
        self.selectedTrackID = selectedTrackID
    }
}

/// Queue identity policy shared by native frontends.
///
/// This type deliberately works on stable track IDs rather than frontend
/// models. CocoaSpice and SPCBoyWK can therefore share the exact same queue
/// transitions while keeping their presentation layers independent.
public enum PlaybackQueueNavigation {
    public static func transportPlaybackTarget(
        currentTrackID: String?,
        selectedTrackID: String?,
        playlistIDs: [String]
    ) -> String? {
        if let currentTrackID {
            return currentTrackID
        }

        if let selectedTrackID,
           playlistIDs.contains(selectedTrackID) {
            return selectedTrackID
        }

        return playlistIDs.first
    }

    public static func adjacentTrackID(
        currentTrackID: String?,
        playlistIDs: [String],
        direction: PlaybackQueueDirection,
        wraps: Bool
    ) -> String? {
        guard let currentTrackID,
              let currentIndex = playlistIDs.firstIndex(of: currentTrackID),
              !playlistIDs.isEmpty else {
            return nil
        }

        switch direction {
        case .next:
            let nextIndex = playlistIDs.index(after: currentIndex)
            if nextIndex == playlistIDs.endIndex {
                return wraps ? playlistIDs.first : nil
            }
            return playlistIDs[nextIndex]
        case .previous:
            if currentIndex == playlistIDs.startIndex {
                return wraps ? playlistIDs.last : nil
            }
            return playlistIDs[playlistIDs.index(before: currentIndex)]
        }
    }

    public static func completionAdvanceTargetID(
        currentTrackID: String?,
        playlistIDs: [String]
    ) -> String? {
        guard !playlistIDs.isEmpty else { return nil }
        guard let currentTrackID,
              playlistIDs.contains(currentTrackID) else {
            // A replacement queue can intentionally keep the old track
            // playing until it finishes. Its identity is not an anchor in
            // the replacement queue, so continuation starts at its head.
            return playlistIDs.first
        }

        return adjacentTrackID(
            currentTrackID: currentTrackID,
            playlistIDs: playlistIDs,
            direction: .next,
            wraps: false
        )
    }

    /// Computes the single target allowed after a native natural-end event.
    ///
    /// Random playback remains a frontend concern because it needs that
    /// frontend's candidate pool. Ordinary repeat behavior, however, is pure
    /// queue policy and must not diverge between native frontends.
    public static func completionTargetID(
        currentTrackID: String?,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> String? {
        guard !playlistIDs.isEmpty else { return nil }

        switch repeatMode {
        case .song:
            guard let currentTrackID,
                  playlistIDs.contains(currentTrackID) else {
                return nil
            }
            return currentTrackID
        case .off:
            return completionAdvanceTargetID(
                currentTrackID: currentTrackID,
                playlistIDs: playlistIDs
            )
        case .playlist:
            return completionAdvanceTargetID(
                currentTrackID: currentTrackID,
                playlistIDs: playlistIDs
            ) ?? playlistIDs.first
        }
    }

    public static func replacementState(
        currentTrackID: String?,
        playlistIDs: [String],
        preservePlayback: Bool
    ) -> PlaybackQueueReplacementState {
        let replacementCurrentTrackID = preservePlayback ? currentTrackID : nil
        let replacementSelectedTrackID: String?

        if let replacementCurrentTrackID,
           playlistIDs.contains(replacementCurrentTrackID) {
            replacementSelectedTrackID = replacementCurrentTrackID
        } else {
            replacementSelectedTrackID = playlistIDs.first
        }

        return PlaybackQueueReplacementState(
            currentTrackID: replacementCurrentTrackID,
            selectedTrackID: replacementSelectedTrackID
        )
    }
}
