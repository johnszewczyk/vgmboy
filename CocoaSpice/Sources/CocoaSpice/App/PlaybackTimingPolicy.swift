import Foundation
import VGMBoyKit

typealias PlaybackPlan = PlaybackTimingPlan

enum PlaybackTimingPolicy {
    static func playbackPlan(
        metadata: TrackMetadata?,
        trackPathExtension: String?,
        longPlayEnabled: Bool,
        manualPreFadeSeconds: Int,
        fadeSeconds: Int,
        unknownDurationSeconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds
    ) -> PlaybackPlan {
        let family = trackPathExtension.flatMap {
            FormatRegistry.family(for: "source.\($0)")
        }
        let useLongPlay = longPlayEnabled && family?.supportsLongPlay == true
        let request = PlaybackTimingRequest(
            playbackMode: useLongPlay ? .longPlay : .fileDefault,
            playMilliseconds: useLongPlay ? manualPreFadeSeconds * 1_000 : nil,
            fadeMilliseconds: max(0, fadeSeconds) * 1_000,
            unknownDurationMilliseconds: max(1, unknownDurationSeconds) * 1_000
        )
        return VGMBoyKit.PlaybackTimingPolicy.plan(
            metadata: metadata?.playbackTimingMetadata,
            family: family,
            request: request
        )
    }
}
