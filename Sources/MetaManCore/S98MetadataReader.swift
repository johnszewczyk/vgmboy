import Foundation

enum S98MetadataReader {
    private struct Header {
        let version: UInt8
        let tickNumerator: UInt32
        let tickDenominator: UInt32
        let tagOffset: Int
        let dataOffset: Int
        let loopOffset: Int
        let deviceCount: UInt32?
    }

    private struct TagBlock {
        let tags: [MetadataTag]
        let raw: Data?
        let encoding: String?
        let diagnostics: [String]

        func firstValue(_ key: String) -> String? {
            let normalized = key.uppercased()
            guard let tag = tags.first(where: { $0.normalizedName == normalized && !$0.value.isEmpty }) else {
                return nil
            }
            let bytes = Array(tag.value.utf8)
            var start = 0
            var end = bytes.count
            while start < end, bytes[start] <= 0x20 { start += 1 }
            while end > start, bytes[end - 1] <= 0x20 { end -= 1 }
            return String(decoding: bytes[start..<end], as: UTF8.self)
        }
    }

    private struct TimingScan {
        let totalTicks: UInt64
        let loopStartTicks: UInt64?
        let commandTerminatorOffset: Int?
        let diagnostics: [String]
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4 && data[0] == 0x53 && data[1] == 0x39 && data[2] == 0x38
            && (0x30...0x33).contains(data[3])
    }

