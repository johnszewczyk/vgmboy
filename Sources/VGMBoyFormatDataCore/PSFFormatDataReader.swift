import Foundation

public enum PSFFormatDataReader {
    private static let maximumTagBytes = 1_048_576

    public struct Result: Sendable, Equatable {
        public let metadata: FormatMetadata
        public let tags: [String: String]

        public init(metadata: FormatMetadata, tags: [String: String]) {
            self.metadata = metadata
            self.tags = tags
        }
    }

    public static func read(
        data: Data,
        pathExtension: String,
        displayName: String
    ) -> FormatMetadata? {
        readResult(data: data, pathExtension: pathExtension, displayName: displayName)?.metadata
    }

    public static func readResult(
        data: Data,
        pathExtension: String,
        displayName: String
    ) -> Result? {
        guard data.count >= 16,
              data.prefix(3) == Data("PSF".utf8) else { return nil }

        let tagOffset = 16 + UInt64(littleEndianUInt32(data, offset: 4))
            + UInt64(littleEndianUInt32(data, offset: 8))
        var tags: [String: String] = [:]
        if tagOffset + 5 <= UInt64(data.count) {
            let start = Int(tagOffset)
            let length = min(maximumTagBytes, data.count - start)
            let footer = data[start..<(start + length)]
            if footer.starts(with: Data("[TAG]".utf8)) {
                tags = parseTags(footer.dropFirst(5))
            }
        }

        let metadata = FormatMetadata(
            game: tags["game"] ?? "",
            song: tags["title"] ?? URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent,
            system: systemName(for: pathExtension.lowercased()),
            author: tags["artist"] ?? "",
            comment: tags["comment"] ?? "",
            introLengthMs: 0,
            loopLengthMs: 0,
            playLengthMs: tags["length"].map(milliseconds) ?? 0,
            fadeLengthMs: tags["fade"].map(milliseconds) ?? 0
        )
        return Result(metadata: metadata, tags: tags)
    }

    public static func milliseconds(_ value: String) -> Int {
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard let seconds = components.last.flatMap({ Double($0) }) else { return 0 }
        let minutes = components.dropLast().reversed().enumerated().reduce(0.0) {
            $0 + (Double($1.element) ?? 0) * pow(60, Double($1.offset + 1))
        }
        return max(0, Int(((minutes + seconds) * 1_000).rounded()))
    }

    private static func littleEndianUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func parseTags(_ bytes: Data.SubSequence) -> [String: String] {
        String(decoding: bytes, as: UTF8.self).split(whereSeparator: \.isNewline).reduce(into: [:]) { result, line in
            guard let equals = line.firstIndex(of: "=") else { return }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            if !key.isEmpty, !value.isEmpty, result[key] == nil { result[key] = value }
        }
    }

    private static func systemName(for extensionName: String) -> String {
        switch extensionName {
        case "gsf", "minigsf": return "Game Boy Advance"
        case "qsf", "miniqsf": return "Capcom QSound"
        case "psf", "minipsf": return "Sony PlayStation"
        case "psf2", "minipsf2": return "Sony PlayStation 2"
        case "usf", "miniusf": return "Nintendo 64"
        case "2sf", "mini2sf": return "Nintendo DS"
        case "ssf", "minissf": return "Sega Saturn"
        default: return ""
        }
    }
}
