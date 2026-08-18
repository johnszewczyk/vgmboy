import Foundation

/// Stereo float ring buffer guarded by a short NSLock critical section. The
/// audio render thread and the 20 ms refill thread contend only briefly. A
/// later checkpoint can port the atomic C ring buffer for lock-free access.
final class PCMRingBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var left: [Float]
    private var right: [Float]
    private let capacity: Int
    private var writeIndex = 0
    private var readIndex = 0
    private var count = 0
    private(set) var framesReadTotal: Int64 = 0
    private(set) var framesWrittenTotal: Int64 = 0
    private(set) var underrunCount: Int64 = 0

    init(capacityFrames: Int) {
        self.capacity = max(1, capacityFrames)
        left = [Float](repeating: 0, count: capacity)
        right = [Float](repeating: 0, count: capacity)
    }

    var bufferedFrames: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var capacityFrames: Int {
        capacity
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        writeIndex = 0
        readIndex = 0
        count = 0
    }

    func write(left leftSamples: [Float], right rightSamples: [Float]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let frames = min(leftSamples.count, rightSamples.count)
        var written = 0
        while written < frames, count < capacity {
            let target = writeIndex
            left[target] = leftSamples[written]
            right[target] = rightSamples[written]
            writeIndex = (writeIndex + 1) % capacity
            count += 1
            written += 1
        }
        framesWrittenTotal += Int64(written)
        return written
    }

    /// Reads up to `leftOut.count` frames, filling silence past the tail.
    func read(
        into leftOut: UnsafeMutableBufferPointer<Float>,
        _ rightOut: UnsafeMutableBufferPointer<Float>
    ) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let frames = min(leftOut.count, rightOut.count)
        var read = 0
        while read < frames, count > 0 {
            let source = readIndex
            leftOut[read] = left[source]
            rightOut[read] = right[source]
            readIndex = (readIndex + 1) % capacity
            count -= 1
            read += 1
        }
        if read < frames {
            underrunCount += 1
            while read < frames {
                leftOut[read] = 0
                rightOut[read] = 0
                read += 1
            }
        }
        framesReadTotal += Int64(frames)
        return frames
    }
}