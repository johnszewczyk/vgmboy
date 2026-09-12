import VGMBoyCPlayPSF
import Foundation

enum PlayPSFDecoderError: LocalizedError {
    case createFailed(String)
    case decodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "Play! could not open the PSF file. \(message)"
        case .decodeFailed(let message):
            "Play! could not decode the PSF file. \(message)"
        }
    }
}

/// Wraps the Play! core (PlayStation PSF/miniPSF, PlayStation 2 PSF2/miniPSF2).
/// Play! emulates the console in real time and streams PCM through a ring
/// buffer, so the decoder cannot seek ahead or fade internally — long play is
/// the bridge's `finished` flag (loop past the tagged length) and the fade is
/// applied by the session DSP. Tempo is unsupported.
///
/// Driver-halt rips: when the emulated music driver stops producing PCM the
/// bridge returns empty chunks. After the first real audio, an empty chunk
/// means the song is over, so we report `trackEnded` instead of playing
/// silence to the cap.
final class PlayPSFDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let handle: UnsafeMutableRawPointer?
    private var producedAudioOnce = false
    private var driverHalted = false

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        guard let handle = path.withCString({ vgmboy_play_psf_open($0) }) else {
            throw PlayPSFDecoderError.createFailed("Play! rejected the file.")
        }
        self.handle = handle
    }

    deinit {
        if let handle { vgmboy_play_psf_close(handle) }
    }

    var appliesFadeInternally: Bool { false }

    var trackCount: Int {
        1
    }

    var systemName: String {
        guard let handle, let name = vgmboy_play_psf_system_name(handle) else {
            return "PlayStation"
        }
        return String(cString: name)
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else {
            throw PlayPSFDecoderError.createFailed("PSF files expose a single playable track.")
        }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0, let handle else {
            throw PlayPSFDecoderError.createFailed("PSF files expose a single playable track.")
        }
        let playMs = Int(vgmboy_play_psf_play_length_frames(handle) * 1000 / Int64(sampleRate))
        let fadeMs = Int(vgmboy_play_psf_fade_length_frames(handle) * 1000 / Int64(sampleRate))
        return TrackMetadata(
            index: index,
            song: tag(handle, "title"),
            game: tag(handle, "game"),
            author: tag(handle, "artist"),
            system: systemName,
            lengthMs: playMs,
            introMs: 0,
            loopMs: 0,
            playMs: playMs,
            fadeMs: fadeMs
        )
    }

    func setTempo(_ tempo: Double) {}

    /// Capped window: loop past the tagged length only when the requested
    /// window exceeds it (or no length is tagged); the session caps at
    /// play + fade and applies the fade DSP.
    func configureFade(playMs: Int, fadeMs: Int) {
        guard let handle else { return }
        let naturalMs = vgmboy_play_psf_play_length_frames(handle) * 1000 / Int64(sampleRate)
        let longPlay = naturalMs <= 0 || playMs > Int(naturalMs)
        vgmboy_play_psf_set_long_play(handle, longPlay ? 1 : 0)
    }

    /// Natural ending: end at the tagged length.
    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        if let handle {
            vgmboy_play_psf_set_long_play(handle, 0)
        }
    }

    func seek(milliseconds: Int) {
        guard let handle else { return }
        _ = vgmboy_play_psf_seek(handle, Int64(milliseconds) * Int64(sampleRate) / 1000)
        producedAudioOnce = false
        driverHalted = false
    }

    var absolutePlayedFrames: Int64 {
        guard let handle else { return 0 }
        return Int64(vgmboy_play_psf_played_frames(handle))
    }

    var trackEnded: Bool {
        guard let handle else { return true }
        return vgmboy_play_psf_finished(handle) != 0 || driverHalted
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard let handle else {
            return ([Float](repeating: 0, count: frameCount), [Float](repeating: 0, count: frameCount))
        }
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        let rendered = Int(vgmboy_play_psf_read(handle, interleaved, Int32(frameCount)))
        if rendered < 0 {
            let message = vgmboy_play_psf_error(handle).map { String(cString: $0) }
                ?? "The emulation core stopped unexpectedly."
            throw PlayPSFDecoderError.decodeFailed(message)
        }
        if rendered > 0 {
            producedAudioOnce = true
        } else if producedAudioOnce {
            driverHalted = true
        }

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<min(rendered, frameCount) {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private func tag(_ handle: UnsafeMutableRawPointer, _ name: String) -> String {
        name.withCString { pointer in
            guard let value = vgmboy_play_psf_tag(handle, pointer) else { return "" }
            return String(cString: value)
        }
    }
}
