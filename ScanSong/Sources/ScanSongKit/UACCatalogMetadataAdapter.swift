import Foundation
import MetaManCore

/// Projects the established common fields from UAC member metadata.
/// UAC is authoritative: absent, null, or invalid fields become blank/default
/// values and never fall back to tags in the contained source file.
enum UACCatalogMetadataAdapter {
    /// Resolves UAC's package-level title-snap attachment tag to the locator
    /// consumed by catalog gallery readers. UAC keeps the image as an ordinary
    /// payload member; materialization remains on demand in the UI.
    static func titleSnapLocator(in packageDocument: MetadataDocument) -> String? {
        guard case .object(let manifest)? = packageDocument.structuredMetadata,
              case .object(let game)? = manifest["game"],
              case .object(let gameMetadata)? = game["metadata"] else {
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

        let attachmentValues = gameMetadata
            .compactMap { entry -> (Int, String, MetadataJSONValue)? in
                let role = normalizedAttachmentRole(entry.key)
                switch role {
                case "titlesnap": return (0, entry.key, entry.value)
                // Read the former front-cover spelling for existing packages.
                case "coverfront": return (1, entry.key, entry.value)
                default: return nil
                }
            }
            .sorted { lhs, rhs in
                lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
            }

        for (_, _, value) in attachmentValues {
            for memberPath in referencedMemberPaths(in: value) {
                guard URL(fileURLWithPath: memberPath).pathExtension.caseInsensitiveCompare("png") == .orderedSame,
                      StandaloneArchiveExtractor.isSafeRelativePath(memberPath),
                      packageMemberPaths.contains(memberPath) else {
                    continue
                }
                return "archive-member:\(memberPath)"
            }
        }
        return nil
    }

    private static func normalizedAttachmentRole(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func referencedMemberPaths(in value: MetadataJSONValue) -> [String] {
        switch value {
        case .string(let path):
            return [path]
        case .array(let values):
            return values.flatMap(referencedMemberPaths)
        case .object(let fields):
            // Legacy descriptor objects remain readable, but new manifests
            // carry the member path directly in the package attachment tag.
            guard case .string(let path)? = fields["memberPath"],
                  case .string(let mediaType)? = fields["mediaType"],
                  mediaType.caseInsensitiveCompare("image/png") == .orderedSame else {
                return []
            }
            return [path]
        case .null, .bool, .integer, .number:
            return []
        }
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
