import Foundation

public struct HESTrackFacts: Codable, Equatable, Sendable {
    /// The HES address slot selected by the playlist; row order remains the
    /// track index published by the scanner.
    public let sourceTrackIndex: Int
    public let metadata: FormatMetadata

    public init(sourceTrackIndex: Int, metadata: FormatMetadata) {
        self.sourceTrackIndex = sourceTrackIndex
        self.metadata = metadata
    }
}

public struct HESFormatFacts: Codable, Equatable, Sendable {
    public let version: Int
    public let firstTrack: Int
    public let initAddress: UInt16
    public let banks: [UInt8]
    public let dataChunkTag: String
    public let dataChunkSize: UInt32
    public let dataAddress: UInt32
    public let hasPlaylist: Bool
    public let tracks: [HESTrackFacts]

    public var trackCount: Int { tracks.count }

    public init(
        version: Int,
        firstTrack: Int,
        initAddress: UInt16,
        banks: [UInt8],
        dataChunkTag: String,
        dataChunkSize: UInt32,
        dataAddress: UInt32,
        hasPlaylist: Bool,
        tracks: [HESTrackFacts]
    ) {
        self.version = version
        self.firstTrack = firstTrack
        self.initAddress = initAddress
        self.banks = banks
        self.dataChunkTag = dataChunkTag
        self.dataChunkSize = dataChunkSize
        self.dataAddress = dataAddress
        self.hasPlaylist = hasPlaylist
        self.tracks = tracks
    }
}

/// Reads HES file tags and the companion libgme extended-M3U catalog without
/// loading the PC Engine emulator. HES has no authored track count; absent an
/// M3U, the reader preserves libgme's 256-slot compatibility listing.
public enum HESFormatDataReader {
    public static let compatibilityTrackCount = 256

    private static let minimumInfoSize = 0xD0
    private static let metadataOffset = 0x40
    private static let playlistByteLimit = 4 * 1024 * 1024
    private static let playlistTrackLimit = 65_536

    public static func read(
        data: Data,
        playlistData: Data? = nil,
        displayName: String
    ) throws -> HESFormatFacts {
        guard data.count >= minimumInfoSize, data.prefix(4) == Data("HESM".utf8) else {
            throw FormatDataError.malformed("Not a HES file with a readable information header: \(displayName)")
        }

        let headerTags = readHeaderTags(data)
        let headerMetadata = FormatMetadata(
            game: headerTags.game,
            song: "",
            system: "PC Engine",
            author: headerTags.author,
            comment: "",
            introLengthMs: -1,
            loopLengthMs: -1,
            playLengthMs: 150_000,
            fadeLengthMs: -1
        )

        let hasPlaylist = playlistData != nil
        let tracks: [HESTrackFacts]
        if let playlistData {
            let playlist = try parsePlaylist(playlistData, displayName: displayName)
            let game = playlist.game.isEmpty ? headerTags.game : playlist.game
            let author = playlist.artist.isEmpty ? headerTags.author : playlist.artist
            tracks = try playlist.entries.map { entry in
                guard entry.sourceTrackIndex < compatibilityTrackCount else {
                    throw FormatDataError.malformed(
                        "HES playlist track \(entry.sourceTrackIndex) is outside the 0-255 address range: \(displayName)"
                    )
                }
                let metadata = FormatMetadata(
                    game: game,
                    song: entry.song,
                    system: "PC Engine",
                    author: author,
                    comment: "",
                    introLengthMs: entry.introLengthMs,
                    loopLengthMs: entry.loopLengthMs,
                    playLengthMs: entry.playLengthMs,
                    fadeLengthMs: entry.fadeLengthMs
                )
                return HESTrackFacts(sourceTrackIndex: entry.sourceTrackIndex, metadata: metadata)
            }
        } else {
            tracks = (0..<compatibilityTrackCount).map { index in
                HESTrackFacts(sourceTrackIndex: index, metadata: headerMetadata)
            }
        }

        return HESFormatFacts(
            version: Int(data[4]),
            firstTrack: Int(data[5]),
            initAddress: littleEndianUInt16(data, at: 6),
            banks: Array(data[8..<16]),
            dataChunkTag: String(decoding: data[16..<20], as: UTF8.self),
            dataChunkSize: littleEndianUInt32(data, at: 20),
            dataAddress: littleEndianUInt32(data, at: 24),
            hasPlaylist: hasPlaylist,
            tracks: tracks
        )
    }

