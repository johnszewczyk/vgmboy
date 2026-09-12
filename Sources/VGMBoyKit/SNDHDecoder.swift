import Foundation
import VGMBoyCPSGPlay
import VGMBoySNDH

enum SNDHDecoderError: LocalizedError {
    case openFailed(String)
    case invalidTrack
    case restartFailed(String)
    case timingFailed(String)
    case seekFailed(String)
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "PSG play could not open the SNDH file. \(message)"
        case .invalidTrack: "SNDH subtune selection is outside the file's declared range."
        case .restartFailed(let message): "PSG play could not restart the SNDH subtune. \(message)"
        case .timingFailed(let message): "PSG play could not configure SNDH timing. \(message)"
        case .seekFailed(let message): "PSG play could not seek the SNDH subtune. \(message)"
        case .renderFailed(let message): "PSG play could not render SNDH audio. \(message)"
        }
    }
}

final class SNDHDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private var handle: vgmboy_psgplay_handle_t?
    private let metadata: SNDHMetadata
    private var currentTrack = 0

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        do {
            metadata = try SNDHMetadataReader.read(fileURL: URL(fileURLWithPath: path))
        } catch {
            throw SNDHDecoderError.openFailed(error.localizedDescription)
        }
        var error: UnsafeMutablePointer<CChar>?
        guard let opened = path.withCString({
            vgmboy_psgplay_open($0, 1, Int32(sampleRate), &error)
        }) else {
            throw SNDHDecoderError.openFailed(Self.message(error))
        }
        handle = opened
    }

    deinit { close() }

    var appliesFadeInternally: Bool { false }
    var trackCount: Int { metadata.tracks.count }
    var systemName: String { "Atari ST" }

    func close() {
        guard let handle else { return }
        vgmboy_psgplay_close(handle)
        self.handle = nil
    }

    func startTrack(_ index: Int) throws {
        guard metadata.tracks.indices.contains(index) else {
            throw SNDHDecoderError.invalidTrack
        }
        currentTrack = index
        var error: UnsafeMutablePointer<CChar>?
        guard let handle, vgmboy_psgplay_select_track(handle, Int32(index + 1), &error) == 0 else {
            throw SNDHDecoderError.restartFailed(Self.message(error))
        }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard metadata.tracks.indices.contains(index) else {
            throw SNDHDecoderError.invalidTrack
        }
        let track = metadata.tracks[index]
        let song = track.subtuneName.isEmpty ? track.title : track.subtuneName
        return TrackMetadata(
            index: index,
            song: song,
            game: "",
            author: track.composer,
            system: systemName,
            lengthMs: track.durationMilliseconds,
            introMs: 0,
            loopMs: 0,
            playMs: track.durationMilliseconds,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_psgplay_configure(handle, Int32(max(0, playMs)), &error)
        if let error { vgmboy_psgplay_error_message_free(error) }
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        configureFade(playMs: playMs, fadeMs: fadeMs)
    }

    func seek(milliseconds: Int) {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_psgplay_seek(handle, Int32(max(0, milliseconds)), &error)
        if let error { vgmboy_psgplay_error_message_free(error) }
    }

    var absolutePlayedFrames: Int64 {
        guard let handle else { return 0 }
        return vgmboy_psgplay_played_frames(handle)
    }

    var trackEnded: Bool {
        guard let handle else { return true }
        return vgmboy_psgplay_track_ended(handle) != 0
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        guard let handle else { return ([], []) }
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        guard vgmboy_psgplay_read_s16(handle, Int32(frameCount), interleaved, &renderedFrames, &error) == 0 else {
            throw SNDHDecoderError.renderFailed(Self.message(error))
        }
        let rendered = min(frameCount, max(0, Int(renderedFrames)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<rendered {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private static func message(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        defer { if let pointer { vgmboy_psgplay_error_message_free(pointer) } }
        guard let pointer else { return "Unknown PSG play error." }
        var bytes: [UInt8] = []
        var index = 0
        while pointer[index] != 0 {
            bytes.append(UInt8(bitPattern: pointer[index]))
            index += 1
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
