import Foundation

public struct NSFEOptionalChunk: Codable, Equatable, Sendable {
    public let identifier: String
    public let data: Data

    public init(identifier: String, data: Data) {
        self.identifier = identifier
        self.data = data
    }
}

public struct NSFETrackFacts: Codable, Equatable, Sendable {
    public let sourceTrackIndex: Int
    public let title: String
    public let author: String
    /// The raw signed NSFE `time` value. Negative means the format default.
    public let timeMs: Int32?
    /// The raw signed NSFE `fade` value. Negative means the format default.
    public let fadeMs: Int32?
    public let metadata: FormatMetadata

    public init(
        sourceTrackIndex: Int,
        title: String,
        author: String,
        timeMs: Int32?,
        fadeMs: Int32?,
        metadata: FormatMetadata
    ) {
        self.sourceTrackIndex = sourceTrackIndex
        self.title = title
        self.author = author
        self.timeMs = timeMs
        self.fadeMs = fadeMs
        self.metadata = metadata
    }
}

public struct NSFEFileFacts: Codable, Equatable, Sendable {
    public let loadAddress: UInt16
    public let initAddress: UInt16
    public let playAddress: UInt16
    public let regionFlags: UInt8
    public let expansionChipFlags: UInt8
    public let trackCount: Int
    public let firstTrack: Int
    public let banks: [UInt8]
    public let ntscSpeedMicroseconds: UInt16?
    public let palSpeedMicroseconds: UInt16?
    public let dendySpeedMicroseconds: UInt16?
    public let regionOverrideFlags: UInt8?
    public let preferredRegion: UInt8?
    public let nsf2Flags: UInt8?
    public let vrc7Variant: UInt8?
    public let vrc7PatchSet: Data
    public let gameTitle: String
    public let artist: String
    public let copyright: String
    public let ripper: String
    public let notes: String
    public let playlist: [Int]
    public let soundEffectTracks: [Int]
    /// Source-order facts. The visible order is `orderedTracks`, which applies
    /// the optional NSFE playlist without losing the source track identity.
    public let tracks: [NSFETrackFacts]
    public let dataByteCount: Int
    public let optionalChunks: [NSFEOptionalChunk]

    public init(
        loadAddress: UInt16,
        initAddress: UInt16,
        playAddress: UInt16,
        regionFlags: UInt8,
        expansionChipFlags: UInt8,
        trackCount: Int,
        firstTrack: Int,
        banks: [UInt8],
        ntscSpeedMicroseconds: UInt16?,
        palSpeedMicroseconds: UInt16?,
        dendySpeedMicroseconds: UInt16?,
        regionOverrideFlags: UInt8?,
        preferredRegion: UInt8?,
        nsf2Flags: UInt8?,
        vrc7Variant: UInt8?,
        vrc7PatchSet: Data,
        gameTitle: String,
        artist: String,
        copyright: String,
        ripper: String,
        notes: String,
        playlist: [Int],
        soundEffectTracks: [Int],
        tracks: [NSFETrackFacts],
        dataByteCount: Int,
        optionalChunks: [NSFEOptionalChunk]
    ) {
        self.loadAddress = loadAddress
        self.initAddress = initAddress
        self.playAddress = playAddress
        self.regionFlags = regionFlags
        self.expansionChipFlags = expansionChipFlags
        self.trackCount = trackCount
        self.firstTrack = firstTrack
        self.banks = banks
        self.ntscSpeedMicroseconds = ntscSpeedMicroseconds
        self.palSpeedMicroseconds = palSpeedMicroseconds
        self.dendySpeedMicroseconds = dendySpeedMicroseconds
        self.regionOverrideFlags = regionOverrideFlags
        self.preferredRegion = preferredRegion
        self.nsf2Flags = nsf2Flags
        self.vrc7Variant = vrc7Variant
        self.vrc7PatchSet = vrc7PatchSet
        self.gameTitle = gameTitle
        self.artist = artist
        self.copyright = copyright
        self.ripper = ripper
        self.notes = notes
        self.playlist = playlist
        self.soundEffectTracks = soundEffectTracks
        self.tracks = tracks
        self.dataByteCount = dataByteCount
        self.optionalChunks = optionalChunks
    }

    public var orderedTracks: [NSFETrackFacts] {
        let order = playlist.isEmpty ? Array(0..<tracks.count) : playlist
        return order.compactMap { index in
            tracks.indices.contains(index) ? tracks[index] : nil
        }
    }
}

/// Foundation-only NSFE metadata and structure reader.
///
/// NSFE metadata is chunked around an NSF data payload. This reader never
/// executes the payload; it validates the mandatory structure and harvests
/// the complete scanner-facing metadata contract, including playlist order,
/// per-track labels/authors, authored times/fades, and optional identity data.
public enum NSFEFormatDataReader {
    private static let gmeDefaultPlayLengthMs = 150_000

