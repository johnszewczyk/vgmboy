import Foundation

/// Portable millisecond schedule for a queued fade and its bridge-reply fallback.
/// The fallback fits WebKit timer bounds; the audio device validates its ramp.
public struct PlaybackQueuedSkipFadePlan: Codable, Equatable, Sendable {
    public let durationMilliseconds: Int
    public let fallbackMilliseconds: Int
}

/// Typed transport facts used to decide whether a user-requested track change
/// should use the shared bounded fade. Playlist activation and adjacent
/// navigation submit this same value instead of unpacking parallel policy
/// arguments.
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

    /// Round up sub-millisecond fades and keep the fallback timer representable.
    /// Existing duration-only callers retain their original contract.
    public var plan: PlaybackQueuedSkipFadePlan? {
        guard let milliseconds = durationMilliseconds, milliseconds.isFinite, milliseconds > 0 else { return nil }
        let graceMilliseconds = 2_000
        let maxDuration = Int(Int32.max) - graceMilliseconds
        guard milliseconds <= Double(maxDuration) else { return nil }
        let duration = Int(milliseconds.rounded(.up))
        return PlaybackQueuedSkipFadePlan(durationMilliseconds: duration,
                                          fallbackMilliseconds: duration + graceMilliseconds)
    }
}

/// UI-neutral policy for a faded track change, including playlist activation
/// and queued adjacent-track navigation.
///
/// The frontend supplies the current transport facts and receives either the
/// bounded fade duration or `nil` when an ordinary replacement is required.
/// The frontends retain target handoff and cancellation; the common VGMBoy
/// output-gain command performs the ramp.
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
