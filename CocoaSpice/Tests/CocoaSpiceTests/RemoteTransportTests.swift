import Foundation
import Testing
@testable import CocoaSpice

@Test
func remoteTransportPublishesTheFirstSnapshot() {
    let snapshot = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 0,
        durationSeconds: 180,
        isPlaying: true
    )

    #expect(RemoteTransportNowPlaying.shouldPublish(previous: nil, next: snapshot))
}

@Test
func remoteTransportCoalescesSubsecondProgressButPublishesNormalProgress() {
    let first = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 10,
        durationSeconds: 180,
        isPlaying: true
    )
    let subsecond = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 10.75,
        durationSeconds: 180,
        isPlaying: true
    )
    let oneSecond = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 11,
        durationSeconds: 180,
        isPlaying: true
    )

    #expect(!RemoteTransportNowPlaying.shouldPublish(previous: first, next: subsecond))
    #expect(RemoteTransportNowPlaying.shouldPublish(previous: first, next: oneSecond))
}

@Test
func remoteTransportPublishesTrackStateAndSeekChangesImmediately() {
    let first = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 10,
        durationSeconds: 180,
        isPlaying: true
    )
    let titleChanged = RemoteTransportNowPlaying(
        title: "Other Song",
        albumTitle: "Game",
        elapsedSeconds: 10,
        durationSeconds: 180,
        isPlaying: true
    )
    let paused = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 10,
        durationSeconds: 180,
        isPlaying: false
    )
    let seeked = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: 90,
        durationSeconds: 180,
        isPlaying: true
    )

    #expect(RemoteTransportNowPlaying.shouldPublish(previous: first, next: titleChanged))
    #expect(RemoteTransportNowPlaying.shouldPublish(previous: first, next: paused))
    #expect(RemoteTransportNowPlaying.shouldPublish(previous: first, next: seeked))
}

@Test
func remoteTransportSanitizesNonFiniteAndNegativeTimes() {
    let snapshot = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: -.infinity,
        durationSeconds: .nan,
        isPlaying: true
    ).sanitizedForMediaRemote

    #expect(snapshot.elapsedSeconds == 0)
    #expect(snapshot.durationSeconds == 0)

    let negative = RemoteTransportNowPlaying(
        title: "Song",
        albumTitle: "Game",
        elapsedSeconds: -4,
        durationSeconds: -1,
        isPlaying: false
    ).sanitizedForMediaRemote

    #expect(negative.elapsedSeconds == 0)
    #expect(negative.durationSeconds == 0)
}
