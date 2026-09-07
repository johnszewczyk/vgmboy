import Foundation
import VGMBoyCZXTune

enum ZXTuneDecoderError: LocalizedError {
    case openFailed(String)
    case metadataFailed(String)
    case renderFailed(String)
    case singleTrack

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "ZXTune could not open the AY-family module. \(message)"
        case .metadataFailed(let message): "ZXTune could not read module metadata. \(message)"
        case .renderFailed(let message): "ZXTune could not render module audio. \(message)"
        case .singleTrack: "ZXTune modules expose one playable sequence."
        }
    }
}

/// ZXTune's AY-family bridge covers tracker formats that are not represented
/// by Game Music Emu. It keeps the upstream player behind the same small C
/// boundary used by the other VGMBoy decoders.
final class ZXTuneDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: OpaquePointer
    private var resolvedSystem = "ZX Spectrum AY"

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = path.withCString({
            vgmboy_zxtune_player_create($0, Int32(sampleRate), &error)
        }) else {
            throw ZXTuneDecoderError.openFailed(Self.takeError(&error))
        }
        self.handle = handle
    }

    deinit {
        vgmboy_zxtune_player_destroy(handle)
    }

    var trackCount: Int { 1 }
    var systemName: String { resolvedSystem }
    var absolutePlayedFrames: Int64 {
        vgmboy_zxtune_player_played_frames(handle)
    }
    var trackEnded: Bool {
        vgmboy_zxtune_player_track_ended(handle) != 0
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw ZXTuneDecoderError.singleTrack }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw ZXTuneDecoderError.singleTrack }
        var raw = vgmboy_zxtune_metadata_t()
        var error: UnsafeMutablePointer<CChar>?
        guard vgmboy_zxtune_player_read_metadata(handle, &raw, &error) == 0 else {
            throw ZXTuneDecoderError.metadataFailed(Self.takeError(&error))
        }
        defer { vgmboy_zxtune_metadata_clear(&raw) }

        let title = Self.string(raw.title)
        let author = Self.string(raw.author)
        let program = Self.string(raw.program)
        let system = Self.string(raw.system)
        if !system.isEmpty {
            resolvedSystem = system
        } else if !program.isEmpty {
            resolvedSystem = program
        }
        let lengthMs = max(0, Int(raw.length_ms))
        let loopMs = max(0, Int(raw.loop_ms))
        return TrackMetadata(
            index: 0,
            song: title,
            game: "",
            author: author,
            system: resolvedSystem,
            lengthMs: lengthMs,
            introMs: max(0, lengthMs - loopMs),
            loopMs: loopMs,
            playMs: lengthMs,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        setLooped(true)
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        setLooped(false)
    }

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_zxtune_player_seek(handle, Int32(max(0, milliseconds)), &error)
        Self.freeError(&error)
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        var interleaved = [Int16](repeating: 0, count: frameCount * 2)
        var rendered: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = interleaved.withUnsafeMutableBufferPointer {
            vgmboy_zxtune_player_render(handle, Int32(frameCount), $0.baseAddress, &rendered, &error)
        }
        guard result == 0 else {
            throw ZXTuneDecoderError.renderFailed(Self.takeError(&error))
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

    private func setLooped(_ enabled: Bool) {
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_zxtune_player_set_looped(handle, enabled ? 1 : 0, &error)
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
            vgmboy_zxtune_error_message_free(pointer)
            error = nil
        }
    }
}
