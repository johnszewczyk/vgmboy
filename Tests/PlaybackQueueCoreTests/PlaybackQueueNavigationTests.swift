import Testing
@testable import PlaybackQueueCore

@Test
func transportTargetPrefersCurrentThenSelectedThenQueueHead() {
    let ids = ["one", "two", "three"]

    #expect(PlaybackQueueNavigation.transportPlaybackTarget(
        currentTrackID: "two", selectedTrackID: "one", playlistIDs: ids
    ) == "two")
    #expect(PlaybackQueueNavigation.transportPlaybackTarget(
        currentTrackID: nil, selectedTrackID: "three", playlistIDs: ids
    ) == "three")
    #expect(PlaybackQueueNavigation.transportPlaybackTarget(
        currentTrackID: nil, selectedTrackID: "missing", playlistIDs: ids
    ) == "one")
}

@Test
func adjacentNavigationMatchesCocoaSpiceWrappingRules() {
    let ids = ["one", "two", "three"]

    #expect(PlaybackQueueNavigation.adjacentTrackID(
        currentTrackID: "two", playlistIDs: ids, direction: .next, wraps: true
    ) == "three")
    #expect(PlaybackQueueNavigation.adjacentTrackID(
        currentTrackID: "three", playlistIDs: ids, direction: .next, wraps: true
    ) == "one")
    #expect(PlaybackQueueNavigation.adjacentTrackID(
        currentTrackID: "one", playlistIDs: ids, direction: .previous, wraps: false
    ) == nil)
}

@Test
func completionStartsReplacementQueueAtItsHeadWhenOldTrackIsAbsent() {
    #expect(PlaybackQueueNavigation.completionAdvanceTargetID(
        currentTrackID: "old", playlistIDs: ["new-one", "new-two"]
    ) == "new-one")
    #expect(PlaybackQueueNavigation.completionAdvanceTargetID(
        currentTrackID: "new-one", playlistIDs: ["new-one", "new-two"]
    ) == "new-two")
    #expect(PlaybackQueueNavigation.completionAdvanceTargetID(
        currentTrackID: "new-two", playlistIDs: ["new-one", "new-two"]
    ) == nil)
}

@Test
func completionTargetAppliesSharedRepeatPolicy() {
    let ids = ["one", "two"]

    #expect(PlaybackQueueNavigation.completionTargetID(
        currentTrackID: "one", playlistIDs: ids, repeatMode: .song
    ) == "one")
    #expect(PlaybackQueueNavigation.completionTargetID(
        currentTrackID: "two", playlistIDs: ids, repeatMode: .off
    ) == nil)
    #expect(PlaybackQueueNavigation.completionTargetID(
        currentTrackID: "two", playlistIDs: ids, repeatMode: .playlist
    ) == "one")
    #expect(PlaybackQueueNavigation.completionTargetID(
        currentTrackID: "old", playlistIDs: ids, repeatMode: .song
    ) == nil)
}

@Test
func replacementClearsCurrentUnlessPlaybackIsExplicitlyPreserved() {
    let ids = ["new-one", "new-two"]

    #expect(PlaybackQueueNavigation.replacementState(
        currentTrackID: "old", playlistIDs: ids,
        preservePlayback: false
    ) == PlaybackQueueReplacementState(currentTrackID: nil, selectedTrackID: "new-one"))

    #expect(PlaybackQueueNavigation.replacementState(
        currentTrackID: "new-two", playlistIDs: ids,
        preservePlayback: true
    ) == PlaybackQueueReplacementState(currentTrackID: "new-two", selectedTrackID: "new-two"))

    #expect(PlaybackQueueNavigation.replacementState(
        currentTrackID: "old", playlistIDs: ids,
        preservePlayback: true
    ) == PlaybackQueueReplacementState(currentTrackID: "old", selectedTrackID: "new-one"))
}
