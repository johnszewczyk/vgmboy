import AVFoundation
import Foundation
import Synchronization

/// AVAudioEngine with a source node and a fixed ten-band equalizer. This is
/// the transport home: VGMBoy owns the macOS audio device, while a frontend
/// only supplies the requested EQ configuration.
private final class OutputControls: @unchecked Sendable {
    let volumeBits = Atomic<UInt32>(Float(1).bitPattern)
    let monoEnabled = Atomic<Bool>(false)
}

final class AudioOutput: @unchecked Sendable {
    let sampleRate: Double
    let channels: AVAudioChannelCount
    let ringBuffer: PCMRingBuffer

    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let equalizer = AVAudioUnitEQ(numberOfBands: EqualizerConfiguration.bandCount)
    private let format: AVAudioFormat
    private let engineLock = NSLock()
    private let transportEnvelope = TransportEnvelope()
    private let controls = OutputControls()

    init(sampleRate: Double = 44_100, channels: AVAudioChannelCount = 2, capacitySeconds: Double = 2.0) {
        self.sampleRate = sampleRate
        self.channels = channels
        ringBuffer = PCMRingBuffer(capacityFrames: Int(sampleRate * capacitySeconds))
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!

        let buffer = ringBuffer
        let envelope = transportEnvelope
        let controls = controls
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
            let volume = Float(bitPattern: controls.volumeBits.load(ordering: .acquiring))
            let mono = controls.monoEnabled.load(ordering: .acquiring)
            for index in 0..<frames {
                let gain = envelope.nextGain() * volume
                let leftValue = left[index] * gain
                let rightValue = right[index] * gain
                if mono {
                    let mixed = (leftValue + rightValue) * 0.5
                    left[index] = mixed
                    right[index] = mixed
                } else {
                    left[index] = leftValue
                    right[index] = rightValue
                }
            }
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
        guard !engine.isRunning else { return }
        _ = transportEnvelope.beginPlayback(over: transportEnvelopeFrameCount)
        try engine.start()
    }

    func pause() {
        engineLock.lock()
        let running = engine.isRunning
        engineLock.unlock()
        guard running else { return }
        let ticket = transportEnvelope.fadeOut(over: transportEnvelopeFrameCount)
        waitForTransportEnvelope(ticket)
        engineLock.lock()
        defer { engineLock.unlock() }
        engine.pause()
    }

    func diagnostics() -> PlaybackDiagnostics {
        let buffer = ringBuffer.diagnostics()
        engineLock.lock()
        let running = engine.isRunning
        engineLock.unlock()
        return PlaybackDiagnostics(
            bufferedFrames: buffer.bufferedFrames,
            capacityFrames: buffer.capacityFrames,
            framesRequested: buffer.framesRequested,
            framesSupplied: buffer.framesSupplied,
            framesWritten: buffer.framesWritten,
            underrunCount: buffer.underrunCount,
            isOutputRunning: running,
            sampleRate: Int(sampleRate)
        )
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

    func setVolume(_ volume: Float) {
        controls.volumeBits.store(volume.bitPattern, ordering: .releasing)
    }

    func setMonoEnabled(_ enabled: Bool) {
        controls.monoEnabled.store(enabled, ordering: .releasing)
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

    private var transportEnvelopeFrameCount: Int {
        max(1, Int((sampleRate * 0.010).rounded(.up)))
    }

    private func waitForTransportEnvelope(_ ticket: Int) {
        let deadline = Date().addingTimeInterval(0.050)
        while !transportEnvelope.isComplete(ticket), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.001)
        }
    }
}
