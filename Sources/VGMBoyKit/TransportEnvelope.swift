import Foundation
import Synchronization

/// A callback-owned transport envelope. Control code publishes a new target
/// atomically; the real-time callback is the sole owner of the active gain.
/// This is separate from musical fades, EQ, and app volume.
final class TransportEnvelope: @unchecked Sendable {
    private let requestedTarget = Atomic<Float>(1)
    private let requestedFrames = Atomic<Int>(0)
    private let requestedReset = Atomic<Bool>(false)
    private let requestGeneration = Atomic<Int>(0)
    private let completedGeneration = Atomic<Int>(0)

    // These values are accessed only by the audio callback.
    private var observedGeneration = 0
    private var activeGain: Float = 1
    private var activeTarget: Float = 1
    private var activeFrames = 0

    init(initialGain: Float = 1) {
        let gain = Self.clamp(initialGain)
        requestedTarget.store(gain, ordering: .relaxed)
        activeGain = gain
        activeTarget = gain
    }

    @discardableResult
    func beginPlayback(over frameCount: Int) -> Int {
        request(target: 1, frameCount: frameCount, resetToSilence: true)
    }

    @discardableResult
    func fadeOut(over frameCount: Int) -> Int {
        request(target: 0, frameCount: frameCount, resetToSilence: false)
    }

    func isComplete(_ ticket: Int) -> Bool {
        completedGeneration.load(ordering: .acquiring) >= ticket
    }

    /// Called only from the audio callback, once per output frame.
    func nextGain() -> Float {
        let generation = requestGeneration.load(ordering: .acquiring)
        if generation != observedGeneration {
            observedGeneration = generation
            if requestedReset.load(ordering: .acquiring) {
                activeGain = 0
            }
            activeTarget = requestedTarget.load(ordering: .acquiring)
            activeFrames = requestedFrames.load(ordering: .acquiring)
            if activeFrames == 0 {
                activeGain = activeTarget
                completedGeneration.store(generation, ordering: .releasing)
            }
        }

        if activeFrames > 0 {
            activeGain += (activeTarget - activeGain) / Float(activeFrames)
            activeFrames -= 1
            if activeFrames == 0 {
                activeGain = activeTarget
                completedGeneration.store(observedGeneration, ordering: .releasing)
            }
        }
        return activeGain
    }

    private func request(target: Float, frameCount: Int, resetToSilence: Bool) -> Int {
        requestedTarget.store(Self.clamp(target), ordering: .relaxed)
        requestedFrames.store(max(0, frameCount), ordering: .relaxed)
        requestedReset.store(resetToSilence, ordering: .relaxed)
        return requestGeneration.wrappingAdd(1, ordering: .releasing).newValue
    }

    private static func clamp(_ gain: Float) -> Float {
        min(1, max(0, gain.isFinite ? gain : 0))
    }
}
