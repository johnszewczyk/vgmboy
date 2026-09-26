import Foundation
import Testing
import VGMBoyCAudioUnit

@Suite("PCM spectrum")
struct SpectrumTests {
    @Test("ten bands follow the stereo signal")
    func measuresStereoTone() throws {
        var configuration = VGMBoyAudioUnitConfig(
            sample_rate: 44_100,
            channel_count: 2,
            callback_frames: 512,
            ring_buffer_frames: 4096
        )
        var handle: OpaquePointer?
        #expect(vgmboy_audio_unit_create(&handle, &configuration) == 0)
        let output = try #require(handle)
        defer { vgmboy_audio_unit_destroy(output) }

        var samples = [Int16](repeating: 0, count: 4096)
        for frame in 0..<2048 {
            samples[frame * 2] = Int16((sin(2 * Double.pi * 1000 * Double(frame) / 44_100) * 20_000).rounded())
        }
        #expect(vgmboy_audio_unit_enqueue_pcm(output, &samples, 2048) == 2048)
        var left = [Float](repeating: 0, count: 10)
        var right = [Float](repeating: 0, count: 10)
        let result = left.withUnsafeMutableBufferPointer { leftBuffer in
            right.withUnsafeMutableBufferPointer { rightBuffer in
                vgmboy_audio_unit_spectrum(output, leftBuffer.baseAddress, rightBuffer.baseAddress, 10)
            }
        }
        #expect(result == 0)
        #expect(left[5] > 0.1)
        #expect(left[5] > left[4])
        #expect(right.allSatisfy { $0 == 0 })
    }
}
