import Foundation
import VGMBoyCQSF

enum QSFDecoderError: LocalizedError, Equatable {
    case createFailed(String)
    case concurrentUse
    case invalidTrack

    var errorDescription: String? {
        switch self {
        case .createFailed(let message):
            "Audio Overload SDK could not open the QSF file. \(message)"
        case .concurrentUse:
            "The process-global QSF decoder is already in use by another playback or inspection session."
        case .invalidTrack:
            "QSF files expose a single playable track."
        }
    }
}

/// Audio Overload's QSF engine stores emulator and dependency-resolution state
/// in process globals. A lease covers the complete native-handle lifetime so a
/// live session cannot be corrupted by concurrent export or inspection work.
enum QSFBridgeLease {
    private static let semaphore = DispatchSemaphore(value: 1)

    final class Token: @unchecked Sendable {
        private let lock = NSLock()
        private var isReleased = false

        func release() {
            lock.lock()
            guard !isReleased else {
                lock.unlock()
                return
            }
            isReleased = true
            lock.unlock()
            QSFBridgeLease.semaphore.signal()
        }

        deinit { release() }
    }

    static func acquire() -> Token? {
        semaphore.wait(timeout: .now()) == .success ? Token() : nil
    }
}

/// QSF/miniQSF playback through the Audio Overload SDK's Capcom QSound core.
/// The native bridge resolves a miniQSF's adjacent .qsflib, renders stereo
/// 44.1 kHz PCM, and keeps the authored [TAG] timing in the same decoder
/// contract used by the other console-music cores.
final class QSFDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private var handle: UnsafeMutableRawPointer?
    private var bridgeLease: QSFBridgeLease.Token?

    init(path: String, sampleRate: Int = 44_100) throws {
        self.sampleRate = sampleRate
        guard let bridgeLease = QSFBridgeLease.acquire() else {
            throw QSFDecoderError.concurrentUse
        }
        guard let handle = path.withCString({ vgmboy_qsf_open($0) }) else {
            throw QSFDecoderError.createFailed("The QSound engine rejected the file or its .qsflib dependency.")
        }
        self.handle = handle
        self.bridgeLease = bridgeLease
    }

    deinit { close() }

    func close() {
        if let handle {
            vgmboy_qsf_close(handle)
            self.handle = nil
        }
        bridgeLease?.release()
        bridgeLease = nil
    }

    var appliesFadeInternally: Bool { false }
    var trackCount: Int { 1 }

    var systemName: String {
        guard let handle, let name = vgmboy_qsf_system_name(handle) else {
            return "Capcom QSound"
        }
        return String(cString: name)
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw QSFDecoderError.invalidTrack }
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0, let handle else { throw QSFDecoderError.invalidTrack }
        let playMs = Int(vgmboy_qsf_play_length_frames(handle) * 1_000 / Int64(sampleRate))
        let fadeMs = Int(vgmboy_qsf_fade_length_frames(handle) * 1_000 / Int64(sampleRate))
        return TrackMetadata(
            index: 0,
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

    func configureFade(playMs: Int, fadeMs: Int) {
        if let handle {
            vgmboy_qsf_configure(handle, Int32(max(0, playMs)), Int32(max(0, fadeMs)))
        }
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        configureFade(playMs: playMs, fadeMs: fadeMs)
    }

    func seek(milliseconds: Int) {
        guard let handle else { return }
        _ = vgmboy_qsf_seek(handle, Int64(max(0, milliseconds)) * Int64(sampleRate) / 1_000)
    }

    var absolutePlayedFrames: Int64 {
        guard let handle else { return 0 }
        return vgmboy_qsf_played_frames(handle)
    }

    var trackEnded: Bool {
        guard let handle else { return true }
        return vgmboy_qsf_finished(handle) != 0
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard let handle, frameCount > 0 else { return ([], []) }
        let interleaved = UnsafeMutablePointer<Int16>.allocate(capacity: frameCount * 2)
        defer { interleaved.deallocate() }
        let rendered = max(0, Int(vgmboy_qsf_read(handle, interleaved, Int32(frameCount))))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<min(frameCount, rendered) {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private func tag(_ handle: UnsafeMutableRawPointer, _ name: String) -> String {
        name.withCString { pointer in
            guard let value = vgmboy_qsf_tag(handle, pointer) else { return "" }
            return String(cString: value)
        }
    }
}
