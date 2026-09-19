import Foundation

/// Reads the variable-length SAP information header and its ordered TIME
/// directives without running an Atari CPU or POKEY playback core.
enum SAPMetadataReader {
    private static let signature = Array("SAP\r\n".utf8)
    private static let maximumHeaderBytes = 1 * 1_024 * 1_024
    private static let maximumTrackCount = 32
    private static let defaultPlayLengthMs = 150_000

    private struct TimeHint {
        let milliseconds: Int
        let loops: Bool
    }

    private struct Directive {
        let name: String
        let value: String
        let lineNumber: Int
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= signature.count && data.prefix(signature.count).elementsEqual(signature)
    }

    static func readResult(data: Data, displayName: String?) throws -> MetadataReadResult {
        let name = displayName ?? "SAP source"
        guard data.count >= 16, matches(data) else {
            throw malformed("Not a SAP file with a readable information header", name)
        }

        var cursor = signature.count
        var markerOffset: Int?
        var directives: [Directive] = []
        while cursor < data.count {
            if data.count - cursor >= 2, data[cursor] == 0xFF, data[cursor + 1] == 0xFF {
                markerOffset = cursor
                break
            }

            guard cursor < maximumHeaderBytes else {
                throw malformed("SAP information header exceeds the scanner safety limit", name)
            }
            let searchEnd = min(data.count, maximumHeaderBytes)
            guard cursor < searchEnd,
                  let carriageReturn = data[cursor..<searchEnd].firstIndex(of: 0x0D),
                  carriageReturn + 1 < data.count,
                  data[carriageReturn + 1] == 0x0A else {
                throw malformed("SAP header has no complete CR/LF-terminated data marker", name)
            }
            let nextLine = carriageReturn + 2
            guard nextLine <= maximumHeaderBytes else {
                throw malformed("SAP information header exceeds the scanner safety limit", name)
            }

            let line = Array(data[cursor..<carriageReturn])
            cursor = nextLine
            let separator = line.firstIndex(where: { $0 <= 0x20 }) ?? line.endIndex
            let tagBytes = line[..<separator]
            let valueStart = line[separator...].firstIndex(where: { $0 > 0x20 }) ?? line.endIndex
            let tag = String(decoding: tagBytes, as: UTF8.self)
            let rawValue = Array(line[valueStart...])
            directives.append(Directive(
                name: tag,
                value: directiveValue(name: tag, bytes: rawValue),
                lineNumber: directives.count + 1
            ))
        }

        guard let markerOffset else {
            throw malformed("SAP binary data marker is missing", name)
        }

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
        var timeHints: [TimeHint?] = []
        var diagnostics: [String] = []
        var technicalFacts: [String: String] = [
            "dataMarkerOffset": String(markerOffset),
            "headerByteCount": String(markerOffset + 2),
            "headerDirectiveCount": String(directives.count)
        ]
        var tags: [MetadataTag] = []

        for directive in directives {
            let valueBytes = Array(directive.value.utf8)
            tags.append(MetadataTag(name: directive.name, value: directive.value))
            switch directive.name {
            case "INIT":
                initAddress = try parseHexAddress(valueBytes, displayName: name, tag: "INIT")
            case "PLAYER":
                playerAddress = try parseHexAddress(valueBytes, displayName: name, tag: "PLAYER")
            case "MUSIC":
                musicAddress = try parseHexAddress(valueBytes, displayName: name, tag: "MUSIC")
            case "SONGS":
                guard let parsed = parsePositiveDecimal(valueBytes), parsed <= maximumTrackCount else {
                    throw malformed("SAP has an invalid or excessive SONGS count", name)
                }
                trackCount = parsed
            case "TYPE":
                guard let type = valueBytes.first,
                      type == 0x42 || type == 0x43 || type == 0x44 || type == 0x53 else {
                    throw malformed("SAP player type is unsupported by the scanner", name)
                }
                playerType = type
            case "FASTPLAY":
                guard let parsed = parsePositiveDecimal(valueBytes) else {
                    throw malformed("SAP has an invalid FASTPLAY value", name)
                }
                fastPlayScanlines = parsed
            case "STEREO":
                isStereo = true
            case "AUTHOR":
                author = directive.value
            case "NAME":
                game = directive.value
            case "DATE":
                copyright = directive.value
            case "TIME":
                guard timeHints.count < maximumTrackCount else {
                    throw malformed("SAP has too many TIME directives", name)
                }
                let hint = parseTimeHint(directive.value)
                timeHints.append(hint)
                if hint == nil {
                    diagnostics.append("Invalid SAP TIME directive on header line \(directive.lineNumber); the corresponding track uses default timing.")
                }
            default:
                // Unknown SAP directives remain in `tags` and the original header block.
                break
            }
        }

        technicalFacts["playerType"] = playerType.map { String(UnicodeScalar($0)) }
        technicalFacts["songCount"] = String(trackCount)
        technicalFacts["isStereo"] = String(isStereo)
        if let initAddress { technicalFacts["initAddress"] = String(format: "0x%04X", initAddress) }
        if let playerAddress { technicalFacts["playerAddress"] = String(format: "0x%04X", playerAddress) }
        if let musicAddress { technicalFacts["musicAddress"] = String(format: "0x%04X", musicAddress) }
        if let fastPlayScanlines { technicalFacts["fastPlayScanlines"] = String(fastPlayScanlines) }

        let normalizedGame = normalizePlaceholder(game)
        let normalizedAuthor = normalizePlaceholder(author)
        let normalizedCopyright = normalizePlaceholder(copyright)
        let rawHeader = Data(data[..<(markerOffset + 2)])
        let rawTagBlock = Data(data[signature.count..<markerOffset])
        var tracks: [MetadataTrack] = []
        tracks.reserveCapacity(trackCount)

        for sourceTrackIndex in 0..<trackCount {
            let hint = timeHints.indices.contains(sourceTrackIndex) ? timeHints[sourceTrackIndex] : nil
            var facts = technicalFacts
            facts["sourceTrackIndex"] = String(sourceTrackIndex)
            if let hint {
                facts["timeHintMilliseconds"] = String(hint.milliseconds)
                facts["timeHintIsLoopStart"] = String(hint.loops)
            }
            let document = MetadataDocument(
                format: "sap",
                fields: MetadataFields(
                    game: normalizedGame.isEmpty ? nil : normalizedGame,
                    system: "Atari XL",
                    artist: normalizedAuthor.isEmpty ? nil : normalizedAuthor,
                    copyright: normalizedCopyright.isEmpty ? nil : normalizedCopyright
                ),
                tags: tags,
                rawTagBlock: rawTagBlock,
                rawMetadataBlocks: ["sapInformationHeader": rawHeader],
                sourceEncoding: String(data: rawTagBlock, encoding: .utf8) == nil ? "Windows-1252" : "UTF-8",
                timing: MetadataTiming(
                    introLengthMs: hint.map { $0.loops ? $0.milliseconds : -1 } ?? -1,
                    loopLengthMs: -1,
                    playLengthMs: hint.map { $0.loops ? defaultPlayLengthMs : $0.milliseconds } ?? defaultPlayLengthMs,
                    fadeLengthMs: -1
                ),
                technicalFacts: facts,
                diagnostics: diagnostics
            )
            tracks.append(MetadataTrack(sourceTrackIndex: sourceTrackIndex, document: document))
        }

        return MetadataReadResult(tracks: tracks)
    }

