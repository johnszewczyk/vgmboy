import Foundation
import UACWrapperCore

/// Bounded adapter from UAC's injected decoder API to the host-installed
/// Zstandard CLI. UACWrapperCore owns the format/index contract; this adapter
/// owns only executable discovery and bounded frame decoding.
public final class UACZstandardCLIFrameCodec: @unchecked Sendable {
    public static let shared = UACZstandardCLIFrameCodec()

    private let zstdCandidates: [String]
    private let processRunner: ArchiveProcessRunner

    public init(
        configuration: ArchiveMaterializerConfiguration = .default,
        processRunner: ArchiveProcessRunner? = nil
    ) {
        self.zstdCandidates = configuration.zstdCandidates
        self.processRunner = processRunner ?? ArchiveProcessRunner(configuration: .init(
            environment: ProcessInfo.processInfo.environment,
            temporaryFilePrefix: "FrontendCore-uac-frame",
            maxConcurrency: min(4, max(1, ProcessInfo.processInfo.activeProcessorCount - 1)),
            listingTimeout: 30,
            extractionTimeout: 60,
            capturedOutputMaximumBytes: Int64(UACZstandardSeekTable.maximumFrameTarByteCount)
        ))
    }

    public var manifestDecoder: UACManifestFrameDecoder {
        { [self] frame, expectedByteCount, maximumMemoryByteCount in
            guard expectedByteCount > 0,
                  expectedByteCount <= UACContainerReader.maximumManifestByteCount,
                  maximumMemoryByteCount > 0,
                  maximumMemoryByteCount <= UACContainerReader.maximumManifestDecoderMemoryByteCount else {
                throw UACZstandardCLIFrameCodecError.invalidBounds
            }
            let decoded = try decode(
                frame,
                maximumOutputByteCount: expectedByteCount,
                maximumMemoryByteCount: maximumMemoryByteCount
            )
            guard decoded.count == expectedByteCount else {
                throw UACZstandardCLIFrameCodecError.decodedSizeMismatch
            }
            return decoded
        }
    }

    public var seekableFrameDecoder: UACSeekableFrameDecoder {
        { [self] frame, checksum in
            let decoded = try decode(
                frame,
                maximumOutputByteCount: Int(UACZstandardSeekTable.maximumFrameTarByteCount),
                maximumMemoryByteCount: Int(UACZstandardSeekTable.maximumFrameTarByteCount)
            )
            if let checksum,
               !UACSeekableFrameChecksum.matches(decoded, checksum: checksum) {
                throw UACZstandardCLIFrameCodecError.checksumMismatch
            }
            return decoded
        }
    }

    private func decode(
        _ compressedFrame: Data,
        maximumOutputByteCount: Int,
        maximumMemoryByteCount: Int
    ) throws -> Data {
        guard !compressedFrame.isEmpty,
              compressedFrame.count <= Int(UACZstandardSeekTable.maximumFrameCompressedByteCount),
              maximumOutputByteCount > 0,
              maximumMemoryByteCount > 0 else {
            throw UACZstandardCLIFrameCodecError.invalidBounds
        }
        guard let executablePath = zstdCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            throw UACZstandardCLIFrameCodecError.toolUnavailable
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrontendCore-uac-frame-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputURL = directory.appendingPathComponent("frame.zst", isDirectory: false)
        try compressedFrame.write(to: inputURL, options: .atomic)
        let memoryMiB = max(1, (maximumMemoryByteCount + 1024 * 1024 - 1) / (1024 * 1024))
        return try processRunner.runBounded(
            executable: executablePath,
            arguments: ["-q", "-d", "-c", "--memory=\(memoryMiB)MB", "--", inputURL.path],
            maximumOutputBytes: Int64(maximumOutputByteCount),
            operation: .extraction
        )
    }
}

public enum UACZstandardCLIFrameCodecError: Error, LocalizedError, Equatable {
    case invalidBounds
    case toolUnavailable
    case decodedSizeMismatch
    case checksumMismatch

    public var errorDescription: String? {
        switch self {
        case .invalidBounds:
            "The UAC Zstandard frame or its declared bounds are invalid."
        case .toolUnavailable:
            "The Zstandard executable required to read this UAC package is unavailable."
        case .decodedSizeMismatch:
            "The UAC manifest frame did not decode to its declared size."
        case .checksumMismatch:
            "The UAC seekable frame failed its XXH64 checksum."
        }
    }
}
