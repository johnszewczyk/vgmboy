import AVFoundation
import Foundation

/// AVAudioEngine with a single AVAudioSourceNode rendering from the ring
/// buffer. This is the transport home: VGMBoy owns the macOS audio device.
/// Later checkpoints add the equalizer, ducking, and configuration-change
/// recovery.
final class AudioOutput: @unchecked Sendable {
    let sampleRate: Double
    let channels: AVAudioChannelCount
    let ringBuffer: PCMRingBuffer

    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let format: AVAudioFormat
    private let engineLock = NSLock()

    init(sampleRate: Double = 44_100, channels: AVAudioChannelCount = 2, capacitySeconds: Double = 2.0) {
        self.sampleRate = sampleRate
        self.channels = channels
        ringBuffer = PCMRingBuffer(capacityFrames: Int(sampleRate * capacitySeconds))
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!

        let buffer = ringBuffer
        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, ioData -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(ioData)
            guard abl.count >= 2 else { return noErr }
            let frames = Int(frameCount)
            guard let leftBase = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBase = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let left = UnsafeMutableBufferPointer(start: leftBase, count: frames)
            let right = UnsafeMutableBufferPointer(start: rightBase, count: frames)
            _ = buffer.read(into: left, right)
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    var isRunning: Bool {
        engineLock.lock()
        defer { engineLock.unlock() }
        return engine.isRunning
    }

    var primeFrameCount: Int {
        Int(Double(ringBuffer.capacityFrames) * 0.5)
    }

    func start() throws {
        engineLock.lock()
        defer { engineLock.unlock() }
        try engine.start()
    }

    func pause() {
        engineLock.lock()
        defer { engineLock.unlock() }
        engine.pause()
    }
}