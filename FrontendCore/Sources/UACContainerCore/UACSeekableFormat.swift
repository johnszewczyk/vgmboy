import Foundation

/// One independently compressed Zstandard frame in a seekable payload.
/// Offsets are relative to the start of the compressed payload and the start
/// of the concatenated, decompressed TAR stream, respectively.
public struct UACZstandardSeekableFrame: Equatable, Sendable {
    public let compressedOffset: UInt64
    public let compressedByteCount: UInt32
    public let tarOffset: UInt64
    public let tarByteCount: UInt32
    public let checksum: UInt32?
}

/// Parsed Zstandard seek table for the concatenated frames that reconstruct a
/// TAR stream. This validates indexing only; frame decompression is supplied
/// by the consuming archive/player layer.
public struct UACZstandardSeekTable: Equatable, Sendable {
    public let frames: [UACZstandardSeekableFrame]
    public let compressedFrameByteCount: UInt64
    public let tarByteCount: UInt64

    public static let skippableFrameMagic: UInt32 = 0x184D2A5E
    public static let seekableFooterMagic: UInt32 = 0x8F92EAB1
    public static let maximumFrameCount: UInt32 = 1_000_000
    /// UAC's reader-side safety limit is smaller than the seek-table format's
    /// theoretical 1 GiB maximum so one requested frame cannot demand extreme
    /// memory. The package builder uses a 4 MiB default.
    public static let maximumFrameTarByteCount: UInt32 = 64 * 1024 * 1024

    /// Returns the independently compressed frames intersecting a byte range
    /// in the decompressed TAR stream.
    public func frameIndexes(intersectingTarRange range: Range<UInt64>) -> [Int] {
        guard range.lowerBound < range.upperBound else { return [] }
        var lower = 0
        var upper = frames.count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            let frame = frames[middle]
            let frameEnd = frame.tarOffset + UInt64(frame.tarByteCount)
            if frameEnd <= range.lowerBound {
                lower = middle + 1
            } else {
                upper = middle
            }
        }

