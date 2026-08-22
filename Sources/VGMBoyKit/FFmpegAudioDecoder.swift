import Foundation
import VGMBoyCFFmpeg

/// Streaming FFmpeg decoder for formats Core Audio does not admit (currently
/// MPEG Layer II and TAK). The core owns it so frontends never substitute a
/// process or PCM graph for individual formats.
final class FFmpegAudioDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    let trackCount = 1
    let systemName = "Standard audio"
    private let handle: OpaquePointer
    private let durationMs: Int
    private(set) var absolutePlayedFrames: Int64 = 0
    private var ended = false

    var trackEnded: Bool { ended }
    let appliesFadeInternally = false

    init(path: String, sampleRate: Int) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = vgmboy_ffmpeg_decoder_create(path, Int32(sampleRate), &error) else {
            let message = error.map { String(cString: $0) } ?? "FFmpeg could not open this audio file."
            if let error { vgmboy_ffmpeg_error_message_free(error) }
            throw DecoderFactoryError.unsupportedFamily(message)
        }
        self.handle = handle
        self.sampleRate = sampleRate
        self.durationMs = max(0, Int(vgmboy_ffmpeg_decoder_duration_ms(handle)))
    }

    deinit { vgmboy_ffmpeg_decoder_destroy(handle) }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        return TrackMetadata(index: 0, song: "", game: "", author: "", system: systemName, lengthMs: durationMs, introMs: 0, loopMs: 0, playMs: durationMs, fadeMs: 0)
    }

    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        let result = vgmboy_ffmpeg_decoder_seek(handle, Int64(max(0, milliseconds)), &error)
        if let error { vgmboy_ffmpeg_error_message_free(error) }
        guard result == 0 else { ended = true; return }
        absolutePlayedFrames = Int64((Double(max(0, milliseconds)) / 1_000 * Double(sampleRate)).rounded(.down))
        ended = false
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0, !ended else { return ([], []) }
        var left = Array(repeating: Float.zero, count: frameCount)
        var right = Array(repeating: Float.zero, count: frameCount)
        var count: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = vgmboy_ffmpeg_decoder_read(handle, &left, &right, Int32(frameCount), &count, &error)
        if let error { vgmboy_ffmpeg_error_message_free(error) }
        guard result == 0, count > 0 else {
            ended = true
            return ([], [])
        }
        let frames = Int(count)
        absolutePlayedFrames += Int64(frames)
        if frames < frameCount { ended = true }
        return (Array(left.prefix(frames)), Array(right.prefix(frames)))
    }
}
