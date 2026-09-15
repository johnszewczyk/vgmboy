import Foundation

/// Direct Atari SNDH tag and timing reader. The executable music routines are
/// never entered; only the bounded header/tag area is interpreted.
enum SNDHMetadataReader {
    private static let tagStart = 16
    private static let maximumTrackCount = 10_000
    private static let timerTags = ["TA", "TB", "TC", "TD", "!V"]
    private static let atariControlCodePoints: [UInt32] = [
        0x0000, 0x21E7, 0x21E9, 0x21E8, 0x21E6, 0x1FBBD, 0x1FBBE, 0x1FBBF,
        0x2713, 0x1F552, 0x1F514, 0x266A, 0x240C, 0x240D, 0x000E, 0x000F,
        0x1FBF0, 0x1FBF1, 0x1FBF2, 0x1FBF3, 0x1FBF4, 0x1FBF5, 0x1FBF6, 0x1FBF7,
        0x1FBF8, 0x1FBF9, 0x0259, 0x241B, 0x001C, 0x001D, 0x001E, 0x001F
    ]
    private static let atariUpperCodePoints: [UInt32] = [
        0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7,
        0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
        0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9,
        0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x00DF, 0x0192,
        0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA,
        0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
        0x00E3, 0x00F5, 0x00D8, 0x00F8, 0x0153, 0x0152, 0x00C0, 0x00C3,
        0x00D5, 0x00A8, 0x00B4, 0x2020, 0x00B6, 0x00A9, 0x00AE, 0x2122,
        0x0133, 0x0132, 0x05D0, 0x05D1, 0x05D2, 0x05D3, 0x05D4, 0x05D5,
        0x05D6, 0x05D7, 0x05D8, 0x05D9, 0x05DB, 0x05DC, 0x05DE, 0x05E0,
        0x05E1, 0x05E2, 0x05E4, 0x05E6, 0x05E7, 0x05E8, 0x05E9, 0x05EA,
        0x05DF, 0x05DA, 0x05DD, 0x05E3, 0x05E5, 0x00A7, 0x2227, 0x221E,
        0x03B1, 0x03B2, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4,
        0x03A6, 0x0398, 0x03A9, 0x03B4, 0x222E, 0x03C6, 0x2208, 0x2229,
        0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248,
        0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x00B3, 0x00AF
    ]

    private struct ParsedHeader {
        var tags: [MetadataTag] = []
        var values: [String: [String]] = [:]
        var timeSeconds: [UInt32] = []
        var frameCounts: [UInt32] = []
        var trackCount = 1
        var hasTrackCount = false
        var defaultSubtune = 1
        var hasDefaultSubtune = false
        var timerTag: String?
        var timerFrequency: Int?
        var endOffset = tagStart
        var diagnostics: [String] = []
    }

    static func hasSupportedHint(_ hint: String?) -> Bool {
        hint == "sndh"
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 20
            && data[12] == 0x53
            && data[13] == 0x4E
            && data[14] == 0x44
            && data[15] == 0x48
    }