    public static func read(data: Data, displayName: String) throws -> NSFEFileFacts {
        let bytes = Array(data)
        guard bytes.count >= 4, bytes[0..<4].elementsEqual([0x4E, 0x53, 0x46, 0x45]) else {
            throw malformed("Not an NSFE file with a valid header: \(displayName)")
        }

        var offset = 4
        var info: Info?
        var dataByteCount: Int?
        var sawNEND = false
        var auth: [String] = []
        var labels: [String] = []
        var authors: [String] = []
        var times: [Int32] = []
        var fades: [Int32] = []
        var playlist: [Int] = []
        var soundEffects: [Int] = []
        var banks = [UInt8](repeating: 0, count: 8)
        var ntscRate: UInt16?
        var palRate: UInt16?
        var dendyRate: UInt16?
        var regionOverride: UInt8?
        var preferredRegion: UInt8?
        var nsf2Flags: UInt8?
        var vrc7Variant: UInt8?
        var vrc7PatchSet = Data()
        var notes = ""
        var optionalChunks: [NSFEOptionalChunk] = []

        while offset < bytes.count {
            guard bytes.count - offset >= 8 else {
                throw malformed("NSFE has a truncated chunk header: \(displayName)")
            }
            let length = UInt64(readUInt32(bytes, at: offset))
            let payloadStart = offset + 8
            guard length <= UInt64(bytes.count - payloadStart) else {
                throw malformed("NSFE chunk exceeds the file boundary: \(displayName)")
            }
            let payloadLength = Int(length)
            let payload = Array(bytes[payloadStart..<(payloadStart + payloadLength)])
            let identifier = String(decoding: bytes[(offset + 4)..<(offset + 8)], as: UTF8.self)
            offset = payloadStart + payloadLength

            switch identifier {
            case "INFO":
                guard info == nil, dataByteCount == nil else {
                    throw malformed("NSFE INFO chunk is duplicated or appears after DATA: \(displayName)")
                }
                info = try parseInfo(payload, displayName: displayName)
            case "DATA":
                guard info != nil, dataByteCount == nil else {
                    throw malformed("NSFE DATA chunk is out of order or duplicated: \(displayName)")
                }
                dataByteCount = payload.count
            case "NEND":
                guard info != nil, dataByteCount != nil else {
                    throw malformed("NSFE NEND appears before INFO/DATA: \(displayName)")
                }
                sawNEND = true
                offset = bytes.count
            case "BANK":
                for index in 0..<min(payload.count, banks.count) {
                    banks[index] = payload[index]
                }
            case "auth":
                auth = strings(in: payload)
            case "time":
                times = signedMilliseconds(in: payload)
            case "fade":
                fades = signedMilliseconds(in: payload)
            case "tlbl":
                labels = strings(in: payload)
            case "taut":
                authors = strings(in: payload)
            case "plst":
                playlist = payload.map(Int.init)
            case "psfx":
                soundEffects = payload.map(Int.init)
            case "text":
                notes = strings(in: payload).first ?? ""
            case "RATE":
                (ntscRate, palRate, dendyRate) = parseRates(payload)
            case "regn":
                regionOverride = payload.first
                preferredRegion = payload.dropFirst().first
            case "NSF2":
                guard let value = payload.first else {
                    throw malformed("NSFE NSF2 chunk is empty: \(displayName)")
                }
                nsf2Flags = value
            case "VRC7":
                guard let variant = payload.first else {
                    throw malformed("NSFE VRC7 chunk is empty: \(displayName)")
                }
                vrc7Variant = variant
                vrc7PatchSet = Data(payload.dropFirst())
            default:
                guard identifier.utf8.first.map({ !isUppercaseASCII($0) }) == true else {
                    throw malformed("Unsupported mandatory NSFE chunk \(identifier): \(displayName)")
                }
                optionalChunks.append(NSFEOptionalChunk(identifier: identifier, data: Data(payload)))
            }
        }

        guard let info, let dataByteCount, sawNEND else {
            throw malformed("NSFE is missing a required INFO, DATA, or NEND chunk: \(displayName)")
        }

        let actualPlaylist = playlist.isEmpty ? Array(0..<info.trackCount) : playlist
        try validateTrackReferences(actualPlaylist, trackCount: info.trackCount, name: "PLST", displayName: displayName)
        try validateTrackReferences(soundEffects, trackCount: info.trackCount, name: "PSFX", displayName: displayName)

        let gameTitle = auth[safe: 0] ?? ""
        let artist = auth[safe: 1] ?? ""
        let copyright = auth[safe: 2] ?? ""
        let ripper = auth[safe: 3] ?? ""
        let comment = comment(copyright: copyright, ripper: ripper, notes: notes)
        let tracks = (0..<info.trackCount).map { sourceIndex in
            let title = labels[safe: sourceIndex] ?? ""
            let trackAuthor = authors[safe: sourceIndex] ?? ""
            let time = times[safe: sourceIndex]
            let fade = fades[safe: sourceIndex]
            let metadata = FormatMetadata(
                game: gameTitle,
                song: title,
                system: "Nintendo NES",
                author: trackAuthor.isEmpty ? artist : trackAuthor,
                comment: comment,
                introLengthMs: -1,
                loopLengthMs: -1,
                playLengthMs: playLength(for: time),
                fadeLengthMs: fadeLength(for: fade)
            )
            return NSFETrackFacts(
                sourceTrackIndex: sourceIndex,
                title: title,
                author: trackAuthor,
                timeMs: time,
                fadeMs: fade,
                metadata: metadata
            )
        }

        return NSFEFileFacts(
            loadAddress: info.loadAddress,
            initAddress: info.initAddress,
            playAddress: info.playAddress,
            regionFlags: info.regionFlags,
            expansionChipFlags: info.expansionChipFlags,
            trackCount: info.trackCount,
            firstTrack: info.firstTrack,
            banks: banks,
            ntscSpeedMicroseconds: ntscRate,
            palSpeedMicroseconds: palRate,
            dendySpeedMicroseconds: dendyRate,
            regionOverrideFlags: regionOverride,
            preferredRegion: preferredRegion,
            nsf2Flags: nsf2Flags,
            vrc7Variant: vrc7Variant,
            vrc7PatchSet: vrc7PatchSet,
            gameTitle: gameTitle,
            artist: artist,
            copyright: copyright,
            ripper: ripper,
            notes: notes,
            playlist: playlist,
            soundEffectTracks: soundEffects,
            tracks: tracks,
            dataByteCount: dataByteCount,
            optionalChunks: optionalChunks
        )
    }

