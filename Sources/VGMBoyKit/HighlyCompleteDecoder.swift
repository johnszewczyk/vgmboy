import VGMBoyCHighlyComplete
import Foundation

private enum HighlyCompleteBridgeGate {
    private static let lock = NSLock()

    static func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

enum HighlyCompleteDecoderError: LocalizedError {
    case createFailed(String)
    case bridgeFailed(String)

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "Highly Complete could not open the GSF file. \(message)"
        case .bridgeFailed(let message):
            "Highly Complete failed while decoding the GSF file. \(message)"
        }
    }
}

/// Wraps the Highly Complete GSF path: PSFLib resolves the complete GSF chain
/// and the copied C bridge runs its ROM through mGBA. mGBA's native rate can
/// change while a title is running; the bridge resamples it into `sampleRate`
/// and counts output-rate frames, which keeps the shared transport accurate.
final class HighlyCompleteDecoder: AudioDecoder, @unchecked Sendable {
    var appliesFadeInternally: Bool { false }
    let sampleRate: Int
    private let handle: highlycomplete_player_handle_t

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        let handle = HighlyCompleteBridgeGate.withLock {
            path.withCString {
                highlycomplete_player_create($0, Int32(sampleRate), 0, &error)
            }
        }
        guard let handle else {
            let message = error.map { String(cString: $0) } ?? "Unknown Highly Complete error."
            if let error { highlycomplete_error_message_free(error) }
            throw HighlyCompleteDecoderError.createFailed(message)
        }
        self.handle = handle
    }

    deinit {
        HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_destroy(handle)
        }
    }

    var trackCount: Int { 1 }

    var systemName: String {
        (try? metadata(for: 0).system).flatMap { $0.isEmpty ? nil : $0 } ?? "Game Boy Advance"
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else {
            throw HighlyCompleteDecoderError.bridgeFailed("GSF files expose a single playable track.")
        }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else {
            throw HighlyCompleteDecoderError.bridgeFailed("GSF files expose a single playable track.")
        }
        return try readMetadata()
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        configure(usesNativeEnding: false)
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        configure(usesNativeEnding: true)
    }

    func seek(milliseconds: Int) {
        var error: UnsafeMutablePointer<CChar>?
        _ = HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_seek_milliseconds(handle, Int32(max(0, milliseconds)), &error)
        }
        if let error { highlycomplete_error_message_free(error) }
    }

    var absolutePlayedFrames: Int64 {
        HighlyCompleteBridgeGate.withLock {
            Int64(highlycomplete_player_played_frames(handle))
        }
    }

    var trackEnded: Bool {
        HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_track_ended(handle) != 0
        }
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let status = HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_render_s16(handle, Int32(frameCount), interleaved, &renderedFrames, &error)
        }
        if let error { highlycomplete_error_message_free(error) }
        guard status == 0 else {
            return ([Float](repeating: 0, count: frameCount), [Float](repeating: 0, count: frameCount))
        }

        let actualFrameCount = min(frameCount, max(0, Int(renderedFrames)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<actualFrameCount {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private func configure(usesNativeEnding: Bool) {
        var error: UnsafeMutablePointer<CChar>?
        _ = HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_configure(handle, 0, 0, usesNativeEnding, &error)
        }
        if let error { highlycomplete_error_message_free(error) }
    }

    private func readMetadata() throws -> TrackMetadata {
        var raw = highlycomplete_metadata_t()
        defer { highlycomplete_metadata_clear(&raw) }
        var error: UnsafeMutablePointer<CChar>?
        let status = HighlyCompleteBridgeGate.withLock {
            highlycomplete_player_read_metadata(handle, &raw, &error)
        }
        try Self.throwIfFailed(status, error: error)
        return Self.metadata(from: raw)
    }

    private static func metadata(from raw: highlycomplete_metadata_t) -> TrackMetadata {
        let playMs = Int(raw.play_length_ms)
        return TrackMetadata(
            index: 0,
            song: string(from: raw.title),
            game: string(from: raw.game),
            author: string(from: raw.artist),
            system: {
                let value = string(from: raw.system)
                return value.isEmpty ? "Game Boy Advance" : value
            }(),
            lengthMs: playMs,
            introMs: Int(raw.intro_length_ms),
            loopMs: Int(raw.loop_length_ms),
            playMs: playMs,
            fadeMs: Int(raw.fade_length_ms)
        )
    }

    private static func string(from pointer: UnsafeMutablePointer<CChar>?) -> String {
        pointer.map { String(cString: $0) } ?? ""
    }

    private static func throwIfFailed(_ status: Int32, error: UnsafeMutablePointer<CChar>?) throws {
        defer {
            if let error { highlycomplete_error_message_free(error) }
        }
        guard status == 0 else {
            throw HighlyCompleteDecoderError.bridgeFailed(error.map { String(cString: $0) } ?? "Unknown Highly Complete error.")
        }
    }
}
