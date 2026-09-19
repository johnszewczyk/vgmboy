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
        guard (1...2).contains(manifest.manifestVersion),
              !manifest.packageID.isEmpty,
              !manifest.game.id.isEmpty,
              !manifest.game.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !manifest.game.console.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UACContainerError.invalidManifest("Missing required version or game identity fields.")
        }
        let legacyPayloadProfile = manifest.payload.format == "tar+zstd"
            && manifest.payload.compressionProfile == "uac-zstd-3-v1"
        let seekablePayloadProfile = manifest.payload.format == "tar+zstd-seekable"
            && Self.isSeekableCompressionProfile(manifest.payload.compressionProfile)
        guard legacyPayloadProfile || seekablePayloadProfile,
              !manifest.payload.encoderVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Self.isBLAKE3(manifest.payload.blake3) else {
            throw UACContainerError.invalidManifest("Unsupported payload profile, missing encoder version, or malformed payload BLAKE3.")
        }
        guard !manifest.members.isEmpty,
              manifest.members.count <= 100_000,
              manifest.variants.count <= 10_000,
              manifest.playlists.count <= 10_000,
              manifest.sources.count <= 10_000 else {
            throw UACContainerError.invalidManifest("Member, variant, or source count is outside the supported bounds.")
        }

        let variantIDs = manifest.variants.map(\.id)
        guard Set(variantIDs).count == variantIDs.count,
              variantIDs.allSatisfy(Self.isSafeComponent) else {
            throw UACContainerError.invalidManifest("Variant identifiers must be unique safe path components.")
        }
        let sourceIDs = manifest.sources.map(\.id)
        guard Set(sourceIDs).count == sourceIDs.count,
              sourceIDs.allSatisfy({ !$0.isEmpty }),
              manifest.sources.allSatisfy({ $0.packageBlake3.map(Self.isBLAKE3) ?? true }) else {
            throw UACContainerError.invalidManifest("Source identifiers must be unique.")
        }
        let transformationIDs = manifest.transformations.map(\.id)
        guard Set(transformationIDs).count == transformationIDs.count,
              transformationIDs.allSatisfy(Self.isSafeComponent) else {
            throw UACContainerError.invalidManifest("Transformation identifiers must be unique safe path components.")
        }

        var paths = Set<String>()
        let sourceIDSet = Set(sourceIDs)
        for member in manifest.members {
            guard Self.isSafeRelativePath(member.path),
                  member.path.utf8.count <= 32 * 1024,
                  paths.insert(member.path).inserted,
                  Self.isBLAKE3(member.blake3),
                  member.streamBlake3.map(Self.isBLAKE3) ?? true,
                  member.variantID.map({ variantIDs.contains($0) }) ?? true,
                  member.sourceIDs.allSatisfy(sourceIDSet.contains) else {
                throw UACContainerError.invalidManifest("Invalid, duplicate, or unsafe member record: \(member.path)")
            }
            var hashRecordKeys = Set<String>()
            for hash in member.hashes {
                let key = "\(hash.scope)\0\(hash.algorithm)\0\(hash.profile)"
                guard !hash.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !hash.algorithm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !hash.profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !hash.digest.isEmpty,
                      // Hash records may use either case for algorithms such
                      // as CRC32. BLAKE3-256 remains canonical lowercase via
                      // the algorithm-specific check below.
                      hash.digest.allSatisfy({ $0.isHexDigit }),
                      hash.algorithm != "blake3-256" || Self.isBLAKE3(hash.digest),
                      hashRecordKeys.insert(key).inserted else {
                    throw UACContainerError.invalidManifest("Invalid or duplicate member hash record: \(member.path)")
                }
            }
            if seekablePayloadProfile {
                guard let tarDataOffset = member.tarDataOffset else {
                    throw UACContainerError.memberMissingSeekOffset(member.path)
                }
                let (_, offsetOverflow) = tarDataOffset.addingReportingOverflow(member.byteSize)
                guard !offsetOverflow else {
                    throw UACContainerError.memberSeekRangeOutOfBounds(member.path)
                }
            }
            if let variantID = member.variantID {
                let isNamespaced = member.path.hasPrefix("variants/\(variantID)/")
                let requiresNamespace = manifest.manifestVersion == 1 || variantIDs.count > 1
                if requiresNamespace && !isNamespaced {
                    throw UACContainerError.invalidManifest("Variant member is outside its isolated variant directory: \(member.path)")
                }
            }
            if member.variantID == nil,
               !(member.path.hasPrefix("assets/") || member.path.hasPrefix("shared/")) {
                throw UACContainerError.invalidManifest("Shared member must live under assets/ or shared/: \(member.path)")
            }
        }

        let membersByPath = Dictionary(uniqueKeysWithValues: manifest.members.map { ($0.path, $0) })
        for transformation in manifest.transformations {
            guard !transformation.operation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.tool.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.toolVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.appliedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.inputs.isEmpty else {
                throw UACContainerError.invalidManifest("Transformation records require an operation, tool, timestamp, and at least one input.")
            }
            for input in transformation.inputs {
                guard sourceIDSet.contains(input.sourceID),
                      Self.isSafeRelativePath(input.sourcePath),
                      Self.isBLAKE3(input.blake3),
                      input.streamBlake3.map(Self.isBLAKE3) ?? true else {
                    throw UACContainerError.invalidManifest("Transformation input has invalid source provenance or hashes.")
                }
            }
            for output in transformation.outputs {
                guard let member = membersByPath[output.memberPath],
                      member.blake3 == output.blake3 else {
                    throw UACContainerError.invalidManifest("Transformation output must reference a member with the same BLAKE3.")
                }
            }
        }

        let playlistIDs = manifest.playlists.map(\.id)
        guard Set(playlistIDs).count == playlistIDs.count,
              playlistIDs.allSatisfy(Self.isSafeComponent) else {
            throw UACContainerError.invalidManifest("Playlist identifiers must be unique safe path components.")
        }
        var playlistEntryCount = 0
        for playlist in manifest.playlists {
            guard playlist.entries.count <= 100_000 - playlistEntryCount,
                  playlist.variantID.map({ variantIDs.contains($0) }) ?? true,
                  playlist.originalMemberPath.map({ membersByPath[$0] != nil }) ?? true else {
                throw UACContainerError.invalidManifest("Playlist has an invalid variant, source member, or excessive entry count: \(playlist.id)")
            }
            playlistEntryCount += playlist.entries.count
            for entry in playlist.entries {
                guard !entry.entryKind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let targetMember = membersByPath[entry.targetMemberPath],
                      entry.targetMemberBlake3.map({ $0 == targetMember.blake3 }) ?? true,
                      playlist.variantID.map({ targetMember.variantID == nil || targetMember.variantID == $0 }) ?? true else {
                    throw UACContainerError.invalidManifest("Playlist entry does not resolve to a compatible member: \(playlist.id) -> \(entry.targetMemberPath)")
                }
                if entry.entryKind == "subsong" {
                    guard let trackIndex = entry.trackIndex,
                          let decodedIndex = Int(trackIndex),
                          decodedIndex >= 0,
                          String(decodedIndex) == trackIndex,
                          targetMember.role == "playable" || targetMember.role == "track" else {
                        throw UACContainerError.invalidManifest(
                            "Subsong playlist entries require a playable member and a nonnegative decimal track index: \(playlist.id) -> \(entry.targetMemberPath)"
                        )
                    }
                }
            }
        }

        for path in paths {
            let components = path.split(separator: "/")
            guard components.count > 1 else { continue }
            for count in 1..<components.count {
                let ancestor = components.prefix(count).joined(separator: "/")
                guard !paths.contains(ancestor) else {
                    throw UACContainerError.invalidManifest("A file path is also used as a directory: \(ancestor)")
                }
            }
        }
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else {
            return false
        }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func isSafeComponent(_ component: String) -> Bool {
        !component.isEmpty && component != "." && component != ".."
            && !component.contains("/") && !component.contains("\\") && !component.contains("\0")
    }

    private static func isSeekableCompressionProfile(_ profile: String) -> Bool {
        if profile == "uac-zstd-seekable-3-v1" { return true }
        let components = profile.split(separator: "-")
        guard components.count == 8,
              components[0] == "uac",
              components[1] == "zstd",
              components[2] == "seekable",
              components[3] == "level",
              components[5] == "frame",
              components[7] == "v1",
              let level = Int(components[4]), (0...22).contains(level),
              let frameSize = UInt32(components[6]), frameSize > 0,
              frameSize <= UACZstandardSeekTable.maximumFrameTarByteCount else {
            return false
        }
        return true
    }

    private static func isBLAKE3(_ value: String) -> Bool {
        value.utf8.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
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

public struct UACManifest: Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let packageID: String
    public let payload: UACPayload
    public let game: UACGame
    public let variants: [UACVariant]
    public let members: [UACMember]
    public let playlists: [UACPlaylist]
    public let sources: [UACSource]
    public let transformations: [UACTransformation]
    public let extensions: [String: UACJSONValue]

    public init(
        manifestVersion: Int = 2,
        packageID: String,
        payload: UACPayload,
        game: UACGame,
        variants: [UACVariant],
        members: [UACMember],
        playlists: [UACPlaylist] = [],
        sources: [UACSource] = [],
        transformations: [UACTransformation] = [],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.manifestVersion = manifestVersion
        self.packageID = packageID
        self.payload = payload
        self.game = game
        self.variants = variants
        self.members = members
        self.playlists = playlists
        self.sources = sources
        self.transformations = transformations
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case manifestVersion, packageID, payload, game, variants, members
        case playlists, sources, transformations, extensions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try values.decode(Int.self, forKey: .manifestVersion)
        packageID = try values.decode(String.self, forKey: .packageID)
        payload = try values.decode(UACPayload.self, forKey: .payload)
        game = try values.decode(UACGame.self, forKey: .game)
        variants = try values.decode([UACVariant].self, forKey: .variants)
        members = try values.decode([UACMember].self, forKey: .members)
        playlists = try values.decodeIfPresent([UACPlaylist].self, forKey: .playlists) ?? []
        sources = try values.decodeIfPresent([UACSource].self, forKey: .sources) ?? []
        transformations = try values.decodeIfPresent([UACTransformation].self, forKey: .transformations) ?? []
        extensions = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .extensions) ?? [:]
    }
}

