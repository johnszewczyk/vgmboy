import Foundation
import MetaManCore
import UACWrapperCore

/// Projects MetaMan's lossless read result into format-neutral UAC member
/// metadata. Native file bytes stay untouched; raw metadata payloads are
/// represented by their names and sizes while ordered decoded tags and facts
/// remain available for inspection.
public enum MetaManMetadataProjector {
    public static func memberFields(from document: MetadataDocument) -> [String: UACJSONValue] {
        var member: [String: UACJSONValue] = [:]
        let commonFields: [(String, String?)] = [
            ("title", document.fields.title),
            ("game", document.fields.game),
            ("system", document.fields.system),
            ("artist", document.fields.artist),
            ("album", document.fields.album),
            ("date", document.fields.date),
            ("year", document.fields.year),
            ("genre", document.fields.genre),
            ("comment", document.fields.comment),
            ("copyright", document.fields.copyright),
            ("encodedBy", document.fields.encodedBy)
        ]
        for (key, value) in commonFields {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                member[key] = .string(value)
            }
        }
        if let timing = document.timing,
           timing.introLengthMs != 0 || timing.loopLengthMs != 0
            || timing.playLengthMs != 0 || timing.fadeLengthMs != 0 {
            member["introLengthMs"] = .integer(Int64(timing.introLengthMs))
            member["loopLengthMs"] = .integer(Int64(timing.loopLengthMs))
            member["playLengthMs"] = .integer(Int64(timing.playLengthMs))
            member["fadeLengthMs"] = .integer(Int64(timing.fadeLengthMs))
        }

        var native: [String: UACJSONValue] = [
            "format": .string(document.format),
            "tags": .array(document.tags.map { .object([
                "name": .string($0.name),
                "value": .string($0.value)
            ]) }),
            "technicalFacts": .object(document.technicalFacts.mapValues(UACJSONValue.string)),
            "diagnostics": .array(document.diagnostics.map(UACJSONValue.string))
        ]
        if let sourceEncoding = document.sourceEncoding {
            native["sourceEncoding"] = .string(sourceEncoding)
        }
        if let rawMetadataBlocks = document.rawMetadataBlocks {
            native["rawBlockByteCounts"] = .object(rawMetadataBlocks.mapValues {
                .integer(Int64($0.count))
            })
        } else if let rawTagBlock = document.rawTagBlock {
            native["rawTagBlockByteCount"] = .integer(Int64(rawTagBlock.count))
        }
        member["nativeMetadata"] = .object(native)
        return member
    }
}
