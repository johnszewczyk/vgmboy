import Foundation
import MetaManCore
import UACWrapperCore

/// Projects only normalized, useful fields from MetaMan's read result into
/// UAC metadata. The unchanged source member remains the preservation copy of
/// its native tags, raw blocks, technical facts, and parser details.
public enum MetaManMetadataProjector {
    /// Converts known legacy machine keys to their canonical Title Case tag
    /// names. Unknown user fields stay untouched.
    public static func canonicalStandardTagName(for key: String) -> String? {
        let token = key.unicodeScalars
            .filter(CharacterSet.alphanumerics.contains)
            .map(String.init)
            .joined()
            .lowercased()
        switch token {
        case "title": return "Title"
        case "game": return "Game"
        case "system": return "System"
        case "artist": return "Artist"
        case "album": return "Album"
        case "date": return "Date"
        case "year": return "Year"
        case "genre": return "Genre"
        case "comment": return "Comment"
        case "copyright": return "Copyright"
        case "encodedby": return "Encoded By"
        case "tracknumber": return "Track Number"
        case "introlengthms": return "Intro Length (ms)"
        case "looplengthms": return "Loop Length (ms)"
        case "playlengthms": return "Play Length (ms)"
        case "durationms": return "Duration (ms)"
        case "fadelengthms": return "Fade Length (ms)"
        case "loop": return "Loop"
        default: return nil
        }
    }

    public static func memberFields(from document: MetadataDocument) -> [String: UACJSONValue] {
        var member: [String: UACJSONValue] = [:]
        let commonFields: [(String, String?)]
        if document.format.caseInsensitiveCompare("nsf") == .orderedSame {
            commonFields = [("Title", document.fields.title)]
        } else {
            commonFields = [
                ("Title", document.fields.title),
                ("Game", document.fields.game),
                ("System", document.fields.system),
                ("Artist", document.fields.artist),
                ("Album", document.fields.album),
                ("Date", document.fields.date),
                ("Year", document.fields.year),
                ("Genre", document.fields.genre),
                ("Comment", document.fields.comment),
                ("Copyright", document.fields.copyright),
                ("Encoded By", document.fields.encodedBy)
            ]
        }
        for (key, value) in commonFields {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                member[key] = .string(value)
            }
        }
        if document.format.caseInsensitiveCompare("nsf") == .orderedSame,
           let version = document.technicalFacts["version"], !version.isEmpty {
            member["Format"] = .string("NSF v.\(version)")
        }
        if let timing = document.timing {
            // Zero and negative values are the readers' "not supplied" defaults.
            // Do not materialize those defaults as package tags; a present value
            // must describe a measured duration.
            if timing.introLengthMs > 0 {
                member["Intro Length (ms)"] = .integer(Int64(timing.introLengthMs))
            }
            if timing.loopLengthMs > 0 {
                member["Loop Length (ms)"] = .integer(Int64(timing.loopLengthMs))
            }
            if timing.playLengthMs > 0 {
                member["Play Length (ms)"] = .integer(Int64(timing.playLengthMs))
            }
            if timing.fadeLengthMs > 0 {
                member["Fade Length (ms)"] = .integer(Int64(timing.fadeLengthMs))
            }
        }
        if let loop = document.loop {
            member["Loop"] = .object([
                "mode": .string(loop.mode),
                "startSamples": .integer(loop.startSample),
                "endSamples": .integer(loop.endSample),
                "sampleRateHz": .integer(Int64(loop.sampleRateHz)),
                "repeat": .string(loop.repeatCount.map(String.init) ?? "forever"),
                "source": .string(loop.source ?? "metaman")
            ])
        }

