import CLazyUSF
import Foundation

enum LazyUSFDecoderError: LocalizedError {
    case createFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "lazyusf could not open the USF file. \(message)"
        }
    }
}

/// Wraps the lazyusf core (Nintendo 64 USF / miniusf). USF has no natural end
/// — the emulator keeps looping — so the decoder never reports `trackEnded`
/// and the family is flagged `hasNaturalEnding == false`, forcing the session
/// to always apply a capped window. Tempo is unsupported.
final class LazyUSFDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let handle: lazyusf_player_handle_t

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = lazyusf_player_create(path, Int32(sampleRate), &error) else {
            let message = error.map { String(cString: $0) } ?? "Unknown lazyusf error."
            if let error { lazyusf_error_message_free(error) }
            throw LazyUSFDecoderError.createFailed(message)
        }
        self.handle = handle
    }

    deinit {
        lazyusf_player_destroy(handle)
    }

    var trackCount: Int {
        1
    }

    var systemName: String {
        var metadata = lazyusf_metadata_t()
        defer { lazyusf_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        _ = lazyusf_player_read_metadata(handle, &metadata, &error)
        if let error { lazyusf_error_message_free(error) }
        return metadata.system.map { String(cString: $0) } ?? "Nintendo 64"
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else {
            throw LazyUSFDecoderError.createFailed("USF files expose a single playable track.")
        }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else {
            throw LazyUSFDecoderError.createFailed("USF files expose a single playable track.")
        }
        var metadata = lazyusf_metadata_t()
        defer { lazyusf_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        guard lazyusf_player_read_metadata(handle, &metadata, &error) == 0 else {
            let message = error.map { String(cString: $0) } ?? "Unknown lazyusf error."
            if let error { lazyusf_error_message_free(error) }
            throw LazyUSFDecoderError.createFailed(message)
        }
        let playMs = Int(metadata.play_length_ms)
        return TrackMetadata(
            index: index,
            song: metadata.title.map { String(cString: $0) } ?? "",
            game: metadata.game.map { String(cString: $0) } ?? "",
            author: metadata.artist.map { String(cString: $0) } ?? "",
            system: metadata.system.map { String(cString: $0) } ?? "Nintendo 64",
            lengthMs: playMs,
            introMs: 0,
            loopMs: 0,
            playMs: playMs,
            fadeMs: Int(metadata.fade_length_ms)
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {}

    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = lazyusf_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        if let error { lazyusf_error_message_free(error) }
    }

    var absolutePlayedFrames: Int64 {
        Int64(lazyusf_player_played_frames(handle))
    }

    var trackEnded: Bool {
        false
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        _ = lazyusf_player_render_s16(handle, Int32(frameCount), interleaved, &renderedFrames, &error)
        if let error { lazyusf_error_message_free(error) }

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }
}