    static func readResult(data source: Data, displayName: String?) throws -> MetadataReadResult {
        guard source.count <= ICEMetadataDecompressor.maximumOutputSize else {
            throw malformed("SNDH source exceeds the 256 MiB safety limit: \(displayName ?? "SNDH")")
        }

        let isICE = ICEMetadataDecompressor.matches(source)
        let data = isICE ? try ICEMetadataDecompressor.decompress(source) : source
        guard matches(data) else {
            throw malformed("Not an Atari SNDH executable: \(displayName ?? "SNDH")")
        }

        var parsed = try parseHeader(data)
        guard (1...maximumTrackCount).contains(parsed.trackCount) else {
            throw malformed("SNDH declares an invalid subtune count: \(displayName ?? "SNDH")")
        }
        if !parsed.hasDefaultSubtune || !(1...parsed.trackCount).contains(parsed.defaultSubtune) {
            parsed.defaultSubtune = 1
        }

        let fileTitle = parsed.values["TITL"]?.first ?? ""
        let composer = parsed.values["COMM"]?.first ?? ""
        let year = parsed.values["YEAR"]?.first ?? ""
        let tagEnd = max(tagStart, min(parsed.endOffset, data.count))
        let rawTagBlock = data.subdata(in: tagStart..<tagEnd)
        let tracks = (0..<parsed.trackCount).map { index -> MetadataTrack in
            let name = parsed.values["!#SN"].flatMap { $0.indices.contains(index) ? $0[index] : nil } ?? ""
            let duration = durationMilliseconds(for: index, parsed: parsed)
            var facts = [
                "headerOffset": "12",
                "tagBlockOffset": String(tagStart),
                "tagBlockEnd": String(tagEnd),
                "tagBlockBytes": String(rawTagBlock.count),
                "trackCount": String(parsed.trackCount),
                "sourceTrackIndex": String(index + 1),
                "defaultSubtune": String(parsed.defaultSubtune)
            ]
            if let timerTag = parsed.timerTag { facts["timerTag"] = timerTag }
            if let timerFrequency = parsed.timerFrequency { facts["timerFrequency"] = String(timerFrequency) }
            if isICE {
                facts["iceCompressed"] = "true"
                facts["icePackedBytes"] = String(source.count)
                facts["iceExpandedBytes"] = String(data.count)
            } else {
                facts["iceCompressed"] = "false"
            }

            var rawBlocks: [String: Data] = [:]
            if isICE { rawBlocks["ice-container-header"] = source.prefix(ICEMetadataDecompressor.headerSize) }
            let title = name.isEmpty ? fileTitle : name
            let document = MetadataDocument(
                format: "sndh",
                fields: MetadataFields(
                    title: title.isEmpty ? nil : title,
                    system: "Atari ST",
                    artist: composer.isEmpty ? nil : composer,
                    year: year.isEmpty ? nil : year
                ),
                tags: parsed.tags,
                rawTagBlock: rawTagBlock,
                rawMetadataBlocks: rawBlocks.isEmpty ? nil : rawBlocks,
                sourceEncoding: "Atari ST",
                timing: MetadataTiming(
                    introLengthMs: 0,
                    loopLengthMs: 0,
                    playLengthMs: duration,
                    fadeLengthMs: 0
                ),
                technicalFacts: facts,
                diagnostics: parsed.diagnostics
            )
            return MetadataTrack(sourceTrackIndex: index + 1, document: document)
        }
        return MetadataReadResult(tracks: tracks)
    }

