import Foundation
import Testing
@testable import PlaybackTransportCore

@Test func queuedSkipLifecycleSupersedesAndCancelsClaims() {
    let lifecycle = PlaybackQueuedSkipLifecycle()
    #expect(!lifecycle.begin(""))
    #expect(lifecycle.begin("one"))
    #expect(lifecycle.claim("one"))
    #expect(!lifecycle.claim("one"))
    #expect(lifecycle.begin("two"))
    #expect(!lifecycle.isCurrent("one"))
    #expect(!lifecycle.cancel("one"))
    #expect(lifecycle.claim("two"))
    #expect(lifecycle.cancel("two"))
    #expect(!lifecycle.isCurrent("two"))
    #expect(!lifecycle.claim("two"))
}

@Test func queuedSkipLifecycleAllowsOnlyOneConcurrentClaim() {
    let lifecycle = PlaybackQueuedSkipLifecycle()
    #expect(lifecycle.begin("concurrent"))
    let count = ClaimCount()
    DispatchQueue.concurrentPerform(iterations: 64) { _ in
        if lifecycle.claim("concurrent") { count.increment() }
    }
    #expect(count.value == 1)
}

private final class ClaimCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}
