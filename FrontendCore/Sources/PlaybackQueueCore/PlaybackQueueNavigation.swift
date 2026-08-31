import Foundation

public enum PlaybackQueueDirection: String, Sendable, Codable {
    case previous
    case next
}

public enum PlaybackRepeatMode: String, Sendable, Codable {
    case off
    case playlist
    case song
}

public enum PlaybackContinuationAction: Equatable, Sendable, Codable {
    case stop
    case play(trackID: String)
}

/// Explicit result of a native natural-end decision.
///
/// A nullable target made it too easy for each frontend to interpret “no
/// target” differently. The shared contract makes the terminal case and the
/// next-track case unambiguous without knowing track models or presentation.
public struct PlaybackContinuationDecision: Equatable, Sendable, Codable {
    public let action: PlaybackContinuationAction

    public init(action: PlaybackContinuationAction) {
        self.action = action
    }

    public var targetID: String? {
        guard case let .play(trackID) = action else { return nil }
        return trackID
    }
}

/// Complete, presentation-free input to the shared completion lifecycle.
/// Frontends may encode/decode this value at a bridge boundary, but they must
/// not reconstruct its fields into a second completion policy.
public struct PlaybackContinuationRequest: Equatable, Sendable, Codable {
    public let generation: Int
    public let state: PlaybackQueueState
    public let playlistIDs: [String]
    public let repeatMode: PlaybackRepeatMode

    public init(
        generation: Int,
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) {
        self.generation = generation
        self.state = state
        self.playlistIDs = playlistIDs
        self.repeatMode = repeatMode
    }
}

/// Thread-safe one-shot claim for a playback continuation.
///
/// Native playback may report the same terminal state through both an event
/// and a status observation. Frontends must share one claim primitive so only
/// one path can retire the completed session and advance the queue.
public final class PlaybackContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimedGeneration: Int?

    public init() {}

    public func reset() {
        lock.lock()
        claimedGeneration = nil
        lock.unlock()
    }

    public func claim(generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard claimedGeneration != generation else { return false }
        claimedGeneration = generation
        return true
    }

    public func isClaimed(generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return claimedGeneration == generation
    }
}

/// Shared owner for the one-shot natural-end handoff boundary.
///
/// The gate and the queue decision are one lifecycle concern: a completion
/// may be observed more than once, but only the first observation may claim
/// the generation and ask the shared queue policy what happens next. The
/// coordinator remains value/ID-only so AppKit and WebKit stay adapters.
public final class PlaybackContinuationCoordinator: @unchecked Sendable {
    private let gate = PlaybackContinuationGate()

    public init() {}

    public func reset() {
        gate.reset()
    }

    public func claim(generation: Int) -> Bool {
        gate.claim(generation: generation)
    }

    public func isClaimed(generation: Int) -> Bool {
        gate.isClaimed(generation: generation)
    }

    public func decision(
        generation: Int,
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        guard claim(generation: generation) else { return nil }
        return state.completionDecision(
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        )
    }
}

public struct PlaybackQueueReplacementState: Equatable, Sendable, Codable {
    public let currentTrackID: String?
    public let selectedTrackID: String?

    public init(currentTrackID: String?, selectedTrackID: String?) {
        self.currentTrackID = currentTrackID
        self.selectedTrackID = selectedTrackID
    }
}

/// Value-only queue identity shared by native frontends.
///
/// This is deliberately unaware of track models, decoders, and presentation.
/// It centralizes the transitions that must remain identical when a frontend
/// replaces a playlist, navigates from the transport, or handles natural end.
public struct PlaybackQueueState: Equatable, Sendable, Codable {
    public let currentTrackID: String?
    public let selectedTrackID: String?
    public let pendingTrackID: String?

    public init(
        currentTrackID: String?,
        selectedTrackID: String?,
        pendingTrackID: String?
    ) {
        self.currentTrackID = currentTrackID
        self.selectedTrackID = selectedTrackID
        self.pendingTrackID = pendingTrackID
    }

