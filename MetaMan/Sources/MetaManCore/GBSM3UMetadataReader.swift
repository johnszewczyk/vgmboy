import Foundation

/// Applies the NEZplug extended-M3U track catalog to the GBS tracks it names.
/// The original M3U bytes remain separate UAC members; these projections make
/// their titles, identity comments, and timing available as native track tags.
enum GBSM3UMetadataReader {
    private static let maximumPlaylistBytes = 4 * 1024 * 1024
    private static let maximumPlaylistRows = 65_536

    private struct Entry {
        let index: Int
        let title: String
        let tags: [MetadataTag]
        let relativePath: String
        let sourceOrder: Int
        let rawData: Data
        let sourceEncoding: String

        var quality: Int {
            (title.isEmpty ? 0 : 4) + tags.count
        }
    }

    static func enrich(
        _ result: MetadataReadResult,
        context: MetadataReadContext,
        displayName: String
    ) throws -> MetadataReadResult {
        let companions = context.companionFiles.filter {
            URL(fileURLWithPath: $0.relativePath).pathExtension.caseInsensitiveCompare("m3u") == .orderedSame
        }
        guard !companions.isEmpty else { return result }
        let targetURL = URL(fileURLWithPath: displayName)
        let targetName = targetURL.lastPathComponent.lowercased()
        let targetStem = targetURL.deletingPathExtension().lastPathComponent.lowercased()
        let validIndexes = Set(result.tracks.compactMap(\.sourceTrackIndex))
        var entries: [Entry] = []

        for companion in companions.sorted(by: { $0.relativePath < $1.relativePath }) {
            guard companion.data.count <= maximumPlaylistBytes,
                  !companion.data.contains(0),
                  let text = String(data: companion.data, encoding: .utf8)
                    ?? String(data: companion.data, encoding: .windowsCP1252) else {
                continue
            }
            let sourceEncoding = String(data: companion.data, encoding: .utf8) == nil ? "Windows-1252" : "UTF-8"
            let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            let oneBasedIndexes = lines.contains {
                String($0).localizedCaseInsensitiveContains("1-indexed playlist")
            }
            var comments: [MetadataTag] = []
            var parsedRows = 0
            for rawLine in lines {
                let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : String(rawLine)
                if line.hasPrefix("#") {
                    // Game_Emu_Player M3Us can explicitly declare their rows
                    // one-based. Treat this as an indexing directive, not a
                    // native COMMENT tag; the original M3U bytes are retained.
                    if line.localizedCaseInsensitiveContains("1-indexed playlist") { continue }
                    if let tag = parseTagComment(line) { comments.append(tag) }
                    continue
                }
                guard let row = parseRow(line),
                      row.fileName.lowercased() == targetName
                        || row.fileName.lowercased() == targetStem else { continue }
                parsedRows += 1
                let sourceIndex = row.index - (oneBasedIndexes ? 1 : 0)
                guard entries.count < maximumPlaylistRows,
                      validIndexes.contains(sourceIndex) else { continue }
                entries.append(Entry(
                    index: sourceIndex,
                    title: row.title,
                    tags: comments,
                    relativePath: companion.relativePath,
                    sourceOrder: parsedRows - 1,
                    rawData: companion.data,
                    sourceEncoding: sourceEncoding
                ))
            }
            // A companion is only in scope when at least one row references
            // this GBS file. Comments from unrelated M3Us never bleed over.
            _ = parsedRows
        }
        guard !entries.isEmpty else { return result }

        let playlistGroups = Dictionary(grouping: entries, by: \.relativePath)
        let playlistOrders = playlistGroups.keys.sorted().map { path in
            (path, (playlistGroups[path] ?? []).sorted { $0.sourceOrder < $1.sourceOrder }.map(\.index))
        }
        var playlistDiagnostics: [String] = []
        for (path, order) in playlistOrders where Set(order).count != order.count {
            playlistDiagnostics.append(
                "GBS M3U \(path) repeats a source track index; preserve the original playlist for review."
            )
        }
        // A one-row M3U is a per-track annotation, not an authored queue. Many
        // GBS distributions include one such file per named track alongside a
        // multi-row master playlist. Compare queue order only among playlists
        // that actually contain more than one row.
        let queueOrders = playlistOrders.filter { $0.1.count > 1 }
        if let firstOrder = queueOrders.first?.1,
           queueOrders.dropFirst().contains(where: { $0.1 != firstOrder }) {
            playlistDiagnostics.append(
                "GBS M3U files define different row orders; preserve the competing playlists for review."
            )
        }
        let grouped = Dictionary(grouping: entries, by: \.index)
        let commonTagResolution = unambiguousCommonTags(from: grouped)
        let commonTags = commonTagResolution.tags
        var queueOrderByIndex: [Int: Int] = [:]
        if let authoredQueue = queueOrders.first?.1 {
            for (position, index) in authoredQueue.enumerated() where queueOrderByIndex[index] == nil {
                queueOrderByIndex[index] = position
            }
        }
        let commonEntry = entries.sorted {
            if $0.quality != $1.quality { return $0.quality > $1.quality }
            return $0.relativePath < $1.relativePath
        }.first
        let tracks = result.tracks.map { track -> MetadataTrack in
            let index = track.sourceTrackIndex
            let choices = index.flatMap { grouped[$0] } ?? []
            let entry = choices.sorted(by: {
                      if $0.quality != $1.quality { return $0.quality > $1.quality }
                      return $0.relativePath < $1.relativePath
                  }).first
            let title = unambiguous(choices.map { $0.title.isEmpty ? nil : $0.title })

            let fields = track.document.fields
            let enrichedFields = MetadataFields(
                title: title ?? fields.title,
                // Keep the native header identity separate from M3U comments.
                // The package projector compares both and only promotes an
                // M3U value when it agrees with the source header.
                game: fields.game,
                system: fields.system,
                artist: fields.artist,
                album: fields.album,
                date: fields.date,
                year: fields.year,
                genre: fields.genre,
                comment: fields.comment,
                copyright: fields.copyright,
                encodedBy: fields.encodedBy
            )

            var tags = track.document.tags
            tags.append(contentsOf: commonTags)
            if let title { tags.append(MetadataTag(name: "title", value: title)) }

            var facts = track.document.technicalFacts
            if let entry {
                facts["m3uSourcePath"] = entry.relativePath
            }
            if let index {
                if let queueOrder = queueOrderByIndex[index] {
                    facts["m3uSourceOrder"] = String(queueOrder)
                } else if let entry {
                    // With annotations only, retain their local row order;
                    // tied one-row annotations fall back to the GBS index in
                    // the UAC writer.
                    facts["m3uSourceOrder"] = String(entry.sourceOrder)
                }
            }
            for tag in commonTags {
                facts["m3uSharedTag.\(tag.normalizedName)"] = tag.value
            }
            var rawBlocks = track.document.rawMetadataBlocks ?? [:]
            if let rawData = entry?.rawData ?? commonEntry?.rawData { rawBlocks["companion-m3u"] = rawData }
            let timing = MetadataTiming(
                // GBS M3U time, fade, and loop columns are not retained.
                introLengthMs: -1,
                loopLengthMs: -1,
                playLengthMs: -1,
                fadeLengthMs: -1
            )
            var diagnostics = track.document.diagnostics
            diagnostics.append(contentsOf: commonTagResolution.diagnostics)
            diagnostics.append(contentsOf: playlistDiagnostics)
            if let index, choices.count > 1,
               hasConflictingValues(choices.map { $0.title.isEmpty ? nil : $0.title }) {
                diagnostics.append("Conflicting GBS M3U titles map to source track \(index); the ambiguous title was omitted.")
            }
            let document = MetadataDocument(
                format: track.document.format,
                fields: enrichedFields,
                tags: tags,
                rawTagBlock: track.document.rawTagBlock,
                rawMetadataBlocks: rawBlocks,
                structuredMetadata: track.document.structuredMetadata,
                sourceEncoding: entry?.sourceEncoding ?? commonEntry?.sourceEncoding ?? track.document.sourceEncoding,
                timing: timing,
                technicalFacts: facts,
                diagnostics: diagnostics
            )
            return MetadataTrack(sourceTrackIndex: index, document: document)
        }
        return MetadataReadResult(tracks: tracks, containerDocument: result.containerDocument)
    }

