import Foundation

/// Serializes ownership of a queued transition independently of the audio
/// transport queue, which may be busy preparing a source.
public final class PlaybackQueuedSkipLifecycle: @unchecked Sendable {
    private let lock = NSLock()
    private var current: String?
    private var claimed = false

    public init() {}

    /// Tokens must be unique for the lifetime of this instance. A new request
    /// supersedes any previous request, including an outstanding claim.
    @discardableResult public func begin(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        lock.lock(); defer { lock.unlock() }
        current = token
        claimed = false
        return true
    }

    /// A deadline, fallback or natural end may claim the current request once.
    public func claim(_ token: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard current == token, !claimed else { return false }
        claimed = true
        return true
    }

    /// Check again after asynchronous work and before applying its result.
    public func isCurrent(_ token: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return current == token
    }

    /// A stale cancellation cannot invalidate a newer request.
    @discardableResult public func cancel(_ token: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard current == token else { return false }
        current = nil
        claimed = false
        return true
    }
}
