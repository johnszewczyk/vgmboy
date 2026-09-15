import Foundation

/// Header facts for the formats whose metadata is complete before playback.
/// The numeric fields are retained so a scanner can preserve format facts
/// without asking a decoder to enumerate or time a track.
public enum GameMusicFormat: String, Codable, Sendable {
    case nsf
    case gbs
}

public struct GameMusicHeaderFacts: Codable, Equatable, Sendable {
    public let format: GameMusicFormat
    public let version: Int
    public let trackCount: Int
    public let firstTrack: Int
    public let loadAddress: UInt16
    public let initAddress: UInt16
    public let playAddress: UInt16
    public let stackAddress: UInt16?
    public let timerModulo: UInt8?
    public let timerControl: UInt8?
    public let ntscSpeedMicroseconds: UInt16?
    public let palSpeedMicroseconds: UInt16?
    public let playbackFlags: UInt8?
    public let expansionAudio: UInt8?
    public let banks: [UInt8]
    public let metadata: FormatMetadata

    public init(
        format: GameMusicFormat,
        version: Int,
        trackCount: Int,
        firstTrack: Int,
        loadAddress: UInt16,
        initAddress: UInt16,
        playAddress: UInt16,
        stackAddress: UInt16?,
        timerModulo: UInt8?,
        timerControl: UInt8?,
        ntscSpeedMicroseconds: UInt16?,
        palSpeedMicroseconds: UInt16?,
        playbackFlags: UInt8?,
        expansionAudio: UInt8?,
        banks: [UInt8],
        metadata: FormatMetadata
    ) {
        self.format = format
        self.version = version
        self.trackCount = trackCount
        self.firstTrack = firstTrack
        self.loadAddress = loadAddress
        self.initAddress = initAddress
        self.playAddress = playAddress
        self.stackAddress = stackAddress
        self.timerModulo = timerModulo
        self.timerControl = timerControl
        self.ntscSpeedMicroseconds = ntscSpeedMicroseconds
        self.palSpeedMicroseconds = palSpeedMicroseconds
        self.playbackFlags = playbackFlags
        self.expansionAudio = expansionAudio
        self.banks = banks
        self.metadata = metadata
    }
}

/// Reads NSF and GBS headers only. These formats carry file identity and the
/// complete track-count contract in their headers; authored per-track names
/// and timing are not part of either format.
///
/// The scanner-facing timing values intentionally match libgme's documented
/// information-only policy: unknown intro/loop/fade values are `-1`, and a
/// format without a positive authored length uses the 150-second fallback.
/// This preserves the existing decoder-derived catalog contract without
/// starting playback or emulation.
public enum GameMusicFormatDataReader {
    public static func read(
        data: Data,
        pathExtension: String,
        displayName: String
    ) throws -> GameMusicHeaderFacts? {
        switch pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased() {
        case "nsf":
            return try readNSF(data, displayName: displayName)
        case "gbs":
            return try readGBS(data, displayName: displayName)
        default:
            return nil
        }
    }

    private static func readNSF(_ data: Data, displayName: String) throws -> GameMusicHeaderFacts {
        guard data.count >= 0x80, data.prefix(5) == Data([0x4E, 0x45, 0x53, 0x4D, 0x1A]) else {
            throw FormatDataError.malformed("Not an NSF file with a valid header: \(displayName)")
        }
        let version = Int(data[0x05])
        let trackCount = Int(data[0x06])
        guard version > 0, trackCount > 0 else {
            throw FormatDataError.malformed("NSF has no usable version or tracks: \(displayName)")
        }

        let metadata = FormatMetadata(
            game: text(data[0x0E..<0x2E]),
            song: "",
            system: "Nintendo NES",
            author: text(data[0x2E..<0x4E]),
            comment: text(data[0x4E..<0x6E]),
            introLengthMs: -1,
            loopLengthMs: -1,
            playLengthMs: 150_000,
            fadeLengthMs: -1
        )
        return GameMusicHeaderFacts(
            format: .nsf,
            version: version,
            trackCount: trackCount,
            firstTrack: Int(data[0x07]),
            loadAddress: littleEndianUInt16(data, at: 0x08),
            initAddress: littleEndianUInt16(data, at: 0x0A),
            playAddress: littleEndianUInt16(data, at: 0x0C),
            stackAddress: nil,
            timerModulo: nil,
            timerControl: nil,
            ntscSpeedMicroseconds: littleEndianUInt16(data, at: 0x6E),
            palSpeedMicroseconds: littleEndianUInt16(data, at: 0x78),
            playbackFlags: data[0x7A],
            expansionAudio: data[0x7B],
            banks: Array(data[0x70..<0x78]),
            metadata: metadata
        )
    }

    private static func readGBS(_ data: Data, displayName: String) throws -> GameMusicHeaderFacts {
        guard data.count >= 0x70, data.prefix(3) == Data("GBS".utf8) else {
            throw FormatDataError.malformed("Not a GBS file with a valid header: \(displayName)")
        }
        let version = Int(data[0x03])
        let trackCount = Int(data[0x04])
        guard version > 0, trackCount > 0 else {
            throw FormatDataError.malformed("GBS has no usable version or tracks: \(displayName)")
        }

        let metadata = FormatMetadata(
            game: text(data[0x10..<0x30]),
            song: "",
            system: "Nintendo Game Boy",
            author: text(data[0x30..<0x50]),
            comment: text(data[0x50..<0x70]),
            introLengthMs: -1,
            loopLengthMs: -1,
            playLengthMs: 150_000,
            fadeLengthMs: -1
        )
        return GameMusicHeaderFacts(
            format: .gbs,
            version: version,
            trackCount: trackCount,
            firstTrack: Int(data[0x05]),
            loadAddress: littleEndianUInt16(data, at: 0x06),
            initAddress: littleEndianUInt16(data, at: 0x08),
            playAddress: littleEndianUInt16(data, at: 0x0A),
            stackAddress: littleEndianUInt16(data, at: 0x0C),
            timerModulo: data[0x0E],
            timerControl: data[0x0F],
            ntscSpeedMicroseconds: nil,
            palSpeedMicroseconds: nil,
            playbackFlags: nil,
            expansionAudio: nil,
            banks: [],
            metadata: metadata
        )
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func text(_ bytes: Data.SubSequence) -> String {
        let bytes = Data(bytes.prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