        return member
    }

    /// Multi-track members receive only metadata that describes the whole
    /// source. Track-specific values stay on their ordered playlist entries.
    public static func sharedMemberFields(
        from documents: [MetadataDocument]
    ) -> [String: UACJSONValue] {
        guard !documents.isEmpty else { return [:] }
        if documents.allSatisfy({ $0.format.caseInsensitiveCompare("nsf") == .orderedSame }) {
            return sharedNSFFields(from: documents).fields
        }
        let commonFields: [(String, (MetadataDocument) -> String?)] = [
            ("Game", { $0.fields.game }),
            ("System", { $0.fields.system }),
            ("Artist", { $0.fields.artist }),
            ("Album", { $0.fields.album }),
            ("Date", { $0.fields.date }),
            ("Year", { $0.fields.year }),
            ("Genre", { $0.fields.genre }),
            ("Comment", { $0.fields.comment }),
            ("Copyright", { $0.fields.copyright }),
            ("Encoded By", { $0.fields.encodedBy })
        ]
        var member: [String: UACJSONValue] = [:]
        for (key, valueForDocument) in commonFields {
            let values = documents.map { valueForDocument($0)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            guard let value = values.first, !value.isEmpty, values.allSatisfy({ $0 == value }) else { continue }
            member[key] = .string(value)
        }
        return member
    }

    public static func sharedNSFFields(
        from documents: [MetadataDocument]
    ) -> (fields: [String: UACJSONValue], conflicts: [String]) {
        guard !documents.isEmpty else { return ([:], []) }
        var member: [String: UACJSONValue] = [:]
        var conflicts: [String] = []

        func commonHeaderValue(_ keyPath: KeyPath<MetadataFields, String?>) -> String? {
            let values = documents.map { $0.fields[keyPath: keyPath]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            guard let first = values.first, !first.isEmpty, values.allSatisfy({ $0 == first }) else { return nil }
            return first
        }
        if let value = commonHeaderValue(\.game) { member["Game Title"] = .string(value) }
        if let value = commonHeaderValue(\.artist) { member["Album Artist"] = .string(value) }

        let tags = documents[0].tags
        func values(for sourceNames: Set<String>) -> [String] {
            var seen = Set<String>()
            return tags.compactMap { tag in
                guard sourceNames.contains(tag.name.uppercased()),
                      !isPlaceholder(tag.value) else { return nil }
                let value = tag.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, seen.insert(value).inserted else { return nil }
                return value
            }
        }
        func setCredit(_ tag: String, from sourceNames: Set<String>) {
            let sourceValues = values(for: sourceNames)
            guard !sourceValues.isEmpty else { return }
            member[tag] = metadataValue(sourceValues)
        }

        setCredit("Composer", from: ["NSF M3U MUSIC BY"])
        setCredit("Dumper", from: ["NSF M3U RIPPED BY", "NSF M3U RIPPER"])
        setCredit("Developer", from: ["NSF M3U DEVELOPED BY"])
        setCredit("Publisher", from: ["NSF M3U PUBLISHED BY"])
        let taggers = values(for: ["NSF M3U TAGGED BY", "NSF M3U UPDATED BY"])
        if !taggers.isEmpty { member["Taggers"] = .array(taggers.map(UACJSONValue.string)) }

        let headerCopyrightValues = documents.compactMap { normalizedSourceValue($0.fields.copyright) }
        let m3uCopyrightValues = values(for: ["NSF M3U COPYRIGHT"])
        let copyrightValues = Array(Set(headerCopyrightValues + m3uCopyrightValues)).sorted()
        let m3uCopyrightConflict = documents.contains { document in
            document.diagnostics.contains { $0.contains("package comment NSF M3U Copyright") }
        }
        if copyrightValues.count == 1 && !m3uCopyrightConflict {
            member["Copyright"] = .string(copyrightValues[0])
        } else if copyrightValues.count > 1 || m3uCopyrightConflict {
            conflicts.append("NSF header and M3U copyright values disagree; Copyright was not promoted.")
        }

        let years = values(for: ["NSF M3U YEAR"])
        if years.count == 1 { member["Year"] = .string(years[0]) }
        else if years.count > 1 { conflicts.append("NSF M3U Published in comments contain multiple years; Year was not promoted.") }
        let dates = values(for: ["NSF M3U DATE"])
        if dates.count == 1 { member["Date"] = .string(dates[0]) }
        else if dates.count > 1 { conflicts.append("NSF M3U Published in comments contain multiple dates; Date was not promoted.") }
        return (member, conflicts)
    }

    private static func normalizedSourceValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || isPlaceholder(cleaned) ? nil : cleaned
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "?" }
        return token.isEmpty || ["unknown", "n/a", "na", "none", "?", "??", "???"].contains(token)
    }

    private static func metadataValue(_ values: [String]) -> UACJSONValue {
        values.count == 1 ? .string(values[0]) : .array(values.map(UACJSONValue.string))
    }
}
