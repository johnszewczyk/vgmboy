import Foundation

/// Bounded ICE! container expansion for metadata readers. This implements the
/// reverse bitstream format directly; it does not call or link a playback core.
enum ICEMetadataDecompressor {
    static let headerSize = 12
    static let maximumOutputSize = 256 * 1024 * 1024

    static func matches(_ data: Data) -> Bool {
        data.count >= headerSize && data.prefix(4) == Data("ICE!".utf8)
    }

    static func decompress(_ data: Data) throws -> Data {
        guard matches(data),
              let packedSize = readUInt32BE(data, at: 4),
              let unpackedSize = readUInt32BE(data, at: 8) else {
            throw malformed("ICE! header is truncated or invalid.")
        }
        let packedCount = Int(packedSize)
        let outputCount = Int(unpackedSize)
        guard packedCount > headerSize,
              packedCount <= data.count,
              outputCount > 0,
              outputCount <= maximumOutputSize else {
            throw malformed("ICE! compressed or decompressed size is outside the supported bounds.")
        }

        var output = [UInt8](repeating: 0, count: outputCount)
        var outputCursor = outputCount
        var bits = ReverseBitReader(data: data, cursor: packedCount - 1)

        while outputCursor > 0 {
            if try bits.readBit() {
                let count = try bits.readLiteralLength()
                guard count > 0, count <= outputCursor else {
                    throw malformed("ICE! literal run exceeds the declared output size.")
                }
                guard bits.cursor - count >= headerSize else {
                    throw malformed("ICE! literal run exceeds the packed input.")
                }
                bits.cursor -= count
                outputCursor -= count
                for index in 0..<count {
                    output[outputCursor + index] = data[bits.cursor + index]
                }
            }

            guard outputCursor > 0 else { break }
            let count = try bits.readBackReferenceLength()
            let distance = try bits.readBackReferenceDistance(length: count)
            guard count > 0, count <= outputCursor else {
                throw malformed("ICE! back-reference exceeds the declared output size.")
            }
            outputCursor -= count
            let source = outputCursor + count + distance
            guard source >= 0, source <= output.count,
                  count <= output.count - source else {
                throw malformed("ICE! back-reference points outside the expanded data.")
            }

            for index in stride(from: count - 1, through: 0, by: -1) {
                output[outputCursor + index] = output[source + index]
            }
        }

        return Data(output)
    }

    private struct ReverseBitReader {
        let data: Data
        var cursor: Int
        private var mask: UInt8

        init(data: Data, cursor: Int) {
            self.data = data
            self.cursor = cursor
            self.mask = data[cursor]
        }

        mutating func readBit() throws -> Bool {
            var bit = mask & 0x80 != 0
            mask = mask &<< 1
            if mask == 0 {
                cursor -= 1
                guard cursor >= ICEMetadataDecompressor.headerSize else {
                    throw malformed("ICE! bitstream ended before the output was complete.")
                }
                mask = data[cursor]
                bit = mask & 0x80 != 0
                mask = (mask &<< 1) | 1
            }
            return bit
        }

        mutating func readBits(_ count: Int) throws -> Int {
            var value = 0
            for _ in 0..<count {
                value = (value << 1) | (try readBit() ? 1 : 0)
            }
            return value
        }

        mutating func readLiteralLength() throws -> Int {
            let bitWidths = [1, 2, 2, 3, 8, 15]
            let terminalValues = [1, 3, 3, 7, 0xFF, 0x7FFF]
            let increments = [1, 2, 5, 8, 15, 270, 270]
            var index = 0
            var value = 0
            while index < bitWidths.count {
                value = try readBits(bitWidths[index])
                if value != terminalValues[index] { break }
                index += 1
            }
            return value + increments[index]
        }

        mutating func readBackReferenceLength() throws -> Int {
            let bitWidths = [0, 0, 1, 2, 10]
            let increments = [2, 3, 4, 6, 10]
            var index = 0
            while index < 4, try readBit() { index += 1 }
            let extra = bitWidths[index] == 0 ? 0 : try readBits(bitWidths[index])
            return extra + increments[index]
        }

        mutating func readBackReferenceDistance(length: Int) throws -> Int {
            if length == 2 {
                if try readBit() { return try readBits(9) + 0x3F }
                return try readBits(6) - 1
            }
            let first = try readBit()
            let distance: Int
            if !first {
                distance = try readBits(8) + 31
            } else if try readBit() == false {
                distance = try readBits(5) - 1
            } else {
                distance = try readBits(12) + 287
            }
            return distance < 0 ? distance + 2 - length : distance
        }
    }

    private static func readUInt32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return (UInt32(data[offset]) << 24)
            | (UInt32(data[offset + 1]) << 16)
            | (UInt32(data[offset + 2]) << 8)
            | UInt32(data[offset + 3])
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
