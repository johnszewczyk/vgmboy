import CLibVGM
import Foundation

enum VGMDecoderError: LocalizedError {
    case createFailed(String)
    case singleTrack
    case metadataFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "libvgm could not open the file. \(message)"
        case .singleTrack:
            "libvgm files expose a single playable track."
        case .metadataFailed(let message):
            "libvgm could not read track metadata. \(message)"
        }
    }
}

/// Wraps the libvgm core (VGM/VGZ/GYM/S98/DRO) through the CLibVGM bridge.
/// Single-track. The bridge handles VGZ gzip decompression internally.
final class VGMDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let handle: libvgm_player_handle_t
    private var absoluteFrames: Int64 = 0
    private var resolvedSystem = ""

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = libvgm_player_create(path, Int32(sampleRate), 0, &error) else {
            let message = error.map { String(cString: $0) } ?? "Unknown libvgm error."
            if let error { libvgm_error_message_free(error) }
            throw VGMDecoderError.createFailed(message)
        }
        self.handle = handle
    }

    deinit {
        libvgm_player_destroy(handle)
    }

    var trackCount: Int {
        1
    }

    var systemName: String {
        resolvedSystem.isEmpty ? "VGM" : resolvedSystem
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else {
            throw VGMDecoderError.singleTrack
        }
        absoluteFrames = 0
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else {
            throw VGMDecoderError.singleTrack
        }
        var metadata = libvgm_metadata_t()
        defer { libvgm_metadata_clear(&metadata) }
        var error: UnsafeMutablePointer<CChar>?
        guard libvgm_player_read_metadata(handle, &metadata, &error) == 0 else {
            let message = error.map { String(cString: $0) } ?? "Unknown libvgm error."
            if let error { libvgm_error_message_free(error) }
            throw VGMDecoderError.metadataFailed(message)
        }
        if resolvedSystem.isEmpty, let system = metadata.system, !String(cString: system).isEmpty {
            resolvedSystem = String(cString: system)
        }
        return TrackMetadata(
            index: index,
            song: metadata.title.map { String(cString: $0) } ?? "",
            game: metadata.game.map { String(cString: $0) } ?? "",
            author: metadata.artist.map { String(cString: $0) } ?? "",
            system: resolvedSystem,
            lengthMs: Int(metadata.intro_length_ms) + Int(metadata.loop_length_ms),
            introMs: Int(metadata.intro_length_ms),
            loopMs: Int(metadata.loop_length_ms),
            playMs: Int(metadata.play_length_ms),
            fadeMs: Int(metadata.fade_length_ms)
        )
    }

    func setTempo(_ tempo: Double) {
        let clamped = max(0.05, min(4.0, tempo))
        let numerator = Int32(max(1, Int((clamped * 1000).rounded())))
        var error: UnsafeMutablePointer<CChar>?
        _ = libvgm_player_set_playback_speed(handle, numerator, 1000, &error)
        if let error { libvgm_error_message_free(error) }
    }

    func configureFade(playMs: Int, fadeMs: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = libvgm_player_configure(
            handle,
            Int32(max(0, playMs / 1000)),
            Int32(max(0, fadeMs / 1000)),
            false,
            &error
        )
        if let error { libvgm_error_message_free(error) }
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = libvgm_player_configure(
            handle,
            Int32(max(0, playMs / 1000)),
            Int32(max(0, fadeMs / 1000)),
            true,
            &error
        )
        if let error { libvgm_error_message_free(error) }
    }

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = libvgm_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        if let error { libvgm_error_message_free(error) }
        absoluteFrames = Int64(milliseconds) * Int64(sampleRate) / 1000
    }

    var absolutePlayedFrames: Int64 {
        absoluteFrames
    }

    var trackEnded: Bool {
        libvgm_player_track_ended(handle) != 0
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        _ = libvgm_player_render_s16(
            handle,
            Int32(frameCount),
            interleaved,
            &renderedFrames,
            &error
        )
        if let error { libvgm_error_message_free(error) }
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