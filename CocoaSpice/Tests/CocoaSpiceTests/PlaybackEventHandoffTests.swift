import Foundation
import PlaybackTransportCore
import Testing
@testable import CocoaSpice

private func eventStatus(
    track: String? = "a", generation: Int = 1, loaded: Bool = true, ended: Bool = true
) -> PlaybackTransportStatus {
    PlaybackTransportStatus(currentTrackID: track, generation: generation,
                            isPlaying: !ended, elapsedSeconds: 3,
                            reachedEnd: ended, trackLoaded: loaded)
}

@Test func naturalEndHandoffRejectsReplacedOrResumedPlayback() {
    let event = eventStatus()
    #expect(PlaybackEngine.acceptsNaturalEnd(event, current: event))
    #expect(!PlaybackEngine.acceptsNaturalEnd(event, current: eventStatus(generation: 2)))
    #expect(!PlaybackEngine.acceptsNaturalEnd(event, current: eventStatus(track: "b")))
    #expect(!PlaybackEngine.acceptsNaturalEnd(event, current: eventStatus(loaded: false)))
    #expect(!PlaybackEngine.acceptsNaturalEnd(event, current: eventStatus(ended: false)))
    #expect(!PlaybackEngine.acceptsNaturalEnd(eventStatus(generation: 0), current: eventStatus(generation: 0)))
}

@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["COCOASPICE_EVENT_WAV"] != nil,
               "Set COCOASPICE_EVENT_WAV to a short WAV fixture."))
func naturalEndHandoffDeliversCurrentTrackOnce() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["COCOASPICE_EVENT_WAV"])
    let engine = PlaybackEngine()
    let track = TrackItem(url: URL(fileURLWithPath: path))
    var endedIDs: [String?] = []
    var statusCount = 0
    engine.setPlaybackStateHandler { _ in statusCount += 1 }
    engine.setPlaybackNaturalEndHandler { snapshot in endedIDs.append(snapshot.currentTrackID) }
    try await engine.play(
        track: track,
        plan: PlaybackPlan(preFadeSeconds: 150, fadeSeconds: 0, usesNativeEnding: true, isLongPlay: false),
        tempo: .defaultValue,
        requestID: engine.reservePlaybackRequest()
    )
    for _ in 0..<80 {
        if !endedIDs.isEmpty { break }
        try await Task.sleep(for: .milliseconds(100))
    }
    try await Task.sleep(for: .milliseconds(400))
    #expect(endedIDs == [track.id])
    #expect(statusCount < 100, "status refresh must not create an event feedback loop")
    await engine.stop()
}