    private static func readHeaderTags(_ data: Data) -> (game: String, author: String, copyright: String) {
        guard data[metadataOffset] >= 0x20 else { return ("", "", "") }
        var offset = metadataOffset
        var values: [String] = []
        for _ in 0..<3 {
            guard let field = readHeaderField(data, at: offset) else {
                values.append(contentsOf: repeatElement("", count: 3 - values.count))
                break
            }
            values.append(field.text)
            offset += field.length
        }
        while values.count < 3 { values.append("") }
        return (values[0], values[1], values[2])
    }

    private static func readHeaderField(_ data: Data, at offset: Int) -> (text: String, length: Int)? {
        guard offset + 0x30 <= data.count else { return nil }
        let length = data[offset + 0x1F] != 0 && data[offset + 0x2F] == 0 ? 0x30 : 0x20
        let bytes = Array(data[offset..<(offset + length)])
        var textBytes: [UInt8] = []
        var foundTerminator = false
        for byte in bytes {
            if byte == 0 {
                foundTerminator = true
                continue
            }
            if foundTerminator || byte < 0x20 || byte == 0xFF { return nil }
            textBytes.append(byte)
        }
        return (cleanGMEText(textBytes), length)
    }

    private struct PlaylistEntry {
        let sourceTrackIndex: Int
        let song: String
        let introLengthMs: Int
        let loopLengthMs: Int
        let playLengthMs: Int
        let fadeLengthMs: Int
    }

    private struct Playlist {
        var entries: [PlaylistEntry] = []
        var game = ""
        var artist = ""
        var hasExtendedIdentity = false
    }

    private static func parsePlaylist(_ data: Data, displayName: String) throws -> Playlist {
        guard data.count <= playlistByteLimit,
              !data.contains(0),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .windowsCP1252) else {
            throw FormatDataError.malformed("HES companion M3U is invalid or too large: \(displayName)")
        }

