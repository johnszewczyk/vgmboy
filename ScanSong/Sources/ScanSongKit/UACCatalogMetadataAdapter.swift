import UACWrapperCore

/// Projects the established schema-23 fields from UAC member metadata.
/// UAC is authoritative: absent, null, or invalid fields become blank/default
/// values and never fall back to tags in the contained source file.
enum UACCatalogMetadataAdapter {
    static func project(_ manifestFields: [String: UACJSONValue]) -> ScannerMetadata {
        func text(_ key: String) -> String {
            guard let value = manifestFields[key] else { return "" }
            switch value {
            case .string(let text): return text
            case .null: return ""
            default: return ""
            }
        }

        func milliseconds(_ key: String) -> Int {
            guard let value = manifestFields[key] else { return 0 }
            switch value {
            case .integer(let value):
                return Int(clamping: value)
            case .number(let value):
                guard value.isFinite,
                      let converted = Int(exactly: value.rounded(.towardZero)) else {
                    return 0
                }
                return converted
            case .null:
                return 0
            default:
                return 0
            }
        }

        return ScannerMetadata(
            game: text("game"),
            song: text("title"),
            system: text("system"),
            author: text("artist"),
            comment: text("comment"),
            introLengthMs: milliseconds("introLengthMs"),
            loopLengthMs: milliseconds("loopLengthMs"),
            playLengthMs: milliseconds("playLengthMs"),
            fadeLengthMs: milliseconds("fadeLengthMs")
        )
    }
}
