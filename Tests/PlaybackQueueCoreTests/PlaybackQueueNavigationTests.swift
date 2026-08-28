import Foundation
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
func completionDecisionMakesTerminalStopExplicit() {
    let terminal = PlaybackQueueNavigation.completionDecision(
        currentTrackID: "two",
        playlistIDs: ["one", "two"],
        repeatMode: .off
    )
    #expect(terminal == PlaybackContinuationDecision(action: .stop))
    #expect(terminal.targetID == nil)

    let next = PlaybackQueueNavigation.completionDecision(
        currentTrackID: "one",
        playlistIDs: ["one", "two"],
        repeatMode: .off
    )
    #expect(next == PlaybackContinuationDecision(action: .play(trackID: "two")))
    #expect(next.targetID == "two")
}

@Test
func continuationGateClaimsEachGenerationOnlyOnce() {
    let gate = PlaybackContinuationGate()

    #expect(gate.claim(generation: 7))
    #expect(!gate.claim(generation: 7))
    #expect(gate.isClaimed(generation: 7))
    #expect(gate.claim(generation: 8))

    gate.reset()
    #expect(gate.claim(generation: 7))
}

@Test
func continuationCoordinatorClaimsBeforeReturningSharedDecision() {
    let coordinator = PlaybackContinuationCoordinator()
    let state = PlaybackQueueState(
        currentTrackID: "one",
        selectedTrackID: "one",
        pendingTrackID: nil
    )

    #expect(coordinator.decision(
        generation: 12,
        state: state,
        playlistIDs: ["one", "two"],
        repeatMode: .off
    ) == PlaybackContinuationDecision(action: .play(trackID: "two")))
    #expect(coordinator.decision(
        generation: 12,
        state: state,
        playlistIDs: ["one", "two"],
        repeatMode: .off
    ) == nil)
}

@Test
func continuationRequestCarriesOneSharedLifecycleEnvelope() throws {
    let request = PlaybackContinuationRequest(
        generation: 12,
        state: PlaybackQueueState(
            currentTrackID: "one",
            selectedTrackID: "one",
            pendingTrackID: nil
        ),
        playlistIDs: ["one", "two"],
        repeatMode: .off
    )

    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(PlaybackContinuationRequest.self, from: encoded)

    #expect(decoded == request)
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

@Test
func queueStateSharesReplacementAnchorAndCompletionTransitions() {
    let state = PlaybackQueueState(
        currentTrackID: "old",
        selectedTrackID: "new-two",
        pendingTrackID: "new-one"
    )
    let ids = ["new-one", "new-two", "new-three"]

    #expect(state.navigationAnchorID(playlistIDs: ids) == "new-one")
    #expect(state.adjacentTargetID(
        playlistIDs: ids,
        direction: .next,
        wraps: true
    ) == "new-two")
    #expect(state.completionTargetID(
        playlistIDs: ids,
        repeatMode: .off
    ) == "new-one")

    #expect(state.replacing(
        playlistIDs: ids,
        preservePlayback: false
    ) == PlaybackQueueState(
        currentTrackID: nil,
        selectedTrackID: "new-one",
        pendingTrackID: nil
    ))
    #expect(state.replacing(
        playlistIDs: ids,
        preservePlayback: true
    ) == PlaybackQueueState(
        currentTrackID: "old",
        selectedTrackID: "new-one",
        pendingTrackID: "new-one"
    ))
}