public struct UACTransformation: Codable, Equatable, Sendable {
    public let id: String
    public let operation: String
    public let inputs: [UACTransformationInput]
    public let outputs: [UACTransformationOutput]
    public let tool: String
    public let toolVersion: String
    public let appliedAt: String
    public let reason: String?
    public let details: [String: UACJSONValue]

    public init(
        id: String,
        operation: String,
        inputs: [UACTransformationInput],
        outputs: [UACTransformationOutput] = [],
        tool: String,
        toolVersion: String,
        appliedAt: String,
        reason: String? = nil,
        details: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.operation = operation
        self.inputs = inputs
        self.outputs = outputs
        self.tool = tool
        self.toolVersion = toolVersion
        self.appliedAt = appliedAt
        self.reason = reason
        self.details = details
    }
}

public struct UACTransformationInput: Codable, Equatable, Sendable {
    public let sourceID: String
    public let sourcePath: String
    public let blake3: String
    public let streamBlake3: String?

    public init(sourceID: String, sourcePath: String, blake3: String, streamBlake3: String? = nil) {
        self.sourceID = sourceID
        self.sourcePath = sourcePath
        self.blake3 = blake3
        self.streamBlake3 = streamBlake3
    }
}

public struct UACTransformationOutput: Codable, Equatable, Sendable {
    public let memberPath: String
    public let blake3: String

