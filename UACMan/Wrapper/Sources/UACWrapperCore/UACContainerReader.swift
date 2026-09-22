import CryptoKit
import Foundation

public enum UACContainerError: Error, Equatable, Sendable {
    case notARegularFile
    case truncatedHeader
    case invalidMagic
    case invalidMetadataMagic
    case invalidPayloadMagic
    case unsupportedVersion(major: UInt16, minor: UInt16)
    case manifestTooLarge
    case invalidLengths
    case manifestChecksumMismatch
    case manifestDecoderRequired
    case manifestDecompressionFailed
    case manifestDecodedSizeMismatch
    case invalidCompressedManifestFrame
    case invalidManifest(String)
    case invalidSeekTable(String)
    case memberMissingSeekOffset(String)
    case memberSeekRangeOutOfBounds(String)
    case memberNotFound(String)
    case seekablePayloadRequired
    case invalidSeekFrameCacheLimit
    case invalidMemberReadRange
    case memberRangeNotCovered
    case seekableFrameReadFailed(Int)
    case seekableFrameDecodeFailed(Int)
    case seekableFrameSizeMismatch(Int)
    case destinationExists
    case sourceChangedDuringRewrite
    case payloadCopyFailed
}

public struct UACContainer: Sendable, Equatable {
    public let manifest: UACManifest
    /// The decoded manifest bytes exactly as stored logically, before JSON
    /// decoding/re-encoding. Editors use this to preserve unknown future keys.
    public let manifestJSON: Data
    public let payloadOffset: UInt64
    public let payloadLength: UInt64
    public let manifestSHA256: String
    public let manifestEncoding: UACManifestEncoding
    public let manifestByteCount: Int
    public let storedManifestByteCount: Int
    public let seekTable: UACZstandardSeekTable?
}

public enum UACManifestEncoding: String, Sendable, Equatable {
    case json
    case zstandardJSON = "zstd-json"
}

/// The host supplies its Zstandard codec. It must cap decoded output at
/// `expectedByteCount`, cap decoder memory at `maximumMemoryByteCount`, and
/// return exactly the declared output size.
public typealias UACManifestFrameDecoder = @Sendable (
    _ compressedFrame: Data,
    _ expectedByteCount: Int,
    _ maximumMemoryByteCount: Int
) throws -> Data
public typealias UACManifestFrameEncoder = @Sendable (_ manifestData: Data) throws -> Data

/// Reads a raw or independently Zstandard-compressed JSON manifest in the
/// outer Zstandard skippable frame. The TAR payload remains untouched.
public enum UACContainerReader {
    public static let skippableFrameHeaderByteCount = 8
    public static let metadataFrameHeaderByteCount = 40
    public static let compressedManifestExtensionByteCount = 8
    public static let maximumManifestByteCount = 16 * 1024 * 1024
    public static let maximumManifestDecoderMemoryByteCount = 32 * 1024 * 1024
    public static let uacSkippableMagic: UInt32 = 0x184D2A55
    public static let zstandardFrameMagic: UInt32 = 0xFD2FB528
    public static let metadataMagic = Data([0x55, 0x41, 0x43, 0x4D]) // UACM
    public static let compressedManifestMagic = Data([0x5A, 0x4A, 0x30, 0x31]) // ZJ01

