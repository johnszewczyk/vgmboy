import Foundation

/// Thread-safe identity of the archive cache root currently used by playback.
/// Cache eviction uses this value to protect the active decoder's files.
public final class ArchivePlaybackLease: @unchecked Sendable {
    private let lock = NSLock()
    private var storedPath: String?

    public init() {}

    public var path: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedPath
    }

    public func replace(with path: String) {
        lock.lock()
        storedPath = path
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        storedPath = nil
        lock.unlock()
    }
}
