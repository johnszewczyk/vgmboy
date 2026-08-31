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
