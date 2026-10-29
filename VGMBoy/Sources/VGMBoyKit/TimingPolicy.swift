import Foundation

struct PlaybackPlan: Sendable {
    var preFadeMilliseconds: Int
    var fadeMilliseconds: Int
    var preFadeSeconds: Int { preFadeMilliseconds / 1_000 }
    var fadeSeconds: Int { fadeMilliseconds / 1_000 }
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
        self.preFadeMilliseconds = preFadeSeconds * 1_000
        self.fadeMilliseconds = fadeSeconds * 1_000
        self.isLongPlay = isLongPlay
        self.usesNativeEnding = usesNativeEnding
        self.usesDecoderNaturalDuration = usesDecoderNaturalDuration
    }

    init(
        preFadeMilliseconds: Int,
        fadeMilliseconds: Int,
        isLongPlay: Bool,
        usesNativeEnding: Bool,
        usesDecoderNaturalDuration: Bool = false
    ) {
        self.preFadeMilliseconds = max(0, preFadeMilliseconds)
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.isLongPlay = isLongPlay
        self.usesNativeEnding = usesNativeEnding
        self.usesDecoderNaturalDuration = usesDecoderNaturalDuration
    }

    var totalMilliseconds: Int { preFadeMilliseconds > 0 ? preFadeMilliseconds + fadeMilliseconds : 0 }
    var totalSeconds: Int { totalMilliseconds / 1_000 }
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
