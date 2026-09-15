import Foundation

/// Presents one TAR member as a byte-addressable file without extracting it.
/// Zstandard frame decoding is injected so the app can use its packaged codec.
/// The cache contains only decompressed frames and is bounded in memory.
public final class UACSeekableMemberFile: @unchecked Sendable {
    public static let defaultMaximumCachedFrames = 4
    public static let maximumCachedFrames = 32
    public static let maximumCachedDecompressedBytes = 64 * 1024 * 1024

    public let member: UACMember
    public let size: UInt64

    private let url: URL
    private let container: UACContainer
    private let memberDataOffset: UInt64
    private let frameCacheLimit: Int
    private let decompressFrame: @Sendable (Data, UInt32?) throws -> Data
    private let lock = NSLock()
    private var frameCache: [Int: Data] = [:]
    private var recentFrameIndexes: [Int] = []

    /// Creates a read-only virtual file for a seekable UAC member.
    /// `decompressFrame` must decode exactly one independent Zstandard frame
    /// and validate the supplied seek-table checksum when it is non-nil.
    public init(
        url: URL,
        memberPath: String,
        maximumCachedFrames: Int = UACSeekableMemberFile.defaultMaximumCachedFrames,
        decompressManifestFrame: UACManifestFrameDecoder? = nil,
        decompressFrame: @escaping @Sendable (Data, UInt32?) throws -> Data
    ) throws {
        guard (1...Self.maximumCachedFrames).contains(maximumCachedFrames) else {
            throw UACContainerError.invalidSeekFrameCacheLimit
        }

        let standardizedURL = url.standardizedFileURL
        let container = try UACContainerReader.read(
            from: standardizedURL,
            decompressManifestFrame: decompressManifestFrame
        )
        guard container.manifest.payload.format == "tar+zstd-seekable",
              container.seekTable != nil else {
            throw UACContainerError.seekablePayloadRequired
        }
        guard let member = container.manifest.members.first(where: { $0.path == memberPath }) else {
            throw UACContainerError.memberNotFound(memberPath)
        }
        guard let memberDataOffset = member.tarDataOffset else {
            throw UACContainerError.memberMissingSeekOffset(member.path)
        }

        self.url = standardizedURL
        self.container = container
        self.member = member
        self.size = member.byteSize
        self.memberDataOffset = memberDataOffset
        self.frameCacheLimit = maximumCachedFrames
        self.decompressFrame = decompressFrame
    }

    /// Reads up to `byteCount` bytes at `offset`; reads at EOF return empty,
    /// and reads crossing EOF return the remaining member bytes.
    public func read(at offset: UInt64, byteCount: Int) throws -> Data {
        guard byteCount >= 0, offset <= size else {
            throw UACContainerError.invalidMemberReadRange
        }
        guard byteCount > 0, offset < size else { return Data() }

        let requestedCount = min(UInt64(byteCount), size - offset)
        let (tarStart, startOverflow) = memberDataOffset.addingReportingOverflow(offset)
        let (tarEnd, endOverflow) = tarStart.addingReportingOverflow(requestedCount)
        guard !startOverflow, !endOverflow else {
            throw UACContainerError.invalidMemberReadRange
        }

        lock.lock()
        defer { lock.unlock() }

        guard let seekTable = container.seekTable else {
            throw UACContainerError.seekablePayloadRequired
        }
        let matchingIndexes = seekTable.frameIndexes(intersectingTarRange: tarStart..<tarEnd)
        var result = Data()
        result.reserveCapacity(Int(requestedCount))

        for frameIndex in matchingIndexes {
            let frame = seekTable.frames[frameIndex]
            let decoded = try decodedFrame(at: frameIndex, frame: frame)
            let intersectionStart = max(tarStart, frame.tarOffset)
            let intersectionEnd = min(tarEnd, frame.tarOffset + UInt64(frame.tarByteCount))
            let localStart = Int(intersectionStart - frame.tarOffset)
            let localEnd = Int(intersectionEnd - frame.tarOffset)
            result.append(contentsOf: decoded[localStart..<localEnd])
        }

        guard result.count == Int(requestedCount) else {
            throw UACContainerError.memberRangeNotCovered
        }
        return result
    }

    private func decodedFrame(at index: Int, frame: UACZstandardSeekableFrame) throws -> Data {
        if let cached = frameCache[index] {
            markRecentlyUsed(index)
            return cached
        }

        let compressedOffset = container.payloadOffset.addingReportingOverflow(frame.compressedOffset)
        guard !compressedOffset.overflow else {
            throw UACContainerError.seekableFrameReadFailed(index)
        }

        let compressed: Data
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: compressedOffset.partialValue)
            guard let bytes = try handle.read(upToCount: Int(frame.compressedByteCount)),
                  bytes.count == Int(frame.compressedByteCount) else {
                throw UACContainerError.seekableFrameReadFailed(index)
            }
            compressed = bytes
        } catch {
            throw UACContainerError.seekableFrameReadFailed(index)
        }

        let decoded: Data
        do {
            decoded = try decompressFrame(compressed, frame.checksum)
        } catch {
            throw UACContainerError.seekableFrameDecodeFailed(index)
        }
        guard decoded.count == Int(frame.tarByteCount) else {
            throw UACContainerError.seekableFrameSizeMismatch(index)
        }

        frameCache[index] = decoded
        markRecentlyUsed(index)
        while recentFrameIndexes.count > frameCacheLimit
            || frameCache.values.reduce(0, { $0 + $1.count }) > Self.maximumCachedDecompressedBytes {
            let evictedIndex = recentFrameIndexes.removeFirst()
            frameCache.removeValue(forKey: evictedIndex)
        }
        return decoded
    }

    private func markRecentlyUsed(_ index: Int) {
        recentFrameIndexes.removeAll { $0 == index }
        recentFrameIndexes.append(index)
    }
}
