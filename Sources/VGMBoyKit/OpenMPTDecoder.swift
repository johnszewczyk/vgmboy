import Foundation
import VGMBoyCOpenMPT

enum OpenMPTDecoderError: LocalizedError {
    case openFailed(String)
    case metadataFailed(String)
    case singleTrack

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "libopenmpt could not open the tracker module. \(message)"
        case .metadataFailed(let message): "libopenmpt could not read tracker metadata. \(message)"
        case .singleTrack: "Tracker modules expose one playable sequence."
        }
    }
}

/// Plays tracker modules through libopenmpt. The public metadata is only the
/// decoder's private timing boundary; hosts continue to present catalog data.
final class OpenMPTDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: UnsafeMutableRawPointer
    private var system = "Tracker module"

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let opened = path.withCString({ openmpt_player_create($0, Int32(sampleRate), &error) }) else {
            throw OpenMPTDecoderError.openFailed(Self.takeError(&error))
        }
        handle = opened
    }

    deinit {
        openmpt_player_destroy(handle)
    }

    var trackCount: Int { 1 }
    var systemName: String { system }
    var absolutePlayedFrames: Int64 { Int64(openmpt_player_played_frames(handle)) }
    var trackEnded: Bool { openmpt_player_track_ended(handle) != 0 }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw OpenMPTDecoderError.singleTrack }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw OpenMPTDecoderError.singleTrack }
        var raw = openmpt_metadata_t()
        var error: UnsafeMutablePointer<CChar>?
        defer { openmpt_metadata_clear(&raw) }
        guard openmpt_player_read_metadata(handle, &raw, &error) == 0 else {
            throw OpenMPTDecoderError.metadataFailed(Self.takeError(&error))
        }
        let tracker = Self.string(raw.tracker)
        if !tracker.isEmpty { system = tracker }
        return TrackMetadata(
            index: 0,
            song: Self.string(raw.title),
            game: "",
            author: Self.string(raw.artist),
            system: system,
            lengthMs: Int(raw.play_length_ms),
            introMs: 0,
            loopMs: 0,
            playMs: Int(raw.play_length_ms),
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        setRepeat(true)
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        setRepeat(false)
    }

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = openmpt_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        Self.freeError(&error)
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        var interleaved = [Int16](repeating: 0, count: frameCount * 2)
        var rendered: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = interleaved.withUnsafeMutableBufferPointer {
            openmpt_player_render_s16(handle, Int32(frameCount), $0.baseAddress, &rendered, &error)
        }
        Self.freeError(&error)
        guard result == 0 else {
            return (Array(repeating: 0, count: frameCount), Array(repeating: 0, count: frameCount))
        }
        let count = min(frameCount, max(0, Int(rendered)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<count {
            left[index] = Float(interleaved[index * 2]) / 32768
            right[index] = Float(interleaved[index * 2 + 1]) / 32768
        }
        return (left, right)
    }

    private func setRepeat(_ enabled: Bool) {
        var error: UnsafeMutablePointer<CChar>?
        _ = openmpt_player_set_repeat(handle, enabled ? 1 : 0, &error)
        Self.freeError(&error)
    }

    private static func string(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        pointer.map { String(cString: $0) } ?? ""
    }

    private static func takeError(_ error: inout UnsafeMutablePointer<CChar>?) -> String {
        let message = error.map { String(cString: $0) } ?? "Unknown error."
        freeError(&error)
        return message
    }

    private static func freeError(_ error: inout UnsafeMutablePointer<CChar>?) {
        if let pointer = error {
            openmpt_error_message_free(pointer)
            error = nil
        }
    }
}