    public func replacing(
        playlistIDs: [String],
        preservePlayback: Bool
    ) -> PlaybackQueueState {
        let replacementCurrentTrackID = preservePlayback ? currentTrackID : nil
        let replacementPendingTrackID = preservePlayback ? pendingTrackID : nil
        let replacementSelectedTrackID: String?

        if let replacementCurrentTrackID,
           playlistIDs.contains(replacementCurrentTrackID) {
            replacementSelectedTrackID = replacementCurrentTrackID
        } else {
            replacementSelectedTrackID = playlistIDs.first
        }

        return PlaybackQueueState(
            currentTrackID: replacementCurrentTrackID,
            selectedTrackID: replacementSelectedTrackID,
            pendingTrackID: replacementPendingTrackID
        )
    }

    public func transportTargetID(playlistIDs: [String]) -> String? {
        PlaybackQueueNavigation.transportPlaybackTarget(
            currentTrackID: currentTrackID,
            selectedTrackID: selectedTrackID,
            playlistIDs: playlistIDs
        )
    }

    public func navigationAnchorID(playlistIDs: [String]) -> String? {
        pendingTrackID ?? currentTrackID ?? transportTargetID(playlistIDs: playlistIDs)
    }

    public func adjacentTargetID(
        playlistIDs: [String],
        direction: PlaybackQueueDirection,
        wraps: Bool
    ) -> String? {
        PlaybackQueueNavigation.adjacentTrackID(
            currentTrackID: navigationAnchorID(playlistIDs: playlistIDs),
            playlistIDs: playlistIDs,
            direction: direction,
            wraps: wraps
        )
    }

    public func completionTargetID(
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> String? {
        PlaybackQueueNavigation.completionDecision(
            currentTrackID: currentTrackID,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        ).targetID
    }

    public func completionDecision(
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision {
        PlaybackQueueNavigation.completionDecision(
            currentTrackID: currentTrackID,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        )
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

    /// Computes the explicit action allowed after a native natural-end event.
    ///
    /// Random playback remains a frontend concern because it needs that
    /// frontend's candidate pool. Ordinary repeat behavior, however, is pure
    /// queue policy and must not diverge between native frontends.
    public static func completionDecision(
        currentTrackID: String?,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision {
        guard !playlistIDs.isEmpty else {
            return PlaybackContinuationDecision(action: .stop)
        }

        switch repeatMode {
        case .song:
            guard let currentTrackID,
                  playlistIDs.contains(currentTrackID) else {
                return PlaybackContinuationDecision(action: .stop)
            }
            return PlaybackContinuationDecision(action: .play(trackID: currentTrackID))
        case .off:
            guard let targetID = completionAdvanceTargetID(
                currentTrackID: currentTrackID,
                playlistIDs: playlistIDs
            ) else {
                return PlaybackContinuationDecision(action: .stop)
            }
            return PlaybackContinuationDecision(action: .play(trackID: targetID))
        case .playlist:
            let targetID = completionAdvanceTargetID(
                currentTrackID: currentTrackID,
                playlistIDs: playlistIDs
            ) ?? playlistIDs.first
            guard let targetID else {
                return PlaybackContinuationDecision(action: .stop)
            }
            return PlaybackContinuationDecision(action: .play(trackID: targetID))
        }
    }

    public static func completionTargetID(
        currentTrackID: String?,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> String? {
        guard case let .play(trackID) = completionDecision(
            currentTrackID: currentTrackID,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        ).action else { return nil }
        return trackID
    }

    public static func replacementState(
        currentTrackID: String?,
        playlistIDs: [String],
        preservePlayback: Bool
    ) -> PlaybackQueueReplacementState {
        let state = PlaybackQueueState(
            currentTrackID: currentTrackID,
            selectedTrackID: nil,
            pendingTrackID: nil
        ).replacing(playlistIDs: playlistIDs, preservePlayback: preservePlayback)
        return PlaybackQueueReplacementState(
            currentTrackID: state.currentTrackID,
            selectedTrackID: state.selectedTrackID
        )
    }
}
