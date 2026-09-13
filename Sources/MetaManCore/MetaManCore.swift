import Foundation

/// Decoder-independent metadata readers. Applications may import this
/// library directly; the `metaman` executable is only a thin JSON frontend.
public enum MetaManCore {
    public static let supportedFormats = [
        MetadataFormatDescriptor(
            identifier: "s98",
            fileExtensions: ["s98"],
            methodology: "Direct header, tag-block, device-table, and command-timing parser; no playback decoder."
        )
    ]

    public static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, formatHint: fileURL.pathExtension)
    }

    public static func read(data: Data, formatHint: String? = nil) throws -> MetadataDocument {
        let cleanedHint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format = cleanedHint.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        let normalizedFormat = format?.isEmpty == false ? format : nil

        if normalizedFormat == "s98" || (normalizedFormat == nil && S98MetadataReader.matches(data)) {
            return try S98MetadataReader.read(data: data)
        }

        throw MetadataReadError.unsupportedFormat(normalizedFormat ?? "unknown content")
    }
}
