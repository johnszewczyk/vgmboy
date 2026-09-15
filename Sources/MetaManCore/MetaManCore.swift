import Foundation

/// Decoder-independent metadata readers. Applications may import this
/// library directly; the `metaman` executable is only a thin JSON frontend.
public enum MetaManCore {
    public static let supportedFormats = [
        MetadataFormatDescriptor(
            identifier: "ay",
            fileExtensions: ["ay"],
            methodology: "Direct ZXAYEMUL header and relative-pointer parser with per-subtune 50 Hz lengths; no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "s98",
            fileExtensions: ["s98"],
            methodology: "Direct header, tag-block, device-table, and command-timing parser; no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "vgm",
            fileExtensions: ["vgm", "vgz"],
            methodology: "Direct VGM header and complete GD3 parser; gzip input is inflated with a 256 MiB output bound; no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "psf-family",
            fileExtensions: PSFMetadataReader.supportedExtensions.sorted(),
            methodology: "Direct PSF-style [TAG] footer parser for PSF, PSF2, SSF, USF, and 2SF; no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "spc",
            fileExtensions: ["spc"],
            methodology: "Direct SPC ID666/xID6 header and chunk parser; preserves both original tag blocks and does not start the playback emulator."
        ),
        MetadataFormatDescriptor(
            identifier: "sid",
            fileExtensions: ["sid"],
            methodology: "Direct PSID/RSID header parser; preserves the raw header and does not instantiate the SID playback core."
        ),
        MetadataFormatDescriptor(
            identifier: "ape",
            fileExtensions: ["ape"],
            methodology: "Direct APE descriptor, seek-table, APEv2, and leading ID3 parser; derives duration from encoded sample counts without an audio decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "adx",
            fileExtensions: ["adx"],
            methodology: "Direct CRI/Monster ADX header and loop-timing parser; non-ADX aliases sharing .adx are not classified as ADX."
        ),
        MetadataFormatDescriptor(
            identifier: "aus",
            fileExtensions: ["aus"],
            methodology: "Direct Atomic Planet header and loop-timing parser; preserves the complete header and native facts without decoding audio or classifying non-AUS aliases."
        ),
        MetadataFormatDescriptor(
            identifier: "at3",
            fileExtensions: ["at3"],
            methodology: "Direct RIFF/WAVE ATRAC3 and ATRAC3+ chunk, INFO-tag, and loop-timing parser; preserves non-audio chunks without decoding audio or claiming unrelated .at3 aliases."
        ),
        MetadataFormatDescriptor(
            identifier: "msf",
            fileExtensions: ["msf"],
            methodology: "Direct Sony MSF header and MPEG-frame-boundary parser for PCM, PSX ADPCM, ATRAC3, and MPEG timing; preserves the complete native header without audio decoding or claiming non-Sony aliases."
        ),
        MetadataFormatDescriptor(
            identifier: "svag",
            fileExtensions: ["svag"],
            methodology: "Direct Konami/SNK SVAG header and PS-ADPCM sample/loop parser; preserves source header facts and does not decode audio or claim unrelated .svag aliases."
        )
    ]

