import Foundation

enum UACManifestValidator {
    static func validate(_ manifest: UACManifest) throws {
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
            && isSeekableCompressionProfile(manifest.payload.compressionProfile)
        guard legacyPayloadProfile || seekablePayloadProfile,
              !manifest.payload.encoderVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isBLAKE3(manifest.payload.blake3) else {
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
              variantIDs.allSatisfy(isSafeComponent) else {
            throw UACContainerError.invalidManifest("Variant identifiers must be unique safe path components.")
        }
        let sourceIDs = manifest.sources.map(\.id)
        guard Set(sourceIDs).count == sourceIDs.count,
              sourceIDs.allSatisfy({ !$0.isEmpty }),
              manifest.sources.allSatisfy({ $0.packageBlake3.map(isBLAKE3) ?? true }) else {
            throw UACContainerError.invalidManifest("Source identifiers must be unique.")
        }
        let transformationIDs = manifest.transformations.map(\.id)
        guard Set(transformationIDs).count == transformationIDs.count,
              transformationIDs.allSatisfy(isSafeComponent) else {
            throw UACContainerError.invalidManifest("Transformation identifiers must be unique safe path components.")
        }

        var paths = Set<String>()
        let sourceIDSet = Set(sourceIDs)
        for member in manifest.members {
            guard isSafeRelativePath(member.path),
                  member.path.utf8.count <= 32 * 1024,
                  paths.insert(member.path).inserted,
                  isBLAKE3(member.blake3),
                  member.streamBlake3.map(isBLAKE3) ?? true,
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
                      isValidHashDigest(algorithm: hash.algorithm, digest: hash.digest),
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
        try validateTransformations(manifest.transformations, sourceIDs: sourceIDSet, membersByPath: membersByPath)
        try validatePlaylists(manifest.playlists, variantIDs: variantIDs, membersByPath: membersByPath)
        try validatePathCollisions(paths)
    }

    private static func validateTransformations(
        _ transformations: [UACTransformation],
        sourceIDs: Set<String>,
        membersByPath: [String: UACMember]
    ) throws {
        for transformation in transformations {
            guard !transformation.operation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.tool.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.toolVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.appliedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !transformation.inputs.isEmpty else {
                throw UACContainerError.invalidManifest("Transformation records require an operation, tool, timestamp, and at least one input.")
            }
            for input in transformation.inputs {
                guard sourceIDs.contains(input.sourceID),
                      isSafeRelativePath(input.sourcePath),
                      isBLAKE3(input.blake3),
                      input.streamBlake3.map(isBLAKE3) ?? true else {
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
    }

    private static func validatePlaylists(
        _ playlists: [UACPlaylist],
        variantIDs: [String],
        membersByPath: [String: UACMember]
    ) throws {
        let playlistIDs = playlists.map(\.id)
        guard Set(playlistIDs).count == playlistIDs.count,
              playlistIDs.allSatisfy(isSafeComponent) else {
            throw UACContainerError.invalidManifest("Playlist identifiers must be unique safe path components.")
        }
        var playlistEntryCount = 0
        for playlist in playlists {
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
    }

    private static func validatePathCollisions(_ paths: Set<String>) throws {
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

    private static func isValidHashDigest(algorithm: String, digest: String) -> Bool {
        guard !digest.isEmpty, digest.allSatisfy({ $0.isHexDigit }) else { return false }
        switch algorithm {
        case "blake3-256":
            return isBLAKE3(digest)
        case "crc32-iso-hdlc":
            return digest.utf8.count == 8
        case "sha1":
            return digest.utf8.count == 40 && digest.allSatisfy { !$0.isUppercase }
        case "md5":
            return digest.utf8.count == 32 && digest.allSatisfy { !$0.isUppercase }
        default:
            return true
        }
    }
}
