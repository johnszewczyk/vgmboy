import Foundation

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
