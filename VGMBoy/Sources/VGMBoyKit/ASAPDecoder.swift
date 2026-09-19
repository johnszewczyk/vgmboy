import Foundation
import VGMBoyCASAP

enum ASAPDecoderError: LocalizedError {
    case loadFailed
    case invalidTrack(Int)
    case startFailed(Int)
    case seekFailed(Int)
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            "ASAP could not open this SAP file."
        case .invalidTrack(let index):
            "ASAP track index \(index) is outside the file's song range."
        case .startFailed(let index):
            "ASAP could not start track \(index)."
        case .seekFailed(let position):
            "ASAP could not seek to \(position) ms."
        case .renderFailed:
            "ASAP could not render the requested audio frames."
        }
    }
}

/// Plays SAP through the vendored ASAP core, including SAP TYPE D and TYPE S
/// files that the linked libgme build does not implement.
final class ASAPDecoder: AudioDecoder, @unchecked Sendable {
    private static let loopPlayLengthMs = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000

    let sampleRate: Int
    let appliesFadeInternally = false
    private let sourceData: Data
    private var player: OpaquePointer?
    private var currentTrack = 0
    private var playedFrames: Int64 = 0
    private var ended = false

    convenience init(path: String, sampleRate: Int = 44_100) throws {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        try self.init(data: data, filename: url.lastPathComponent, sampleRate: sampleRate)
    }

    init(data: Data, filename: String = "memory.sap", sampleRate: Int = 44_100) throws {
        guard !data.isEmpty, data.count <= Int(Int32.max), sampleRate > 0 else {
            throw ASAPDecoderError.loadFailed
        }
        self.sourceData = data
        self.sampleRate = sampleRate

        let created = data.withUnsafeBytes { bytes in
            filename.withCString { filenamePointer in
                vgmboy_asap_create(
                    bytes.bindMemory(to: UInt8.self).baseAddress,
                    Int32(data.count),
                    filenamePointer,
                    Int32(sampleRate)
                )
            }
        }
        guard let created else { throw ASAPDecoderError.loadFailed }
        self.player = created
        guard trackCount > 0 else {
            vgmboy_asap_destroy(created)
            self.player = nil
            throw ASAPDecoderError.loadFailed
        }
    }

    deinit {
        close()
    }

    var trackCount: Int {
        Int(vgmboy_asap_song_count(player))
    }

    var systemName: String { "Atari XL" }

    var absolutePlayedFrames: Int64 { playedFrames }

    var trackEnded: Bool { ended }

    func startTrack(_ index: Int) throws {
        guard (0..<trackCount).contains(index) else {
            throw ASAPDecoderError.invalidTrack(index)
        }
        guard vgmboy_asap_start_song(player, Int32(index), -1) else {
            throw ASAPDecoderError.startFailed(index)
        }
        currentTrack = index
        playedFrames = 0
        ended = false
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard (0..<trackCount).contains(index) else {
            throw ASAPDecoderError.invalidTrack(index)
        }
        let duration = Int(vgmboy_asap_duration_ms(player, Int32(index)))
        let loops = vgmboy_asap_song_loops(player, Int32(index))
        let title = Self.string(vgmboy_asap_title(player))
        let song = Self.string(vgmboy_asap_title_or_filename(player))
        return TrackMetadata(
            index: index,
            song: song,
            game: title,
            author: Self.string(vgmboy_asap_author(player)),
            system: systemName,
            lengthMs: duration,
            introMs: loops ? duration : -1,
            loopMs: -1,
            playMs: loops && duration > 0 ? Self.loopPlayLengthMs : duration,
            fadeMs: -1
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {
        restart(durationMs: Self.boundedDuration(playMs: playMs, fadeMs: fadeMs))
    }

    func configureNativeEnding(playMs: Int, fadeMs: Int) {
        restart(durationMs: Self.boundedDuration(playMs: playMs, fadeMs: fadeMs))
    }

    func seek(milliseconds: Int) {
        guard milliseconds >= 0, vgmboy_asap_seek(player, Int32(clamping: milliseconds)) else { return }
        playedFrames = Int64(milliseconds) * Int64(sampleRate) / 1_000
        ended = false
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount >= 0, frameCount <= Int(Int32.max / 4), let player else {
            if frameCount == 0 { return ([], []) }
            throw ASAPDecoderError.renderFailed
        }
        if frameCount == 0 { return ([], []) }

        var samples = [Int16](repeating: 0, count: frameCount * 2)
        let generated = samples.withUnsafeMutableBufferPointer { buffer in
            vgmboy_asap_render_stereo(player, buffer.baseAddress, Int32(frameCount))
        }
        guard generated >= 0 else { throw ASAPDecoderError.renderFailed }
        if generated < frameCount { ended = true }
        playedFrames += Int64(frameCount)

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            left[frame] = Float(samples[frame * 2]) / 32_768.0
            right[frame] = Float(samples[frame * 2 + 1]) / 32_768.0
        }
        return (left, right)
    }

    func close() {
        guard let player else { return }
        vgmboy_asap_destroy(player)
        self.player = nil
    }

    private func restart(durationMs: Int) {
        guard let player else { return }
        let duration = durationMs > 0 ? Int32(clamping: durationMs) : -1
        guard vgmboy_asap_start_song(player, Int32(currentTrack), duration) else { return }
        playedFrames = 0
        ended = false
    }

    private static func boundedDuration(playMs: Int, fadeMs: Int) -> Int {
        guard playMs > 0 else { return 0 }
        let total = Int64(playMs) + Int64(max(0, fadeMs))
        return Int(min(total, Int64(Int32.max)))
    }

    private static func string(_ value: UnsafePointer<CChar>?) -> String {
        value.map(String.init(cString:)) ?? ""
    }
}