    private static func directiveValue(name: String, bytes: [UInt8]) -> String {
        if ["AUTHOR", "NAME", "DATE"].contains(name) {
            guard bytes.first == 0x22,
                  let closingQuote = bytes.dropFirst().firstIndex(of: 0x22) else { return "" }
            return decodeText(Array(bytes[1..<closingQuote].prefix(255)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return decodeText(bytes).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeText(_ bytes: [UInt8]) -> String {
        if let value = String(bytes: bytes, encoding: .utf8) { return value }
        if let value = String(bytes: bytes, encoding: .windowsCP1252) { return value }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func normalizePlaceholder(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["?", "<?>", "< ? >"].contains(normalized)
            ? ""
            : normalized
    }

    private static func parseHexAddress(_ bytes: [UInt8], displayName: String, tag: String) throws -> UInt16 {
        guard bytes.count >= 4 else { throw malformed("SAP has an invalid \(tag) address", displayName) }
        var value: UInt16 = 0
        for byte in bytes.prefix(4) {
            let digit: UInt16
            switch byte {
            case 0x30...0x39: digit = UInt16(byte - 0x30)
            case 0x41...0x46: digit = UInt16(byte - 0x41) + 10
            case 0x61...0x66: digit = UInt16(byte - 0x61) + 10
            default: throw malformed("SAP has an invalid \(tag) address", displayName)
            }
            value = value * 16 + digit
        }
        return value
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

    private static func parseTimeHint(_ value: String) -> TimeHint? {
        let components = value.split(separator: " ", omittingEmptySubsequences: true)
        guard components.count == 1 || components.count == 2,
              components.count == 1 || components[1] == "LOOP" else { return nil }
        let time = components[0].split(separator: ".", omittingEmptySubsequences: false)
        guard time.count == 1 || time.count == 2 else { return nil }
        let clock = time[0].split(separator: ":", omittingEmptySubsequences: false)
        guard clock.count == 2,
              (1...2).contains(clock[0].count),
              clock[1].count == 2,
              let minutes = Int(clock[0]),
              let seconds = Int(clock[1]), seconds < 60 else { return nil }

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
        return TimeHint(milliseconds: total, loops: components.count == 2)
    }

    private static func malformed(_ message: String, _ displayName: String) -> MetadataReadError {
        .malformedFile("\(message): \(displayName)")
    }
}