    private static func parseHeader(_ data: Data) throws -> ParsedHeader {
        let bound = tagBound(data)
        guard bound > tagStart else {
            throw malformed("SNDH executable vectors leave no bounded tag area.")
        }

        var parsed = ParsedHeader()
        var offset = tagStart
        var foundEndMarker = false

        while offset < bound {
            if data[offset] == 0 {
                offset += 1
                continue
            }

            if matchesTag("HDNS", data, at: offset, bound: bound) {
                offset += 4
                foundEndMarker = true
                break
            }
            if matchesTag("!#SN", data, at: offset, bound: bound) {
                offset = try readSubstrings(
                    name: "!#SN", data: data, tagOffset: offset, bound: bound, into: &parsed
                )
                continue
            }
            if matchesTag("FLAG~", data, at: offset, bound: bound) {
                let start = offset
                offset += 5
                guard let value = readTerminatedText(data, from: offset, bound: bound) else {
                    parsed.diagnostics.append("FLAG~ at offset \(start) has no bounded NUL terminator.")
                    break
                }
                offset = value.nextOffset
                appendTag("FLAG~", value.text, to: &parsed)
                continue
            }
            if matchesTag("FLAG", data, at: offset, bound: bound) {
                offset = try readSubstrings(
                    name: "FLAG", data: data, tagOffset: offset, bound: bound, into: &parsed
                )
                continue
            }
            if matchesTag("TIME", data, at: offset, bound: bound) {
                offset = readTimes(data, at: offset, bound: bound, into: &parsed)
                continue
            }
            if matchesTag("FRMS", data, at: offset, bound: bound) {
                offset = readFrames(data, at: offset, bound: bound, into: &parsed)
                continue
            }
            if matchesTag("##", data, at: offset, bound: bound) {
                let start = offset
                guard offset + 4 <= bound else {
                    parsed.diagnostics.append("Subtune-count tag at offset \(start) is truncated.")
                    break
                }
                let text = String(decoding: data[(offset + 2)..<(offset + 4)], as: UTF8.self)
                offset += 4
                guard let count = parseInteger(text) else {
                    parsed.diagnostics.append("Subtune-count tag at offset \(start) is not decimal.")
                    break
                }
                if !parsed.hasTrackCount {
                    guard (1...maximumTrackCount).contains(count) else {
                        throw malformed("SNDH declares an invalid subtune count.")
                    }
                    parsed.trackCount = count
                    parsed.hasTrackCount = true
                }
                appendTag("##", String(count), to: &parsed)
                continue
            }

            let numericNames = ["TA", "TB", "TC", "TD", "!#", "!V"]
            if let name = numericNames.first(where: { matchesTag($0, data, at: offset, bound: bound) }) {
                let start = offset
                offset += name.utf8.count
                guard let value = readTerminatedText(data, from: offset, bound: bound) else {
                    parsed.diagnostics.append("\(name) at offset \(start) has no bounded NUL terminator.")
                    break
                }
                offset = value.nextOffset
                guard let number = parseInteger(value.text) else {
                    parsed.diagnostics.append("\(name) at offset \(start) is not a decimal integer.")
                    break
                }
                appendTag(name, String(number), to: &parsed)
                if name == "!#", !parsed.hasDefaultSubtune {
                    parsed.defaultSubtune = number
                    parsed.hasDefaultSubtune = true
                }
                if timerTags.contains(name), parsed.timerTag == nil {
                    parsed.timerTag = name
                    parsed.timerFrequency = number
                }
                continue
            }

            let stringNames = ["TITL", "COMM", "RIPP", "CONV", "YEAR"]
            if let name = stringNames.first(where: { matchesTag($0, data, at: offset, bound: bound) }) {
                let start = offset
                offset += name.utf8.count
                guard let value = readTerminatedText(data, from: offset, bound: bound) else {
                    parsed.diagnostics.append("\(name) at offset \(start) has no bounded NUL terminator.")
                    break
                }
                offset = value.nextOffset
                appendTag(name, value.text, to: &parsed)
                continue
            }

            parsed.diagnostics.append("Unrecognized SNDH header data at offset \(offset); remaining bytes are retained in rawTagBlock.")
            break
        }

        parsed.endOffset = foundEndMarker ? offset : bound
        if !foundEndMarker {
            parsed.diagnostics.append("SNDH HDNS end marker was not found before the executable-vector bound.")
        }
        return parsed
    }

    private static func readSubstrings(
        name: String,
        data: Data,
        tagOffset: Int,
        bound: Int,
        into parsed: inout ParsedHeader
    ) throws -> Int {
        let tableStart = tagOffset + name.utf8.count
        let (tableBytes, overflow) = parsed.trackCount.multipliedReportingOverflow(by: 2)
        guard !overflow, tableBytes <= bound - tableStart else {
            parsed.diagnostics.append("\(name) subtune table at offset \(tagOffset) is truncated.")
            return bound
        }
        let tableEnd = tableStart + tableBytes
        var dataEnd = tableEnd
        var strings: [String] = []

        for index in 0..<parsed.trackCount {
            let pointerOffset = tableStart + index * 2
            guard let relative = readUInt16BE(data, at: pointerOffset),
                  relative <= bound - tagOffset else {
                parsed.diagnostics.append("\(name) subtune pointer \(index + 1) is outside the bounded tag area.")
                return bound
            }
            let stringStart = tagOffset + Int(relative)
            guard stringStart >= tableEnd,
                  let value = readTerminatedText(data, from: stringStart, bound: bound) else {
                parsed.diagnostics.append("\(name) subtune pointer \(index + 1) does not reach a bounded NUL-terminated string.")
                return bound
            }
            strings.append(value.text)
            dataEnd = max(dataEnd, value.nextOffset)
        }

        for value in strings { appendTag(name, value, to: &parsed) }
        return dataEnd
    }

    private static func readTimes(_ data: Data, at tagOffset: Int, bound: Int, into parsed: inout ParsedHeader) -> Int {
        let start = tagOffset + 4
        let (byteCount, overflow) = parsed.trackCount.multipliedReportingOverflow(by: 2)
        guard !overflow, byteCount <= bound - start else {
            parsed.diagnostics.append("TIME array at offset \(tagOffset) is truncated.")
            return bound
        }
        for index in 0..<parsed.trackCount {
            let value = UInt32(readUInt16BE(data, at: start + index * 2) ?? 0)
            parsed.timeSeconds.append(value)
            appendTag("TIME", String(value), to: &parsed)
        }
        return start + byteCount
    }

