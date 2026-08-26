import CatalogReader
import Foundation

/// Owns the most recent task in an independently cancellable UI workflow.
///
/// The generation changes on replacement, completion, and cancellation so
/// late asynchronous callbacks cannot publish stale state. This is a
/// lifecycle primitive only; the consuming frontend owns its observable
/// state, presentation, and completion callbacks.
public final class LatestTaskOwner: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var generation = 0
    private var active = false

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    public init() {}

    public func begin() -> Int {
        lock.lock()
        defer { lock.unlock() }
        task?.cancel()
        task = nil
        generation &+= 1
        active = true
        return generation
    }

    public func install(_ task: Task<Void, Never>, generation: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isCurrentUnlocked(generation) else {
            task.cancel()
            return
        }
        self.task = task
    }

    public func isCurrent(_ generation: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == self.generation
    }

    public func finish(generation: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard isCurrentUnlocked(generation) else { return }
        task = nil
        active = false
        self.generation &+= 1
    }

    /// Requests cooperative cancellation without invalidating the generation.
    /// Use this when UI state must remain active until owned cleanup settles.
    public func requestCancellation() {
        lock.lock()
        defer { lock.unlock() }
        task?.cancel()
    }

    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        task?.cancel()
        task = nil
        active = false
    }

    private func isCurrentUnlocked(_ generation: Int) -> Bool {
        generation == self.generation
    }
}

/// Independent catalog workflows used by both native frontends.
///
/// A game/sidebar read must not cancel an unrelated file read, while a newer
/// playlist read must retire an older playlist read. The coordinator keeps
/// those scopes explicit and reuses the exact latest-request semantics of
/// `LatestTaskOwner`.
public enum CatalogSessionScope: String, CaseIterable, Codable, Sendable {
    case games
    case files
    case playlist
    case search
}

public extension CatalogSessionScope {
    static func scope(for method: String) -> Self? {
        switch method {
        case "databaseGames": return .games
        case "databaseFiles", "databaseFileTree": return .files
        case "databaseGameTracks", "databaseFileTracks", "databaseFolderTracks",
             "refreshTree", "openPath", "selectFolder", "selectFile": return .playlist
        case "databaseSearchGames": return .search
        default: return nil
        }
    }
}

public final class CatalogSessionCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private var owners: [CatalogSessionScope: LatestTaskOwner] =
        Dictionary(uniqueKeysWithValues: CatalogSessionScope.allCases.map { ($0, LatestTaskOwner()) })

    public init() {}

    public func begin(_ scope: CatalogSessionScope) -> Int {
        owner(for: scope).begin()
    }

    public func isCurrent(_ generation: Int, for scope: CatalogSessionScope) -> Bool {
        owner(for: scope).isCurrent(generation)
    }

    public func install(
        _ task: Task<Void, Never>,
        generation: Int,
        for scope: CatalogSessionScope
    ) {
        owner(for: scope).install(task, generation: generation)
    }

    public func finish(_ generation: Int, for scope: CatalogSessionScope) {
        owner(for: scope).finish(generation: generation)
    }

    public func cancel(_ scope: CatalogSessionScope) {
        owner(for: scope).cancel()
    }

    private func owner(for scope: CatalogSessionScope) -> LatestTaskOwner {
        lock.lock()
        defer { lock.unlock() }
        if let owner = owners[scope] { return owner }
        let owner = LatestTaskOwner()
        owners[scope] = owner
        return owner
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
