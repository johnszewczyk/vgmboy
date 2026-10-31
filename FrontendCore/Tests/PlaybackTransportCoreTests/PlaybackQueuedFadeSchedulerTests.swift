import Foundation
import Testing
@testable import PlaybackTransportCore

private final class FadeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [(Int, @Sendable () -> Void)] = []
    private var completions: [String] = []
    func schedule(_ delay: Int, _ work: @escaping @Sendable () -> Void) -> PlaybackQueuedFadeScheduler.Cancel {
        lock.lock(); tasks.append((delay, work)); lock.unlock()
        return {}
    }
    func complete(_ token: String) {
        lock.lock(); completions.append(token); lock.unlock()
    }
    func run(_ index: Int) {
        lock.lock(); let work = tasks[index].1; lock.unlock(); work()
    }
    var delays: [Int] { lock.lock(); defer { lock.unlock() }; return tasks.map(\.0) }
    var finished: [String] { lock.lock(); defer { lock.unlock() }; return completions }
}

@Test func queuedFadeSchedulerOrdersAcknowledgementAndFallback() {
    let clock = FadeClock()
    let scheduler = PlaybackQueuedFadeScheduler(schedule: clock.schedule)
    #expect(scheduler.start(token: "one", durationMilliseconds: 6_000, fallbackMilliseconds: 8_000, completion: clock.complete))
    scheduler.rampReady(token: "one")
    scheduler.rampReady(token: "one")
    #expect(clock.delays == [8_000, 6_000])
    clock.run(0)
    #expect(clock.finished.isEmpty)
    clock.run(1); clock.run(1)
    scheduler.rampReady(token: "one")
    #expect(clock.finished == ["one"])
    #expect(clock.delays.count == 2)
}

@Test func queuedFadeSchedulerRejectsStaleWorkAndInvalidPlans() {
    let clock = FadeClock()
    let scheduler = PlaybackQueuedFadeScheduler(schedule: clock.schedule)
    #expect(!scheduler.start(token: "", durationMilliseconds: 1, fallbackMilliseconds: 1, completion: clock.complete))
    #expect(!scheduler.start(token: "bad", durationMilliseconds: 5, fallbackMilliseconds: 4, completion: clock.complete))
    #expect(scheduler.start(token: "old", durationMilliseconds: 1, fallbackMilliseconds: 2, completion: clock.complete))
    #expect(scheduler.start(token: "new", durationMilliseconds: 3, fallbackMilliseconds: 4, completion: clock.complete))
    scheduler.rampReady(token: "old"); scheduler.cancel(token: "old")
    clock.run(0); clock.run(1)
    scheduler.rampReady(token: "new")
    #expect(clock.finished == ["new"])
    #expect(scheduler.start(token: "cancel", durationMilliseconds: 1, fallbackMilliseconds: 2, completion: clock.complete))
    scheduler.cancel(token: "cancel"); scheduler.rampReady(token: "cancel"); clock.run(2)
    #expect(clock.finished == ["new"])
}

@Test func queuedFadeSchedulerHandlesDeadlineFiringDuringRegistration() {
    let clock = FadeClock()
    let scheduler = PlaybackQueuedFadeScheduler { _, work in
        work()
        return {}
    }
    #expect(scheduler.start(token: "immediate", durationMilliseconds: 1, fallbackMilliseconds: 2,
                            completion: clock.complete))
    scheduler.rampReady(token: "immediate")
    scheduler.cancel(token: "immediate")
    #expect(clock.finished == ["immediate"])
}
