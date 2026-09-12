import Foundation

public struct SAPTimeHint: Codable, Equatable, Sendable {
    public let milliseconds: Int
    public let loops: Bool

    public init(milliseconds: Int, loops: Bool) {
        self.milliseconds = milliseconds
        self.loops = loops
    }
}

public struct SAPTrackFacts: Codable, Equatable, Sendable {
    public let metadata: FormatMetadata
    /// SAP-native TIME is retained as a source fact. A TIME value with LOOP
    /// denotes the loop start, not a finite total play length.
    public let timeHint: SAPTimeHint?

    public init(metadata: FormatMetadata, timeHint: SAPTimeHint?) {
        self.metadata = metadata
        self.timeHint = timeHint
    }
}

public struct SAPFormatFacts: Codable, Equatable, Sendable {
    public let playerType: UInt8?
    public let trackCount: Int
    public let initAddress: UInt16?
    public let playerAddress: UInt16?
    public let musicAddress: UInt16?
    public let fastPlayScanlines: Int?
    public let isStereo: Bool
    public let game: String
    public let author: String
    public let copyright: String
    public let tracks: [SAPTrackFacts]

    public init(
        playerType: UInt8?,
        trackCount: Int,
        initAddress: UInt16?,
        playerAddress: UInt16?,
        musicAddress: UInt16?,
        fastPlayScanlines: Int?,
        isStereo: Bool,
        game: String,
        author: String,
        copyright: String,
        tracks: [SAPTrackFacts]
    ) {
        self.playerType = playerType
        self.trackCount = trackCount
        self.initAddress = initAddress
        self.playerAddress = playerAddress
        self.musicAddress = musicAddress
        self.fastPlayScanlines = fastPlayScanlines
        self.isStereo = isStereo
        self.game = game
        self.author = author
        self.copyright = copyright
        self.tracks = tracks
    }
}

/// Reads SAP's information header without constructing or starting the Atari
/// CPU/POKEY playback core. Its published metadata matches libgme's info-only
/// SAP file reader; SAP TIME hints are retained separately because LOOP marks
/// a loop start rather than a finite play duration.
public enum SAPFormatDataReader {
    public static let maximumTrackCount = 65_536
    private static let signature = Array("SAP\r\n".utf8)
    private static let maximumHeaderBytes = 1 * 1_024 * 1_024

    public static func read(data: Data, displayName: String) throws -> SAPFormatFacts {
        guard data.count >= 16, data.starts(with: signature) else {
            throw malformed("Not a SAP file with a readable information header", displayName)
        }

        var cursor = signature.count
        var foundDataMarker = false
        var playerType: UInt8?
        var trackCount = 1
        var initAddress: UInt16?
        var playerAddress: UInt16?
        var musicAddress: UInt16?
        var fastPlayScanlines: Int?
        var isStereo = false
        var game = ""
        var author = ""
        var copyright = ""
        var timeHints: [SAPTimeHint?] = []

        while cursor < data.count {
            if cursor + 1 < data.count, data[cursor] == 0xFF, data[cursor + 1] == 0xFF {
                foundDataMarker = true
                break
            }

            guard cursor < maximumHeaderBytes,
                  let carriageReturn = data[cursor...].firstIndex(of: 0x0D),
                  carriageReturn + 1 < data.count,
                  data[carriageReturn + 1] == 0x0A else {
                throw malformed("SAP header has no complete CR/LF-terminated data marker", displayName)
            }
            let headerBytes = carriageReturn + 2
            guard headerBytes <= maximumHeaderBytes else {
                throw malformed("SAP information header exceeds the scanner safety limit", displayName)
            }

            let line = Array(data[cursor..<carriageReturn])
            cursor = carriageReturn + 2
            let separator = line.firstIndex(where: { $0 <= 0x20 }) ?? line.endIndex
            let tag = Array(line[..<separator])
            var valueStart = separator
            while valueStart < line.count, line[valueStart] <= 0x20 { valueStart += 1 }
            let value = Array(line[valueStart...])

            switch String(decoding: tag, as: UTF8.self) {
            case "INIT":
                initAddress = try parseHexAddress(value, displayName: displayName, tag: "INIT")
            case "PLAYER":
                playerAddress = try parseHexAddress(value, displayName: displayName, tag: "PLAYER")
            case "MUSIC":
                musicAddress = try parseHexAddress(value, displayName: displayName, tag: "MUSIC")
            case "SONGS":
                guard let value = parsePositiveDecimal(value), value <= maximumTrackCount else {
                    throw malformed("SAP has an invalid or excessive SONGS count", displayName)
                }
                trackCount = value
            case "TYPE":
                guard let type = value.first, type == 0x42 || type == 0x43 else {
                    throw malformed("SAP player type is unsupported by the scanner", displayName)
                }
                playerType = type
            case "FASTPLAY":
                guard let value = parsePositiveDecimal(value) else {
                    throw malformed("SAP has an invalid FASTPLAY value", displayName)
                }
                fastPlayScanlines = value
            case "STEREO":
                isStereo = true
            case "AUTHOR":
                author = parseQuotedString(value)
            case "NAME":
                game = parseQuotedString(value)
            case "DATE":
                copyright = parseQuotedString(value)
            case "TIME":
                timeHints.append(parseTimeHint(value))
            default:
                break
            }
        }

        guard foundDataMarker else {
            throw malformed("SAP binary data marker is missing", displayName)
        }

        let tracks = (0..<trackCount).map { index in
            let timeHint = timeHints.indices.contains(index) ? timeHints[index] : nil
            let introLengthMs = timeHint.map { $0.loops ? $0.milliseconds : -1 } ?? -1
            let playLengthMs = timeHint.map { $0.loops ? 150_000 : $0.milliseconds } ?? 150_000
            let metadata = FormatMetadata(
                game: normalizeGMEPlaceholder(game),
                song: "",
                system: "Atari XL",
                author: normalizeGMEPlaceholder(author),
                comment: "",
                introLengthMs: introLengthMs,
                loopLengthMs: -1,
                playLengthMs: playLengthMs,
                fadeLengthMs: -1
            )
            return SAPTrackFacts(
                metadata: metadata,
                timeHint: timeHint
            )
        }

        return SAPFormatFacts(
            playerType: playerType,
            trackCount: trackCount,
            initAddress: initAddress,
            playerAddress: playerAddress,
            musicAddress: musicAddress,
            fastPlayScanlines: fastPlayScanlines,
            isStereo: isStereo,
            game: normalizeGMEPlaceholder(game),
            author: normalizeGMEPlaceholder(author),
            copyright: normalizeGMEPlaceholder(copyright),
            tracks: tracks
        )
    }

