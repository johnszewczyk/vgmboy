import Foundation
import VGMBoyCMDX

enum MDXDecoderError: LocalizedError {
    case createFailed(String)
    case metadataFailed(String)
    case renderFailed(String)
    case singleTrack

    var errorDescription: String? {
        switch self {
        case .createFailed(let message): "mdxmini could not open the MDX file. \(message)"
        case .metadataFailed(let message): "mdxmini could not read MDX metadata. \(message)"
        case .renderFailed(let message): "mdxmini could not render MDX audio. \(message)"
        case .singleTrack: "MDX files expose one playable sequence."
        }
    }
}

/// Native X68000 MDX playback through mdxmini. An MDX is one logical
/// sequence; the decoder's FM/PCM channel count is not a playlist count.
final class MDXDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: mdx_player_handle_t
    private var resolvedSystem = "Sharp X68000"

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = mdx_player_create(path, Int32(sampleRate), &error) else {
            let message = Self.takeError(&error)
            throw MDXDecoderError.createFailed(message)
        }
        self.handle = handle
    }

    deinit {
        mdx_player_destroy(handle)
    }

    var trackCount: Int { 1 }
    var systemName: String { resolvedSystem }
    var absolutePlayedFrames: Int64 { mdx_player_played_frames(handle) }
    var trackEnded: Bool { mdx_player_track_ended(handle) != 0 }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw MDXDecoderError.singleTrack }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw MDXDecoderError.singleTrack }
        var raw = mdx_metadata_t()
        var error: UnsafeMutablePointer<CChar>?
        guard mdx_player_read_metadata(handle, &raw, &error) == 0 else {
            throw MDXDecoderError.metadataFailed(Self.takeError(&error))
        }
        defer { mdx_metadata_clear(&raw) }

        let title = Self.decodeTitle(raw.title)
        let lengthMs = max(0, Int(raw.play_length_ms))
        return TrackMetadata(
            index: 0,
            song: title,
            game: "",
            author: "",
            system: Self.string(raw.system),
            lengthMs: lengthMs,
            introMs: lengthMs,
            loopMs: 0,
            playMs: lengthMs,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = mdx_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        Self.freeError(&error)
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        var interleaved = [Int16](repeating: 0, count: frameCount * 2)
        var rendered: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = interleaved.withUnsafeMutableBufferPointer {
            mdx_player_render_s16(handle, Int32(frameCount), $0.baseAddress, &rendered, &error)
        }
        guard result == 0 else {
            throw MDXDecoderError.renderFailed(Self.takeError(&error))
        }
        Self.freeError(&error)
        let count = min(frameCount, max(0, Int(rendered)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<count {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private static func string(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        pointer.map { String(cString: $0) } ?? ""
    }

    private static func decodeTitle(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        let length = strlen(pointer)
        let data = Data(bytes: pointer, count: length)
        return String(data: data, encoding: .shiftJIS)
            ?? String(decoding: data, as: UTF8.self)
    }

    private static func takeError(_ error: inout UnsafeMutablePointer<CChar>?) -> String {
        let message = error.map { String(cString: $0) } ?? "Unknown error."
        freeError(&error)
        return message
    }

    private static func freeError(_ error: inout UnsafeMutablePointer<CChar>?) {
        if let pointer = error {
            mdx_error_message_free(pointer)
            error = nil
        }
    }
}
