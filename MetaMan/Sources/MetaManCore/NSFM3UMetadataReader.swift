import Foundation

/// Projects NSFPlay's extended-M3U rows onto the NSF songs they name. The M3U
/// remains a byte-exact member; these values make its authored order and
/// playback timing usable through UAC's structured playlist.
enum NSFM3UMetadataReader {
    private static let maximumPlaylistBytes = 4 * 1024 * 1024
    private static let maximumPlaylistRows = 65_536

    private struct Entry: Equatable {
        let index: Int
        let title: String
        let timeRaw: String?
        let timeMs: Int?
        let loopRaw: String?
        let loopStartRaw: String?
        let loopStartMs: Int?
        let loopLengthMs: Int?
        let fadeRaw: String?
        let fadeMs: Int?
        let repeatRaw: String?
        let rawLine: String
        let playlistPath: String
        let sourceEncoding: String
        let validationIssues: [String]

        var conflictValues: [String?] {
            [
                title.isEmpty ? nil : title,
                timeMs.map(String.init),
                loopStartMs.map { "start:\($0)" } ?? loopLengthMs.map { "length:\($0)" },
                fadeMs.map(String.init),
                repeatRaw.flatMap(Int.init) == 0 ? nil : repeatRaw
            ]
        }
    }

    private struct ParsedPlaylist {
        let companion: MetadataCompanionFile
        let entries: [Entry]
        let packageComments: [MetadataTag]
        let issues: [String]
    }

