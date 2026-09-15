import Foundation

/// Computes the checksum defined by the Zstandard seekable-frame format:
/// the low 32 bits of XXH64 over the decompressed TAR-frame bytes.
public enum UACSeekableFrameChecksum {
    private static let prime1: UInt64 = 11_400_714_785_074_694_791
    private static let prime2: UInt64 = 14_029_467_366_897_019_727
    private static let prime3: UInt64 = 1_609_587_929_392_839_161
    private static let prime4: UInt64 = 9_650_029_242_287_828_579
    private static let prime5: UInt64 = 2_870_177_450_012_600_261

    public static func value(for data: Data) -> UInt32 {
        UInt32(truncatingIfNeeded: digest(data))
    }

    public static func matches(_ data: Data, checksum: UInt32) -> Bool {
        value(for: data) == checksum
    }

    private static func digest(_ data: Data) -> UInt64 {
        let bytes = Array(data)
        var offset = 0
        var hash: UInt64
        if bytes.count >= 32 {
            var v1 = prime1 &+ prime2
            var v2 = prime2
            var v3: UInt64 = 0
            var v4 = 0 &- prime1
            while offset <= bytes.count - 32 {
                v1 = round(v1, read64(bytes, offset)); offset += 8
                v2 = round(v2, read64(bytes, offset)); offset += 8
                v3 = round(v3, read64(bytes, offset)); offset += 8
                v4 = round(v4, read64(bytes, offset)); offset += 8
            }
            hash = rotateLeft(v1, 1) &+ rotateLeft(v2, 7) &+ rotateLeft(v3, 12) &+ rotateLeft(v4, 18)
            hash = merge(hash, v1)
            hash = merge(hash, v2)
            hash = merge(hash, v3)
            hash = merge(hash, v4)
        } else {
            hash = prime5
        }

        hash &+= UInt64(bytes.count)
        while offset <= bytes.count - 8 {
            hash ^= round(0, read64(bytes, offset))
            hash = rotateLeft(hash, 27) &* prime1 &+ prime4
            offset += 8
        }
        if offset <= bytes.count - 4 {
            hash ^= UInt64(read32(bytes, offset)) &* prime1
            hash = rotateLeft(hash, 23) &* prime2 &+ prime3
            offset += 4
        }
        while offset < bytes.count {
            hash ^= UInt64(bytes[offset]) &* prime5
            hash = rotateLeft(hash, 11) &* prime1
            offset += 1
        }
        hash ^= hash >> 33
        hash &*= prime2
        hash ^= hash >> 29
        hash &*= prime3
        hash ^= hash >> 32
        return hash
    }

    private static func round(_ accumulator: UInt64, _ lane: UInt64) -> UInt64 {
        rotateLeft(accumulator &+ lane &* prime2, 31) &* prime1
    }

    private static func merge(_ accumulator: UInt64, _ value: UInt64) -> UInt64 {
        (accumulator ^ round(0, value)) &* prime1 &+ prime4
    }

    private static func rotateLeft(_ value: UInt64, _ count: UInt64) -> UInt64 {
        (value << count) | (value >> (64 - count))
    }

    private static func read64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        (0..<8).reduce(UInt64.zero) { $0 | (UInt64(bytes[offset + $1]) << UInt64($1 * 8)) }
    }

    private static func read32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32.zero) { $0 | (UInt32(bytes[offset + $1]) << UInt32($1 * 8)) }
    }
}
