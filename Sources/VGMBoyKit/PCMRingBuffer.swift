import Foundation
import Synchronization

struct PCMRingBufferDiagnostics: Sendable, Equatable {
    var bufferedFrames: Int
    var capacityFrames: Int
    var framesRequested: Int64
    var framesSupplied: Int64
    var framesWritten: Int64
    var underrunCount: Int64
}

/// Stereo single-producer/single-consumer ring. The session queue is the sole
/// producer and AVAudioSourceNode's callback is the sole consumer, so the
/// callback does not wait on a lock. A reset advances the read position to
/// the current writer position; compare-and-exchange prevents an in-flight
/// callback from restoring stale pre-transition PCM afterwards.
final class PCMRingBuffer: @unchecked Sendable {
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let capacity: Int
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)
    private let framesRequested = Atomic<Int64>(0)
    private let framesSupplied = Atomic<Int64>(0)
    private let framesWritten = Atomic<Int64>(0)
    private let underrunCount = Atomic<Int64>(0)

    init(capacityFrames: Int) {
        self.capacity = max(1, capacityFrames)
        left = .allocate(capacity: capacity)
        right = .allocate(capacity: capacity)
        left.initialize(repeating: 0, count: capacity)
        right.initialize(repeating: 0, count: capacity)
    }

    deinit {
        left.deinitialize(count: capacity)
        right.deinitialize(count: capacity)
        left.deallocate()
        right.deallocate()
    }

    var bufferedFrames: Int {
        availableFrames()
    }

    var capacityFrames: Int {
        capacity
    }

    func clear() {
        readIndex.store(writeIndex.load(ordering: .acquiring), ordering: .releasing)
    }

    func resetDiagnostics() {
        framesRequested.store(0, ordering: .releasing)
        framesSupplied.store(0, ordering: .releasing)
        framesWritten.store(0, ordering: .releasing)
        underrunCount.store(0, ordering: .releasing)
    }

    func diagnostics() -> PCMRingBufferDiagnostics {
        PCMRingBufferDiagnostics(
            bufferedFrames: availableFrames(),
            capacityFrames: capacity,
            framesRequested: framesRequested.load(ordering: .acquiring),
            framesSupplied: framesSupplied.load(ordering: .acquiring),
            framesWritten: framesWritten.load(ordering: .acquiring),
            underrunCount: underrunCount.load(ordering: .acquiring)
        )
    }

    func write(left leftSamples: [Float], right rightSamples: [Float]) -> Int {
        let frames = min(leftSamples.count, rightSamples.count)
        guard frames > 0 else { return 0 }
        let write = writeIndex.load(ordering: .relaxed)
        let used = write - readIndex.load(ordering: .acquiring)
        guard used >= 0, used <= capacity else { return 0 }
        let written = min(frames, capacity - used)
        guard written > 0 else { return 0 }
        for index in 0..<written {
            let target = (write + index) % capacity
            left[target] = leftSamples[index]
            right[target] = rightSamples[index]
        }
        writeIndex.store(write + written, ordering: .releasing)
        _ = framesWritten.wrappingAdd(Int64(written), ordering: .relaxed)
        return written
    }

    /// Reads up to `leftOut.count` frames, filling silence past the tail.
    func read(
        into leftOut: UnsafeMutableBufferPointer<Float>,
        _ rightOut: UnsafeMutableBufferPointer<Float>
    ) -> Int {
        let frames = min(leftOut.count, rightOut.count)
        guard frames > 0 else { return 0 }
        _ = framesRequested.wrappingAdd(Int64(frames), ordering: .relaxed)
        let read = readIndex.load(ordering: .relaxed)
        let available = writeIndex.load(ordering: .acquiring) - read
        guard available >= 0, available <= capacity else {
            fillSilence(leftOut, rightOut, from: 0)
            _ = underrunCount.wrappingAdd(1, ordering: .relaxed)
            return 0
        }
        let supplied = min(frames, available)
        for index in 0..<supplied {
            let source = (read + index) % capacity
            leftOut[index] = left[source]
            rightOut[index] = right[source]
        }
        guard readIndex.compareExchange(
            expected: read,
            desired: read + supplied,
            ordering: .acquiringAndReleasing
        ).exchanged else {
            fillSilence(leftOut, rightOut, from: 0)
            _ = underrunCount.wrappingAdd(1, ordering: .relaxed)
            return 0
        }
        if supplied < frames {
            fillSilence(leftOut, rightOut, from: supplied)
            _ = underrunCount.wrappingAdd(1, ordering: .relaxed)
        }
        _ = framesSupplied.wrappingAdd(Int64(supplied), ordering: .relaxed)
        return supplied
    }

    private func availableFrames() -> Int {
        let available = writeIndex.load(ordering: .acquiring) - readIndex.load(ordering: .acquiring)
        return available >= 0 && available <= capacity ? available : 0
    }

    private func fillSilence(
        _ leftOut: UnsafeMutableBufferPointer<Float>,
        _ rightOut: UnsafeMutableBufferPointer<Float>,
        from start: Int
    ) {
        guard start < leftOut.count else { return }
        for index in start..<leftOut.count {
            leftOut[index] = 0
            rightOut[index] = 0
        }
    }
}