    public static func read(
        from url: URL,
        decompressManifestFrame: UACManifestFrameDecoder? = nil
    ) throws -> UACContainer {
        let standardizedURL = url.standardizedFileURL
        let attributes = try FileManager.default.attributesOfItem(atPath: standardizedURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let sizeNumber = attributes[.size] as? NSNumber else {
            throw UACContainerError.notARegularFile
        }
        let fileByteCount = sizeNumber.uint64Value
        guard fileByteCount >= UInt64(skippableFrameHeaderByteCount + metadataFrameHeaderByteCount + 1 + 4) else {
            throw UACContainerError.truncatedHeader
        }

        let handle = try FileHandle(forReadingFrom: standardizedURL)
        defer { try? handle.close() }
        guard let frameHeader = try handle.read(upToCount: skippableFrameHeaderByteCount),
              frameHeader.count == skippableFrameHeaderByteCount else {
            throw UACContainerError.truncatedHeader
        }
        guard Self.uint32LE(frameHeader, at: 0) == uacSkippableMagic else {
            throw UACContainerError.invalidMagic
        }

        let metadataFrameByteCount = UInt64(Self.uint32LE(frameHeader, at: 4))
        guard metadataFrameByteCount >= UInt64(metadataFrameHeaderByteCount + 1),
              metadataFrameByteCount <= UInt64(
                metadataFrameHeaderByteCount + compressedManifestExtensionByteCount + maximumManifestByteCount
              ),
              metadataFrameByteCount <= UInt64(Int.max) else {
            throw UACContainerError.manifestTooLarge
        }
        let (payloadOffset, offsetOverflow) = UInt64(skippableFrameHeaderByteCount)
            .addingReportingOverflow(metadataFrameByteCount)
        guard !offsetOverflow,
              payloadOffset <= fileByteCount,
              fileByteCount - payloadOffset >= 4 else {
            throw UACContainerError.invalidLengths
        }
        let payloadByteCount = fileByteCount - payloadOffset

        guard let framePayload = try handle.read(upToCount: Int(metadataFrameByteCount)),
              framePayload.count == Int(metadataFrameByteCount) else {
            throw UACContainerError.invalidLengths
        }
        guard framePayload.prefix(metadataMagic.count) == metadataMagic else {
            throw UACContainerError.invalidMetadataMagic
        }

        let major = Self.uint16LE(framePayload, at: 4)
        let minor = Self.uint16LE(framePayload, at: 6)
        guard major == 1, minor == 0 else {
            throw UACContainerError.unsupportedVersion(major: major, minor: minor)
        }
        let storedManifest = Data(framePayload.dropFirst(metadataFrameHeaderByteCount))
        let manifestEncoding: UACManifestEncoding
        let manifestData: Data
        if storedManifest.starts(with: compressedManifestMagic) {
            guard storedManifest.count > compressedManifestExtensionByteCount else {
                throw UACContainerError.invalidLengths
            }
            let decodedByteCount = uint32LE(storedManifest, at: 4)
            guard decodedByteCount > 0,
                  decodedByteCount <= UInt32(maximumManifestByteCount) else {
                throw UACContainerError.manifestTooLarge
            }
            guard storedManifest.count < Int(decodedByteCount) else {
                throw UACContainerError.invalidCompressedManifestFrame
            }
            let compressedFrame = Data(storedManifest.dropFirst(compressedManifestExtensionByteCount))
            guard compressedFrame.count >= 4,
                  uint32LE(compressedFrame, at: 0) == zstandardFrameMagic else {
                throw UACContainerError.invalidCompressedManifestFrame
            }
            guard let decompressManifestFrame else {
                throw UACContainerError.manifestDecoderRequired
            }
            do {
                manifestData = try decompressManifestFrame(
                    compressedFrame,
                    Int(decodedByteCount),
                    maximumManifestDecoderMemoryByteCount
                )
            } catch {
                throw UACContainerError.manifestDecompressionFailed
            }
            guard manifestData.count == Int(decodedByteCount) else {
                throw UACContainerError.manifestDecodedSizeMismatch
            }
            manifestEncoding = .zstandardJSON
        } else {
            guard !storedManifest.isEmpty,
                  storedManifest.count <= maximumManifestByteCount else {
                throw UACContainerError.manifestTooLarge
            }
            manifestData = storedManifest
            manifestEncoding = .json
        }
        let expectedDigest = Data(framePayload[8..<metadataFrameHeaderByteCount])
        let actualDigest = Data(SHA256.hash(data: manifestData))
        guard expectedDigest == actualDigest else {
            throw UACContainerError.manifestChecksumMismatch
        }

        try handle.seek(toOffset: payloadOffset)
        guard let payloadMagic = try handle.read(upToCount: 4),
              payloadMagic.count == 4 else {
            throw UACContainerError.invalidLengths
        }
        guard Self.uint32LE(payloadMagic, at: 0) == zstandardFrameMagic else {
            throw UACContainerError.invalidPayloadMagic
        }

        let manifest: UACManifest
        do {
            manifest = try JSONDecoder().decode(UACManifest.self, from: manifestData)
        } catch {
            throw UACContainerError.invalidManifest("JSON decode failed: \(error.localizedDescription)")
        }
        try validate(manifest)
        let seekTable: UACZstandardSeekTable?
        if manifest.payload.format == "tar+zstd-seekable" {
            let parsedSeekTable = try UACZstandardSeekTable.read(
                from: handle,
                payloadOffset: payloadOffset,
                payloadByteCount: payloadByteCount
            )
            for member in manifest.members {
                guard let tarDataOffset = member.tarDataOffset else {
                    throw UACContainerError.memberMissingSeekOffset(member.path)
                }
                let (memberEnd, offsetOverflow) = tarDataOffset.addingReportingOverflow(member.byteSize)
                guard !offsetOverflow, memberEnd <= parsedSeekTable.tarByteCount else {
                    throw UACContainerError.memberSeekRangeOutOfBounds(member.path)
                }
            }
            seekTable = parsedSeekTable
        } else {
            seekTable = nil
        }
        return UACContainer(
            manifest: manifest,
            manifestJSON: manifestData,
            payloadOffset: payloadOffset,
            payloadLength: payloadByteCount,
            manifestSHA256: actualDigest.map { String(format: "%02x", $0) }.joined(),
            manifestEncoding: manifestEncoding,
            manifestByteCount: manifestData.count,
            storedManifestByteCount: storedManifest.count,
            seekTable: seekTable
        )
    }

    /// Copies the compressed payload byte-for-byte. The destination must not
    /// exist; a temporary sibling is atomically moved into place on success.
    @discardableResult
    public static func copyPayload(
        from sourceURL: URL,
        to destinationURL: URL,
        decompressManifestFrame: UACManifestFrameDecoder? = nil
    ) throws -> UACContainer {
        let container = try read(from: sourceURL, decompressManifestFrame: decompressManifestFrame)
        let fileManager = FileManager.default
        let destinationURL = destinationURL.standardizedFileURL
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw UACContainerError.destinationExists
        }
        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
        guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
            throw UACContainerError.payloadCopyFailed
        }

