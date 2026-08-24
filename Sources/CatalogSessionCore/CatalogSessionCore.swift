import CatalogReader
import Foundation

/// Owns the most recent task in an independently cancellable UI workflow.
///
/// The generation changes on replacement, completion, and cancellation so
/// late asynchronous callbacks cannot publish stale state. This is a
/// lifecycle primitive only; the consuming frontend owns its observable
/// state, presentation, and completion callbacks.
@MainActor
public final class LatestTaskOwner {
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

    /// Requests cooperative cancellation without invalidating the generation.
    /// Use this when UI state must remain active until owned cleanup settles.
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

/// Read-only database projections used to hydrate persistent sidebar views.
/// The returned values are catalog facts; row presentation and tree/index
/// construction remain owned by each frontend.
public enum CatalogSidebarReader {
    public static func gameBuckets(
        databaseURL: URL,
        preferFoldersOverMetadata: Bool = true
    ) throws -> [CatalogGameBucket] {
        try ReadOnlyCatalog(databaseURL: databaseURL)
            .gameBuckets(preferFoldersOverMetadata: preferFoldersOverMetadata)
    }

    public static func fileBuckets(databaseURL: URL) throws -> [CatalogFileBucket] {
        try ReadOnlyCatalog(databaseURL: databaseURL).fileBuckets()
    }
}
