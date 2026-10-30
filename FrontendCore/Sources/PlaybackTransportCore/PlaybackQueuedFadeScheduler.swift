import Foundation

/// Owns one queued fade deadline. A host starts the fallback before issuing
/// the ramp, then confirms the ramp to begin its full duration. Tokens make
/// replacement, cancellation and late bridge replies harmless.
public final class PlaybackQueuedFadeScheduler: @unchecked Sendable {
    public typealias Cancel = @Sendable () -> Void
    public typealias Schedule = @Sendable (Int, @escaping @Sendable () -> Void) -> Cancel
    public typealias Completion = @Sendable (String) -> Void

    private struct Pending {
        let token: String
        let duration: Int
        let revision: UInt64
        let completion: Completion
        let rampAcknowledged: Bool
        var cancelTimer: Cancel?
    }

    private let lock = NSLock()
    private let schedule: Schedule
    private var nextRevision: UInt64 = 0
    private var pending: Pending?

    public init(schedule: @escaping Schedule = { delay, work in
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + .milliseconds(delay))
        timer.setEventHandler(handler: work)
        timer.resume()
        return { timer.cancel() }
    }) {
        self.schedule = schedule
    }

    deinit { pending?.cancelTimer?() }

    /// Call in host message-receipt order, before dispatching the gain ramp.
    @discardableResult
    public func start(token: String, durationMilliseconds: Int, fallbackMilliseconds: Int,
                      completion: @escaping Completion) -> Bool {
        guard !token.isEmpty, durationMilliseconds > 0,
              fallbackMilliseconds >= durationMilliseconds,
              fallbackMilliseconds <= Int(Int32.max) else { return false }
        lock.lock()
        let previousTimer = pending?.cancelTimer
        nextRevision &+= 1
        let revision = nextRevision
        pending = Pending(token: token, duration: durationMilliseconds, revision: revision, completion: completion,
                          rampAcknowledged: false, cancelTimer: nil)
        lock.unlock()
        previousTimer?()
        enqueue(token: token, revision: revision, delay: fallbackMilliseconds)
        return true
    }

    /// Confirm only the still-current ramp. A late confirmation cannot revive
    /// a canceled, replaced or already-completed deadline.
    public func rampReady(token: String) {
        lock.lock()
        guard let previous = pending, previous.token == token, !previous.rampAcknowledged else { lock.unlock(); return }
        nextRevision &+= 1
        let revision = nextRevision
        pending = Pending(token: token, duration: previous.duration, revision: revision, completion: previous.completion,
                          rampAcknowledged: true, cancelTimer: nil)
        lock.unlock()
        previous.cancelTimer?()
        enqueue(token: token, revision: revision, delay: previous.duration)
    }

    public func cancel(token: String) {
        lock.lock()
        let timer = pending?.token == token ? pending?.cancelTimer : nil
        if pending?.token == token { pending = nil }
        lock.unlock()
        timer?()
    }

    private func enqueue(token: String, revision: UInt64, delay: Int) {
        let cancelTimer = schedule(delay) { [weak self] in self?.fire(token: token, revision: revision) }
        lock.lock()
        if pending?.token == token && pending?.revision == revision {
            pending?.cancelTimer = cancelTimer
            lock.unlock()
        } else {
            lock.unlock()
            cancelTimer()
        }
    }

    private func fire(token: String, revision: UInt64) {
        lock.lock()
        guard let item = pending, item.token == token, item.revision == revision else { lock.unlock(); return }
        pending = nil
        lock.unlock()
        item.cancelTimer?()
        item.completion(token)
    }
}