    private struct Info {
        let loadAddress: UInt16
        let initAddress: UInt16
        let playAddress: UInt16
        let regionFlags: UInt8
        let expansionChipFlags: UInt8
        let trackCount: Int
        let firstTrack: Int
    }

    private static func parseInfo(_ payload: [UInt8], displayName: String) throws -> Info {
        // libgme historically accepts the eight-byte prefix and supplies the
        // count/start defaults. The NSFe specification requires nine bytes;
        // accepting the compatible prefix avoids regressing files the old
        // scanner could inspect while exposing the supplied facts exactly.
        guard payload.count >= 8 else {
            throw malformed("NSFE INFO chunk is too short: \(displayName)")
        }
        let trackCount = payload.count >= 9 ? Int(payload[8]) : 1
        let firstTrack = payload.count >= 10 ? Int(payload[9]) : 0
        guard trackCount > 0 else {
            throw malformed("NSFE INFO chunk declares no tracks: \(displayName)")
        }
        return Info(
            loadAddress: littleEndianUInt16(payload, at: 0),
            initAddress: littleEndianUInt16(payload, at: 2),
            playAddress: littleEndianUInt16(payload, at: 4),
            regionFlags: payload[6],
            expansionChipFlags: payload[7],
            trackCount: trackCount,
            firstTrack: firstTrack
        )
    }

    private static func parseRates(_ payload: [UInt8]) -> (UInt16?, UInt16?, UInt16?) {
        (
            payload.count >= 2 ? littleEndianUInt16(payload, at: 0) : nil,
            payload.count >= 4 ? littleEndianUInt16(payload, at: 2) : nil,
            payload.count >= 6 ? littleEndianUInt16(payload, at: 4) : nil
        )
    }

    private static func signedMilliseconds(in payload: [UInt8]) -> [Int32] {
        stride(from: 0, through: payload.count - 4, by: 4).map { offset in
            Int32(bitPattern: readUInt32(payload, at: offset))
        }
    }

    private static func strings(in payload: [UInt8]) -> [String] {
        guard !payload.isEmpty else { return [] }
        var result: [String] = []
        var start = 0
        for index in payload.indices where payload[index] == 0 {
            result.append(decodeText(payload[start..<index]))
            start = index + 1
        }
        if start < payload.count {
            result.append(decodeText(payload[start..<payload.count]))
        }
        return result
    }

    private static func decodeText<S: Collection>(_ bytes: S) -> String where S.Element == UInt8 {
        let data = Data(bytes)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? ""
    }

    private static func validateTrackReferences(
        _ references: [Int],
        trackCount: Int,
        name: String,
        displayName: String
    ) throws {
        guard references.allSatisfy({ $0 >= 0 && $0 < trackCount }) else {
            throw malformed("NSFE \(name) references a track outside INFO: \(displayName)")
        }
    }

    private static func playLength(for time: Int32?) -> Int {
        guard let time, time > 0 else { return gmeDefaultPlayLengthMs }
        return Int(time)
    }

    private static func fadeLength(for fade: Int32?) -> Int {
        guard let fade, fade >= 0 else { return -1 }
        return Int(fade)
    }

    private static func comment(copyright: String, ripper: String, notes: String) -> String {
        [
            copyright.isEmpty ? nil : "Copyright: \(copyright)",
            ripper.isEmpty ? nil : "Ripped by: \(ripper)",
            notes.isEmpty ? nil : notes
        ].compactMap { $0 }.joined(separator: "\n")
    }

    private static func littleEndianUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private static func isUppercaseASCII(_ byte: UInt8) -> Bool {
        byte >= 0x41 && byte <= 0x5A
    }

    private static func malformed(_ message: String) -> FormatDataError {
        .malformed(message)
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
