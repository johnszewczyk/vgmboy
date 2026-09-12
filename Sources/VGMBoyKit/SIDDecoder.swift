import Foundation
import VGMBoyCSIDPlayFP

enum SIDDecoderError: LocalizedError {
    case openFailed(String)
    case metadataFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "libsidplayfp could not open the SID file. \(message)"
        case .metadataFailed(let message): "libsidplayfp could not read SID metadata. \(message)"
        }
    }
}

/// One SID tune through libsidplayfp/SIDLite. SID has no intrinsic finite end,
/// so VGMBoy's timing policy supplies its playback window and fade.
final class SIDDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: UnsafeMutableRawPointer

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let opened = path.withCString({ vgmboy_sid_open($0, Int32(sampleRate), &error) }) else {
            throw SIDDecoderError.openFailed(Self.takeError(&error))
        }
        handle = opened
    }

    deinit {
        vgmboy_sid_close(handle)
    }

    var trackCount: Int { 1 }
    var systemName: String { "Commodore 64" }
    var absolutePlayedFrames: Int64 { vgmboy_sid_played_frames(handle) }
    var trackEnded: Bool { false }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw SIDDecoderError.openFailed("SID files expose one tune.") }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw SIDDecoderError.metadataFailed("SID track index is unavailable.") }
        var raw = vgmboy_sid_metadata_t()
        var error: UnsafeMutablePointer<CChar>?
        defer { vgmboy_sid_metadata_clear(&raw) }
        guard vgmboy_sid_read_metadata(handle, &raw, &error) == 0 else {
            throw SIDDecoderError.metadataFailed(Self.takeError(&error))
        }
        return TrackMetadata(
            index: 0,
            song: Self.string(raw.title),
            game: "",
            author: Self.string(raw.artist),
            system: Self.string(raw.system).isEmpty ? systemName : Self.string(raw.system),
            lengthMs: 0,
            introMs: 0,
            loopMs: 0,
            playMs: 0,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_sid_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        Self.freeError(&error)
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        var interleaved = [Int16](repeating: 0, count: frameCount * 2)
        var rendered: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = interleaved.withUnsafeMutableBufferPointer {
            vgmboy_sid_render_s16(handle, Int32(frameCount), $0.baseAddress, &rendered, &error)
        }
        Self.freeError(&error)
        guard result == 0 else { return (Array(repeating: 0, count: frameCount), Array(repeating: 0, count: frameCount)) }
        let count = min(frameCount, max(0, Int(rendered)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<count {
            let sample = Float(interleaved[index * 2]) / 32768
            left[index] = sample
            right[index] = sample
        }
        return (left, right)
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
            vgmboy_sid_free_string(pointer)
            error = nil
        }
    }
}
