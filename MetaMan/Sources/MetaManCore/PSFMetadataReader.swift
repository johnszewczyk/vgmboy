import Foundation

enum PSFMetadataReader {
    static let supportedExtensions: Set<String> = [
        "psf", "minipsf", "psf2", "minipsf2",
        "ssf", "minissf", "usf", "miniusf", "2sf", "mini2sf"
    ]

    private static let signature = Data("PSF".utf8)
    private static let tagMarker = Data("[TAG]".utf8)
    private static let maximumParsedTagBytes = 1_048_576

    static func matches(_ data: Data) -> Bool {
        data.count >= 3 && data.prefix(3) == signature
    }

    static func read(
        data: Data,
        formatHint: String?,
        displayName: String?
    ) throws -> MetadataDocument {
        guard data.count >= 16, matches(data) else {
            throw MetadataReadError.malformedFile("Not a PSF file with a valid 16-byte header.")
        }

        let reservedSize = readUInt32(data, at: 4)
        let compressedSize = readUInt32(data, at: 8)
        let tagOffset64 = UInt64(16) + UInt64(reservedSize) + UInt64(compressedSize)
        let tagOffset = tagOffset64 <= UInt64(data.count) ? Int(tagOffset64) : nil
        var tags: [MetadataTag] = []
        var rawTagBlock: Data?
        var diagnostics: [String] = []
        if let tagOffset,
           data.count - tagOffset >= tagMarker.count,
           data[tagOffset..<(tagOffset + tagMarker.count)] == tagMarker {
            rawTagBlock = Data(data[tagOffset..<data.endIndex])
            let availableBytes = data.count - tagOffset - tagMarker.count
            let parsedByteCount = min(availableBytes, maximumParsedTagBytes)
            let tagBytes = Data(data[(tagOffset + tagMarker.count)..<(tagOffset + tagMarker.count + parsedByteCount)])
            tags = parseTags(tagBytes)
            if String(data: tagBytes, encoding: .utf8) == nil {
                diagnostics.append("PSF tag text contains invalid UTF-8; replacement characters were used.")
            }
            if availableBytes > maximumParsedTagBytes {
                diagnostics.append("PSF tag text exceeds the 1 MiB parsing limit; original bytes were retained.")
            }
        } else if tagOffset64 > UInt64(data.count) {
            diagnostics.append("PSF tag offset points beyond the available file bytes.")
        }

        func tag(_ name: String) -> String? {
            let key = name.uppercased()
            return tags.lazy
                .filter { $0.normalizedName == key }
                .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
        }

        let extensionName = canonicalExtension(formatHint)
        let title = tag("title") ?? displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let length = tag("length").map(milliseconds) ?? 0
        let fade = tag("fade").map(milliseconds) ?? 0

        var facts = [
            "psfVersionByte": String(format: "0x%02X", data[3]),
            "reservedSize": String(reservedSize),
            "compressedSize": String(compressedSize),
            "crc32": String(readUInt32(data, at: 12)),
            "tagOffset": tagOffset.map(String.init) ?? "out-of-range"
        ]
        if let rawTagBlock {
            facts["tagBlockBytes"] = String(rawTagBlock.count)
        }

        return MetadataDocument(
            format: extensionName ?? "psf",
            fields: MetadataFields(
                title: title,
                game: tag("game"),
                system: systemName(for: extensionName),
                artist: tag("artist"),
                album: tag("album"),
                date: tag("date"),
                year: tag("year"),
                genre: tag("genre"),
                comment: tag("comment"),
                copyright: tag("copyright"),
                encodedBy: tag("psfby") ?? tag("encodedby")
            ),
            tags: tags,
            rawTagBlock: rawTagBlock,
            sourceEncoding: rawTagBlock == nil ? nil : "UTF-8",
            timing: MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: length, fadeLengthMs: fade),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func parseTags(_ bytes: Data) -> [MetadataTag] {
        String(decoding: bytes, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                guard let equals = line.firstIndex(of: "=") else { return nil }
                let name = line[..<equals].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
                return MetadataTag(name: String(name), value: String(value))
            }
    }

    private static func canonicalExtension(_ hint: String?) -> String? {
        guard let hint else { return nil }
        let normalizedHint = hint.lowercased()
        let value = normalizedHint.hasPrefix(".") ? String(normalizedHint.dropFirst()) : normalizedHint
        guard supportedExtensions.contains(value) else { return nil }
        return value.hasPrefix("mini") ? String(value.dropFirst(4)) : value
    }

    private static func systemName(for format: String?) -> String? {
        switch format {
        case "psf": "Sony PlayStation"
        case "psf2": "Sony PlayStation 2"
        case "ssf": "Sega Saturn"
        case "usf": "Nintendo 64"
        case "2sf": "Nintendo DS"
        default: nil
        }
    }

    private static func milliseconds(_ value: String) -> Int {
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard let seconds = components.last.flatMap({ Double($0) }), seconds.isFinite else { return 0 }
        let minutes = components.dropLast().reversed().enumerated().reduce(0.0) { total, component in
            guard let value = Double(component.element), value.isFinite else { return total }
            return total + value * pow(60, Double(component.offset + 1))
        }
        let totalMilliseconds = (minutes + seconds) * 1_000
        guard totalMilliseconds.isFinite else { return 0 }
        guard totalMilliseconds > 0 else { return 0 }
        guard totalMilliseconds < Double(Int.max) else { return Int.max }
        return Int(totalMilliseconds.rounded())
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }
}