    private static func parseQuotedString(_ bytes: [UInt8]) -> String {
        guard bytes.first == 0x22,
              let closingQuote = bytes.dropFirst().firstIndex(of: 0x22) else { return "" }
        let value = Array(bytes[1..<closingQuote].prefix(255))
        let decoded = String(data: Data(value), encoding: .utf8)
            ?? String(data: Data(value), encoding: .windowsCP1252)
            ?? String(decoding: value, as: UTF8.self)
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeGMEPlaceholder(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["?", "<?>", "< ? >"].contains(normalized) ? "" : normalized
    }

    private static func parseHexAddress(_ bytes: [UInt8], displayName: String, tag: String) throws -> UInt16 {
        guard bytes.count >= 4 else {
            throw malformed("SAP has an invalid \(tag) address", displayName)
        }
        var result: UInt16 = 0
        for byte in bytes.prefix(4) {
            let digit: UInt16
            switch byte {
            case 0x30...0x39: digit = UInt16(byte - 0x30)
            case 0x41...0x46: digit = UInt16(byte - 0x41) + 10
            case 0x61...0x66: digit = UInt16(byte - 0x61) + 10
            default: throw malformed("SAP has an invalid \(tag) address", displayName)
            }
            result = result * 16 + digit
        }
        return result
    }

    private static func parsePositiveDecimal(_ bytes: [UInt8]) -> Int? {
        guard !bytes.isEmpty else { return nil }
        var value = 0
        for byte in bytes {
            guard (0x30...0x39).contains(byte) else { return nil }
            let digit = Int(byte - 0x30)
            guard value <= (Int.max - digit) / 10 else { return nil }
            value = value * 10 + digit
        }
        return value > 0 ? value : nil
    }

    private static func parseTimeHint(_ bytes: [UInt8]) -> SAPTimeHint? {
        let text = String(decoding: bytes, as: UTF8.self)
        let components = text.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count == 1 || components.count == 2,
              components.count == 1 || components[1] == "LOOP" else { return nil }
        let time = components[0].split(separator: ".", omittingEmptySubsequences: false)
        guard time.count == 1 || time.count == 2 else { return nil }
        let clock = time[0].split(separator: ":", omittingEmptySubsequences: false)
        guard clock.count == 2,
              (1...2).contains(clock[0].count),
              clock[1].count == 2,
              let minutes = Int(clock[0]),
              let seconds = Int(clock[1]),
              seconds < 60 else { return nil }

        var fractionMilliseconds = 0
        if time.count == 2 {
            let fraction = time[1]
            guard (1...3).contains(fraction.count), fraction.allSatisfy(\.isNumber),
                  let parsed = Int(fraction) else { return nil }
            fractionMilliseconds = parsed * (fraction.count == 1 ? 100 : fraction.count == 2 ? 10 : 1)
        }
        let (totalSeconds, secondsOverflow) = minutes.multipliedReportingOverflow(by: 60)
        let (withSeconds, sumOverflow) = totalSeconds.addingReportingOverflow(seconds)
        let (milliseconds, scaleOverflow) = withSeconds.multipliedReportingOverflow(by: 1_000)
        let (total, fractionOverflow) = milliseconds.addingReportingOverflow(fractionMilliseconds)
        guard !secondsOverflow, !sumOverflow, !scaleOverflow, !fractionOverflow else { return nil }
        return SAPTimeHint(milliseconds: total, loops: components.count == 2)
    }

    private static func malformed(_ message: String, _ displayName: String) -> FormatDataError {
        .malformed("\(message): \(displayName)")
    }
}