    static func enrich(
        _ result: MetadataReadResult,
        context: MetadataReadContext,
        displayName: String
    ) throws -> MetadataReadResult {
        guard !result.tracks.isEmpty else { return result }
        let companions = context.companionFiles.filter {
            URL(fileURLWithPath: $0.relativePath).pathExtension.caseInsensitiveCompare("m3u") == .orderedSame
        }.sorted { $0.relativePath < $1.relativePath }
        guard !companions.isEmpty else { return result }

        let targetName = URL(fileURLWithPath: displayName).lastPathComponent
        let targetRelativePath = context.sourceRelativePath ?? targetName
        let pathReferencesAreExact = context.sourceRelativePath != nil
        let targetStem = URL(fileURLWithPath: targetName).deletingPathExtension().lastPathComponent
        let sameStem = companions.filter {
            URL(fileURLWithPath: $0.relativePath).deletingPathExtension().lastPathComponent
                .compare(targetStem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }

        var parsedByPlaylist: [ParsedPlaylist] = []
        for companion in companions {
            guard companion.data.count <= maximumPlaylistBytes,
                  !companion.data.contains(0),
                  let text = String(data: companion.data, encoding: .utf8)
                    ?? String(data: companion.data, encoding: .windowsCP1252) else {
                continue
            }
            let encoding = String(data: companion.data, encoding: .utf8) == nil ? "Windows-1252" : "UTF-8"
            var entries: [Entry] = []
            var packageComments: [MetadataTag] = []
            var issues: [String] = []
            for rawLineSlice in text.split(separator: "\n", omittingEmptySubsequences: false) {
                var line = String(rawLineSlice)
                if line.hasSuffix("\r") { line.removeLast() }
                if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
                if line.hasPrefix("#") {
                    let parsedComments = parsePackageComment(line)
                    packageComments.append(contentsOf: parsedComments)
                    if parsedComments.contains(where: { $0.name == "NSF M3U Ambiguous Published In" }) {
                        issues.append("Ambiguous NSF M3U Published in value in \(companion.relativePath).")
                    }
                    continue
                }
                guard line.range(of: "::NSF", options: [.caseInsensitive]) != nil else { continue }

                guard let parsed = parseRow(
                    line,
                    targetRelativePath: targetRelativePath,
                    pathReferencesAreExact: pathReferencesAreExact,
                    playlistPath: companion.relativePath,
                    trackCount: result.tracks.count,
                    encoding: encoding
                ) else {
                    if references(
                        line,
                        targetRelativePath: targetRelativePath,
                        pathReferencesAreExact: pathReferencesAreExact,
                        playlistPath: companion.relativePath
                    ) {
                        issues.append("Malformed NSF M3U row in \(companion.relativePath).")
                    }
                    continue
                }
                guard entries.count < maximumPlaylistRows else {
                    issues.append("NSF M3U row limit exceeded in \(companion.relativePath).")
                    break
                }
                if parsed.matchesTarget {
                    if let entry = parsed.entry {
                        entries.append(entry)
                        issues.append(contentsOf: entry.validationIssues.map {
                            "Invalid NSF M3U \($0) in \(companion.relativePath)."
                        })
                    } else {
                        issues.append("Invalid or out-of-range NSF song row in \(companion.relativePath).")
                    }
                } else if pathReferencesAreExact || sameStem.contains(where: { $0.relativePath == companion.relativePath }) {
                    issues.append("NSF M3U references another member in \(companion.relativePath).")
                }
            }
            parsedByPlaylist.append(ParsedPlaylist(
                companion: companion,
                entries: entries,
                packageComments: packageComments,
                issues: issues
            ))
        }

        // A same-stem M3U is the authored game playlist. If it is absent,
        // accept a single unambiguous sibling list that actually names this
        // NSF; never guess between per-track sidecars.
        let primary: ParsedPlaylist?
        if let sameName = parsedByPlaylist.first(where: {
            URL(fileURLWithPath: $0.companion.relativePath).deletingPathExtension().lastPathComponent
                .compare(targetStem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            primary = sameName
        } else {
            let candidates = parsedByPlaylist.filter { !$0.entries.isEmpty }
            primary = candidates.count == 1 ? candidates[0] : nil
        }
        guard let primary else { return result }

        let originalTracks = Dictionary(uniqueKeysWithValues: result.tracks.compactMap { track in
            track.sourceTrackIndex.map { ($0, track) }
        })
        let validIndexes = Set(originalTracks.keys)
        let primaryEntries = primary.entries.filter { validIndexes.contains($0.index) }

        var diagnostics = primary.issues
        let relevantPlaylists = parsedByPlaylist.filter {
            $0.companion.relativePath == primary.companion.relativePath || !$0.entries.isEmpty || !$0.issues.isEmpty
        }
        for playlist in relevantPlaylists where playlist.companion.relativePath != primary.companion.relativePath {
            diagnostics.append(contentsOf: playlist.issues)
        }
        var commentValues: [String: Set<String>] = [:]
        for playlist in relevantPlaylists {
            for comment in playlist.packageComments {
                commentValues[comment.name, default: []].insert(comment.value)
            }
        }
        let conflictingCommentNames = Set(commentValues.compactMap { name, values in
            values.count > 1 ? name : nil
        })
        for name in conflictingCommentNames.sorted() {
            diagnostics.append("NSF M3U package comment \(name) disagrees across playlists; its value was not promoted.")
        }
        let packageComments = primary.packageComments.filter { !conflictingCommentNames.contains($0.name) }
        let allEntries = parsedByPlaylist.flatMap(\.entries).filter { validIndexes.contains($0.index) }
        let entriesByIndex = Dictionary(grouping: allEntries, by: \.index)
        for (index, choices) in entriesByIndex where choices.count > 1 {
            guard let first = choices.first,
                  choices.dropFirst().contains(where: { $0.conflictValues != first.conflictValues }) else { continue }
            diagnostics.append("Conflicting NSF M3U title or timing rows map to source song \(index + 1).")
        }
        if let headerCopyright = result.tracks.first?.document.fields.copyright,
           primary.packageComments.contains(where: {
               $0.name == "NSF M3U Copyright" && $0.value != headerCopyright
           }) {
            diagnostics.append("NSF header copyright and M3U copyright comment disagree.")
        }

        var tracks: [MetadataTrack] = []
        var listedIndexes = Set<Int>()
        for entry in primaryEntries {
            guard let sourceTrack = originalTracks[entry.index] else { continue }
            listedIndexes.insert(entry.index)
            let rowDiagnostics = tracks.isEmpty ? diagnostics : []
            tracks.append(MetadataTrack(
                sourceTrackIndex: entry.index,
                document: applying(
                    entry,
                    to: sourceTrack.document,
                    packageComments: packageComments,
                    additionalDiagnostics: rowDiagnostics
                )
            ))
        }
        // Partial M3Us are common. Keep all NSF songs selectable after the
        // authored entries, without inventing titles or timings.
        for track in result.tracks {
            guard let index = track.sourceTrackIndex, !listedIndexes.contains(index) else { continue }
            let rowDiagnostics = tracks.isEmpty ? diagnostics : []
            tracks.append(MetadataTrack(sourceTrackIndex: index, document: applyingPackageComments(
                packageComments,
                sourcePath: primary.companion.relativePath,
                additionalDiagnostics: rowDiagnostics,
                to: track.document
            )))
        }
        return MetadataReadResult(tracks: tracks, containerDocument: result.containerDocument)
    }

    private struct ParsedRow {
        let matchesTarget: Bool
        let entry: Entry?
    }

    private static func parseRow(
        _ line: String,
        targetRelativePath: String,
        pathReferencesAreExact: Bool,
        playlistPath: String,
        trackCount: Int,
        encoding: String
    ) -> ParsedRow? {
        guard let marker = line.range(of: "::NSF,", options: [.caseInsensitive]) else { return nil }
        let reference = String(line[..<marker.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !reference.isEmpty else { return nil }
        guard sameNSFReference(
            reference,
            targetRelativePath: targetRelativePath,
            pathReferencesAreExact: pathReferencesAreExact,
            playlistPath: playlistPath
        ) else {
            return ParsedRow(matchesTarget: false, entry: nil)
        }

        let fields = csvFields(String(line[marker.upperBound...]))
        guard (2...6).contains(fields.count),
              let songNumber = Int(fields[0]), songNumber > 0, songNumber <= trackCount else {
            return ParsedRow(matchesTarget: true, entry: nil)
        }
        let index = songNumber - 1
        let title = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let timeRaw = field(fields, 2)
        let timeMs = timeRaw.flatMap(parseTime)
        var validationIssues: [String] = []
        if timeRaw != nil && timeMs == nil { validationIssues.append("play time") }
        let loopField = field(fields, 3)
        let loopRaw: String?
        let loopStartRaw: String?
        let loopStartMs: Int?
        let loopLengthMs: Int?
        if loopField == nil {
            loopRaw = nil
            loopStartRaw = nil
            loopStartMs = nil
            loopLengthMs = nil
        } else if let loopField, loopField == "-" || loopField == "0" {
            loopRaw = loopField
            loopStartRaw = nil
            loopStartMs = nil
            loopLengthMs = nil
        } else if let loopField, loopField.hasSuffix("-"),
                  let startRaw = Optional(String(loopField.dropLast())),
                  let startMs = parseTime(startRaw) {
            loopRaw = nil
            loopStartRaw = loopField
            loopStartMs = startMs
            loopLengthMs = nil
        } else if let loopField, let length = parseTime(loopField) {
            loopRaw = loopField
            loopStartRaw = nil
            loopStartMs = nil
            loopLengthMs = length
        } else {
            loopRaw = nil
            loopStartRaw = nil
            loopStartMs = nil
            loopLengthMs = nil
            validationIssues.append("loop value")
        }
        let fadeField = field(fields, 4)
        let fadeMs = fadeField.flatMap(parseTime)
        if fadeField != nil && fadeMs == nil { validationIssues.append("fade time") }
        let repeatField = field(fields, 5)
        let repeatRaw: String? = {
            guard let repeatField, let count = Int(repeatField), count >= 0 else { return nil }
            return repeatField
        }()
        if repeatField != nil && repeatRaw == nil { validationIssues.append("loop count") }
        let usableTimeRaw = timeMs.map { $0 > 0 ? timeRaw : nil } ?? nil
        let usableFadeRaw = fadeMs.map { $0 > 0 ? fadeField : nil } ?? nil

        return ParsedRow(matchesTarget: true, entry: Entry(
            index: index,
            title: title,
            timeRaw: usableTimeRaw,
            timeMs: timeMs,
            loopRaw: loopRaw,
            loopStartRaw: loopStartRaw,
            loopStartMs: loopStartMs,
            loopLengthMs: loopLengthMs,
            fadeRaw: usableFadeRaw,
            fadeMs: fadeMs,
            repeatRaw: repeatRaw,
            rawLine: line,
            playlistPath: playlistPath,
            sourceEncoding: encoding,
            validationIssues: validationIssues
        ))
    }

    private static func applying(
        _ entry: Entry,
        to source: MetadataDocument,
        packageComments: [MetadataTag],
        additionalDiagnostics: [String]
    ) -> MetadataDocument {
        var facts = source.technicalFacts
        facts["m3uSourcePath"] = entry.playlistPath
        facts["m3uRawLine"] = entry.rawLine
        facts["m3uTimeRaw"] = entry.timeRaw
        facts["m3uLoopRaw"] = entry.loopRaw
        facts["m3uLoopStartRaw"] = entry.loopStartRaw
        facts["m3uFadeRaw"] = entry.fadeRaw
        facts["m3uRepeatRaw"] = entry.repeatRaw
        if let value = entry.timeMs { facts["m3uPlayLengthMs"] = String(value) }
        if let value = entry.loopStartMs { facts["m3uIntroLengthMs"] = String(value) }
        if let value = entry.loopLengthMs { facts["m3uLoopLengthMs"] = String(value) }
        if let value = entry.fadeMs { facts["m3uFadeLengthMs"] = String(value) }
        var diagnostics = source.diagnostics
        diagnostics.append(contentsOf: additionalDiagnostics)
        return MetadataDocument(
            format: source.format,
            fields: MetadataFields(
                title: entry.title.isEmpty ? source.fields.title : entry.title,
                game: source.fields.game,
                system: source.fields.system,
                artist: source.fields.artist,
                album: source.fields.album,
                date: source.fields.date,
                year: source.fields.year,
                genre: source.fields.genre,
                comment: source.fields.comment,
                copyright: source.fields.copyright,
                encodedBy: source.fields.encodedBy
            ),
            tags: source.tags + packageComments + (entry.title.isEmpty ? [] : [MetadataTag(name: "title", value: entry.title)]),
            rawTagBlock: source.rawTagBlock,
            rawMetadataBlocks: source.rawMetadataBlocks,
            structuredMetadata: source.structuredMetadata,
            sourceEncoding: entry.sourceEncoding,
            timing: MetadataTiming(
                introLengthMs: entry.loopStartMs ?? -1,
                loopLengthMs: entry.loopLengthMs ?? -1,
                playLengthMs: entry.timeMs ?? -1,
                fadeLengthMs: entry.fadeMs ?? -1
            ),
            loop: source.loop,
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func applyingPackageComments(
        _ packageComments: [MetadataTag],
        sourcePath: String,
        additionalDiagnostics: [String],
        to source: MetadataDocument
    ) -> MetadataDocument {
        var facts = source.technicalFacts
        facts["m3uSourcePath"] = sourcePath
        return MetadataDocument(
            format: source.format,
            fields: source.fields,
            tags: source.tags + packageComments,
            rawTagBlock: source.rawTagBlock,
            rawMetadataBlocks: source.rawMetadataBlocks,
            structuredMetadata: source.structuredMetadata,
            sourceEncoding: source.sourceEncoding,
            timing: source.timing,
            loop: source.loop,
            technicalFacts: facts,
            diagnostics: source.diagnostics + additionalDiagnostics
        )
    }

    private static func parsePackageComment(_ line: String) -> [MetadataTag] {
        let value = line.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        let recognized: [(String, String)] = [
            ("music by", "NSF M3U Music By"),
            ("developed by", "NSF M3U Developed By"),
            ("published in", "NSF M3U Published In"),
            ("published by", "NSF M3U Published By"),
            ("copyright", "NSF M3U Copyright"),
            ("ripped by", "NSF M3U Ripped By"),
            ("ripper", "NSF M3U Ripper"),
            ("tagged by", "NSF M3U Tagged By"),
            ("updated by", "NSF M3U Updated By")
        ]
        for (prefix, tagName) in recognized {
            guard value.count >= prefix.count,
                  value.prefix(prefix.count).compare(prefix, options: [.caseInsensitive]) == .orderedSame else { continue }
            let suffix = value.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            let credit = suffix.hasPrefix(":") ? String(suffix.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) : suffix
            guard !credit.isEmpty else { return [] }
            if tagName == "NSF M3U Published In" {
                var result = [MetadataTag(name: tagName, value: credit)]
                if let byRange = credit.range(of: #"\bby\s+(.+)$"#, options: [.caseInsensitive, .regularExpression]) {
                    let publisher = String(credit[byRange]).replacingOccurrences(
                        of: #"^\s*by\s+"#,
                        with: "",
                        options: [.caseInsensitive, .regularExpression]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !publisher.isEmpty { result.append(MetadataTag(name: "NSF M3U Published By", value: publisher)) }
                }
                if credit.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                    result.append(MetadataTag(name: "NSF M3U Date", value: credit))
                } else {
                    let years = regexMatches(#"\b\d{4}\b"#, in: credit)
                    if years.count == 1 {
                        result.append(MetadataTag(name: "NSF M3U Year", value: years[0]))
                    } else if years.count > 1 {
                        result.append(MetadataTag(name: "NSF M3U Ambiguous Published In", value: credit))
                    }
                }
                return result
            }
            return [MetadataTag(name: tagName, value: credit)]
        }
        return []
    }

    private static func regexMatches(_ pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: nsRange).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }

    private static func field(_ fields: [String], _ index: Int) -> String? {
        guard fields.indices.contains(index) else { return nil }
        let value = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func sameNSFReference(
        _ reference: String,
        targetRelativePath: String,
        pathReferencesAreExact: Bool,
        playlistPath: String
    ) -> Bool {
        let target = targetRelativePath.replacingOccurrences(of: "\\", with: "/")
        let extensionName = URL(fileURLWithPath: reference).pathExtension.lowercased()
        guard extensionName.isEmpty || extensionName == "nsf" else { return false }
        if pathReferencesAreExact {
            guard let resolved = resolve(reference, relativeTo: playlistPath) else { return false }
            let expected = extensionName.isEmpty && target.lowercased().hasSuffix(".nsf")
                ? String(target.dropLast(4))
                : target
            return resolved.compare(expected, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let lhs = URL(fileURLWithPath: reference.replacingOccurrences(of: "\\", with: "/"))
        let targetName = URL(fileURLWithPath: target).lastPathComponent
        return lhs.lastPathComponent.compare(targetName,
            options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            || (extensionName.isEmpty && lhs.lastPathComponent.compare(
                URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame)
    }

    private static func references(
        _ line: String,
        targetRelativePath: String,
        pathReferencesAreExact: Bool,
        playlistPath: String
    ) -> Bool {
        guard let marker = line.range(of: "::NSF", options: [.caseInsensitive]) else { return false }
        let reference = String(line[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return sameNSFReference(
            reference,
            targetRelativePath: targetRelativePath,
            pathReferencesAreExact: pathReferencesAreExact,
            playlistPath: playlistPath
        )
    }

    private static func resolve(_ reference: String, relativeTo playlistPath: String) -> String? {
        let normalizedReference = reference.replacingOccurrences(of: "\\", with: "/")
        guard !normalizedReference.hasPrefix("/"), !normalizedReference.contains(":"),
              !normalizedReference.contains("\0") else { return nil }
        var components = playlistPath.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .dropLast()
            .map(String.init)
        for component in normalizedReference.split(separator: "/") {
            if component == "." { continue }
            if component == ".." {
                guard !components.isEmpty else { return nil }
                components.removeLast()
            } else {
                components.append(String(component))
            }
        }
        return components.joined(separator: "/")
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
            } else if character == "\"" {
                if quoted, next < line.endIndex, line[next] == "\"" {
                    field.append("\"")
                    index = line.index(after: next)
                } else {
                    quoted.toggle()
                    index = next
                }
            } else if character == ",", !quoted {
                fields.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
                field = ""
                index = next
            } else {
                field.append(character)
                index = next
            }
        }
        guard !quoted else { return [] }
        fields.append(field.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    /// NSFPlay times use h:m:s, with fractional seconds allowed in source
    /// lists. Milliseconds are rounded half-up; raw authored timing stays in
    /// the manifest and original M3U so sub-millisecond precision is retained.
    private static func parseTime(_ value: String) -> Int? {
        let components = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count) else { return nil }
        var totalSeconds: Int64 = 0
        var fractionMs = 0
        for (index, component) in components.enumerated() {
            let final = index == components.count - 1
            let parts = component.split(separator: ".", omittingEmptySubsequences: false)
            guard parts.count == 1 || (final && parts.count == 2),
                  let number = Int64(parts[0]), number >= 0,
                  (components.count == 1 || index == 0 || number < 60),
                  totalSeconds <= (Int64.max - number) / 60 else { return nil }
            totalSeconds = totalSeconds * 60 + number
            if parts.count == 2 {
                let fraction = parts[1]
                guard !fraction.isEmpty, fraction.count <= 9,
                      fraction.allSatisfy(\.isNumber),
                      let fractional = Int64(fraction) else { return nil }
                let scale = Int64(pow10(fraction.count))
                let scaled = fractional * 1_000
                fractionMs = Int((scaled + scale / 2) / scale)
            }
        }
        guard totalSeconds <= (Int64.max - Int64(fractionMs)) / 1_000 else { return nil }
        let totalMs = totalSeconds * 1_000 + Int64(fractionMs)
        return totalMs <= Int64(Int.max) ? Int(totalMs) : nil
    }

    private static func pow10(_ exponent: Int) -> Int64 {
        (0..<exponent).reduce(1) { value, _ in value * 10 }
    }
}
