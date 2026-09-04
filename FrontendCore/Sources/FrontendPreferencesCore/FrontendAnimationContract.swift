import Foundation

/// Cross-frontend contract for user-visible animations.
///
/// The contract deliberately describes elapsed time rather than a fixed number
/// of updates. Native and WebKit renderers may receive frames at different
/// rates, but both must reach the target after the requested duration and must
/// keep zero as the explicit immediate-transition value.
public enum FrontendAnimationContract {
    public static let frameRate = 60
    public static let frameNanoseconds: UInt64 = 1_000_000_000 / UInt64(frameRate)
    public static let easingName = "easeInOut"

    public static func easedProgress(
        elapsedMilliseconds: Double,
        durationMilliseconds: Int
    ) -> Double {
        guard durationMilliseconds > 0 else { return 1 }
        let linearProgress = min(
            1,
            max(0, elapsedMilliseconds / Double(durationMilliseconds))
        )
        return linearProgress < 0.5
            ? 2 * linearProgress * linearProgress
            : 1 - (pow(-2 * linearProgress + 2, 2) / 2)
    }
}
