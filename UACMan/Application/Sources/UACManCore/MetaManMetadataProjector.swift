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
        let commonFields: [(String, String?)] = [
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
        for (key, value) in commonFields {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                member[key] = .string(value)
            }
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
}