        var playlist = Playlist()
        var firstComment = true
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : String(rawLine)
            if line.first == "#" {
                parseComment(line, first: firstComment, into: &playlist)
                firstComment = false
            } else if !line.isEmpty {
                if let entry = parseEntry(line) {
                    guard entry.sourceTrackIndex < compatibilityTrackCount else {
                        throw FormatDataError.malformed(
                            "HES playlist references an address outside 0-255: \(displayName)"
                        )
                    }
                    playlist.entries.append(entry)
                    guard playlist.entries.count <= playlistTrackLimit else {
                        throw FormatDataError.malformed("HES companion M3U has too many tracks: \(displayName)")
                    }
                }
                firstComment = false
            }
        }

        guard !playlist.entries.isEmpty else {
            throw FormatDataError.malformed("HES companion M3U has no usable tracks: \(displayName)")
        }
        if !playlist.hasExtendedIdentity { playlist.game = "" }
        return playlist
    }

    private static func parseComment(_ line: String, first: Bool, into playlist: inout Playlist) {
        let content = line.dropFirst().drop(while: { $0 == " " })
        if content.first == "@" {
            let tagAndValue = content.dropFirst().split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
            guard tagAndValue.count == 2 else { return }
            let key = String(tagAndValue[0])
            let value = cleanGMEText(Array(tagAndValue[1].utf8))
            guard !value.isEmpty else { return }
            switch key {
            case "TITLE": playlist.game = value
            case "ARTIST": playlist.artist = value
            case "COMPOSER", "ENGINEER", "RIPPER", "TAGGER": playlist.hasExtendedIdentity = true
            default: break
            }
            return
        }

        guard let colon = content.firstIndex(of: ":") else {
            if first { playlist.game = cleanGMEText(Array(content.utf8)) }
            return
        }
        let key = String(content[..<colon])
        let value = cleanGMEText(Array(content[content.index(after: colon)...].utf8))
        guard !value.isEmpty else { return }
        switch key {
        case "Game": playlist.game = value
        case "Artist": playlist.artist = value
        case "Composer", "Engineer", "Ripping", "Tagging": playlist.hasExtendedIdentity = true
        default: break
        }
    }

    private static func parseEntry(_ line: String) -> PlaylistEntry? {
        let bytes = Array(line.utf8)
        guard let separator = trackSeparator(in: bytes) else {
            // libgme accepts a bare playlist line as a track with no authored
            // title or timing and maps it to HES address zero.
            return PlaylistEntry(
                sourceTrackIndex: 0,
                song: "",
                introLengthMs: -1,
                loopLengthMs: -1,
                playLengthMs: 150_000,
                fadeLengthMs: -1
            )
        }

        var cursor = skipSpaces(bytes, from: separator + 1)
        var sourceTrackIndex = 0
        if cursor < bytes.count, bytes[cursor] == 0x24 {
            cursor += 1
            var value = 0
            var digits = 0
            while cursor < bytes.count, let digit = hexDigit(bytes[cursor]) {
                guard value <= (Int.max - digit) / 16 else { return nil }
                value = value * 16 + digit
                digits += 1
                cursor += 1
            }
            if digits > 0 { sourceTrackIndex = value }
        } else {
            guard let decimal = parseUnsignedInteger(bytes, from: cursor) else { return nil }
            sourceTrackIndex = decimal.value == 0 ? -1 : decimal.value - 1
            cursor = decimal.end
        }

        cursor = skipSpaces(bytes, from: cursor)
        if cursor < bytes.count {
            guard bytes[cursor] == 0x2C else { return nil }
            cursor = skipSpaces(bytes, from: cursor + 1)
        }

        let name = parseName(bytes, from: cursor)
        cursor = name.end
        let length = parseTime(bytes, from: cursor)
        cursor = skipToNextField(bytes, from: length.end)

        var intro = -1
        var loop = -1
        if cursor < bytes.count, bytes[cursor] == 0x2D {
            loop = length.value ?? -1
            cursor += 1
        } else {
            let loopValue = parseTime(bytes, from: cursor)
            cursor = loopValue.end
            if let loopMilliseconds = loopValue.value {
                intro = 0
                loop = loopMilliseconds
                if cursor < bytes.count, bytes[cursor] == 0x2D {
                    intro = loop
                    loop = (length.value ?? -1) - intro
                    cursor += 1
                }
            }
        }
        cursor = skipToNextField(bytes, from: cursor)
        let fade = parseTime(bytes, from: cursor)

        let playLength: Int
        if let lengthMs = length.value, lengthMs > 0 {
            playLength = lengthMs
        } else {
            let (twiceLoop, loopOverflow) = loop.multipliedReportingOverflow(by: 2)
            let (inferred, inferredOverflow) = intro.addingReportingOverflow(twiceLoop)
            playLength = !loopOverflow && !inferredOverflow && inferred > 0 ? inferred : 150_000
        }

        return PlaylistEntry(
            sourceTrackIndex: sourceTrackIndex,
            song: cleanGMEText(name.bytes),
            introLengthMs: intro,
            loopLengthMs: loop,
            playLengthMs: playLength,
            fadeLengthMs: fade.value ?? -1
        )
    }

    private static func trackSeparator(in bytes: [UInt8]) -> Int? {
        for index in bytes.indices where bytes[index] == 0x2C {
            var slashCount = 0
            var previous = index
            while previous > 0, bytes[previous - 1] == 0x5C {
                slashCount += 1
                previous -= 1
            }
            if slashCount % 2 == 1 { continue }
            let next = skipSpaces(bytes, from: index + 1)
            guard next < bytes.count else { continue }
            if bytes[next] == 0x24 || isDecimal(bytes[next]) { return index }
        }
        return nil
    }

    private static func parseName(_ bytes: [UInt8], from start: Int) -> (bytes: [UInt8], end: Int) {
        var result: [UInt8] = []
        var cursor = start
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if byte == 0x5C, cursor + 1 < bytes.count {
                result.append(bytes[cursor + 1])
                cursor += 2
                continue
            }
            if byte == 0x2C {
                let next = skipSpaces(bytes, from: cursor + 1)
                if next < bytes.count,
                   (bytes[next] == 0x2C || bytes[next] == 0x2D || isDecimal(bytes[next])) {
                    return (result, next)
                }
            }
            result.append(byte)
            cursor += 1
        }
        return (result, cursor)
    }

    private static func parseTime(_ bytes: [UInt8], from start: Int) -> (value: Int?, end: Int) {
        var cursor = start
        guard let first = parseUnsignedInteger(bytes, from: cursor) else { return (nil, start) }
        var seconds = Int64(first.value)
        cursor = first.end
        while cursor < bytes.count, bytes[cursor] == 0x3A {
            guard let component = parseUnsignedInteger(bytes, from: cursor + 1) else { break }
            let (scaled, scaleOverflow) = seconds.multipliedReportingOverflow(by: 60)
            let (sum, sumOverflow) = scaled.addingReportingOverflow(Int64(component.value))
            guard !scaleOverflow, !sumOverflow else { return (nil, cursor) }
            seconds = sum
            cursor = component.end
        }

        let (milliseconds, overflow) = seconds.multipliedReportingOverflow(by: 1_000)
        guard !overflow else { return (nil, cursor) }
        var result = milliseconds
        if cursor < bytes.count, bytes[cursor] == 0x2E {
            var fractionCursor = cursor + 1
            var fraction = 0
            var digits = 0
            while fractionCursor < bytes.count, digits < 3, isDecimal(bytes[fractionCursor]) {
                fraction = fraction * 10 + Int(bytes[fractionCursor] - 0x30)
                fractionCursor += 1
                digits += 1
            }
            if digits == 1 { fraction *= 100 }
            if digits == 2 { fraction *= 10 }
            let (fractionalResult, fractionOverflow) = result.addingReportingOverflow(Int64(fraction))
            guard !fractionOverflow else { return (nil, fractionCursor) }
            result = fractionalResult
            cursor = fractionCursor
        }
        guard result <= Int64(Int.max) else { return (nil, cursor) }
        return (Int(result), cursor)
    }

    private static func parseUnsignedInteger(_ bytes: [UInt8], from start: Int) -> (value: Int, end: Int)? {
        var cursor = start
        var value = 0
        var found = false
        while cursor < bytes.count, isDecimal(bytes[cursor]) {
            let digit = Int(bytes[cursor] - 0x30)
            guard value <= (Int.max - digit) / 10 else { return nil }
            value = value * 10 + digit
            cursor += 1
            found = true
        }
        return found ? (value, cursor) : nil
    }

    private static func skipToNextField(_ bytes: [UInt8], from start: Int) -> Int {
        var cursor = skipSpaces(bytes, from: start)
        while cursor < bytes.count, bytes[cursor] != 0x2C { cursor += 1 }
        if cursor < bytes.count { cursor += 1 }
        return skipSpaces(bytes, from: cursor)
    }

    private static func skipSpaces(_ bytes: [UInt8], from start: Int) -> Int {
        var cursor = start
        while cursor < bytes.count, bytes[cursor] == 0x20 { cursor += 1 }
        return cursor
    }

    private static func isDecimal(_ byte: UInt8) -> Bool { (0x30...0x39).contains(byte) }

    private static func hexDigit(_ byte: UInt8) -> Int? {
        switch byte {
        case 0x30...0x39: Int(byte - 0x30)
        case 0x41...0x46: Int(byte - 0x41) + 10
        case 0x61...0x66: Int(byte - 0x61) + 10
        default: nil
        }
    }

    private static func cleanGMEText(_ bytes: [UInt8]) -> String {
        let terminator = bytes.firstIndex(of: 0) ?? bytes.endIndex
        var start = bytes.startIndex
        var end = terminator
        while start < end, bytes[start] <= 0x20 { start += 1 }
        while end > start, bytes[end - 1] <= 0x20 { end -= 1 }
        let boundedEnd = min(end, start + 255)
        let textBytes = Array(bytes[start..<boundedEnd])
        let value = String(data: Data(textBytes), encoding: .utf8)
            ?? String(data: Data(textBytes), encoding: .windowsCP1252)
            ?? String(decoding: textBytes, as: UTF8.self)
        if ["?", "<?>", "< ? >"].contains(value) { return "" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