    private struct ParsedRow {
        let fileName: String
        let index: Int
        let title: String
    }

    private static func parseRow(_ line: String) -> ParsedRow? {
        guard let marker = line.range(of: "::GBS,", options: [.caseInsensitive]) else { return nil }
        let fileName = URL(fileURLWithPath: String(line[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines))
            .lastPathComponent
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        let fields = csvFields(String(line[marker.upperBound...]))
        guard fields.count >= 2,
              let index = parseIndex(fields[0]),
              !fileName.isEmpty else { return nil }
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedRow(
            fileName: fileName,
            index: index,
            title: title
        )
    }

    private static func parseTagComment(_ line: String) -> MetadataTag? {
        let content = line.dropFirst().drop(while: { $0 == " " || $0 == "\t" })
        guard content.first == "@" else { return nil }
        let pair = content.dropFirst().split(maxSplits: 1, whereSeparator: { $0 == " " || $0 == "\t" })
        guard pair.count == 2 else { return nil }
        let name = String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !value.isEmpty else { return nil }
        return MetadataTag(name: name, value: value)
    }

    private static func unambiguousCommonTags(
        from entriesByTrack: [Int: [Entry]]
    ) -> (tags: [MetadataTag], diagnostics: [String]) {
        guard !entriesByTrack.isEmpty else { return ([], []) }
        let allEntries = entriesByTrack.values.flatMap { $0 }
        let names = Set(allEntries.flatMap { $0.tags.map(\.normalizedName) }).sorted()
        var result: [MetadataTag] = []
        var diagnostics: [String] = []
        for name in names {
            var valuesByTrack: [String] = []
            var conflictingIndexes: [Int] = []
            for index in entriesByTrack.keys.sorted() {
                let values = Set((entriesByTrack[index] ?? []).flatMap { entry in
                    entry.tags
                        .filter { $0.normalizedName == name }
                        .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                })
                if values.count > 1 {
                    conflictingIndexes.append(index)
                } else if let value = values.first {
                    valuesByTrack.append(value)
                }
            }
            let values = Set(valuesByTrack)
            if !conflictingIndexes.isEmpty {
                let displayName = allEntries.flatMap(\.tags).first(where: { $0.normalizedName == name })?.name ?? name
                diagnostics.append(
                    "GBS M3U # @\(displayName) values conflict for source track indexes \(conflictingIndexes.map { String($0) }.joined(separator: ", ")); the shared value was not promoted."
                )
                continue
            }
            // A master M3U's shared comment is repeated on each applicable
            // row. One-row track sidecars may omit that comment, so compare
            // the resolved values by source index rather than by M3U file.
            // Missing values remain absent and do not become a blank tag.
            guard values.count == 1,
                  valuesByTrack.count == entriesByTrack.count else {
                continue
            }
            if let value = values.first {
                let displayName = allEntries.flatMap(\.tags).first(where: { $0.normalizedName == name })?.name ?? name
                result.append(MetadataTag(name: displayName, value: value))
            }
        }
        return (result, diagnostics)
    }

    private static func csvFields(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var quoted = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            let next = line.index(after: index)
            if character == "\\", next < line.endIndex, line[next] == "," {
                field.append(",")
                index = line.index(after: next)
                continue
            }
            if character == "\"" {
                if quoted, next < line.endIndex, line[next] == "\"" {
                    field.append("\"")
                    index = line.index(after: next)
                    continue
                }
                quoted.toggle()
            } else if character == ",", !quoted {
                fields.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
                field = ""
            } else {
                field.append(character)
            }
            index = next
        }
        fields.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    private static func parseIndex(_ value: String) -> Int? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("$"), text.count > 1 { return Int(text.dropFirst(), radix: 16) }
        return Int(text)
    }

    private static func unambiguous<Value: Hashable>(_ values: [Value?]) -> Value? {
        guard let first = values.first,
              values.dropFirst().allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    private static func hasConflictingValues<Value: Hashable>(_ values: [Value?]) -> Bool {
        guard let first = values.first else { return false }
        return !values.dropFirst().allSatisfy { $0 == first }
    }

}
