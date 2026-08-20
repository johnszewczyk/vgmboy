import AVFoundation
import Foundation

/// AVAudioEngine with a source node and a fixed ten-band equalizer. This is
/// the transport home: VGMBoy owns the macOS audio device, while a frontend
/// only supplies the requested EQ configuration.
final class AudioOutput: @unchecked Sendable {
    let sampleRate: Double
    let channels: AVAudioChannelCount
    let ringBuffer: PCMRingBuffer

    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let equalizer = AVAudioUnitEQ(numberOfBands: EqualizerConfiguration.bandCount)
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
        engine.attach(equalizer)
        configureEqualizerBands()
        engine.connect(sourceNode, to: equalizer, format: format)
        engine.connect(equalizer, to: engine.mainMixerNode, format: format)
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

    func setEqualizer(_ configuration: EqualizerConfiguration) {
        engineLock.lock()
        defer { engineLock.unlock() }
        for (index, band) in equalizer.bands.enumerated() {
            band.bypass = !configuration.enabled
            band.gain = configuration.gainsDecibels[index]
        }
        equalizer.bypass = !configuration.enabled
    }

    private func configureEqualizerBands() {
        // ISO octave centers. AVAudioUnitEQ runs in the engine graph, so this
        // remains effective for every decoder instead of being a frontend DSP.
        for (band, frequency) in zip(equalizer.bands, EqualizerConfiguration.bandFrequencies) {
            band.filterType = .parametric
            band.frequency = frequency
            band.bandwidth = 1
            band.gain = 0
            band.bypass = true
        }
        equalizer.bypass = true
    }
}
