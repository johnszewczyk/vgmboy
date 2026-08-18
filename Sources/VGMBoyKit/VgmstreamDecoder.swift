import CVGmstream
import Foundation

enum VgmstreamDecoderError: LocalizedError {
    case createFailed(String)
    case trackSelectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "vgmstream could not open the file. \(message)"
        case .trackSelectionFailed(let message):
            "vgmstream could not select the subsong. \(message)"
        }
    }
}

/// Wraps the vgmstream core (streamed console audio: ADX, XA, AT3, FSB, HD
/// banks, ...). Handles arbitrary source sample rates and channel counts via
/// the bridge's internal resampler/downmix to stereo. Subsongs are 1-based in
/// the bridge, 0-based here.
final class VgmstreamDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: vgmstream_player_handle_t
    private let sourceRate: Int
    private var currentTrack: Int
    private var absoluteFrames: Int64 = 0

    init(path: String, sampleRate: Int = 44_100, trackIndex: Int = 0) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = vgmstream_player_create(path, Int32(sampleRate), Int32(trackIndex + 1), &error) else {
            let message = error.map { String(cString: $0) } ?? "Unknown vgmstream error."
            if let error { vgmstream_error_message_free(error) }
            throw VgmstreamDecoderError.createFailed(message)
        }
        self.handle = handle
        self.currentTrack = trackIndex
        var metadata = vgmstream_metadata_t()
        defer { vgmstream_metadata_clear(&metadata) }
        _ = vgmstream_player_read_metadata(handle, &metadata, &error)
        if let error { vgmstream_error_message_free(error) }
        self.sourceRate = Int(metadata.sample_rate)
    }

    deinit {
        vgmstream_player_destroy(handle)
    }

    var trackCount: Int {
        var metadata = vgmstream_metadata_t()
        defer { vgmstream_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_read_metadata(handle, &metadata, &error)
        if let error { vgmstream_error_message_free(error) }
        return max(1, Int(metadata.track_count))
    }

    var systemName: String {
        var metadata = vgmstream_metadata_t()
        defer { vgmstream_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_read_metadata(handle, &metadata, &error)
        if let error { vgmstream_error_message_free(error) }
        return metadata.system.map { String(cString: $0) } ?? "Game Audio"
    }

    func startTrack(_ index: Int) throws {
        guard index >= 0, index < trackCount else {
            throw VgmstreamDecoderError.trackSelectionFailed("Subsong \(index + 1) is out of range.")
        }
        if index != currentTrack {
            var error: UnsafeMutablePointer<CChar>?
            guard vgmstream_player_select_track(handle, Int32(index + 1), &error) == 0 else {
                let message = error.map { String(cString: $0) } ?? "Unknown vgmstream error."
                if let error { vgmstream_error_message_free(error) }
                throw VgmstreamDecoderError.trackSelectionFailed(message)
            }
            currentTrack = index
        }
        absoluteFrames = 0
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        try startTrack(index)
        var metadata = vgmstream_metadata_t()
        defer { vgmstream_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        guard vgmstream_player_read_metadata(handle, &metadata, &error) == 0 else {
            let message = error.map { String(cString: $0) } ?? "Unknown vgmstream error."
            if let error { vgmstream_error_message_free(error) }
            throw VgmstreamDecoderError.trackSelectionFailed(message)
        }
        let playMs = Int(metadata.play_length_frames * 1_000 / Int64(max(1, sourceRate)))
        let loopMs = Int(metadata.loop_length_frames * 1_000 / Int64(max(1, sourceRate)))
        return TrackMetadata(
            index: index,
            song: metadata.title.map { String(cString: $0) } ?? "",
            game: "",
            author: "",
            system: metadata.system.map { String(cString: $0) } ?? "Game Audio",
            lengthMs: playMs,
            introMs: 0,
            loopMs: loopMs,
            playMs: playMs,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_configure(handle, true, &error)
        if let error { vgmstream_error_message_free(error) }
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_configure(handle, false, &error)
        if let error { vgmstream_error_message_free(error) }
    }

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        if let error { vgmstream_error_message_free(error) }
        absoluteFrames = Int64(milliseconds) * Int64(sampleRate) / 1000
    }

    var absolutePlayedFrames: Int64 {
        absoluteFrames
    }

    var trackEnded: Bool {
        vgmstream_player_track_ended(handle) != 0
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmstream_player_render_s16(handle, Int32(frameCount), interleaved, &renderedFrames, &error)
        if let error { vgmstream_error_message_free(error) }
        let rendered = max(0, Int(renderedFrames))
        absoluteFrames += Int64(rendered)

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<min(rendered, frameCount) {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }
}

private func vgmstream_error_message_free(_ pointer: UnsafeMutablePointer<CChar>?) {
    guard let pointer else { return }
    free(pointer)
}