    static func read(data: Data) throws -> MetadataDocument {
        try data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let header = try readHeader(bytes)
            let commandEnd = header.tagOffset > header.dataOffset && header.tagOffset <= bytes.count
                ? header.tagOffset
                : bytes.count
            let loopOffset = header.loopOffset >= header.dataOffset && header.loopOffset < commandEnd
                ? header.loopOffset
                : 0
            let timingScan = try readTiming(
                bytes,
                header: header,
                commandEnd: commandEnd,
                loopOffset: loopOffset
            )
            let tags = readTags(bytes, header: header)

            var diagnostics = tags.diagnostics + timingScan.diagnostics
            if header.loopOffset != 0, timingScan.loopStartTicks == nil {
                diagnostics.append("S98 loop offset does not identify an event before the command-stream end; loop timing was omitted.")
            }
            let totalTicks = timingScan.totalTicks
            let loopStartTicks = timingScan.loopStartTicks
            let hasLoop = loopOffset != 0
                && loopStartTicks.map { $0 < totalTicks } == true
            if header.loopOffset != 0,
               let loopStartTicks,
               loopStartTicks >= totalTicks {
                diagnostics.append("S98 loop offset identifies the end command and has zero duration; loop timing was omitted.")
            }
            let introTicks = hasLoop ? (loopStartTicks ?? 0) : 0
            let loopTicks = hasLoop ? totalTicks - introTicks : 0

            let fields = MetadataFields(
                title: tags.firstValue("TITLE") ?? (header.version < 3 ? tags.tags.first?.value : nil),
                game: tags.firstValue("GAME"),
                system: tags.firstValue("SYSTEM") ?? String(format: "S98 v%X.00", header.version),
                artist: tags.firstValue("ARTIST"),
                date: tags.firstValue("DATE") ?? tags.firstValue("YEAR"),
                year: tags.firstValue("YEAR"),
                genre: tags.firstValue("GENRE"),
                comment: tags.firstValue("COMMENT"),
                copyright: tags.firstValue("COPYRIGHT"),
                encodedBy: tags.firstValue("S98BY")
            )

            var facts = [
                "version": String(header.version),
                "tickNumerator": String(header.tickNumerator),
                "tickDenominator": String(header.tickDenominator),
                "dataOffset": String(header.dataOffset),
                "tagOffset": String(header.tagOffset),
                "loopOffset": String(header.loopOffset)
            ]
            if let deviceCount = header.deviceCount {
                facts["deviceCount"] = String(deviceCount)
            }
            if hasLoop {
                facts["loopStartTicks"] = String(introTicks)
                facts["loopDurationTicks"] = String(loopTicks)
            }
            if let commandTerminatorOffset = timingScan.commandTerminatorOffset {
                facts["commandTerminatorOffset"] = String(commandTerminatorOffset)
            }
            if header.loopOffset != 0 {
                facts["loopOffsetRecognized"] = String(loopStartTicks != nil)
            }

            return MetadataDocument(
                format: "s98",
                fields: fields,
                tags: tags.tags,
                rawTagBlock: tags.raw,
                sourceEncoding: tags.encoding,
                timing: MetadataTiming(
                    introLengthMs: hasLoop ? milliseconds(ticks: introTicks, numerator: header.tickNumerator, denominator: header.tickDenominator) : 0,
                    loopLengthMs: hasLoop ? milliseconds(ticks: loopTicks, numerator: header.tickNumerator, denominator: header.tickDenominator) : 0,
                    playLengthMs: milliseconds(ticks: totalTicks, numerator: header.tickNumerator, denominator: header.tickDenominator)
                ),
                technicalFacts: facts,
                diagnostics: diagnostics
            )
        }
    }

    private static func readHeader(_ bytes: UnsafeBufferPointer<UInt8>) throws -> Header {
        guard bytes.count >= 0x20,
              bytes[0] == 0x53, bytes[1] == 0x39, bytes[2] == 0x38,
              (0x30...0x33).contains(bytes[3]) else {
            throw malformed("Invalid or unsupported S98 header.")
        }

        let version = bytes[3] - 0x30
        guard var tickNumerator = uint32LE(bytes, at: 0x04),
              var tickDenominator = uint32LE(bytes, at: 0x08),
              let tagOffsetValue = uint32LE(bytes, at: 0x10),
              let dataOffsetValue = uint32LE(bytes, at: 0x14),
              let loopOffsetValue = uint32LE(bytes, at: 0x18) else {
            throw malformed("Truncated S98 header fields.")
        }

        if version == 0 { tickNumerator = 0 }
        if version <= 1 { tickDenominator = 0 }
        if tickNumerator == 0 { tickNumerator = 10 }
        if tickDenominator == 0 { tickDenominator = 1_000 }

        var minimumDataOffset = 0x20
        var deviceCount: UInt32?
        switch version {
        case 0, 1:
            break
        case 2:
            var position = 0x20
            var count: UInt32 = 0
            var foundTerminator = false
            while position <= bytes.count - 0x10 {
                guard let deviceType = uint32LE(bytes, at: position) else { break }
                if deviceType == 0 {
                    minimumDataOffset = position + 0x10
                    foundTerminator = true
                    break
                }
                count += 1
                guard count <= 64 else { throw malformed("S98 v2 device table exceeds 64 entries.") }
                position += 0x10
            }
            guard foundTerminator else { throw malformed("S98 v2 device table has no complete terminator.") }
            deviceCount = count
        case 3:
            guard let count = uint32LE(bytes, at: 0x1C), count <= 64 else {
                throw malformed("Invalid S98 v3 device count.")
            }
            let (deviceBytes, multiplicationOverflow) = Int(count).multipliedReportingOverflow(by: 0x10)
            let (end, additionOverflow) = 0x20.addingReportingOverflow(deviceBytes)
            guard !multiplicationOverflow, !additionOverflow, end <= bytes.count else {
                throw malformed("S98 v3 device table extends beyond the file.")
            }
            minimumDataOffset = end
            deviceCount = count
        default:
            throw malformed("Unsupported S98 version.")
        }

        let dataOffset = Int(dataOffsetValue)
        guard dataOffset >= minimumDataOffset, dataOffset <= bytes.count else {
            throw malformed("S98 data offset is outside the command stream.")
        }

        return Header(
            version: version,
            tickNumerator: tickNumerator,
            tickDenominator: tickDenominator,
            tagOffset: Int(tagOffsetValue),
            dataOffset: dataOffset,
            loopOffset: Int(loopOffsetValue),
            deviceCount: deviceCount
        )
    }

    private static func readTiming(
        _ bytes: UnsafeBufferPointer<UInt8>,
        header: Header,
        commandEnd: Int,
        loopOffset: Int
    ) throws -> TimingScan {
        var position = header.dataOffset
        var totalTicks: UInt64 = 0
        var loopStartTicks: UInt64?
        var diagnostics: [String] = []

        while position < commandEnd {
            if position == loopOffset { loopStartTicks = totalTicks }
            let commandOffset = position
            let command = bytes[position]
            position += 1
            switch command {
            case 0xFF:
                totalTicks = try addTicks(totalTicks, 1)
            case 0xFE:
                let delta = try readVariableInteger(bytes, position: &position, end: commandEnd)
                totalTicks = try addTicks(totalTicks, UInt64(delta) + 2)
            case 0xFD:
                return TimingScan(
                    totalTicks: totalTicks,
                    loopStartTicks: loopStartTicks,
                    commandTerminatorOffset: commandOffset,
                    diagnostics: diagnostics
                )
            default:
                guard position <= commandEnd - 2 else {
                    diagnostics.append("S98 command stream ends with a truncated register-write event; timing from complete events was retained.")
                    return TimingScan(
                        totalTicks: totalTicks,
                        loopStartTicks: loopStartTicks,
                        commandTerminatorOffset: nil,
                        diagnostics: diagnostics
                    )
                }
                position += 2
            }
        }
        return TimingScan(
            totalTicks: totalTicks,
            loopStartTicks: loopStartTicks,
            commandTerminatorOffset: nil,
            diagnostics: diagnostics
        )
    }

    private static func addTicks(_ current: UInt64, _ addition: UInt64) throws -> UInt64 {
        let (value, overflow) = current.addingReportingOverflow(addition)
        guard !overflow else { throw malformed("S98 command timing overflows the supported range.") }
        return value
    }

    private static func readVariableInteger(
        _ bytes: UnsafeBufferPointer<UInt8>,
        position: inout Int,
        end: Int
    ) throws -> UInt32 {
        var value: UInt32 = 0
        for byteIndex in 0..<5 {
            guard position < end else { throw malformed("Truncated S98 variable-length tick value.") }
            let byte = bytes[position]
            position += 1
            value |= UInt32(byte & 0x7F) &<< (byteIndex * 7)
            if byte & 0x80 == 0 { return value }
        }
        throw malformed("S98 variable-length tick value exceeds 32 bits.")
    }

    private static func readTags(_ bytes: UnsafeBufferPointer<UInt8>, header: Header) -> TagBlock {
        guard header.tagOffset > 0, header.tagOffset < bytes.count else {
            return TagBlock(tags: [], raw: nil, encoding: nil, diagnostics: [])
        }

        var end = header.tagOffset
        while end < bytes.count, bytes[end] != 0 { end += 1 }
        let tagData = Data(bytes[header.tagOffset..<end])

        if header.version < 3 {
            let decoded = String(data: tagData, encoding: .shiftJIS)
            let title = decoded ?? String(decoding: tagData, as: UTF8.self)
            let diagnostics = decoded == nil
                ? ["Legacy S98 title is not valid Shift_JIS; UTF-8 replacement decoding was used."]
                : []
            return TagBlock(
                tags: title.isEmpty ? [] : [MetadataTag(name: "title", value: title)],
                raw: tagData,
                encoding: decoded == nil ? "undetermined legacy bytes" : "Shift_JIS",
                diagnostics: diagnostics
            )
        }

        guard tagData.starts(with: Data("[S98]".utf8)) else {
            return TagBlock(tags: [], raw: tagData, encoding: nil, diagnostics: ["S98 v3 tag block is missing the [S98] marker."])
        }
        let body = tagData.dropFirst(5)
        let decoded: String
        let encoding: String
        var diagnostics: [String] = []
        if body.starts(with: [0xEF, 0xBB, 0xBF]) {
            let utf8Data = Data(body.dropFirst(3))
            if let strictUTF8 = String(data: utf8Data, encoding: .utf8) {
                decoded = strictUTF8
            } else {
                decoded = String(decoding: utf8Data, as: UTF8.self)
                diagnostics.append("S98 v3 tag block declares UTF-8 but contains invalid byte sequences; replacement characters were used.")
            }
            encoding = "UTF-8"
        } else {
            if let shiftJIS = String(data: Data(body), encoding: .shiftJIS) {
                decoded = shiftJIS
                encoding = "Shift_JIS"
            } else {
                decoded = String(decoding: Data(body), as: UTF8.self)
                encoding = "undetermined legacy bytes"
                diagnostics.append("S98 v3 legacy tag block is not valid Shift_JIS; UTF-8 replacement decoding was used.")
            }
        }

        var tags: [MetadataTag] = []
        for (lineNumber, line) in decoded.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard let separator = line.firstIndex(of: "=") else {
                if !line.isEmpty { diagnostics.append("Ignored S98 tag line \(lineNumber + 1) without '='.") }
                continue
            }
            let name = String(line[..<separator])
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                diagnostics.append("Ignored S98 tag line \(lineNumber + 1) with an empty name.")
                continue
            }
            tags.append(MetadataTag(name: name, value: String(line[line.index(after: separator)...])))
        }
        return TagBlock(tags: tags, raw: tagData, encoding: encoding, diagnostics: diagnostics)
    }

    private static func milliseconds(ticks: UInt64, numerator: UInt32, denominator: UInt32) -> Int {
        let value = Double(ticks) * Double(numerator) / Double(denominator) * 1_000
        guard value.isFinite, value > 0 else { return 0 }
        return value >= Double(Int.max) ? Int.max : Int(value)
    }

    private static func uint32LE(_ bytes: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= bytes.count - 4, let base = bytes.baseAddress else { return nil }
        return UInt32(base[offset])
            | UInt32(base[offset + 1]) << 8
            | UInt32(base[offset + 2]) << 16
            | UInt32(base[offset + 3]) << 24
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
