import Foundation

struct PlaybackPlan: Sendable {
    var preFadeSeconds: Int
    var fadeSeconds: Int
    var isLongPlay: Bool
    var usesNativeEnding: Bool

    init(preFadeSeconds: Int, fadeSeconds: Int, isLongPlay: Bool, usesNativeEnding: Bool) {
        self.preFadeSeconds = preFadeSeconds
        self.fadeSeconds = fadeSeconds
        self.isLongPlay = isLongPlay
        self.usesNativeEnding = usesNativeEnding
    }

    var totalSeconds: Int { preFadeSeconds + fadeSeconds }
}

enum TimingPolicy {
    /// Builds a decode-window plan from metadata and the requested mode.
    ///
    /// Long play caps the stream at (manual + fade) seconds in the shell;
    /// a natural plan lets the decoder end at its own tagged length and fade.
    /// When no timing is known, a 150-second window with a native ending keeps
    /// looping formats from running forever. Families without a natural ending
    /// (USF) always get a capped window so they never run indefinitely.
    static func plan(
        supportsLongPlay: Bool,
        metadata: TrackMetadata?,
        longPlayEnabled: Bool,
        manualSeconds: Int,
        fadeSeconds: Int,
        hasNaturalEnding: Bool = true
    ) -> PlaybackPlan {
        let clampedFade = max(0, fadeSeconds)
        if longPlayEnabled, supportsLongPlay {
            return PlaybackPlan(
                preFadeSeconds: max(1, manualSeconds),
                fadeSeconds: clampedFade,
                isLongPlay: true,
                usesNativeEnding: false
            )
        }
        if let metadata, metadata.playMs > 0 {
            let native = max(1, Int((Double(metadata.playMs) / 1000.0).rounded()))
            return PlaybackPlan(
                preFadeSeconds: native,
                fadeSeconds: clampedFade,
                isLongPlay: false,
                usesNativeEnding: hasNaturalEnding && clampedFade == 0
            )
        }
        return PlaybackPlan(
            preFadeSeconds: 150,
            fadeSeconds: clampedFade,
            isLongPlay: false,
            usesNativeEnding: hasNaturalEnding
        )
    }
}
