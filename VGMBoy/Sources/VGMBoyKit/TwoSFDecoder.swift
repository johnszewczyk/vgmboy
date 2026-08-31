import VGMBoyC2SF
import Foundation

private enum TwoSFBridgeGate {
    private static let lock = NSLock()

    static func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

enum TwoSFDecoderError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): return "2SF decoder failed. \(message)"
        }
    }
}

/// Wraps 2sf2wav for Nintendo DS 2SF. The bridge validates a complete
/// mini2SF dependency chain before the process-global DS core is created.
final class TwoSFDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { true }
    let sampleRate: Int
    private var handle: twosf_player_handle_t?

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        let created = TwoSFBridgeGate.withLock {
            path.withCString { twosf_player_create($0, Int32(sampleRate), &error) }
        }
        guard let created else {
            let message = error.map { String(cString: $0) } ?? "Unknown 2SF error."
            if let error { twosf_error_message_free(error) }
            throw TwoSFDecoderError.failed(message)
        }
        handle = created
    }

    deinit { close() }

    func close() {
        guard let handle else { return }
        self.handle = nil
        TwoSFBridgeGate.withLock { twosf_player_destroy(handle) }
    }

    var trackCount: Int { 1 }
    var systemName: String { (try? metadata(for: 0).system).flatMap { $0.isEmpty ? nil : $0 } ?? "Nintendo DS" }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw TwoSFDecoderError.failed("2SF files expose a single playable track.") }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw TwoSFDecoderError.failed("2SF files expose a single playable track.") }
        guard let handle else { throw TwoSFDecoderError.failed("2SF playback was released.") }
        var raw = twosf_metadata_t()
        defer { twosf_metadata_clear(&raw) }
        var error: UnsafeMutablePointer<CChar>?
        let status = TwoSFBridgeGate.withLock { twosf_player_read_metadata(handle, &raw, &error) }
        try Self.throwIfFailed(status, error: error)
        return Self.metadata(from: raw)
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        configure(playMs: playMs, fadeMs: fadeMs)
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        _ = TwoSFBridgeGate.withLock { twosf_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error) }
        if let error { twosf_error_message_free(error) }
    }

    var absolutePlayedFrames: Int64 {
        guard let handle else { return 0 }
        return TwoSFBridgeGate.withLock { Int64(twosf_player_played_frames(handle)) }
    }

    var trackEnded: Bool {
        guard let handle else { return true }
        return TwoSFBridgeGate.withLock { twosf_player_track_ended(handle) != 0 }
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0, let handle else { return ([], []) }
        let pcm = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { pcm.deallocate() }
        var rendered: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let status = TwoSFBridgeGate.withLock {
            twosf_player_render_s16(handle, Int32(frameCount), pcm, &rendered, &error)
        }
        if let error { twosf_error_message_free(error) }
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        guard status == 0 else { return (left, right) }
        for index in 0..<min(frameCount, max(0, Int(rendered))) {
            left[index] = Float(pcm[index * 2]) / 32768.0
            right[index] = Float(pcm[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private func configure(playMs: Int, fadeMs: Int) {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        _ = TwoSFBridgeGate.withLock {
            twosf_player_configure(handle, Int32(max(0, playMs)), Int32(max(0, fadeMs)), &error)
        }
        if let error { twosf_error_message_free(error) }
    }

    private static func metadata(from raw: twosf_metadata_t) -> TrackMetadata {
        let playMs = Int(raw.play_length_ms)
        return TrackMetadata(index: 0, song: string(raw.title), game: string(raw.game), author: string(raw.artist), system: {
            let value = string(raw.system)
            return value.isEmpty ? "Nintendo DS" : value
        }(), lengthMs: playMs, introMs: 0, loopMs: 0, playMs: playMs, fadeMs: Int(raw.fade_length_ms))
    }

    private static func string(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        pointer.map { String(cString: $0) } ?? ""
    }

    private static func throwIfFailed(_ status: Int32, error: UnsafeMutablePointer<CChar>?) throws {
        defer { if let error { twosf_error_message_free(error) } }
        guard status == 0 else {
            throw TwoSFDecoderError.failed(error.map { String(cString: $0) } ?? "Unknown 2SF error.")
        }
    }
}