        do {
            let input = try FileHandle(forReadingFrom: sourceURL.standardizedFileURL)
            let output = try FileHandle(forWritingTo: temporaryURL)
            defer {
                try? input.close()
                try? output.close()
            }
            try input.seek(toOffset: container.payloadOffset)
            var remaining = container.payloadLength
            while remaining > 0 {
                let nextCount = Int(min(remaining, 1024 * 1024))
                guard let chunk = try input.read(upToCount: nextCount), !chunk.isEmpty else {
                    throw UACContainerError.payloadCopyFailed
                }
                try output.write(contentsOf: chunk)
                remaining -= UInt64(chunk.count)
            }
            try output.synchronize()
            try output.close()
            try input.close()
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            if let error = error as? UACContainerError { throw error }
            throw UACContainerError.payloadCopyFailed
        }
        return container
    }

    public static func validate(_ manifest: UACManifest) throws {
        try UACManifestValidator.validate(manifest)
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32.zero) { $0 | (UInt32(data[offset + $1]) << (UInt32($1) * 8)) }
    }

    private static func uint64LE(_ data: Data, at offset: Int) -> UInt64 {
        (0..<8).reduce(UInt64.zero) { $0 | (UInt64(data[offset + $1]) << (UInt64($1) * 8)) }
    }
}
