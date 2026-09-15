import CryptoKit
import Foundation

/// Adds a UAC metadata frame in front of an already-built TAR+Zstandard
/// payload (sequential legacy or seekable). TAR creation, payload Zstandard
/// compression, BLAKE3 calculation, and source-to-member provenance remain
/// the packer's responsibility. Manifest-frame compression is injected.
public enum UACContainerWriter {
    /// Writes a new UAC beside the destination and atomically moves it into
    /// place. The compressed payload is copied byte-for-byte, never decoded
    /// or recompressed. The caller must supply accurate payload/member BLAKE3
    /// values in the manifest; this wrapper has no BLAKE3 dependency.
    @discardableResult
    public static func write(
        manifest: UACManifest,
        compressedTarPayloadURL: URL,
        to destinationURL: URL,
        compressManifestFrame: @escaping UACManifestFrameEncoder,
        decompressManifestFrame: @escaping UACManifestFrameDecoder
    ) throws -> UACContainer {
        try UACContainerReader.validate(manifest)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let manifestData = try encoder.encode(manifest)
        return try writeManifestJSON(
            manifestData,
            payloadSourceURL: compressedTarPayloadURL,
            payloadOffset: 0,
            payloadLength: nil,
            to: destinationURL,
            compressManifestFrame: compressManifestFrame,
            decompressManifestFrame: decompressManifestFrame
        )
    }

    /// Replaces only the UAC manifest in a new output file. The source
    /// container is validated first and its compressed TAR/seek-table payload
    /// is copied byte-for-byte from its existing offset; no payload temp copy,
    /// decompression, or recompression is performed. The destination must not
    /// already exist.
    @discardableResult
    public static func rewriteManifest(
        manifestJSON: Data,
        in sourceURL: URL,
        to destinationURL: URL,
        compressManifestFrame: @escaping UACManifestFrameEncoder,
        decompressManifestFrame: @escaping UACManifestFrameDecoder
    ) throws -> UACContainer {
        let sourceStamp = try fileStamp(for: sourceURL)
        let source = try UACContainerReader.read(
            from: sourceURL,
            decompressManifestFrame: decompressManifestFrame
        )
        guard sourceStamp == (try fileStamp(for: sourceURL)) else {
            throw UACContainerError.sourceChangedDuringRewrite
        }
        let rewritten = try writeManifestJSON(
            manifestJSON,
            payloadSourceURL: sourceURL,
            payloadOffset: source.payloadOffset,
            payloadLength: source.payloadLength,
            to: destinationURL,
            compressManifestFrame: compressManifestFrame,
            decompressManifestFrame: decompressManifestFrame
        )
        guard sourceStamp == (try fileStamp(for: sourceURL)) else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw UACContainerError.sourceChangedDuringRewrite
        }
        return rewritten
    }

    private static func writeManifestJSON(
        _ manifestData: Data,
        payloadSourceURL: URL,
        payloadOffset: UInt64,
        payloadLength requestedPayloadLength: UInt64?,
        to destinationURL: URL,
        compressManifestFrame: @escaping UACManifestFrameEncoder,
        decompressManifestFrame: @escaping UACManifestFrameDecoder
    ) throws -> UACContainer {
        guard !manifestData.isEmpty,
              manifestData.count <= UACContainerReader.maximumManifestByteCount else {
            throw UACContainerError.manifestTooLarge
        }
        let manifest: UACManifest
        do {
            manifest = try JSONDecoder().decode(UACManifest.self, from: manifestData)
        } catch {
            throw UACContainerError.invalidManifest("JSON decode failed: \(error.localizedDescription)")
        }
        try UACContainerReader.validate(manifest)

        let compressedManifest = try compressManifestFrame(manifestData)
        guard compressedManifest.count >= 4,
              Self.uint32LE(compressedManifest) == UACContainerReader.zstandardFrameMagic else {
            throw UACContainerError.invalidCompressedManifestFrame
        }
        let storedManifest: Data
        if compressedManifest.count + UACContainerReader.compressedManifestExtensionByteCount < manifestData.count {
            guard manifestData.count <= Int(UInt32.max) else {
                throw UACContainerError.manifestTooLarge
            }
            var encoded = UACContainerReader.compressedManifestMagic
            encoded.append(contentsOf: Self.littleEndian(UInt32(manifestData.count)))
            encoded.append(compressedManifest)
            storedManifest = encoded
        } else {
            storedManifest = manifestData
        }

        let sourceURL = payloadSourceURL.standardizedFileURL
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let sizeNumber = attributes[.size] as? NSNumber else {
            throw UACContainerError.notARegularFile
        }
        let sourceByteCount = sizeNumber.uint64Value
        guard payloadOffset <= sourceByteCount else { throw UACContainerError.invalidLengths }
        let availablePayloadLength = sourceByteCount - payloadOffset
        let payloadByteCount = requestedPayloadLength ?? availablePayloadLength
        guard payloadByteCount >= 4, payloadByteCount <= availablePayloadLength else {
            throw UACContainerError.invalidLengths
        }

        let input = try FileHandle(forReadingFrom: sourceURL)
        try input.seek(toOffset: payloadOffset)
        guard let payloadMagic = try input.read(upToCount: 4),
              payloadMagic.count == 4,
              Self.uint32LE(payloadMagic) == UACContainerReader.zstandardFrameMagic else {
            try? input.close()
            throw UACContainerError.invalidPayloadMagic
        }
        try input.seek(toOffset: payloadOffset)

        var metadataFrame = UACContainerReader.metadataMagic
        metadataFrame.append(contentsOf: Self.littleEndian(UInt16(1)))
        metadataFrame.append(contentsOf: Self.littleEndian(UInt16(0)))
        metadataFrame.append(contentsOf: SHA256.hash(data: manifestData))
        metadataFrame.append(storedManifest)

        var prefix = Data()
        prefix.append(contentsOf: Self.littleEndian(UACContainerReader.uacSkippableMagic))
        prefix.append(contentsOf: Self.littleEndian(UInt32(metadataFrame.count)))
        prefix.append(metadataFrame)

        let fileManager = FileManager.default
        let destinationURL = destinationURL.standardizedFileURL
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            try? input.close()
            throw UACContainerError.destinationExists
        }
        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".\(destinationURL.lastPathComponent).\(UUID().uuidString).tmp")
        guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
            try? input.close()
            throw UACContainerError.payloadCopyFailed
        }

        do {
            let output = try FileHandle(forWritingTo: temporaryURL)
            defer {
                try? input.close()
                try? output.close()
            }
            try output.write(contentsOf: prefix)
            var remaining = payloadByteCount
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

            let container = try UACContainerReader.read(
                from: temporaryURL,
                decompressManifestFrame: decompressManifestFrame
            )
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            return container
        } catch {
            try? input.close()
            try? fileManager.removeItem(at: temporaryURL)
            if let error = error as? UACContainerError { throw error }
            throw UACContainerError.payloadCopyFailed
        }
    }

    private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
    }

    private static func uint32LE(_ data: Data) -> UInt32 {
        (0..<4).reduce(UInt32.zero) { $0 | (UInt32(data[$1]) << (UInt32($1) * 8)) }
    }

    private static func fileStamp(for url: URL) throws -> FileStamp {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            throw UACContainerError.notARegularFile
        }
        return FileStamp(
            size: size.uint64Value,
            modificationDate: attributes[.modificationDate] as? Date,
            systemFileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )
    }

    private struct FileStamp: Equatable {
        let size: UInt64
        let modificationDate: Date?
        let systemFileNumber: UInt64?
    }
}
