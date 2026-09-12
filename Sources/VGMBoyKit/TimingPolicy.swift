import Foundation

struct PlaybackPlan: Sendable {
    var preFadeSeconds: Int
    var fadeSeconds: Int
    var isLongPlay: Bool
    var usesNativeEnding: Bool
    var usesDecoderNaturalDuration: Bool

    init(
        preFadeSeconds: Int,
        fadeSeconds: Int,
        isLongPlay: Bool,
        usesNativeEnding: Bool,
        usesDecoderNaturalDuration: Bool = false
    ) {
        self.preFadeSeconds = preFadeSeconds
        self.fadeSeconds = fadeSeconds
        self.isLongPlay = isLongPlay
        self.usesNativeEnding = usesNativeEnding
        self.usesDecoderNaturalDuration = usesDecoderNaturalDuration
    }

    var totalSeconds: Int { preFadeSeconds > 0 ? preFadeSeconds + fadeSeconds : 0 }
}

enum TimingPolicy {
    /// Builds a decode-window plan from metadata and the requested mode.
    ///
    /// Long play caps the stream at (manual + fade) seconds in the shell;
    /// a natural plan lets the decoder end at its own tagged length and fade.
    /// When no timing is known, a 150-second window keeps looping formats from
    /// running forever. A requested fade always makes that window explicit;
    /// with zero fade, natural-ending families may still use their native end.
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
                preFadeSeconds: max(0, manualSeconds),
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
            usesNativeEnding: hasNaturalEnding && clampedFade == 0
        )
    }
}
