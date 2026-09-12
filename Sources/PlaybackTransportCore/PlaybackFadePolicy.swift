import Foundation

/// Typed transport facts used to decide whether an adjacent-navigation request
/// should use the shared bounded fade. Both native and WebKit frontends submit
/// this same value instead of unpacking parallel policy arguments.
public struct PlaybackQueuedSkipFadeRequest: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let isPlaying: Bool
    public let hasCurrentTrack: Bool
    public let elapsedSeconds: Double
    public let preFadeSeconds: Double
    public let fadeSeconds: Double
    public let totalSeconds: Double

    public init(
        enabled: Bool,
        isPlaying: Bool,
        hasCurrentTrack: Bool,
        elapsedSeconds: Double,
        preFadeSeconds: Double,
        fadeSeconds: Double,
        totalSeconds: Double
    ) {
        self.enabled = enabled
        self.isPlaying = isPlaying
        self.hasCurrentTrack = hasCurrentTrack
        self.elapsedSeconds = elapsedSeconds
        self.preFadeSeconds = preFadeSeconds
        self.fadeSeconds = fadeSeconds
        self.totalSeconds = totalSeconds
    }

    public var duration: TimeInterval? {
        PlaybackFadePolicy.queuedSkipDuration(
            enabled: enabled,
            isPlaying: isPlaying,
            hasCurrentTrack: hasCurrentTrack,
            elapsedSeconds: elapsedSeconds,
            preFadeSeconds: preFadeSeconds,
            fadeSeconds: fadeSeconds,
            totalSeconds: totalSeconds
        )
    }

    public var durationMilliseconds: TimeInterval? {
        duration.map { $0 * 1_000 }
    }
}

/// UI-neutral policy for a queued adjacent-track fade.
///
/// The frontend supplies the current transport facts and receives either the
/// bounded fade duration or `nil` when an ordinary replacement is required.
/// VGMBoy still owns the actual output ramp and audio timing.
public enum PlaybackFadePolicy {
    public static func queuedSkipDuration(
        enabled: Bool,
        isPlaying: Bool,
        hasCurrentTrack: Bool,
        elapsedSeconds: Double,
        preFadeSeconds: Double,
        fadeSeconds: Double,
        totalSeconds: Double
    ) -> TimeInterval? {
        guard enabled,
              isPlaying,
              hasCurrentTrack,
              elapsedSeconds.isFinite,
              preFadeSeconds.isFinite,
              fadeSeconds.isFinite,
              totalSeconds.isFinite,
              fadeSeconds > 0,
              elapsedSeconds < preFadeSeconds else {
            return nil
        }

        let remainingSeconds = max(0, totalSeconds - max(0, elapsedSeconds))
        let duration = min(fadeSeconds, remainingSeconds)
        return duration > 0 ? duration : nil
    }
}
