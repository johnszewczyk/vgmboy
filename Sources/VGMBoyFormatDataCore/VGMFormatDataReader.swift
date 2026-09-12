import Foundation

/// Reads VGM headers/GD3 and sample timing from already-decoded VGM bytes.
/// VGZ decompression is intentionally left to the caller's bounded I/O layer.
public enum VGMFormatDataReader {
    public static func read(data: Data, displayName: String) throws -> FormatMetadata {
        guard data.count >= 0x40, data.prefix(4) == Data("Vgm ".utf8) else {
            throw FormatDataError.malformed("Not a VGM file with a valid header: \(displayName)")
        }

        let gd3Relative = Int(littleEndianUInt32(data, at: 0x14))
        let totalSamples = Int(littleEndianUInt32(data, at: 0x18))
        let loopSamples = Int(littleEndianUInt32(data, at: 0x20))
        let totalMs = milliseconds(samples: totalSamples)
        let loopMs = milliseconds(samples: loopSamples)
        guard gd3Relative > 0 else {
            return FormatMetadata(
                game: "",
                song: URL(fileURLWithPath: displayName).deletingPathExtension().lastPathComponent,
                system: "",
                author: "",
                comment: "",
                introLengthMs: max(0, totalMs - loopMs),
                loopLengthMs: loopMs,
                playLengthMs: totalMs,
                fadeLengthMs: 0
            )
        }

        let gd3 = 0x14 + gd3Relative
        guard gd3 + 12 <= data.count,
              data[gd3..<(gd3 + 4)] == Data("Gd3 ".utf8) else {
            throw FormatDataError.malformed("VGM GD3 pointer is invalid: \(displayName)")
        }
        let byteCount = Int(littleEndianUInt32(data, at: gd3 + 8))
        guard byteCount % 2 == 0, gd3 + 12 + byteCount <= data.count else {
            throw FormatDataError.malformed("VGM GD3 payload is invalid: \(displayName)")
        }
        let strings = decodeUTF16Strings(Data(data[(gd3 + 12)..<(gd3 + 12 + byteCount)]))
        func first(_ index: Int, alternate: Int? = nil) -> String {
            if strings.indices.contains(index), !strings[index].isEmpty { return strings[index] }
            if let alternate, strings.indices.contains(alternate) { return strings[alternate] }
            return ""
        }
        return FormatMetadata(
            game: first(2, alternate: 3),
            song: first(0, alternate: 1),
            system: first(4, alternate: 5),
            author: first(6, alternate: 7),
            comment: first(10),
            introLengthMs: max(0, totalMs - loopMs),
            loopLengthMs: loopMs,
            playLengthMs: totalMs,
            fadeLengthMs: 0
        )
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func milliseconds(samples: Int) -> Int {
        samples > 0 ? Int((Double(samples) / 44_100.0 * 1_000.0).rounded()) : 0
    }

    private static func decodeUTF16Strings(_ data: Data) -> [String] {
        var values: [String] = []
        var units: [UInt16] = []
        var offset = 0
        while offset + 1 < data.count {
            let unit = UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
            offset += 2
            if unit == 0 {
                values.append(String(decoding: units, as: UTF16.self).trimmingCharacters(in: .whitespacesAndNewlines))
                units.removeAll(keepingCapacity: true)
            } else {
                units.append(unit)
            }
        }
        if !units.isEmpty { values.append(String(decoding: units, as: UTF16.self)) }
        return values
    }
}
