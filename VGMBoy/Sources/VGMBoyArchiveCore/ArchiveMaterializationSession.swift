import Foundation

/// Thread-safe ownership of the one temporary materialization currently
/// handed to playback. Replacing a session removes the previous directory;
/// clearing it is idempotent and never touches durable archive cache roots.
public final class ArchiveMaterializationSession: @unchecked Sendable {
    private let lock = NSLock()
    private var activeDirectory: URL?

    public init() {}

    public var path: String? {
        lock.lock()
        defer { lock.unlock() }
        return activeDirectory?.path
    }

    public func replace(with directory: URL) {
        lock.lock()
        let previous = activeDirectory
        activeDirectory = directory
        lock.unlock()
        if let previous, previous != directory {
            try? FileManager.default.removeItem(at: previous)
        }
    }

    public func clear() {
        lock.lock()
        let previous = activeDirectory
        activeDirectory = nil
        lock.unlock()
        if let previous {
            try? FileManager.default.removeItem(at: previous)
        }
    }
}
