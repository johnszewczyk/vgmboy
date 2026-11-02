import Foundation
import UACWrapperCore
import VGMBoyCZstdDecompress

public enum UACEmbeddedCodecError: LocalizedError, Equatable, Sendable {
    case emptyFrame
    case contentSizeUnavailable
    case exceedsMaximumMemory(Int)
    case decompressionFailed(String)
    case checksumMismatch

    public var errorDescription: String? {
        switch self {
        case .emptyFrame:
            return "Compressed Zstandard frame is empty."
        case .contentSizeUnavailable:
            return "Zstandard frame header does not carry a valid content size."
        case .exceedsMaximumMemory(let requested):
            return "Zstandard frame requires \(requested) bytes, exceeding safety bounds."
        case .decompressionFailed(let detail):
            return "Zstandard frame decompression failed: \(detail)"
        case .checksumMismatch:
            return "Seekable UAC frame failed XXH64 low-32 checksum verification."
        }
    }
}

/// In-process Zstandard frame decoder backed by VGMBoy's vendored zstd 1.5.6 library.
/// Suitable for sandboxed iOS and macOS hosts where spawning external CLI decoders is unavailable.
public enum UACEmbeddedZstandardCodec {
    public static let defaultMaximumFrameBytes = Int(UACZstandardSeekTable.maximumFrameTarByteCount)

    public static let manifestFrameDecoder: UACManifestFrameDecoder = { compressedFrame, expectedByteCount, maximumMemoryByteCount in
        guard !compressedFrame.isEmpty else {
            throw UACEmbeddedCodecError.emptyFrame
        }
        guard expectedByteCount > 0, expectedByteCount <= maximumMemoryByteCount else {
            throw UACEmbeddedCodecError.exceedsMaximumMemory(expectedByteCount)
        }
        return try decompress(compressedFrame, capacity: expectedByteCount)
    }

    public static let seekableFrameDecoder: UACSeekableFrameDecoder = { compressedFrame, expectedChecksum in
        guard !compressedFrame.isEmpty else {
            throw UACEmbeddedCodecError.emptyFrame
        }
        let contentSize = compressedFrame.withUnsafeBytes { rawBuffer -> Int in
            guard let base = rawBuffer.baseAddress else { return -1 }
            return vgmboy_zstd_frame_content_size(base, rawBuffer.count)
        }
        let targetCapacity: Int
        if contentSize >= 0 {
            guard contentSize <= defaultMaximumFrameBytes else {
                throw UACEmbeddedCodecError.exceedsMaximumMemory(contentSize)
            }
            targetCapacity = max(contentSize, 1)
        } else {
            targetCapacity = 4 * 1024 * 1024
        }

        let decoded = try decompress(compressedFrame, capacity: targetCapacity)
        if let expectedChecksum, !UACSeekableFrameChecksum.matches(decoded, checksum: expectedChecksum) {
            throw UACEmbeddedCodecError.checksumMismatch
        }
        return decoded
    }

    public static func decompress(_ compressedFrame: Data, capacity: Int) throws -> Data {
        guard capacity > 0 else { return Data() }
        var output = Data(count: capacity)
        let decodedCount = output.withUnsafeMutableBytes { dstBuffer -> Int in
            compressedFrame.withUnsafeBytes { srcBuffer -> Int in
                guard let dstBase = dstBuffer.baseAddress,
                      let srcBase = srcBuffer.baseAddress else {
                    return -1
                }
                return vgmboy_zstd_decompress_frame(
                    dstBase,
                    dstBuffer.count,
                    srcBase,
                    srcBuffer.count
                )
            }
        }
        if decodedCount < 0 {
            let message = String(cString: vgmboy_zstd_error_name(decodedCount))
            throw UACEmbeddedCodecError.decompressionFailed(message)
        }
        if decodedCount < output.count {
            output.removeSubrange(decodedCount..<output.count)
        }
        return output
    }
}
