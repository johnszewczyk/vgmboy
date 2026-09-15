import Foundation

/// Reads PSID/RSID identity and header facts without starting the playback core.
public enum SIDMetadataReader {
    private static let v1HeaderSize = 0x76
    private static let extendedHeaderSize = 0x7C
    private static let magicValues = ["PSID", "RSID"]

    public static func matches(_ data: Data) -> Bool {
        guard data.count >= 4, let magic = String(data: data.prefix(4), encoding: .ascii) else {
            return false
        }
        return magicValues.contains(magic)
    }

    public static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    public static func read(data: Data, displayName: String = "SID") throws -> MetadataDocument {
        guard matches(data),
              let magic = String(data: data.prefix(4), encoding: .ascii),
              let version = bigEndianUInt16(data, at: 0x04) else {
            throw MetadataReadError.malformedFile(
                "Not a SID file with a valid PSID/RSID signature and version field: \(displayName)"
            )
        }
        let expectedHeaderLength = version == 1 ? v1HeaderSize : extendedHeaderSize
        guard data.count >= expectedHeaderLength else {
            throw MetadataReadError.malformedFile(
                "Truncated PSID/RSID v\(version) header in \(displayName); expected \(expectedHeaderLength) bytes."
            )
        }

        // PSID/RSID stores the three 32-byte identity fields consecutively;
        // v2+ appends technical flags after this v1 header region.
        let sourceTitle = text(data[0x16..<0x36])
        let artist = text(data[0x36..<0x56])
        let released = text(data[0x56..<0x76])
        let fallbackTitle = URL(fileURLWithPath: displayName)
            .deletingPathExtension()
            .lastPathComponent
        let title = sourceTitle.isEmpty ? fallbackTitle : sourceTitle
        let rawHeader = Data(data.prefix(expectedHeaderLength))

        var tags: [MetadataTag] = []
        if !sourceTitle.isEmpty { tags.append(MetadataTag(name: "Title", value: sourceTitle)) }
        if !artist.isEmpty { tags.append(MetadataTag(name: "Author", value: artist)) }
        if !released.isEmpty { tags.append(MetadataTag(name: "Released", value: released)) }

        var facts: [String: String] = [
            "format": "SID",
            "magicID": magic,
            "version": String(version),
            "durationSource": "none"
        ]
        if let value = bigEndianUInt16(data, at: 0x06) { facts["dataOffset"] = String(value) }
        if let value = bigEndianUInt16(data, at: 0x08) { facts["loadAddress"] = String(format: "0x%04X", value) }
        if let value = bigEndianUInt16(data, at: 0x0A) { facts["initAddress"] = String(format: "0x%04X", value) }
        if let value = bigEndianUInt16(data, at: 0x0C) { facts["playAddress"] = String(format: "0x%04X", value) }
        if let value = bigEndianUInt16(data, at: 0x0E) { facts["songCount"] = String(value) }
        if let value = bigEndianUInt16(data, at: 0x10) { facts["startSong"] = String(value) }
        if let value = bigEndianUInt32(data, at: 0x12) { facts["speedBits"] = String(format: "0x%08X", value) }
        if sourceTitle.isEmpty { facts["titleSource"] = "filename" }

        return MetadataDocument(
            format: "sid",
            fields: MetadataFields(
                title: title,
                game: sourceTitle.isEmpty ? nil : sourceTitle,
                system: "Commodore 64",
                artist: artist.isEmpty ? nil : artist,
                comment: released.isEmpty ? nil : released,
                copyright: released.isEmpty ? nil : released
            ),
            tags: tags,
            rawMetadataBlocks: ["sidHeader": rawHeader],
            sourceEncoding: "Windows-1252",
            timing: MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 0, fadeLengthMs: 0),
            technicalFacts: facts
        )
    }

    private static func bigEndianUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset + 2 <= data.count else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func bigEndianUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }

    private static func text(_ bytes: Data.SubSequence) -> String {
        let bytes = Data(bytes.prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
