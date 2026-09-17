import Foundation
import UACWrapperCore

/// Reads UAC's independently stored manifest. The TAR/Zstandard payload is
/// never expanded here; playback and extraction remain other components' work.
enum UACMetadataReader {
    static func read(
        fileURL: URL,
        decompressManifestFrame: MetadataContainerFrameDecoder?
    ) throws -> MetadataReadResult {
        let container: UACContainer
        do {
            container = try UACContainerReader.read(
                from: fileURL,
                decompressManifestFrame: decompressManifestFrame
            )
        } catch {
            throw MetadataReadError.malformedFile("Invalid UAC metadata: \(error.localizedDescription)")
        }

        let manifestValue: MetadataJSONValue
        do {
            manifestValue = try JSONDecoder().decode(MetadataJSONValue.self, from: container.manifestJSON)
        } catch {
            throw MetadataReadError.malformedFile("The UAC manifest is not valid JSON: \(error.localizedDescription)")
        }
        guard case .object(let manifestObject) = manifestValue else {
            throw MetadataReadError.malformedFile("The UAC manifest root must be a JSON object.")
        }

        let rawMembers = objectArray(manifestObject["members"])
        let rawMembersByPath = Dictionary(uniqueKeysWithValues: rawMembers.compactMap { value -> (String, MetadataJSONValue)? in
            guard case .object(let member) = value,
                  case .string(let path)? = member["path"] else { return nil }
            return (path, value)
        })
        let rawVariants = objectArray(manifestObject["variants"])
        let rawVariantsByID = Dictionary(uniqueKeysWithValues: rawVariants.compactMap { value -> (String, MetadataJSONValue)? in
            guard case .object(let variant) = value,
                  case .string(let id)? = variant["id"] else { return nil }
            return (id, value)
        })
        let rawSources = objectArray(manifestObject["sources"])
        let rawSourcesByID = Dictionary(uniqueKeysWithValues: rawSources.compactMap { value -> (String, MetadataJSONValue)? in
            guard case .object(let source) = value,
                  case .string(let id)? = source["id"] else { return nil }
            return (id, value)
        })

        let gameValue = manifestObject["game"] ?? .null
        let containerDocument = MetadataDocument(
            format: "uac",
            fields: MetadataFields(title: container.manifest.game.title, game: container.manifest.game.title,
                                   system: container.manifest.game.console),
            tags: [
                MetadataTag(name: "PACKAGE_ID", value: container.manifest.packageID),
                MetadataTag(name: "GAME_TITLE", value: container.manifest.game.title),
                MetadataTag(name: "SYSTEM", value: container.manifest.game.console)
            ],
            rawMetadataBlocks: ["uac-manifest": container.manifestJSON],
            structuredMetadata: manifestValue,
            sourceEncoding: "UTF-8 JSON manifest",
            technicalFacts: [
                "uac.manifestVersion": String(container.manifest.manifestVersion),
                "uac.packageID": container.manifest.packageID,
                "uac.manifestSHA256": container.manifestSHA256,
                "uac.payloadFormat": container.manifest.payload.format,
                "uac.payloadCompressionProfile": container.manifest.payload.compressionProfile,
                "uac.gameID": container.manifest.game.id,
                "uac.gameTitle": container.manifest.game.title,
                "uac.console": container.manifest.game.console,
                "uac.memberCount": String(container.manifest.members.count),
                "uac.playlistCount": String(container.manifest.playlists.count),
                "uac.sourceCount": String(container.manifest.sources.count),
                "uac.payloadByteCount": String(container.payloadLength)
            ]
        )

        // UAC tracks describe the playable-member inventory in manifest order.
        // Authored playlists are a separate ordered structure, preserved in the
        // package document; expanding them here would duplicate member rows.
        let tracks = container.manifest.members.enumerated().compactMap { index, member -> MetadataTrack? in
            // "track" was used by early UAC fixtures before "playable" became
            // the stable member role. Retain that spelling as a read alias.
            guard member.role == "playable" || member.role == "track" else { return nil }

            var scopedMetadata: [String: MetadataJSONValue] = [
                "packageID": .string(container.manifest.packageID),
                "game": gameValue,
                "member": rawMembersByPath[member.path] ?? .null
            ]
            if let variantID = member.variantID {
                scopedMetadata["variant"] = rawVariantsByID[variantID] ?? .null
            }
            scopedMetadata["sources"] = .array(member.sourceIDs.compactMap { rawSourcesByID[$0] })

            let tags = member.metadata.keys.sorted().map { key in
                MetadataTag(name: key, value: displayValue(member.metadata[key] ?? .null))
            }
            let document = MetadataDocument(
                format: "uac",
                fields: MetadataFields(
                    title: string(member.metadata["title"]),
                    game: string(member.metadata["game"]),
                    system: string(member.metadata["system"]),
                    artist: string(member.metadata["artist"]),
                    album: string(member.metadata["album"]),
                    date: string(member.metadata["date"]),
                    year: string(member.metadata["year"]),
                    genre: string(member.metadata["genre"]),
                    comment: string(member.metadata["comment"]),
                    copyright: string(member.metadata["copyright"]),
                    encodedBy: string(member.metadata["encodedBy"])
                ),
                tags: tags,
                structuredMetadata: .object(scopedMetadata),
                sourceEncoding: "UAC manifest JSON",
                timing: MetadataTiming(
                    introLengthMs: milliseconds(member.metadata["introLengthMs"]),
                    loopLengthMs: milliseconds(member.metadata["loopLengthMs"]),
                    playLengthMs: milliseconds(member.metadata["playLengthMs"]),
                    fadeLengthMs: milliseconds(member.metadata["fadeLengthMs"])
                ),
                technicalFacts: [
                    "uac.packageID": container.manifest.packageID,
                    "uac.manifestSHA256": container.manifestSHA256,
                    "uac.memberPath": member.path,
                    "uac.memberOriginalName": member.originalName,
                    "uac.memberRole": member.role,
                    "uac.memberFormat": member.format ?? URL(fileURLWithPath: member.path).pathExtension,
                    "uac.memberByteSize": String(member.byteSize),
                    "uac.memberBLAKE3": member.blake3,
                    "uac.gameTitle": container.manifest.game.title,
                    "uac.console": container.manifest.game.console,
                    "uac.memberIndex": String(index)
                ].merging(member.streamBlake3.map { ["uac.memberStreamBLAKE3": $0] } ?? [:]) { current, _ in current }
                    .merging(member.variantID.map { ["uac.variantID": $0] } ?? [:]) { current, _ in current },
                diagnostics: []
            )
            return MetadataTrack(sourceTrackIndex: index, document: document)
        }

        return MetadataReadResult(tracks: tracks, containerDocument: containerDocument)
    }

    private static func objectArray(_ value: MetadataJSONValue?) -> [MetadataJSONValue] {
        guard case .array(let values)? = value else { return [] }
        return values
    }

    private static func string(_ value: UACJSONValue?) -> String? {
        guard case .string(let text)? = value else { return nil }
        return text
    }

    private static func milliseconds(_ value: UACJSONValue?) -> Int {
        switch value {
        case .integer(let value): return Int(clamping: value)
        case .number(let value):
            guard value.isFinite,
                  let converted = Int(exactly: value.rounded(.towardZero)) else { return 0 }
            return converted
        default: return 0
        }
    }

    private static func displayValue(_ value: UACJSONValue) -> String {
        switch value {
        case .null: return ""
        case .bool(let value): return value ? "true" : "false"
        case .integer(let value): return String(value)
        case .number(let value): return String(value)
        case .string(let value): return value
        case .array, .object:
            guard let data = try? JSONEncoder().encode(value),
                  let text = String(data: data, encoding: .utf8) else { return "" }
            return text
        }
    }
}
