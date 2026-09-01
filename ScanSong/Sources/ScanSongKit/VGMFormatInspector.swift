import Foundation
import zlib

public struct VGMFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        let metadata = try VGMTagReader.read(fileURL: fileURL)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
        )
    }
}

private enum VGMTagReader {
    private static let maximumCompressedOutputBytes = 256 * 1_024 * 1_024

    static func read(fileURL: URL) throws -> ScannerMetadata? {
        let extensionName = fileURL.pathExtension.lowercased()
        guard extensionName == "vgm" || extensionName == "vgz" else { return nil }
        let data = try readData(fileURL: fileURL, isCompressed: extensionName == "vgz")
        guard data.count >= 0x40, data.prefix(4) == Data("Vgm ".utf8) else {
            throw ScannerInspectionError.malformedFile(
                "Not a VGM file with a valid header: \(fileURL.lastPathComponent)"
            )
        }
        let gd3Relative = Int(littleEndianUInt32(data, at: 0x14))
        let totalSamples = Int(littleEndianUInt32(data, at: 0x18))
        let loopSamples = Int(littleEndianUInt32(data, at: 0x20))
        let totalMs = milliseconds(samples: totalSamples)
        let loopMs = milliseconds(samples: loopSamples)
        guard gd3Relative > 0 else {
            return ScannerMetadata(
                game: "", song: fileURL.deletingPathExtension().lastPathComponent,
                system: "", author: "", comment: "",
                introLengthMs: max(0, totalMs - loopMs), loopLengthMs: loopMs,
                playLengthMs: totalMs, fadeLengthMs: 0
            )
        }
        let gd3 = 0x14 + gd3Relative
        guard gd3 + 12 <= data.count, data[gd3..<(gd3 + 4)] == Data("Gd3 ".utf8) else { return nil }
        let byteCount = Int(littleEndianUInt32(data, at: gd3 + 8))
        guard byteCount >= 0, gd3 + 12 + byteCount <= data.count else { return nil }
        let strings = decodeUTF16Strings(Data(data[(gd3 + 12)..<(gd3 + 12 + byteCount)]))
        func first(_ index: Int, alternate: Int? = nil) -> String {
            if strings.indices.contains(index), !strings[index].isEmpty { return strings[index] }
            if let alternate, strings.indices.contains(alternate) { return strings[alternate] }
            return ""
        }
        return ScannerMetadata(
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

    private static func readData(fileURL: URL, isCompressed: Bool) throws -> Data {
        guard isCompressed else {
            return try Data(contentsOf: fileURL, options: .mappedIfSafe)
        }

        guard let handle = gzopen(fileURL.path, "rb") else {
            throw ScannerInspectionError.malformedFile(
                "Could not open compressed VGM: \(fileURL.lastPathComponent)"
            )
        }
        defer { _ = gzclose(handle) }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let count = gzread(handle, &buffer, UInt32(buffer.count))
            if count < 0 {
                throw ScannerInspectionError.malformedFile(
                    "Could not decompress VGM: \(fileURL.lastPathComponent)"
                )
            }
            if count == 0 { break }
            guard data.count <= maximumCompressedOutputBytes - Int(count) else {
                throw ScannerInspectionError.malformedFile(
                    "Compressed VGM exceeds the scanner safety limit: \(fileURL.lastPathComponent)"
                )
            }
            data.append(contentsOf: buffer.prefix(Int(count)))
        }
        return data
    }

    private static func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
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
