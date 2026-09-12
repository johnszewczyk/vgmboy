import Foundation
import VGMBoyCUADE

enum AmigaDecoderError: LocalizedError {
    case openFailed(String)
    case metadataFailed(String)
    case invalidTrack
    case selectFailed(String)
    case seekFailed(String)
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): "UADE could not open the Amiga module: \(message)"
        case .metadataFailed(let message): "UADE could not read Amiga module metadata: \(message)"
        case .invalidTrack: "The Amiga module track is outside its declared subsong range."
        case .selectFailed(let message): "UADE could not select the Amiga subsong: \(message)"
        case .seekFailed(let message): "UADE could not seek within the Amiga subsong: \(message)"
        case .renderFailed(let message): "UADE could not render Amiga audio: \(message)"
        }
    }
}

/// Plays Amiga modules through libuade. UADE owns the format detection and
/// EaglePlayer emulation; VGMBoy owns the common PCM/transport contract.
final class AmigaDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let path: String
    private var handle: vgmboy_uade_handle_t?
    private let minimumSubsong: Int
    private let defaultSubsong: Int
    private let maximumSubsong: Int
    private var currentTrack = 0
    private(set) var playerName = ""
    private(set) var formatName = ""

    init(path: String, sampleRate: Int = 44_100) throws {
        self.path = path
        self.sampleRate = sampleRate
        var error: UnsafeMutablePointer<CChar>?
        guard let opened = path.withCString({
            vgmboy_uade_create($0, Int32(sampleRate), &error)
        }) else {
            throw AmigaDecoderError.openFailed(Self.takeError(&error))
        }
        handle = opened

        do {
            let info = try Self.readInfo(handle: opened)
            guard info.minimum >= 0,
                  info.maximum >= info.minimum,
                  info.maximum - info.minimum <= 10_000 else {
                throw AmigaDecoderError.metadataFailed("UADE returned an invalid subsong range.")
            }
            minimumSubsong = Int(info.minimum)
            defaultSubsong = Int(info.default)
            maximumSubsong = Int(info.maximum)
        } catch {
            vgmboy_uade_destroy(opened)
            handle = nil
            throw error
        }
        currentTrack = max(0, min(defaultSubsong - minimumSubsong, trackCount - 1))
    }

    deinit { close() }

    var appliesFadeInternally: Bool { false }
    var trackCount: Int { max(0, maximumSubsong - minimumSubsong + 1) }
    var systemName: String { "Commodore Amiga" }
    var absolutePlayedFrames: Int64 {
        guard let handle else { return 0 }
        return vgmboy_uade_played_frames(handle)
    }
    var trackEnded: Bool {
        guard let handle else { return true }
        return vgmboy_uade_track_ended(handle) != 0
    }

    func close() {
        guard let handle else { return }
        vgmboy_uade_destroy(handle)
        self.handle = nil
    }

    func startTrack(_ index: Int) throws {
        guard index >= 0, index < trackCount else {
            throw AmigaDecoderError.invalidTrack
        }
        guard let handle else {
            throw AmigaDecoderError.openFailed("UADE playback state is closed.")
        }
        var error: UnsafeMutablePointer<CChar>?
        guard vgmboy_uade_select_subsong(handle, Int32(minimumSubsong + index), &error) == 0 else {
            throw AmigaDecoderError.selectFailed(Self.takeError(&error))
        }
        currentTrack = index
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index >= 0, index < trackCount else {
            throw AmigaDecoderError.invalidTrack
        }
        guard let handle else {
            throw AmigaDecoderError.metadataFailed("UADE playback state is closed.")
        }
        let info = try Self.readInfo(handle: handle)
        playerName = info.playerName
        formatName = info.formatName
        let moduleName = info.moduleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let song = moduleName.isEmpty || moduleName.hasPrefix("<no ")
            ? URL(fileURLWithPath: path).lastPathComponent
            : moduleName
        return TrackMetadata(
            index: index,
            song: song,
            game: "",
            author: "",
            system: systemName,
            lengthMs: info.durationMs,
            introMs: 0,
            loopMs: 0,
            playMs: info.durationMs,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}

    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        _ = vgmboy_uade_seek(handle, Int32(max(0, milliseconds)), &error)
        Self.freeError(&error)
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        guard let handle else { return ([], []) }
        var interleaved = [Int16](repeating: 0, count: frameCount * 2)
        var renderedFrames: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = interleaved.withUnsafeMutableBufferPointer {
            vgmboy_uade_read_s16(handle, Int32(frameCount), $0.baseAddress, &renderedFrames, &error)
        }
        guard result == 0 else {
            throw AmigaDecoderError.renderFailed(Self.takeError(&error))
        }
        Self.freeError(&error)
        let rendered = min(frameCount, max(0, Int(renderedFrames)))
        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        for index in 0..<rendered {
            left[index] = Float(interleaved[index * 2]) / 32768.0
            right[index] = Float(interleaved[index * 2 + 1]) / 32768.0
        }
        return (left, right)
    }

    private struct Info {
        let moduleName: String
        let formatName: String
        let playerName: String
        let minimum: Int32
        let `default`: Int32
        let maximum: Int32
        let durationMs: Int
    }

    private static func readInfo(handle: vgmboy_uade_handle_t) throws -> Info {
        var moduleName = [CChar](repeating: 0, count: 1024)
        var formatName = [CChar](repeating: 0, count: 1024)
        var playerName = [CChar](repeating: 0, count: 1024)
        var minimum: Int32 = 0
        var `default`: Int32 = 0
        var maximum: Int32 = 0
        var durationMs: Int32 = 0
        var error: UnsafeMutablePointer<CChar>?
        let result = moduleName.withUnsafeMutableBufferPointer { moduleBuffer in
            formatName.withUnsafeMutableBufferPointer { formatBuffer in
                playerName.withUnsafeMutableBufferPointer { playerBuffer in
                    vgmboy_uade_read_metadata(
                        handle,
                        moduleBuffer.baseAddress,
                        moduleBuffer.count,
                        formatBuffer.baseAddress,
                        formatBuffer.count,
                        playerBuffer.baseAddress,
                        playerBuffer.count,
                        &minimum,
                        &`default`,
                        &maximum,
                        &durationMs,
                        &error
                    )
                }
            }
        }
        guard result == 0 else {
            throw AmigaDecoderError.metadataFailed(takeError(&error))
        }
        return Info(
            moduleName: string(moduleName),
            formatName: string(formatName),
            playerName: string(playerName),
            minimum: minimum,
            default: `default`,
            maximum: maximum,
            durationMs: max(0, Int(durationMs))
        )
    }

    private static func string(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func takeError(_ error: inout UnsafeMutablePointer<CChar>?) -> String {
        let message = error.map { String(cString: $0) } ?? "Unknown UADE error."
        freeError(&error)
        return message
    }

    private static func freeError(_ error: inout UnsafeMutablePointer<CChar>?) {
        if let errorPointer = error {
            vgmboy_uade_error_message_free(errorPointer)
            error = nil
        }
    }
}

public struct VGMBoyAmigaTrackInspection: Codable, Sendable {
    public let index: Int
    public let title: String
    public let system: String
    public let player: String
    public let format: String
    public let lengthMs: Int

    public init(index: Int, title: String, system: String, player: String, format: String, lengthMs: Int) {
        self.index = index
        self.title = title
        self.system = system
        self.player = player
        self.format = format
        self.lengthMs = lengthMs
    }
}

public struct VGMBoyAmigaInspection: Codable, Sendable {
    public let trackCount: Int
    public let tracks: [VGMBoyAmigaTrackInspection]

    public init(path: String) throws {
        let decoder = try AmigaDecoder(path: path)
        defer { decoder.close() }
        var tracks: [VGMBoyAmigaTrackInspection] = []
        for index in 0..<decoder.trackCount {
            try decoder.startTrack(index)
            let metadata = try decoder.metadata(for: index)
            tracks.append(.init(
                index: index,
                title: metadata.song,
                system: metadata.system,
                player: decoder.playerName,
                format: decoder.formatName,
                lengthMs: metadata.playMs
            ))
        }
        trackCount = tracks.count
        self.tracks = tracks
    }
}