    public static func read(fileURL: URL) throws -> MetadataDocument {
        if fileURL.pathExtension.lowercased() == "svag" {
            return try SVAGMetadataReader.read(fileURL: fileURL)
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(
            data: data,
            formatHint: fileURL.pathExtension,
            displayName: fileURL.lastPathComponent
        )
    }

    /// Reads one source file into an ordered track result. Single-track
    /// readers publish one entry; multi-track readers retain native indices
    /// and ordered occurrences without flattening them into one document.
    public static func readResult(fileURL: URL) throws -> MetadataReadResult {
        let formatHint = fileURL.pathExtension.lowercased()
        if formatHint != "svag" {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            return try readResult(data: data, formatHint: formatHint, displayName: fileURL.lastPathComponent)
        }
        let document = try read(fileURL: fileURL)
        return MetadataReadResult(tracks: [MetadataTrack(document: document)])
    }

    /// Data-based counterpart to `readResult(fileURL:)`.
    public static func readResult(
        data: Data,
        formatHint: String? = nil,
        displayName: String? = nil
    ) throws -> MetadataReadResult {
        let cleanedHint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format = cleanedHint.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        let normalizedFormat = format?.isEmpty == false ? format : nil
        if normalizedFormat == "ay" || (normalizedFormat == nil && AYMetadataReader.matches(data)) {
            return try AYMetadataReader.readResult(data: data, displayName: displayName)
        }
        let document = try read(data: data, formatHint: formatHint, displayName: displayName)
        return MetadataReadResult(tracks: [MetadataTrack(document: document)])
    }

    /// Content probe used by clients routing ambiguous file extensions. This
    /// does not decode audio or produce metadata; false means the specified
    /// direct reader does not claim this payload, not that no decoder supports it.
    public static func canReadDirectly(fileURL: URL, formatHint: String) -> Bool {
        let normalized = formatHint.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        return switch normalized {
        case "at3": RIFFATRAC3MetadataReader.supports(fileURL: fileURL)
        case "msf": SonyMSFMetadataReader.supports(fileURL: fileURL)
        case "svag": SVAGMetadataReader.supports(fileURL: fileURL)
        default: false
        }
    }

    public static func read(
        data: Data,
        formatHint: String? = nil,
        displayName: String? = nil
    ) throws -> MetadataDocument {
        let cleanedHint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format = cleanedHint.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        let normalizedFormat = format?.isEmpty == false ? format : nil

        if normalizedFormat == "ay" || (normalizedFormat == nil && AYMetadataReader.matches(data)) {
            _ = try AYMetadataReader.readResult(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired("AY")
        }

        if normalizedFormat == "s98" || (normalizedFormat == nil && S98MetadataReader.matches(data)) {
            return try S98MetadataReader.read(data: data)
        }

        let isVGMHint = normalizedFormat == "vgm" || normalizedFormat == "vgz"
        var vgmData = data
        if (isVGMHint || normalizedFormat == nil), GzipDataDecompressor.matches(data) {
            vgmData = try GzipDataDecompressor.decompress(data)
        }
        if isVGMHint || VGMMetadataReader.matches(vgmData) {
            return try VGMMetadataReader.read(data: vgmData, displayName: displayName)
        }

        let isPSFHint = normalizedFormat.map(PSFMetadataReader.supportedExtensions.contains) ?? false
        if isPSFHint || (normalizedFormat == nil && PSFMetadataReader.matches(data)) {
            return try PSFMetadataReader.read(data: data, formatHint: normalizedFormat, displayName: displayName)
        }

        if normalizedFormat == "spc" || (normalizedFormat == nil && SPCMetadataReader.matches(data)) {
            return try SPCMetadataReader.read(data: data, displayName: displayName ?? "SPC")
        }

        if normalizedFormat == "sid" || (normalizedFormat == nil && SIDMetadataReader.matches(data)) {
            return try SIDMetadataReader.read(data: data, displayName: displayName ?? "SID")
        }

        if normalizedFormat == "ape" || (normalizedFormat == nil && APEMetadataReader.matches(data)) {
            return try APEMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "adx" {
            guard ADXMetadataReader.matches(data) else {
                throw MetadataReadError.unsupportedFormat("ADX signature")
            }
            return try ADXMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "aus" {
            guard AtomicPlanetAUSMetadataReader.matches(data) else {
                throw MetadataReadError.unsupportedFormat("Atomic Planet AUS signature")
            }
            return try AtomicPlanetAUSMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "at3" {
            guard RIFFATRAC3MetadataReader.matches(data) else {
                throw MetadataReadError.unsupportedFormat("RIFF ATRAC3 signature")
            }
            return try RIFFATRAC3MetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "msf" {
            guard SonyMSFMetadataReader.matches(data) else {
                throw MetadataReadError.unsupportedFormat("Sony MSF signature")
            }
            return try SonyMSFMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "svag" {
            guard SVAGMetadataReader.matches(data) else {
                throw MetadataReadError.unsupportedFormat("Konami/SNK SVAG signature")
            }
            return try SVAGMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == nil && ADXMetadataReader.matches(data) {
            return try ADXMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == nil && AtomicPlanetAUSMetadataReader.matches(data) {
            return try AtomicPlanetAUSMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == nil && RIFFATRAC3MetadataReader.matches(data) {
            return try RIFFATRAC3MetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == nil && SonyMSFMetadataReader.matches(data) {
            return try SonyMSFMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == nil && SVAGMetadataReader.matches(data) {
            return try SVAGMetadataReader.read(data: data, displayName: displayName)
        }

        throw MetadataReadError.unsupportedFormat(normalizedFormat ?? "unknown content")
    }
}
