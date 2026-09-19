import MetaManCore

/// Projects the established schema-24 fields from UAC member metadata.
/// UAC is authoritative: absent, null, or invalid fields become blank/default
/// values and never fall back to tags in the contained source file.
enum UACCatalogMetadataAdapter {
    static func project(_ document: MetadataDocument) -> ScannerMetadata {
        let timing = document.timing
        return ScannerMetadata(
            game: document.fields.game ?? "",
            song: document.fields.title ?? "",
            system: document.fields.system ?? "",
            author: document.fields.artist ?? "",
            comment: document.fields.comment ?? "",
            introLengthMs: timing?.introLengthMs ?? 0,
            loopLengthMs: timing?.loopLengthMs ?? 0,
            playLengthMs: timing?.playLengthMs ?? 0,
            fadeLengthMs: timing?.fadeLengthMs ?? 0,
            trackNumber: trackNumber(in: document),
            loopStartSample: document.loop?.startSample,
            loopEndSample: document.loop?.endSample,
            loopSampleRateHz: document.loop?.sampleRateHz,
            loopSource: document.loop?.source
        )
    }

    private static func trackNumber(in document: MetadataDocument) -> Int? {
        if let direct = document.tags.first(where: { $0.normalizedName == "TRACKNUMBER" })?.value {
            let first = direct.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? direct
            if let number = Int(first.trimmingCharacters(in: .whitespacesAndNewlines)) { return number }
        }
        guard case .object(let scoped)? = document.structuredMetadata,
              case .object(let member)? = scoped["member"],
              case .object(let memberMetadata)? = member["metadata"],
              case .object(let tags)? = memberMetadata["tags"],
              case .string(let value)? = tags.first(where: { $0.key.uppercased() == "TRACKNUMBER" })?.value else { return nil }
        let first = value.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? value
        return Int(first.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
