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
        if let timing = document.timing {
            // Zero and negative values are the readers' "not supplied" defaults.
            // Do not materialize those defaults as package tags; a present value
            // must describe a measured duration.
            if timing.introLengthMs > 0 {
                member["introLengthMs"] = .integer(Int64(timing.introLengthMs))
            }
            if timing.loopLengthMs > 0 {
                member["loopLengthMs"] = .integer(Int64(timing.loopLengthMs))
            }
            if timing.playLengthMs > 0 {
                member["playLengthMs"] = .integer(Int64(timing.playLengthMs))
            }
            if timing.fadeLengthMs > 0 {
                member["fadeLengthMs"] = .integer(Int64(timing.fadeLengthMs))
            }
        }
        if let loop = document.loop {
            member["loop"] = .object([
                "mode": .string(loop.mode),
                "startSamples": .integer(loop.startSample),
                "endSamples": .integer(loop.endSample),
                "sampleRateHz": .integer(Int64(loop.sampleRateHz)),
                "repeat": .string(loop.repeatCount.map(String.init) ?? "forever"),
                "source": .string(loop.source ?? "metaman")
            ])
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

    /// Multi-track members receive only metadata that describes the whole
    /// source. Track-specific values stay on their ordered playlist entries.
    public static func sharedMemberFields(
        from documents: [MetadataDocument],
        sourceTrackIndices: [Int]
    ) -> [String: UACJSONValue] {
        guard let first = documents.first else { return [:] }
        let commonFields: [(String, (MetadataDocument) -> String?)] = [
            ("game", { $0.fields.game }),
            ("system", { $0.fields.system }),
            ("artist", { $0.fields.artist }),
            ("album", { $0.fields.album }),
            ("date", { $0.fields.date }),
            ("year", { $0.fields.year }),
            ("genre", { $0.fields.genre }),
            ("comment", { $0.fields.comment }),
            ("copyright", { $0.fields.copyright }),
            ("encodedBy", { $0.fields.encodedBy })
        ]
        var member: [String: UACJSONValue] = [:]
        for (key, valueForDocument) in commonFields {
            let values = documents.map { valueForDocument($0)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
            guard let value = values.first, !value.isEmpty, values.allSatisfy({ $0 == value }) else { continue }
            member[key] = .string(value)
        }
        member["nativeMetadata"] = .object([
            "format": .string(first.format),
            "trackCount": .integer(Int64(documents.count)),
            "sourceTrackIndices": .array(sourceTrackIndices.map { .integer(Int64($0)) })
        ])
        return member
    }
}
