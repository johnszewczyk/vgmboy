import CGameMusicEmu
import Foundation

enum GMEDecoderError: LocalizedError {
    case loadFailed(String)
    case startFailed(String)
    case metadataFailed(String)

    var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            "libgme could not open the file. \(message)"
        case .startFailed(let message):
            "libgme could not start the track. \(message)"
        case .metadataFailed(let message):
            "libgme could not read track metadata. \(message)"
        }
    }
}

/// Wraps the game-music-emu (libgme) core for one loaded file. Owns the
/// emulator instance. All calls must happen on the owning session's serial
/// queue; the audio render thread never touches this type directly.
final class GMEDecoder: @unchecked Sendable {
    let sampleRate: Int
    private let emu: OpaquePointer
    private var absoluteFrames: Int64 = 0

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var created: OpaquePointer?
        let error = gme_open_file(path, &created, Int32(sampleRate))
        guard error == nil, let created else {
            throw GMEDecoderError.loadFailed(
                error.map { String(cString: $0) } ?? "Unknown error."
            )
        }
        self.emu = created
    }

    deinit {
        gme_delete(emu)
    }

    var trackCount: Int {
        Int(gme_track_count(emu))
    }

    var systemName: String {
        guard let type = gme_type(emu),
              let system = gme_type_system(type) else {
            return ""
        }
        return String(cString: system)
    }

    func startTrack(_ index: Int) throws {
        let error = gme_start_track(emu, Int32(index))
        guard error == nil else {
            throw GMEDecoderError.startFailed(
                error.map { String(cString: $0) } ?? "Unknown error."
            )
        }
        absoluteFrames = 0
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        var infoPointer: UnsafeMutablePointer<gme_info_t>?
        let error = gme_track_info(emu, &infoPointer, Int32(index))
        guard error == nil, let info = infoPointer?.pointee else {
            throw GMEDecoderError.metadataFailed(
                error.map { String(cString: $0) } ?? "Unknown error."
            )
        }
        defer { gme_free_info(infoPointer) }
        return TrackMetadata(
            index: index,
            song: String(cString: info.song),
            game: String(cString: info.game),
            author: String(cString: info.author),
            system: String(cString: info.system),
            lengthMs: Int(info.length),
            introMs: Int(info.intro_length),
            loopMs: Int(info.loop_length),
            playMs: Int(info.play_length),
            fadeMs: Int(info.fade_length)
        )
    }

    func setTempo(_ tempo: Double) {
        gme_set_tempo(emu, tempo)
    }

    /// Configures libgme's own fade-out. When `playMs > 0` the track ends at
    /// `playMs + fadeMs` and `trackEnded` becomes true after the fade.
    func configureFade(playMs: Int, fadeMs: Int) {
        if playMs > 0 && fadeMs >= 0 {
            gme_set_fade_msecs(emu, Int32(playMs), Int32(fadeMs))
        }
    }

    func seek(milliseconds: Int) {
        gme_seek(emu, Int32(milliseconds))
        absoluteFrames = Int64(milliseconds) * Int64(sampleRate) / 1000
    }

    var absolutePlayedFrames: Int64 {
        absoluteFrames
    }

    var trackEnded: Bool {
        gme_track_ended(emu) != 0
    }

    /// Decodes up to `frameCount` stereo frames into separate float arrays.
    /// Ended tracks fill silence, so the caller consults `trackEnded`.
    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        _ = gme_play(emu, Int32(frameCount * 2), interleaved)
        absoluteFrames += Int64(frameCount)

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }
}