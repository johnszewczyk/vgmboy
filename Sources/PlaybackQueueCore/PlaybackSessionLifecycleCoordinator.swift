import PlaybackRequestCore

/// Shared lifecycle for one frontend playback request.
///
/// The coordinator deliberately stores no track model, decoder, or UI state.
/// Hosts retain their own presentation rows while this type guarantees that a
/// replacement invalidates older frontend work.
@MainActor
public final class PlaybackSessionLifecycleCoordinator {
    private let requestLifecycle = PlaybackRequestLifecycle()

    public init() {}

    public var isActive: Bool {
        requestLifecycle.isActive
    }

    public func begin() -> Int {
        let generation = requestLifecycle.begin()
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

}
