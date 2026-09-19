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
        let rawPlaylists = objectArray(manifestObject["playlists"])
        let rawPlaylistsByID = Dictionary(uniqueKeysWithValues: rawPlaylists.compactMap { value -> (String, MetadataJSONValue)? in
            guard case .object(let playlist) = value,
                  case .string(let id)? = playlist["id"] else { return nil }
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

        func makeTrack(
            member: UACMember,
            memberIndex: Int,
            metadata: [String: UACJSONValue],
            trackIndex: Int,
            trackCount: Int,
            sourceTrackIndex: Int? = nil,
            playlistID: String? = nil,
            playlistEntry: MetadataJSONValue? = nil,
            visibleTrackIndex: Int? = nil,
            loop: MetadataLoop? = nil
        ) -> MetadataTrack {
            var scopedMetadata: [String: MetadataJSONValue] = [
                "packageID": .string(container.manifest.packageID),
                "game": gameValue,
                "member": rawMembersByPath[member.path] ?? .null
            ]
            if let variantID = member.variantID {
                scopedMetadata["variant"] = rawVariantsByID[variantID] ?? .null
            }
            scopedMetadata["sources"] = .array(member.sourceIDs.compactMap { rawSourcesByID[$0] })
            if let playlistID {
                scopedMetadata["subsongPlaylistID"] = .string(playlistID)
            }
            if let playlistEntry {
                scopedMetadata["subsongEntry"] = playlistEntry
            }

            let tags = metadata.keys.sorted().compactMap { key -> MetadataTag? in
                let value = displayValue(metadata[key] ?? .null)
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                return MetadataTag(name: key, value: value)
            }
            let document = MetadataDocument(
                format: "uac",
                fields: MetadataFields(
                    title: string(metadata["title"]),
                    game: string(metadata["game"]),
                    system: string(metadata["system"]),
                    artist: string(metadata["artist"]),
                    album: string(metadata["album"]),
                    date: string(metadata["date"]),
                    year: string(metadata["year"]),
                    genre: string(metadata["genre"]),
                    comment: string(metadata["comment"]),
                    copyright: string(metadata["copyright"]),
                    encodedBy: string(metadata["encodedBy"])
                ),
                tags: tags,
                structuredMetadata: .object(scopedMetadata),
                sourceEncoding: "UAC manifest JSON",
                timing: MetadataTiming(
                    introLengthMs: milliseconds(metadata["introLengthMs"]),
                    loopLengthMs: loop?.loopLengthMs ?? milliseconds(metadata["loopLengthMs"]),
                    playLengthMs: milliseconds(metadata["playLengthMs"]),
                    fadeLengthMs: milliseconds(metadata["fadeLengthMs"])
                ),
                loop: loop,
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
                    "uac.memberIndex": String(memberIndex),
                    "uac.trackIndex": String(trackIndex),
                    "uac.trackCount": String(trackCount)
                ].merging(member.streamBlake3.map { ["uac.memberStreamBLAKE3": $0] } ?? [:]) { current, _ in current }
                    .merging(member.variantID.map { ["uac.variantID": $0] } ?? [:]) { current, _ in current }
                    .merging(visibleTrackIndex.map { ["uac.visibleTrackIndex": String($0)] } ?? [:]) { current, _ in current },
                diagnostics: []
            )
            return MetadataTrack(sourceTrackIndex: sourceTrackIndex ?? trackIndex, document: document)
        }

        var subsongReferences: [(playlistID: String, entry: UACPlaylistEntry, rawEntry: MetadataJSONValue)] = []
        for playlist in container.manifest.playlists {
            guard let rawPlaylistValue = rawPlaylistsByID[playlist.id],
                  case .object(let rawPlaylist) = rawPlaylistValue else { continue }
            let rawEntries = objectArray(rawPlaylist["entries"])
            for (entryIndex, entry) in playlist.entries.enumerated()
            where entry.entryKind == "subsong" {
                guard rawEntries.indices.contains(entryIndex) else { continue }
                subsongReferences.append((playlist.id, entry, rawEntries[entryIndex]))
            }
        }

        let playableMembersByPath = Dictionary(uniqueKeysWithValues: container.manifest.members.enumerated().compactMap {
            index, member -> (String, (Int, UACMember))? in
            guard member.role == "playable" || member.role == "track" else { return nil }
            return (member.path, (index, member))
        })
        var seenSubsongTracks = Set<String>()
        let orderedSubsongReferences = subsongReferences.filter { reference in
            guard let trackIndex = reference.entry.trackIndex,
                  playableMembersByPath[reference.entry.targetMemberPath] != nil else { return false }
            return seenSubsongTracks.insert("\(reference.entry.targetMemberPath)\u{1F}\(trackIndex)").inserted
        }
        let trackCountsByMember = Dictionary(grouping: orderedSubsongReferences, by: { $0.entry.targetMemberPath })
            .mapValues { references in Set(references.compactMap { $0.entry.trackIndex }).count }
        let expandedMembers = Set(orderedSubsongReferences.map { $0.entry.targetMemberPath })
        var tracks: [MetadataTrack] = []
        for (visibleTrackIndex, reference) in orderedSubsongReferences.enumerated() {
            guard let trackIndexText = reference.entry.trackIndex,
                  let trackIndex = Int(trackIndexText),
                  let (memberIndex, member) = playableMembersByPath[reference.entry.targetMemberPath] else { continue }
            var metadata = member.metadata
            if case .object(let projected)? = reference.entry.extraFields["metaManMetadata"] {
                metadata.merge(projected) { _, trackValue in trackValue }
            }
            if let title = reference.entry.title { metadata["title"] = .string(title) }
            if let artist = reference.entry.artist { metadata["artist"] = .string(artist) }
            let loop = loopMetadata(
                metadata: metadata,
                playlistEntry: reference.entry
            )
            tracks.append(makeTrack(
                member: member,
                memberIndex: memberIndex,
                metadata: metadata,
                trackIndex: trackIndex,
                trackCount: trackCountsByMember[member.path] ?? 1,
                sourceTrackIndex: trackIndex,
                playlistID: reference.playlistID,
                playlistEntry: reference.rawEntry,
                visibleTrackIndex: visibleTrackIndex,
                loop: loop
            ))
        }

        // Ordinary file playlists do not expand member rows. Unreferenced
        // playable members remain visible after explicitly mapped subsongs.
        for (index, member) in container.manifest.members.enumerated() {
            guard (member.role == "playable" || member.role == "track"),
                  !expandedMembers.contains(member.path) else { continue }
            let loop = loopMetadata(metadata: member.metadata, playlistEntry: nil)
            tracks.append(makeTrack(
                member: member,
                memberIndex: index,
                metadata: member.metadata,
                trackIndex: 0,
                trackCount: 1,
                sourceTrackIndex: index,
                loop: loop
            ))
        }

        return MetadataReadResult(tracks: tracks, containerDocument: containerDocument)
    }


    private static func objectArray(_ value: MetadataJSONValue?) -> [MetadataJSONValue] {
        guard case .array(let values)? = value else { return [] }
        return values
    }

    private static func string(_ value: UACJSONValue?) -> String? {
        guard case .string(let text)? = value else { return nil }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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

    private static func loopMetadata(
        metadata: [String: UACJSONValue],
        playlistEntry: UACPlaylistEntry?
    ) -> MetadataLoop? {
        if case .object(let object)? = metadata["loop"],
           let loop = parseLoopObject(object, source: "uac-manifest") {
            return loop
        }
        let object = metadata
        if let loop = parseLoopObject(object, source: "uac-manifest") { return loop }
        guard let entry = playlistEntry else { return nil }
        let start = entry.loopStartRaw.flatMap(Int64.init)
        let end = entry.extraFields["loopEndSamples"].flatMap(int64)
        guard let start, let end, end > start else { return nil }
        let rate = entry.extraFields["loopSampleRate"].flatMap(intValue) ?? 44_100
        return MetadataLoop(startSample: start, endSample: end, sampleRateHz: rate, source: "uac-playlist")
    }

    private static func parseLoopObject(
        _ object: [String: UACJSONValue],
        source: String
    ) -> MetadataLoop? {
        let start = firstInt(object, keys: ["startSamples", "start_samples", "startSample", "start_sample"])
        var end = firstInt(object, keys: ["endSamples", "end_samples", "endSample", "end_sample"])
        if end == nil,
           let length = firstInt(object, keys: ["lengthSamples", "length_samples", "lengthSample", "length_sample"]),
           let start {
            end = start + length
        }
        guard let start, let end, end > start, start >= 0 else { return nil }
        let rate = Int(firstInt(object, keys: ["sampleRateHz", "sample_rate", "sampleRate"]) ?? 44_100)
        guard rate > 0 else { return nil }
        let mode = firstString(object, keys: ["mode", "type"]) ?? "forward"
        let repeatCount: Int?
        if let repeatValue = firstString(object, keys: ["repeat", "repeats", "count"]) {
            if ["forever", "infinite", "unbounded", "0"].contains(repeatValue.lowercased()) {
                repeatCount = nil
            } else {
                repeatCount = Int(repeatValue).map { max(0, $0) }
            }
        } else if let repeatValue = firstInt(object, keys: ["repeat", "repeats", "count"]) {
            repeatCount = repeatValue == 0 ? nil : Int(clamping: repeatValue)
        } else {
            repeatCount = nil
        }
        return MetadataLoop(
            startSample: start,
            endSample: end,
            sampleRateHz: rate,
            mode: mode,
            repeatCount: repeatCount,
            source: firstString(object, keys: ["source"]) ?? source
        )
    }

    private static func firstInt(_ object: [String: UACJSONValue], keys: [String]) -> Int64? {
        for key in keys {
            if let value = object[key], let integer = int64(value) { return integer }
        }
        return nil
    }

    private static func firstString(_ object: [String: UACJSONValue], keys: [String]) -> String? {
        for key in keys {
            if case .string(let value)? = object[key] {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty { return normalized }
            }
        }
        return nil
    }

    private static func int64(_ value: UACJSONValue?) -> Int64? {
        switch value {
        case .integer(let value): return value
        case .number(let value) where value.isFinite: return Int64(value.rounded(.towardZero))
        case .string(let value): return Int64(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }

    private static func intValue(_ value: UACJSONValue?) -> Int? {
        int64(value).map(Int.init)
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
