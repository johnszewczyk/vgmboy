import Foundation

/// Owns newest-request-wins cancellation and generation checks for a frontend
/// playback workflow. Track rows, queue policy, and observable UI state remain
/// outside this lifecycle primitive.
@MainActor
public final class PlaybackRequestLifecycle {
    private var task: Task<Void, Never>?
    private var generation = 0
    public private(set) var isActive = false

    public init() {}

    public func begin() -> Int {
        task?.cancel()
        task = nil
        generation &+= 1
        isActive = true
        return generation
    }

    public func install(_ task: Task<Void, Never>, generation: Int) {
        guard isCurrent(generation) else {
            task.cancel()
            return
        }
        self.task = task
    }

    public func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation
    }

    public func finish(generation: Int) {
        guard isCurrent(generation) else { return }
        task = nil
        isActive = false
        self.generation &+= 1
    }

    public func requestCancellation() {
        task?.cancel()
    }

    public func cancel() {
        generation &+= 1
        task?.cancel()
        task = nil
        isActive = false
    }
}
