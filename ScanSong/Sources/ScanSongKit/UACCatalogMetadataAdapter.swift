import Foundation
import MetaManCore

/// Projects the established common fields from UAC member metadata.
/// UAC is authoritative: absent, null, or invalid fields become blank/default
/// values and never fall back to tags in the contained source file.
enum UACCatalogMetadataAdapter {
    /// Resolves UAC's canonical package-level front-cover reference to the
    /// locator consumed by catalog gallery readers. UAC keeps the image as an
    /// ordinary payload member; materialization remains on demand in the UI.
    static func titleSnapLocator(in packageDocument: MetadataDocument) -> String? {
        guard case .object(let manifest)? = packageDocument.structuredMetadata,
              case .object(let game)? = manifest["game"],
              case .object(let gameMetadata)? = game["metadata"],
              let referenceValue = gameMetadata["cover_front"] else {
            return nil
        }

        let references: [MetadataJSONValue]
        switch referenceValue {
        case .object:
            references = [referenceValue]
        case .array(let values):
            references = values
        default:
            return nil
        }

        let packageMemberPaths: Set<String> = {
            guard case .array(let members)? = manifest["members"] else { return [] }
            return Set(members.compactMap { member -> String? in
                guard case .object(let fields) = member,
                      case .string(let path)? = fields["path"] else { return nil }
                return path
            })
        }()

        for reference in references {
            guard case .object(let fields) = reference,
                  case .string(let memberPath)? = fields["memberPath"],
                  case .string(let mediaType)? = fields["mediaType"],
                  mediaType.caseInsensitiveCompare("image/png") == .orderedSame,
                  URL(fileURLWithPath: memberPath).pathExtension.caseInsensitiveCompare("png") == .orderedSame,
                  StandaloneArchiveExtractor.isSafeRelativePath(memberPath),
                  packageMemberPaths.contains(memberPath) else {
                continue
            }
            return "archive-member:\(memberPath)"
        }
        return nil
    }

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