    public init(memberPath: String, blake3: String) {
        self.memberPath = memberPath
        self.blake3 = blake3
    }
}

public struct UACPayload: Codable, Equatable, Sendable {
    public let format: String
    public let compressionProfile: String
    public let encoderVersion: String
    public let blake3: String

    public init(
        format: String = "tar+zstd-seekable",
        compressionProfile: String = "uac-zstd-seekable-level-3-frame-4194304-v1",
        encoderVersion: String,
        blake3: String
    ) {
        self.format = format
        self.compressionProfile = compressionProfile
        self.encoderVersion = encoderVersion
        self.blake3 = blake3
    }
}

public struct UACGame: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let console: String
    public let canonicalIDs: [String]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        title: String,
        console: String,
        canonicalIDs: [String] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.title = title
        self.console = console
        self.canonicalIDs = canonicalIDs
        self.metadata = metadata
        self.extensions = extensions
    }
}

public struct UACVariant: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let kind: String
    public let canonicalReleaseIDs: [String]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        label: String,
        kind: String,
        canonicalReleaseIDs: [String] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.canonicalReleaseIDs = canonicalReleaseIDs
        self.metadata = metadata
        self.extensions = extensions
    }
}

public struct UACMember: Codable, Equatable, Sendable {
    public let path: String
    public let originalName: String
    public let variantID: String?
    public let sourceIDs: [String]
    public let role: String
    public let format: String?
    public let byteSize: UInt64
    /// Offset of this member's file data within the decompressed TAR stream.
    /// Required for the seekable payload profile; absent for legacy streams.
    public let tarDataOffset: UInt64?
    public let blake3: String
    public let streamBlake3: String?
    public let hashes: [UACHashRecord]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        path: String,
        originalName: String,
        variantID: String? = nil,
        sourceIDs: [String] = [],
        role: String,
        format: String? = nil,
        byteSize: UInt64,
        tarDataOffset: UInt64? = nil,
        blake3: String,
        streamBlake3: String? = nil,
        hashes: [UACHashRecord] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.path = path
        self.originalName = originalName
        self.variantID = variantID
        self.sourceIDs = sourceIDs
        self.role = role
        self.format = format
        self.byteSize = byteSize
        self.tarDataOffset = tarDataOffset
        self.blake3 = blake3
        self.streamBlake3 = streamBlake3
        self.hashes = hashes
        self.metadata = metadata
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case path, originalName, variantID, sourceIDs, role, format, byteSize
        case tarDataOffset, blake3, streamBlake3, hashes, metadata, extensions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        path = try values.decode(String.self, forKey: .path)
        originalName = try values.decode(String.self, forKey: .originalName)
        variantID = try values.decodeIfPresent(String.self, forKey: .variantID)
        sourceIDs = try values.decodeIfPresent([String].self, forKey: .sourceIDs) ?? []
        role = try values.decode(String.self, forKey: .role)
        format = try values.decodeIfPresent(String.self, forKey: .format)
        byteSize = try values.decode(UInt64.self, forKey: .byteSize)
        tarDataOffset = try values.decodeIfPresent(UInt64.self, forKey: .tarDataOffset)
        blake3 = try values.decode(String.self, forKey: .blake3)
        streamBlake3 = try values.decodeIfPresent(String.self, forKey: .streamBlake3)
        hashes = try values.decodeIfPresent([UACHashRecord].self, forKey: .hashes) ?? []
        metadata = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .metadata) ?? [:]
        extensions = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .extensions) ?? [:]
    }
}

public struct UACSource: Codable, Equatable, Sendable {
    public let id: String
    public let collection: String
    public let setName: String
    public let sourceName: String
    public let sourceURL: String?
    public let packageBlake3: String?
    public let observedAt: String
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        collection: String,
        setName: String,
        sourceName: String,
        sourceURL: String? = nil,
        packageBlake3: String? = nil,
        observedAt: String,
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.collection = collection
        self.setName = setName
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.packageBlake3 = packageBlake3
        self.observedAt = observedAt
        self.metadata = metadata
        self.extensions = extensions
    }
}

public indirect enum UACJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([UACJSONValue])
    case object([String: UACJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([UACJSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: UACJSONValue].self) { self = .object(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