    private static func readFrames(_ data: Data, at tagOffset: Int, bound: Int, into parsed: inout ParsedHeader) -> Int {
        let start = tagOffset + 4
        let (byteCount, overflow) = parsed.trackCount.multipliedReportingOverflow(by: 4)
        guard !overflow, byteCount <= bound - start else {
            parsed.diagnostics.append("FRMS array at offset \(tagOffset) is truncated.")
            return bound
        }
        for index in 0..<parsed.trackCount {
            let value = readUInt32BE(data, at: start + index * 4) ?? 0
            parsed.frameCounts.append(value)
            appendTag("FRMS", String(value), to: &parsed)
        }
        return start + byteCount
    }

    private static func appendTag(_ name: String, _ value: String, to parsed: inout ParsedHeader) {
        parsed.tags.append(MetadataTag(name: name, value: value))
        parsed.values[name, default: []].append(value)
    }

    private static func readTerminatedText(_ data: Data, from start: Int, bound: Int) -> (text: String, nextOffset: Int)? {
        guard start >= 0, start < bound else { return nil }
        var end = start
        while end < bound, data[end] != 0 { end += 1 }
        guard end < bound else { return nil }
        return (decodeAtariST(data[start..<end]), end + 1)
    }

    private static func parseInteger(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func matchesTag(_ name: String, _ data: Data, at offset: Int, bound: Int) -> Bool {
        let bytes = Array(name.utf8)
        guard offset >= 0, offset + bytes.count <= bound else { return false }
        return bytes.enumerated().allSatisfy { data[offset + $0.offset] == $0.element }
    }

    private static func durationMilliseconds(for index: Int, parsed: ParsedHeader) -> Int {
        if parsed.frameCounts.indices.contains(index) {
            let frames = parsed.frameCounts[index]
            let frequency = parsed.timerFrequency.flatMap { $0 == 0 ? nil : $0 } ?? 50
            let seconds = Float(frames) / Float(frequency)
            guard seconds > 0, seconds < 2_147_483 else { return 0 }
            return Int(seconds * 1_000 + 0.5)
        }
        guard parsed.timeSeconds.indices.contains(index) else { return 0 }
        let seconds = Float(parsed.timeSeconds[index])
        guard seconds > 0, seconds < 2_147_483 else { return 0 }
        return Int(seconds * 1_000 + 0.5)
    }

    private static func tagBound(_ data: Data) -> Int {
        var limit = data.count
        for offset in [0, 4, 8] {
            guard let target = branchTarget(data, at: offset), target > 0, target < limit else { continue }
            limit = target
        }
        return limit
    }

    private static func branchTarget(_ data: Data, at start: Int) -> Int? {
        var offset = start
        while offset + 2 <= data.count {
            let word = Int(data[offset]) << 8 | Int(data[offset + 1])
            if word == 0x4E71 {
                offset += 2
                continue
            }
            if word & 0xFF00 == 0x6000, word & 0x00FF != 0 {
                return offset + (word & 0x00FF)
            }
            guard offset + 4 <= data.count else { return nil }
            if word == 0x6000 || word == 0x4EFA {
                let displacement = Int(data[offset + 2]) << 8 | Int(data[offset + 3])
                return offset + 2 + displacement
            }
            return nil
        }
        return nil
    }

    private static func readUInt16BE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else { return nil }
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }

    private static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func decodeAtariST<S: Collection>(_ bytes: S) -> String where S.Element == UInt8 {
        var scalars = String.UnicodeScalarView()
        scalars.reserveCapacity(bytes.count)
        for byte in bytes {
            let codePoint: UInt32
            if byte < 0x20 {
                codePoint = atariControlCodePoints[Int(byte)]
            } else if byte < 0x80 {
                codePoint = UInt32(byte)
            } else {
                codePoint = atariUpperCodePoints[Int(byte) - 0x80]
            }
            if let scalar = Unicode.Scalar(codePoint) { scalars.append(scalar) }
        }
        return String(scalars)
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
