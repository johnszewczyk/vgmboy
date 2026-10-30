import Foundation
import Testing
@testable import PlaybackTransportCore

@Test
func queuedSkipRequiresPlayingTrackBeforePreFadeBoundary() {
    #expect(PlaybackFadePolicy.queuedSkipDuration(
        enabled: true,
        isPlaying: true,
        hasCurrentTrack: true,
        elapsedSeconds: 10,
        preFadeSeconds: 150,
        fadeSeconds: 6,
        totalSeconds: 156
    ) == 6)

    #expect(PlaybackFadePolicy.queuedSkipDuration(
        enabled: true,
        isPlaying: false,
        hasCurrentTrack: true,
        elapsedSeconds: 10,
        preFadeSeconds: 150,
        fadeSeconds: 6,
        totalSeconds: 156
    ) == nil)

    #expect(PlaybackFadePolicy.queuedSkipDuration(
        enabled: true,
        isPlaying: true,
        hasCurrentTrack: true,
        elapsedSeconds: 150,
        preFadeSeconds: 150,
        fadeSeconds: 6,
        totalSeconds: 156
    ) == nil)
}

@Test
func queuedSkipIsBoundedByRemainingWindow() {
    #expect(PlaybackFadePolicy.queuedSkipDuration(
        enabled: true,
        isPlaying: true,
        hasCurrentTrack: true,
        elapsedSeconds: 154,
        preFadeSeconds: 155,
        fadeSeconds: 6,
        totalSeconds: 155
    ) == 1)
}

@Test
func queuedSkipRequestCarriesTheCommonPolicyInput() throws {
    let request = PlaybackQueuedSkipFadeRequest(
        enabled: true,
        isPlaying: true,
        hasCurrentTrack: true,
        elapsedSeconds: 10,
        preFadeSeconds: 150,
        fadeSeconds: 6,
        totalSeconds: 156
    )

    let decoded = try JSONDecoder().decode(
        PlaybackQueuedSkipFadeRequest.self,
        from: JSONEncoder().encode(request)
    )

    #expect(decoded == request)
    #expect(request.duration == 6)
    #expect(request.durationMilliseconds == 6_000)
}

@Test
func queuedFadePlanUsesIntegralBoundedBridgeTimers() throws {
    func request(fade: Double) -> PlaybackQueuedSkipFadeRequest {
        .init(enabled: true, isPlaying: true, hasCurrentTrack: true,
              elapsedSeconds: 0, preFadeSeconds: 1, fadeSeconds: fade, totalSeconds: max(1, fade))
    }
    let plan = try #require(request(fade: 0.0001).plan)
    #expect(plan.durationMilliseconds == 1)
    #expect(plan.fallbackMilliseconds == 2_001)
    let encoded = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(PlaybackQueuedSkipFadePlan.self, from: encoded)
    #expect(decoded == plan)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Int])
    #expect(object == ["durationMilliseconds": 1, "fallbackMilliseconds": 2_001])
    let maxMilliseconds = Int(Int32.max) - 2_000
    let boundary = try #require(request(fade: Double(maxMilliseconds) / 1_000).plan)
    #expect(boundary.fallbackMilliseconds == Int(Int32.max))
    #expect(request(fade: Double(Int32.max) / 1_000).plan == nil)
    #expect(request(fade: Double.greatestFiniteMagnitude).plan == nil)
    let disabled = PlaybackQueuedSkipFadeRequest(enabled: false, isPlaying: true, hasCurrentTrack: true,
        elapsedSeconds: 0, preFadeSeconds: 1, fadeSeconds: 1, totalSeconds: 2)
    #expect(disabled.plan == nil)
}