        var indexes: [Int] = []
        var index = lower
        while index < frames.count, frames[index].tarOffset < range.upperBound {
            let frame = frames[index]
            if frame.tarByteCount > 0,
               frame.tarOffset + UInt64(frame.tarByteCount) > range.lowerBound {
                indexes.append(index)
            }
            index += 1
        }
        return indexes
    }

    static func read(
        from handle: FileHandle,
        payloadOffset: UInt64,
        payloadByteCount: UInt64
    ) throws -> UACZstandardSeekTable {
        let footerByteCount: UInt64 = 9
        let seekTableHeaderByteCount: UInt64 = 8
        guard payloadByteCount >= seekTableHeaderByteCount + footerByteCount else {
            throw UACContainerError.invalidSeekTable("Seek table payload is truncated.")
        }

        let (payloadEnd, payloadEndOverflow) = payloadOffset.addingReportingOverflow(payloadByteCount)
        guard !payloadEndOverflow, payloadEnd >= footerByteCount else {
            throw UACContainerError.invalidSeekTable("Payload bounds overflow.")
        }

        let footerOffset = payloadEnd - footerByteCount
        try handle.seek(toOffset: footerOffset)
        let footer = try Self.readExactly(Int(footerByteCount), from: handle)
        guard Self.uint32LE(footer, at: 5) == seekableFooterMagic else {
            throw UACContainerError.invalidSeekTable("Missing Zstandard seekable footer.")
        }

        let frameCount = Self.uint32LE(footer, at: 0)
        guard frameCount > 0, frameCount <= maximumFrameCount else {
            throw UACContainerError.invalidSeekTable("Seek table frame count is outside supported bounds.")
        }
        let descriptor = footer[4]
        guard descriptor & 0x7C == 0 else {
            throw UACContainerError.invalidSeekTable("Seek table uses unsupported reserved descriptor bits.")
        }
        let hasChecksums = descriptor & 0x80 != 0
        let entryByteCount = hasChecksums ? 12 : 8
        let (allEntriesByteCount, entriesOverflow) = UInt64(frameCount)
            .multipliedReportingOverflow(by: UInt64(entryByteCount))
        guard !entriesOverflow, allEntriesByteCount <= UInt64(Int.max) else {
            throw UACContainerError.invalidSeekTable("Seek table entry byte count overflows.")
        }
        let (seekTableFrameSize, frameSizeOverflow) = allEntriesByteCount.addingReportingOverflow(footerByteCount)
        guard !frameSizeOverflow, seekTableFrameSize <= UInt64(UInt32.max) else {
            throw UACContainerError.invalidSeekTable("Seek table frame is too large.")
        }
        let (wholeSeekTableByteCount, wholeTableOverflow) = seekTableFrameSize
            .addingReportingOverflow(seekTableHeaderByteCount)
        guard !wholeTableOverflow, wholeSeekTableByteCount <= payloadByteCount else {
            throw UACContainerError.invalidSeekTable("Seek table extends before the compressed payload.")
        }
        let tableStartOffset = payloadEnd - wholeSeekTableByteCount
        let tableStartInPayload = tableStartOffset - payloadOffset

        try handle.seek(toOffset: tableStartOffset)
        let seekTableHeader = try Self.readExactly(Int(seekTableHeaderByteCount), from: handle)
        guard Self.uint32LE(seekTableHeader, at: 0) == skippableFrameMagic,
              UInt64(Self.uint32LE(seekTableHeader, at: 4)) == seekTableFrameSize else {
            throw UACContainerError.invalidSeekTable("Malformed seek-table skippable frame header.")
        }

        let entries = try Self.readExactly(Int(allEntriesByteCount), from: handle)
        let trailingFooter = try Self.readExactly(Int(footerByteCount), from: handle)
        guard trailingFooter == footer else {
            throw UACContainerError.invalidSeekTable("Seek-table footer changed while reading.")
        }

        var frames: [UACZstandardSeekableFrame] = []
        frames.reserveCapacity(Int(frameCount))
        var compressedOffset: UInt64 = 0
        var tarOffset: UInt64 = 0
        for index in 0..<Int(frameCount) {
            let entryOffset = index * entryByteCount
            let compressedByteCount = Self.uint32LE(entries, at: entryOffset)
            let tarByteCount = Self.uint32LE(entries, at: entryOffset + 4)
            guard compressedByteCount > 0,
                  tarByteCount <= maximumFrameTarByteCount else {
                throw UACContainerError.invalidSeekTable("Frame \(index) has an invalid size.")
            }
            let checksum = hasChecksums
                ? Self.uint32LE(entries, at: entryOffset + 8)
                : nil
            frames.append(UACZstandardSeekableFrame(
                compressedOffset: compressedOffset,
                compressedByteCount: compressedByteCount,
                tarOffset: tarOffset,
                tarByteCount: tarByteCount,
                checksum: checksum
            ))
            let (nextCompressedOffset, compressedOverflow) = compressedOffset
                .addingReportingOverflow(UInt64(compressedByteCount))
            let (nextTarOffset, tarOverflow) = tarOffset
                .addingReportingOverflow(UInt64(tarByteCount))
            guard !compressedOverflow, !tarOverflow else {
                throw UACContainerError.invalidSeekTable("Frame offsets overflow.")
            }
            compressedOffset = nextCompressedOffset
            tarOffset = nextTarOffset
        }

        guard compressedOffset == tableStartInPayload else {
            throw UACContainerError.invalidSeekTable("Frame sizes do not reach the seek table.")
        }
        return UACZstandardSeekTable(
            frames: frames,
            compressedFrameByteCount: compressedOffset,
            tarByteCount: tarOffset
        )
    }

    private static func readExactly(_ byteCount: Int, from handle: FileHandle) throws -> Data {
        guard let data = try handle.read(upToCount: byteCount), data.count == byteCount else {
            throw UACContainerError.invalidSeekTable("Unexpected end of seek table.")
        }
        return data
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32.zero) { value, index in
            value | (UInt32(data[offset + index]) << (UInt32(index) * 8))
        }
    }
}
