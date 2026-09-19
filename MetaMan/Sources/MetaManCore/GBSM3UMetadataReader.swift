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
        let playLengthMs: Int?
        let loopLengthMs: Int?
        let fadeLengthMs: Int?
        let loopCount: Int?
        let tags: [MetadataTag]
        let relativePath: String
        let rawData: Data
        let sourceEncoding: String

        var quality: Int {
            (title.isEmpty ? 0 : 4)
                + (playLengthMs == nil ? 0 : 2)
                + (loopLengthMs == nil ? 0 : 1)
                + (fadeLengthMs == nil ? 0 : 1)
                + tags.count
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
        let targetName = URL(fileURLWithPath: displayName).lastPathComponent.lowercased()
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
            var comments: [MetadataTag] = []
            var parsedRows = 0
            for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
                let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : String(rawLine)
                if line.hasPrefix("#") {
                    if let tag = parseTagComment(line) { comments.append(tag) }
                    continue
                }
                guard let row = parseRow(line), row.fileName.lowercased() == targetName else { continue }
                parsedRows += 1
                guard entries.count < maximumPlaylistRows,
                      validIndexes.contains(row.index),
                      !row.title.isEmpty else { continue }
                entries.append(Entry(
                    index: row.index,
                    title: row.title,
                    playLengthMs: row.playLengthMs,
                    loopLengthMs: row.loopLengthMs,
                    fadeLengthMs: row.fadeLengthMs,
                    loopCount: row.loopCount,
                    tags: comments,
                    relativePath: companion.relativePath,
                    rawData: companion.data,
                    sourceEncoding: sourceEncoding
                ))
            }
            // A companion is only in scope when at least one row references
            // this GBS file. Comments from unrelated M3Us never bleed over.
            _ = parsedRows
        }
        guard !entries.isEmpty else { return result }

        let commonTags = preferredCommonTags(from: entries)
        let commonFields = Dictionary(
            commonTags.map { ($0.normalizedName, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let grouped = Dictionary(grouping: entries, by: \.index)
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

            let fields = track.document.fields
            let enrichedFields = MetadataFields(
                title: entry?.title ?? fields.title,
                game: commonFields["TITLE"] ?? fields.game,
                system: fields.system,
                artist: commonFields["ARTIST"] ?? fields.artist,
                album: fields.album,
                date: commonFields["DATE"] ?? fields.date,
                year: fields.year,
                genre: fields.genre,
                comment: fields.comment,
                copyright: fields.copyright,
                encodedBy: fields.encodedBy
            )

            var tags = track.document.tags
            tags.append(contentsOf: commonTags)
            if let title = entry?.title { tags.append(MetadataTag(name: "title", value: title)) }

            var facts = track.document.technicalFacts
            if let entry {
                facts["m3uSourcePath"] = entry.relativePath
                if let playLengthMs = entry.playLengthMs { facts["m3uPlayLengthMs"] = String(playLengthMs) }
                if let loopLengthMs = entry.loopLengthMs { facts["m3uLoopLengthMs"] = String(loopLengthMs) }
                if let fadeLengthMs = entry.fadeLengthMs { facts["m3uFadeLengthMs"] = String(fadeLengthMs) }
                if let loopCount = entry.loopCount { facts["m3uLoopCount"] = String(loopCount) }
            }

            var rawBlocks = track.document.rawMetadataBlocks ?? [:]
            if let rawData = entry?.rawData ?? commonEntry?.rawData { rawBlocks["companion-m3u"] = rawData }
            let baseTiming = track.document.timing
            let timing = MetadataTiming(
                introLengthMs: baseTiming?.introLengthMs ?? -1,
                loopLengthMs: entry?.loopLengthMs ?? baseTiming?.loopLengthMs ?? -1,
                playLengthMs: entry?.playLengthMs ?? baseTiming?.playLengthMs ?? 150_000,
                fadeLengthMs: entry?.fadeLengthMs ?? baseTiming?.fadeLengthMs ?? -1
            )
            var diagnostics = track.document.diagnostics
            if let index, choices.count > 1 {
                let distinct = Set(choices.map { "\($0.title)|\($0.playLengthMs ?? -1)|\($0.loopLengthMs ?? -1)" })
                if distinct.count > 1 {
                    diagnostics.append("Conflicting GBS M3U rows map to source track \(index); the richest row was selected.")
                }
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
        let playLengthMs: Int?
        let loopLengthMs: Int?
        let fadeLengthMs: Int?
        let loopCount: Int?
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
        let playLengthMs = fields.indices.contains(2) ? parseTime(fields[2]) : nil
        let loopLengthMs = fields.indices.contains(3) ? parseTime(fields[3]) : nil
        let fadeLengthMs = fields.indices.contains(4) ? parseTime(fields[4]) : nil
        let loopCount = fields.indices.contains(5) ? Int(fields[5].trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        return ParsedRow(
            fileName: fileName,
            index: index,
            title: title,
            playLengthMs: playLengthMs,
            loopLengthMs: loopLengthMs,
            fadeLengthMs: fadeLengthMs,
            loopCount: loopCount
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

    private static func preferredCommonTags(from entries: [Entry]) -> [MetadataTag] {
        let ranked = entries.sorted {
            if $0.tags.count != $1.tags.count { return $0.tags.count > $1.tags.count }
            return $0.relativePath < $1.relativePath
        }
        var result: [MetadataTag] = []
        var seen = Set<String>()
        for entry in ranked {
            for tag in entry.tags where seen.insert(tag.normalizedName).inserted {
                result.append(tag)
            }
        }
        return result
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

    private static func parseTime(_ value: String) -> Int? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "-" else { return nil }
        let components = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count) else { return nil }
        var seconds = 0
        for component in components {
            guard let number = Int(component), number >= 0,
                  seconds <= (Int.max - number) / 60 else { return nil }
            seconds = seconds * 60 + number
        }
        guard seconds <= Int.max / 1_000 else { return nil }
        return seconds * 1_000
    }
}
