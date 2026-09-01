import Foundation

public struct PSFFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        let metadata = try PSFTagReader.read(fileURL: fileURL)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
        )
    }
}

enum PSFTagReader {
    private static let maximumTagBytes = 1_048_576

    struct Result {
        let metadata: ScannerMetadata
        let tags: [String: String]

        func merged(with fallback: ScannerMetadata) -> ScannerMetadata {
            ScannerMetadata(
                game: tags["game"] ?? fallback.game,
                song: tags["title"] ?? fallback.song,
                system: fallback.system,
                author: tags["artist"] ?? fallback.author,
                comment: tags["comment"] ?? fallback.comment,
                introLengthMs: fallback.introLengthMs,
                loopLengthMs: fallback.loopLengthMs,
                playLengthMs: tags["length"].map(PSFTagReader.milliseconds) ?? fallback.playLengthMs,
                fadeLengthMs: tags["fade"].map(PSFTagReader.milliseconds) ?? fallback.fadeLengthMs
            )
        }
    }

    static func read(fileURL: URL) throws -> ScannerMetadata? {
        try readResult(fileURL: fileURL)?.metadata
    }

    static func readResult(fileURL: URL) throws -> Result? {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        guard let header = try handle.read(upToCount: 16), header.count == 16,
              header.prefix(3) == Data("PSF".utf8) else { return nil }
        let tagOffset = 16 + UInt64(littleEndianUInt32(header, offset: 4))
            + UInt64(littleEndianUInt32(header, offset: 8))
        let fileSize = UInt64((try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        var tags: [String: String] = [:]
        if tagOffset + 5 <= fileSize {
            try handle.seek(toOffset: tagOffset)
            let length = min(UInt64(maximumTagBytes), fileSize - tagOffset)
            if let footer = try handle.read(upToCount: Int(length)), footer.starts(with: Data("[TAG]".utf8)) {
                tags = parseTags(footer.dropFirst(5))
            }
        }
        let metadata = ScannerMetadata(
            game: tags["game"] ?? "",
            song: tags["title"] ?? fileURL.deletingPathExtension().lastPathComponent,
            system: systemName(for: fileURL.pathExtension.lowercased()),
            author: tags["artist"] ?? "",
            comment: tags["comment"] ?? "",
            introLengthMs: 0,
            loopLengthMs: 0,
            playLengthMs: tags["length"].map { milliseconds($0) } ?? 0,
            fadeLengthMs: tags["fade"].map { milliseconds($0) } ?? 0
        )
        return Result(metadata: metadata, tags: tags)
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

    static func milliseconds(_ value: String) -> Int {
        let components = value.split(separator: ":", omittingEmptySubsequences: false)
        guard let seconds = components.last.flatMap({ Double($0) }) else { return 0 }
        let minutes = components.dropLast().reversed().enumerated().reduce(0.0) {
            $0 + (Double($1.element) ?? 0) * pow(60, Double($1.offset + 1))
        }
        return max(0, Int(((minutes + seconds) * 1_000).rounded()))
    }
}
