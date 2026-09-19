import MetaManCore

extension ScannerMetadata {
    init(metadataDocument: MetadataDocument, includeDateAndEncodedByInComment: Bool = true) {
        let fields = metadataDocument.fields
        var comment = fields.comment ?? ""
        if includeDateAndEncodedByInComment {
            if let date = fields.date, !date.isEmpty {
                if !comment.isEmpty { comment += " | " }
                comment += "Date: \(date)"
            }
            if let encodedBy = fields.encodedBy, !encodedBy.isEmpty {
                if !comment.isEmpty { comment += " | " }
                comment += "Encoded By: \(encodedBy)"
            }
        }

        self.init(
            game: fields.game ?? "",
            song: fields.title ?? "",
            system: fields.system ?? "",
            author: fields.artist ?? "",
            comment: comment,
            introLengthMs: metadataDocument.timing?.introLengthMs ?? 0,
            loopLengthMs: metadataDocument.timing?.loopLengthMs ?? 0,
            playLengthMs: metadataDocument.timing?.playLengthMs ?? 0,
            fadeLengthMs: metadataDocument.timing?.fadeLengthMs ?? 0,
            trackNumber: Self.trackNumber(in: metadataDocument.tags),
            loopStartSample: metadataDocument.loop?.startSample,
            loopEndSample: metadataDocument.loop?.endSample,
            loopSampleRateHz: metadataDocument.loop?.sampleRateHz,
            loopSource: metadataDocument.loop?.source
        )
    }

    private static func trackNumber(in tags: [MetadataTag]) -> Int? {
        guard let value = tags.first(where: { $0.normalizedName == "TRACKNUMBER" })?.value else { return nil }
        let first = value.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? value
        return Int(first.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
