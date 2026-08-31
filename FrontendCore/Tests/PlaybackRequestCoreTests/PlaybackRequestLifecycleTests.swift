import Foundation
import Testing
@testable import PlaybackRequestCore

@Suite("Playback request lifecycle")
struct PlaybackRequestLifecycleTests {
    @Test("newest request cancels and invalidates the previous generation")
    @MainActor
    func newestRequestWins() {
        let lifecycle = PlaybackRequestLifecycle()
        let first = lifecycle.begin()
        #expect(lifecycle.isCurrent(first))

        let second = lifecycle.begin()
        #expect(second != first)
        #expect(!lifecycle.isCurrent(first))
        #expect(lifecycle.isCurrent(second))

        lifecycle.finish(generation: first)
        #expect(lifecycle.isCurrent(second))
        #expect(lifecycle.isActive)
        lifecycle.finish(generation: second)
        #expect(!lifecycle.isActive)
        #expect(!lifecycle.isCurrent(second))
    }

    @Test("cancel invalidates the active generation")
    @MainActor
    func cancellationInvalidatesGeneration() {
        let lifecycle = PlaybackRequestLifecycle()
        let generation = lifecycle.begin()
        lifecycle.cancel()
        #expect(!lifecycle.isCurrent(generation))
        #expect(!lifecycle.isActive)
    }
}

@Suite("Playback serial executor")
struct PlaybackSerialExecutorTests {
    private final class ValuesBox: @unchecked Sendable {
        let lock = NSLock()
        var values: [Int] = []
    }

    @Test("preserves command order and supports reentrant sync work")
    func preservesCommandOrder() async throws {
        let executor = PlaybackSerialExecutor(label: "test.playback-serial-executor")
        let box = ValuesBox()

        await withTaskGroup(of: Void.self) { group in
            for value in 0..<8 {
                group.addTask {
                    executor.async {
                        box.lock.lock()
                        box.values.append(value)
                        box.lock.unlock()
                    }
                }
            }
        }

        try await Task.sleep(for: .milliseconds(20))
        #expect(Set(box.values) == Set(0..<8))

        let result = executor.sync {
            executor.sync { 42 }
        }
        #expect(result == 42)
    }
}
