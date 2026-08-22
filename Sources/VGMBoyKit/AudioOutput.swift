import Foundation
import VGMBoyCAudioUnit

/// Persistent direct-AudioUnit transport. The realtime callback is the only
/// consumer of the PCM ring and owns the final 10 ms gain envelope. Decoders
/// and frontends never touch the hardware callback or output device.
final class AudioOutput: @unchecked Sendable {
    let sampleRate: Double
    private let handle: OpaquePointer
    private let controlLock = NSLock()
    // The endpoint stays alive and silent between tracks. Stopping and
    // restarting a DefaultOutput unit is itself an audible hardware boundary
    // on some devices, even when PCM was correctly ramped to zero.
    private var transportPlaying = false

    init(sampleRate: Double = 44_100, capacitySeconds: Double = 2.0) {
        self.sampleRate = sampleRate
        var config = VGMBoyAudioUnitConfig(
            sample_rate: sampleRate,
            channel_count: 2,
            callback_frames: 512,
            ring_buffer_frames: UInt32(max(1, Int(sampleRate * capacitySeconds)))
        )
        var created: OpaquePointer?
        precondition(vgmboy_audio_unit_create(&created, &config) == 0, "Could not create VGMBoy direct audio transport.")
        guard let created else { fatalError("VGMBoy direct audio transport returned no handle.") }
        handle = created
    }

    deinit { vgmboy_audio_unit_destroy(handle) }

    var isRunning: Bool {
        controlLock.lock()
        defer { controlLock.unlock() }
        return transportPlaying
    }
    var capacityFrames: Int { Int(snapshot().ring_buffer_frames) }
    var bufferedFrames: Int { Int(snapshot().buffered_frames) }
    var primeFrameCount: Int { capacityFrames / 2 }

    func start() throws {
        controlLock.lock()
        defer { controlLock.unlock() }
        guard !transportPlaying else { return }
        vgmboy_audio_unit_set_transport_gain(handle, 0)
        if snapshot().is_running == 0 {
            guard vgmboy_audio_unit_start(handle) == 0 else {
                throw PlaybackControlError.invalidPayload("VGMBoy could not start the macOS audio output.")
            }
        }
        vgmboy_audio_unit_ramp_transport_gain(handle, 1, transportEnvelopeFrameCount)
        transportPlaying = true
    }

    func pause() {
        controlLock.lock()
        defer { controlLock.unlock() }
        guard transportPlaying else { return }
        vgmboy_audio_unit_ramp_transport_gain(handle, 0, transportEnvelopeFrameCount)
        // Let the device callback emit final zero-gain frames, but deliberately
        // do not stop the endpoint: its restart is an independent click source.
        Thread.sleep(forTimeInterval: 0.012)
        transportPlaying = false
    }

    func clearBuffer() { vgmboy_audio_unit_clear(handle) }
    func resetDiagnostics() { vgmboy_audio_unit_reset_counters(handle) }

    @discardableResult
    func write(left: [Float], right: [Float]) -> Int {
        let count = min(left.count, right.count)
        guard count > 0 else { return 0 }
        var interleaved = [Int16](repeating: 0, count: count * 2)
        for index in 0..<count {
            interleaved[index * 2] = Self.pcm16(left[index])
            interleaved[index * 2 + 1] = Self.pcm16(right[index])
        }
        return interleaved.withUnsafeMutableBufferPointer { samples in
            Int(vgmboy_audio_unit_enqueue_pcm(handle, samples.baseAddress, count))
        }
    }

    func diagnostics() -> PlaybackDiagnostics {
        let values = snapshot()
        return PlaybackDiagnostics(
            bufferedFrames: Int(values.buffered_frames),
            capacityFrames: Int(values.ring_buffer_frames),
            framesRequested: Int64(values.frames_requested),
            framesSupplied: Int64(values.frames_supplied),
            framesWritten: Int64(values.frames_written),
            underrunCount: Int64(values.underrun_count),
            isOutputRunning: isRunning,
            sampleRate: Int(values.sample_rate.rounded())
        )
    }

    func setEqualizer(_ configuration: EqualizerConfiguration) {
        let gains = configuration.gainsDecibels
        gains.withUnsafeBufferPointer { buffer in
            vgmboy_audio_unit_set_equalizer(handle, configuration.enabled ? 1 : 0, buffer.baseAddress, buffer.count)
        }
    }

    func setVolume(_ volume: Float) { vgmboy_audio_unit_set_volume(handle, volume) }
    func setMonoEnabled(_ enabled: Bool) { vgmboy_audio_unit_set_mono(handle, enabled ? 1 : 0) }

    func rampTransportGain(to gain: Float, durationMilliseconds: Int) {
        controlLock.lock()
        defer { controlLock.unlock() }
        let frameCount = UInt32(max(1, Int((sampleRate * Double(max(1, durationMilliseconds)) / 1_000).rounded(.up))))
        vgmboy_audio_unit_ramp_transport_gain(handle, min(1, max(0, gain)), frameCount)
    }

    private var transportEnvelopeFrameCount: UInt32 {
        UInt32(max(1, Int((sampleRate * 0.010).rounded(.up))))
    }

    private func snapshot() -> VGMBoyAudioUnitSnapshot {
        var values = VGMBoyAudioUnitSnapshot()
        precondition(vgmboy_audio_unit_snapshot(handle, &values) == 0)
        return values
    }

    private static func pcm16(_ value: Float) -> Int16 {
        let scaled = (value.isFinite ? value : 0) * 32_767
        return Int16(max(Float(Int16.min), min(Float(Int16.max), scaled.rounded())))
    }
}
