import Foundation

enum VGMMetadataReader {
    private static let headerSize = 0x40
    private static let gd3Signature = Data("Gd3 ".utf8)

    private static let gd3FieldNames = [
        "title_english", "title_original", "game_english", "game_original",
        "system_english", "system_original", "artist_english", "artist_original",
        "date", "converted_by", "notes"
    ]

    private struct GD3Data {
        let fields: [String]
        let tags: [MetadataTag]
        let raw: Data
        let version: UInt32
        let diagnostics: [String]
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4 && data.prefix(4) == Data("Vgm ".utf8)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= headerSize, matches(data) else {
            throw malformed("Not a VGM file with a valid 64-byte header.")
        }

        let eofOffset = readUInt32(data, at: 0x04)
        let version = readUInt32(data, at: 0x08)
        let gd3RelativeOffset = readUInt32(data, at: 0x14)
        let totalSamples = readUInt32(data, at: 0x18)
        let loopRelativeOffset = readUInt32(data, at: 0x1C)
        let loopSamples = readUInt32(data, at: 0x20)
        let dataRelativeOffset = readUInt32(data, at: 0x34)
        let dataOffset = version >= 0x0000_0150 && dataRelativeOffset > 0
            ? 0x34 + Int(dataRelativeOffset)
            : headerSize

        var diagnostics: [String] = []
        if eofOffset > 0, UInt64(eofOffset) + 4 > UInt64(data.count) {
            diagnostics.append("VGM EOF offset points beyond the available file bytes.")
        }
        if dataOffset > data.count {
            diagnostics.append("VGM data offset points beyond the available file bytes.")
        }
        if loopRelativeOffset > 0 {
            let loopOffset = 0x1C + Int(loopRelativeOffset)
            if loopOffset >= data.count {
                diagnostics.append("VGM loop offset points beyond the available file bytes.")
            }
        }
        if loopSamples > totalSamples {
            diagnostics.append("VGM loop sample count exceeds its total sample count; header values were retained.")
        }

        let gd3 = try readGD3(data: data, relativeOffset: gd3RelativeOffset)
        diagnostics.append(contentsOf: gd3?.diagnostics ?? [])

