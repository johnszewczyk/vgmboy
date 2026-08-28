import PlaybackRequestCore

/// Shared lifecycle for one frontend playback request and its natural-end handoff.
///
/// The coordinator deliberately stores no track model, decoder, or UI state.
/// Hosts retain their own presentation rows while this type guarantees that a
/// replacement invalidates older work and that only one completion path can
/// advance the active generation.
@MainActor
public final class PlaybackSessionLifecycleCoordinator {
    private let requestLifecycle = PlaybackRequestLifecycle()
    private let completionCoordinator = PlaybackContinuationCoordinator()
    private var completionGeneration = 0

    public init() {}

    public var isActive: Bool {
        requestLifecycle.isActive
    }

    public func begin() -> Int {
        let generation = requestLifecycle.begin()
        resetCompletion()
        return generation
    }

    public func install(_ task: Task<Void, Never>, generation: Int) {
        requestLifecycle.install(task, generation: generation)
    }

    public func isCurrent(_ generation: Int) -> Bool {
        requestLifecycle.isCurrent(generation)
    }

    public func finish(generation: Int) {
        requestLifecycle.finish(generation: generation)
    }

    public func requestCancellation() {
        requestLifecycle.requestCancellation()
    }

    public func cancel() {
        requestLifecycle.cancel()
    }

    public var completionClaimed: Bool {
        completionCoordinator.isClaimed(generation: completionGeneration)
    }

    public func markCompletionHandled() {
        _ = completionCoordinator.claim(generation: completionGeneration)
    }

    public func resetCompletion() {
        completionGeneration &+= 1
        completionCoordinator.reset()
    }

    public func completionDecision(
        state: PlaybackQueueState,
        playlistIDs: [String],
        repeatMode: PlaybackRepeatMode
    ) -> PlaybackContinuationDecision? {
        completionCoordinator.decision(
            generation: completionGeneration,
            state: state,
            playlistIDs: playlistIDs,
            repeatMode: repeatMode
        )
    }
}
