import Foundation

public struct SIDFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let metadata = try SIDMetadataReader.read(fileURL: fileURL)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
        )
    }
}

private enum SIDMetadataReader {
    private static let nameOffset = 0x16
    private static let nameLength = 32
    private static let authorOffset = 0x2E
    private static let authorLength = 32
    private static let copyrightOffset = 0x46
    private static let copyrightLength = 32
    private static let palPlayLengthOffset = 0x76
    private static let ntscPlayLengthOffset = 0x78

    static func read(fileURL: URL) throws -> ScannerMetadata? {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard data.count >= 0x7A, let magic = String(data: data.prefix(4), encoding: .ascii),
              magic == "PSID" || magic == "RSID" else {
            throw ScannerInspectionError.malformedFile("Not a SID file with a valid PSID/RSID header: \(fileURL.lastPathComponent)")
        }
        let version = Int(bigEndianUInt16(data, at: 0x04) ?? 0)
        var playLengthMs = 0
        if version >= 2 {
            let palSeconds = Int(bigEndianUInt16(data, at: palPlayLengthOffset) ?? 0)
            let ntscSeconds = Int(bigEndianUInt16(data, at: ntscPlayLengthOffset) ?? 0)
            playLengthMs = max(palSeconds, ntscSeconds) * 1_000
        }
        let name = text(data[nameOffset..<(nameOffset + nameLength)])
        let author = text(data[authorOffset..<(authorOffset + authorLength)])
        let copyright = text(data[copyrightOffset..<(copyrightOffset + copyrightLength)])
        return ScannerMetadata(
            game: name,
            song: name.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : name,
            system: "Commodore 64",
            author: author,
            comment: copyright,
            introLengthMs: 0,
            loopLengthMs: 0,
            playLengthMs: playLengthMs,
            fadeLengthMs: 0
        )
    }

    private static func bigEndianUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func text(_ bytes: some Collection<UInt8>) -> String {
        let bytes = Data(bytes.prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
