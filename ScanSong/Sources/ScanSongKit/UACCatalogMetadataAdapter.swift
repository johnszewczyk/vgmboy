import MetaManCore

/// Projects the established schema-23 fields from UAC member metadata.
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
            fadeLengthMs: timing?.fadeLengthMs ?? 0
        )
    }
}
