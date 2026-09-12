import Foundation

public enum SIDFormatDataReader {
    public static func read(data: Data, displayName: String) throws -> FormatMetadata? {
        guard data.count >= 0x7A, let magic = String(data: data.prefix(4), encoding: .ascii),
              magic == "PSID" || magic == "RSID" else {
            throw FormatDataError.malformed("Not a SID file with a valid PSID/RSID header: \(displayName)")
        }

        let version = Int(bigEndianUInt16(data, at: 0x04) ?? 0)
        var playLengthMs = 0
        if version >= 2 {
            let palSeconds = Int(bigEndianUInt16(data, at: 0x76) ?? 0)
            let ntscSeconds = Int(bigEndianUInt16(data, at: 0x78) ?? 0)
            playLengthMs = max(palSeconds, ntscSeconds) * 1_000
        }
        let name = text(data[0x16..<0x36])
        let author = text(data[0x2E..<0x4E])
        let copyright = text(data[0x46..<0x66])
        return FormatMetadata(
            game: name,
            song: name.isEmpty ? URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent : name,
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

    private static func text(_ bytes: Data.SubSequence) -> String {
        let bytes = Data(bytes.prefix { $0 != 0 })
        return (String(data: bytes, encoding: .windowsCP1252) ?? String(decoding: bytes, as: UTF8.self))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