        let values = gd3?.fields ?? []
        func field(_ index: Int) -> String? {
            guard values.indices.contains(index) else { return nil }
            let value = values[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        func preferred(_ englishIndex: Int, originalIndex: Int) -> String? {
            field(englishIndex) ?? field(originalIndex)
        }

        let date = field(8)
        let year = date.flatMap { value -> String? in
            let prefix = value.prefix(4)
            guard prefix.count == 4, prefix.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
            return String(prefix)
        }
        let filenameTitle = gd3 == nil ? displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        } : nil

        let fields = MetadataFields(
            title: preferred(0, originalIndex: 1) ?? filenameTitle,
            game: preferred(2, originalIndex: 3),
            system: preferred(4, originalIndex: 5),
            artist: preferred(6, originalIndex: 7),
            date: date,
            year: year,
            comment: field(10),
            encodedBy: field(9)
        )

        let totalMilliseconds = milliseconds(samples: totalSamples)
        let loopMilliseconds = milliseconds(samples: loopSamples)
        let gd3AbsoluteOffset = gd3RelativeOffset == 0 ? 0 : 0x14 + Int(gd3RelativeOffset)
        var facts = [
            "version": formatVersion(version),
            "versionRaw": String(format: "0x%08X", version),
            "eofOffset": String(eofOffset),
            "gd3Offset": String(gd3AbsoluteOffset),
            "totalSamples": String(totalSamples),
            "loopOffset": String(loopRelativeOffset == 0 ? 0 : 0x1C + Int(loopRelativeOffset)),
            "loopSamples": String(loopSamples),
            "dataOffset": String(dataOffset),
            "sampleRate": "44100"
        ]
        if let gd3 {
            facts["gd3Version"] = String(format: "0x%08X", gd3.version)
            facts["gd3FieldCount"] = String(gd3.fields.count)
        }

        return MetadataDocument(
            format: "vgm",
            fields: fields,
            tags: gd3?.tags ?? [],
            rawTagBlock: gd3?.raw,
            sourceEncoding: gd3 == nil ? nil : "UTF-16LE",
            timing: MetadataTiming(
                introLengthMs: max(0, totalMilliseconds - loopMilliseconds),
                loopLengthMs: loopMilliseconds,
                playLengthMs: totalMilliseconds
            ),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func readGD3(data: Data, relativeOffset: UInt32) throws -> GD3Data? {
        guard relativeOffset > 0 else { return nil }
        let absoluteOffset = 0x14 + Int(relativeOffset)
        guard absoluteOffset <= data.count - 12,
              data[absoluteOffset..<(absoluteOffset + 4)] == gd3Signature else {
            throw malformed("VGM GD3 pointer is invalid.")
        }

        let version = readUInt32(data, at: absoluteOffset + 4)
        let byteCount = Int(readUInt32(data, at: absoluteOffset + 8))
        let payloadStart = absoluteOffset + 12
        guard byteCount.isMultiple(of: 2), byteCount <= data.count - payloadStart else {
            throw malformed("VGM GD3 payload length is invalid or extends beyond the file.")
        }

        let payloadEnd = payloadStart + byteCount
        let payload = data[payloadStart..<payloadEnd]
        var values: [String] = []
        var codeUnits: [UInt16] = []
        var diagnostics: [String] = []
        var byteIndex = payload.startIndex
        while byteIndex < payload.endIndex {
            let unit = UInt16(payload[byteIndex]) | UInt16(payload[payload.index(after: byteIndex)]) << 8
            byteIndex = payload.index(byteIndex, offsetBy: 2)
            if unit == 0 {
                values.append(String(decoding: codeUnits, as: UTF16.self))
                if !isValidUTF16(codeUnits) {
                    let label = values.count <= gd3FieldNames.count ? gd3FieldNames[values.count - 1] : "extra field \(values.count)"
                    diagnostics.append("GD3 field \(label) contains invalid UTF-16; replacement characters were used.")
                }
                codeUnits.removeAll(keepingCapacity: true)
            } else {
                codeUnits.append(unit)
            }
        }
        if !codeUnits.isEmpty {
            values.append(String(decoding: codeUnits, as: UTF16.self))
            let label = values.count <= gd3FieldNames.count ? gd3FieldNames[values.count - 1] : "extra field \(values.count)"
            diagnostics.append("GD3 field \(label) is not NUL-terminated; its decoded value was retained.")
            if !isValidUTF16(codeUnits) {
                diagnostics.append("GD3 field \(label) contains invalid UTF-16; replacement characters were used.")
            }
        }

        if version != 0x0000_0100 {
            diagnostics.append("GD3 version \(String(format: "0x%08X", version)) is not the standard 1.00 version; the common field sequence was read.")
        }
        if values.count < gd3FieldNames.count {
            diagnostics.append("GD3 contains \(values.count) strings; missing standard fields were supplied as empty values.")
            values.append(contentsOf: repeatElement("", count: gd3FieldNames.count - values.count))
        } else if values.count > gd3FieldNames.count {
            diagnostics.append("GD3 contains \(values.count - gd3FieldNames.count) additional strings; they were retained as extra fields.")
        }

        var tags = gd3FieldNames.enumerated().map { index, name in
            MetadataTag(name: name, value: values[index])
        }
        if values.count > gd3FieldNames.count {
            for index in gd3FieldNames.count..<values.count {
                tags.append(MetadataTag(name: "gd3_field_\(index + 1)", value: values[index]))
            }
        }

        return GD3Data(
            fields: values,
            tags: tags,
            raw: Data(data[absoluteOffset..<payloadEnd]),
            version: version,
            diagnostics: diagnostics
        )
    }

    private static func isValidUTF16(_ units: [UInt16]) -> Bool {
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xD800...0xDBFF).contains(unit) {
                guard index + 1 < units.count, (0xDC00...0xDFFF).contains(units[index + 1]) else { return false }
                index += 2
            } else {
                if (0xDC00...0xDFFF).contains(unit) { return false }
                index += 1
            }
        }
        return true
    }

    private static func formatVersion(_ version: UInt32) -> String {
        let major = (version >> 8) & 0xFF
        let minor = version & 0xFF
        return String(format: "%d.%02X", major, minor)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func milliseconds(samples: UInt32) -> Int {
        samples > 0 ? Int((Double(samples) / 44_100.0 * 1_000.0).rounded()) : 0
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
