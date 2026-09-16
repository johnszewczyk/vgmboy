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
            identifier: "sap",
            fileExtensions: ["sap"],
            methodology: "Direct SAP CRLF information-header parser with ordered SONGS/TIME subtunes, retained unknown directives, and no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "nsf",
            fileExtensions: ["nsf"],
            methodology: "Direct fixed-header reader for identity, playback setup, and declared tracks; no playback decoder or emulator is started, and absent authored timing keeps scanner-compatible defaults."
        ),
        MetadataFormatDescriptor(
            identifier: "gbs",
            fileExtensions: ["gbs"],
            methodology: "Direct fixed-header reader for identity, timer/address facts, and declared tracks; no playback decoder or Game Boy emulation is started."
        ),
        MetadataFormatDescriptor(
            identifier: "nsfe",
            fileExtensions: ["nsfe"],
            methodology: "Direct bounded chunk walk for NSFE identity, playlist, per-track labels/authors/time/fade, and hardware facts; audio DATA is validated and counted, never decoded."
        ),
        MetadataFormatDescriptor(
            identifier: "hes",
            fileExtensions: ["hes"],
            methodology: "Direct HES header and bounded same-basename M3U reader; retains ordered address slots, authored titles/timing, raw source blocks, and header facts without PC Engine emulation."
        ),
        MetadataFormatDescriptor(
            identifier: "sndh",
            fileExtensions: ["sndh"],
            methodology: "Direct executable-vector-bounded SNDH tag and subtune timing parser with bounded ICE! expansion; no Atari ST playback core."
        ),
        MetadataFormatDescriptor(
            identifier: "kss",
            fileExtensions: ["kss"],
            methodology: "Direct KSCC/KSSX header reader for hardware flags, payload facts, and KSSX-declared tracks; no Z80 or playback core."
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
            identifier: "gsf",
            fileExtensions: GSFMetadataReader.supportedExtensions.sorted(),
            methodology: "Complete PSF v0x22 reader: validates CRC/zlib, parses ordered tags, resolves the bounded PSFLib chain, stitches GBA load segments, and checks the GBA ROM header without mGBA."
        ),
        MetadataFormatDescriptor(
            identifier: "qsf",
            fileExtensions: QSFMetadataReader.supportedExtensions.sorted(),
            methodology: "Complete PSF v0x41 reader: validates CRC/zlib, ordered tags, QSound block bounds, and declared QSFLib companions without the QSound playback core."
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
        ),
        MetadataFormatDescriptor(
            identifier: "xmd",
            fileExtensions: ["xmd"],
            methodology: "Direct Konami XMD v1/v2 header and ADPCM frame-timing reader; retains the complete header and reproduces the scanner's default loop/fade projection without decoding audio."
        ),
        MetadataFormatDescriptor(
            identifier: "sony-sshd",
            fileExtensions: ["ads"],
            methodology: "Direct Sony SSHD/ADS header and encoded-frame timing reader; reproduces the complete vgmstream loop/address handling without decoding PCM, PS-ADPCM, or IMA audio."
        ),
        MetadataFormatDescriptor(
            identifier: "ps-headerless-mib",
            fileExtensions: ["mib"],
            methodology: "Direct headerless PlayStation PS-ADPCM frame probe with vgmstream-compatible channel, interleave, loop, and timing inference; no playback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "bink-audio",
            fileExtensions: BinkAudioMetadataReader.supportedExtensions,
            methodology: "Direct Bink container header, frame-offset, and audio-packet walk for stream timing; no Bink decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "ngc-dtk-adp",
            fileExtensions: ["adp"],
            methodology: "Direct headerless Nintendo GameCube DTK frame probe and sample arithmetic; no playback decoder, and unknown .adp aliases remain available to the fallback decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "txth-ima-adp",
            fileExtensions: ["adp"],
            methodology: "Direct exact .adp.txth parser for raw IMA layout, sample-rate/channel facts, and bytes-to-samples timing; the original sidecar is retained and unknown TXTH directives fall back to the decoder."
        ),
        MetadataFormatDescriptor(
            identifier: "ahx",
            fileExtensions: ["ahx"],
            methodology: "Direct CRI AHX header and fixed-bitrate payload-duration reader; preserves the declared sample count separately and does not open the MPEG/AHX playback path."
        ),
        MetadataFormatDescriptor(
            identifier: "xa",
            fileExtensions: ["xa"],
            methodology: "Direct Sony CD-XA sector walk for interleaved file/channel subsongs and sample timing; validates raw-sector frames without decoding audio and does not claim unrelated .xa aliases."
        ),
        MetadataFormatDescriptor(
            identifier: "nds-strm",
            fileExtensions: ["strm"],
            methodology: "Direct standard Nintendo DS STRM header, codec, channel, loop, and sample-timing reader; validates the STRM/HEAD/DATA structure and does not decode audio."
        ),
        MetadataFormatDescriptor(
            identifier: "nds-strm-ffta2",
            fileExtensions: ["bin", "strm"],
            methodology: "Direct Final Fantasy Tactics A2 RIFF/IMA header and loop-timing reader; validates the Square Enix size, channel, and loop bounds without decoding audio."
        ),
        MetadataFormatDescriptor(
            identifier: "ngc-dsp-standard",
            fileExtensions: ["dsp"],
            methodology: "Direct big-endian Nintendo DSPADPCM header reader for standard mono DSP streams; retains codec coefficients and sample/loop facts without decoding audio."
        ),
        MetadataFormatDescriptor(
            identifier: "rs03",
            fileExtensions: ["dsp"],
            methodology: "Direct Retro Studios RS03 signature/header reader for channel, sample, interleave, and loop facts; no DSP decoding."
        ),
        MetadataFormatDescriptor(
            identifier: "ngc-thp-audio",
            fileExtensions: ["dsp"],
            methodology: "Direct Nintendo THP component-table and audio-header reader for DSP audio; retains bounded component/header blocks without decoding video or audio."
        )
    ]

    public static func read(
        fileURL: URL,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataDocument {
        if QSFMetadataReader.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
            return try QSFMetadataReader.read(fileURL: fileURL, context: context)
        }
        if GSFMetadataReader.supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
            return try GSFMetadataReader.read(fileURL: fileURL, context: context)
        }
        if fileURL.pathExtension.lowercased() == "svag" {
            return try SVAGMetadataReader.read(fileURL: fileURL)
        }
        if fileURL.pathExtension.lowercased() == "xmd" {
            return try KonamiXMDMetadataReader.read(fileURL: fileURL)
        }
        if fileURL.pathExtension.lowercased() == "ads" {
            return try SonySSHDMetadataReader.read(fileURL: fileURL)
        }
        if fileURL.pathExtension.lowercased() == "mib" {
            return try MIBMetadataReader.read(fileURL: fileURL)
        }
        if fileURL.pathExtension.lowercased() == "bika" {
            return try BinkAudioMetadataReader.read(fileURL: fileURL)
        }
        if fileURL.pathExtension.caseInsensitiveCompare("adp") == .orderedSame {
            return try ADPMetadataReader.read(fileURL: fileURL, context: context)
        }
        if fileURL.pathExtension.caseInsensitiveCompare("ahx") == .orderedSame {
            return try AHXMetadataReader.read(fileURL: fileURL)
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
    public static func readResult(
        fileURL: URL,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataReadResult {
        let formatHint = fileURL.pathExtension.lowercased()
        if QSFMetadataReader.supportedExtensions.contains(formatHint) {
            let document = try QSFMetadataReader.read(fileURL: fileURL, context: context)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if GSFMetadataReader.supportedExtensions.contains(formatHint) {
            let document = try GSFMetadataReader.read(fileURL: fileURL, context: context)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint == "xmd" {
            let document = try KonamiXMDMetadataReader.read(fileURL: fileURL)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint == "ads" {
            let document = try SonySSHDMetadataReader.read(fileURL: fileURL)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint == "mib" {
            let document = try MIBMetadataReader.read(fileURL: fileURL)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint == "bika" {
            return try BinkAudioMetadataReader.readResult(fileURL: fileURL)
        }
        if formatHint == "adp" {
            let document = try ADPMetadataReader.read(fileURL: fileURL, context: context)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint == "ahx" {
            let document = try AHXMetadataReader.read(fileURL: fileURL)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if formatHint != "svag" {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            let resolvedContext = try contextIncludingHESPlaylist(for: fileURL, context: context)
            return try readResult(
                data: data,
                formatHint: formatHint,
                displayName: fileURL.lastPathComponent,
                context: resolvedContext
            )
        }
        let document = try read(fileURL: fileURL)
        return MetadataReadResult(tracks: [MetadataTrack(document: document)])
    }

    /// Data-based counterpart to `readResult(fileURL:)`.
    public static func readResult(
        data: Data,
        formatHint: String? = nil,
        displayName: String? = nil,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataReadResult {
        let cleanedHint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format = cleanedHint.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        let normalizedFormat = format?.isEmpty == false ? format : nil
        if QSFMetadataReader.supportedExtensions.contains(normalizedFormat ?? "")
            || (normalizedFormat == nil && QSFMetadataReader.matches(data)) {
            return try QSFMetadataReader.readResult(data: data, displayName: displayName, context: context)
        }
        if GSFMetadataReader.supportedExtensions.contains(normalizedFormat ?? "")
            || (normalizedFormat == nil && GSFMetadataReader.matches(data)) {
            return try GSFMetadataReader.readResult(data: data, displayName: displayName, context: context)
        }
        if SNDHMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && SNDHMetadataReader.matches(data)) {
            return try SNDHMetadataReader.readResult(data: data, displayName: displayName)
        }
        if normalizedFormat == "kss" || (normalizedFormat == nil && KSSMetadataReader.matches(data)) {
            return try KSSMetadataReader.readResult(data: data, displayName: displayName)
        }
        if normalizedFormat == "xa" || (normalizedFormat == nil && SonyXAMetadataReader.matches(data)) {
            return try SonyXAMetadataReader.read(data: data, displayName: displayName)
        }
        if HESMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && HESMetadataReader.matches(data)) {
            return try HESMetadataReader.readResult(
                data: data,
                context: context,
                displayName: displayName ?? "HES"
            )
        }
        if GameMusicMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && GameMusicMetadataReader.matches(data)) {
            return try GameMusicMetadataReader.readResult(
                data: data,
                formatHint: normalizedFormat,
                displayName: displayName
            )
        }
        if normalizedFormat == "ay" || (normalizedFormat == nil && AYMetadataReader.matches(data)) {
            return try AYMetadataReader.readResult(data: data, displayName: displayName)
        }
        if normalizedFormat == "sap" || (normalizedFormat == nil && SAPMetadataReader.matches(data)) {
            return try SAPMetadataReader.readResult(data: data, displayName: displayName)
        }
        if normalizedFormat == "bika" || (normalizedFormat == nil && BinkAudioMetadataReader.matches(data)) {
            return try BinkAudioMetadataReader.readResult(data: data, displayName: displayName)
        }
        if normalizedFormat == "adp" || (normalizedFormat == nil && ADPMetadataReader.matches(data)) {
            let document = try ADPMetadataReader.read(data: data, displayName: displayName, context: context)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
        }
        if normalizedFormat == "ahx" || (normalizedFormat == nil && AHXMetadataReader.matches(data)) {
            let document = try AHXMetadataReader.read(data: data, displayName: displayName)
            return MetadataReadResult(tracks: [MetadataTrack(document: document)])
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
        case "xmd": KonamiXMDMetadataReader.supports(fileURL: fileURL)
        case "ads": SonySSHDMetadataReader.supports(fileURL: fileURL)
        case "mib": MIBMetadataReader.supports(fileURL: fileURL)
        case "bika": BinkAudioMetadataReader.supports(fileURL: fileURL)
        case "adp": ADPMetadataReader.supports(fileURL: fileURL)
        case "ahx": AHXMetadataReader.supports(fileURL: fileURL)
        case "dsp": NintendoDSPMetadataReader.supports(fileURL: fileURL)
        case "xa": SonyXAMetadataReader.supports(fileURL: fileURL)
        case "strm":
            NDSSTRMMetadataReader.supports(fileURL: fileURL)
                || NDSSTRMFFTA2MetadataReader.supports(fileURL: fileURL)
        case "bin": NDSSTRMFFTA2MetadataReader.supports(fileURL: fileURL)
        default: false
        }
    }

    public static func read(
        data: Data,
        formatHint: String? = nil,
        displayName: String? = nil,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataDocument {
        let cleanedHint = formatHint?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let format = cleanedHint.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        let normalizedFormat = format?.isEmpty == false ? format : nil

        if QSFMetadataReader.supportedExtensions.contains(normalizedFormat ?? "")
            || (normalizedFormat == nil && QSFMetadataReader.matches(data)) {
            return try QSFMetadataReader.read(data: data, displayName: displayName, context: context)
        }

        if GSFMetadataReader.supportedExtensions.contains(normalizedFormat ?? "")
            || (normalizedFormat == nil && GSFMetadataReader.matches(data)) {
            return try GSFMetadataReader.read(data: data, displayName: displayName, context: context)
        }

        if SNDHMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && SNDHMetadataReader.matches(data)) {
            _ = try SNDHMetadataReader.readResult(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired("SNDH")
        }
        if normalizedFormat == "kss" || (normalizedFormat == nil && KSSMetadataReader.matches(data)) {
            let result = try KSSMetadataReader.readResult(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired(result.tracks.first?.document.format.uppercased() ?? "KSS")
        }
        if normalizedFormat == "xa" || (normalizedFormat == nil && SonyXAMetadataReader.matches(data)) {
            _ = try SonyXAMetadataReader.read(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired("Sony XA")
        }

        if HESMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && HESMetadataReader.matches(data)) {
            _ = try HESMetadataReader.readResult(
                data: data,
                context: MetadataReadContext(),
                displayName: displayName ?? "HES"
            )
            throw MetadataReadError.trackAwareResultRequired("HES")
        }

        if GameMusicMetadataReader.hasSupportedHint(normalizedFormat)
            || (normalizedFormat == nil && GameMusicMetadataReader.matches(data)) {
            let result = try GameMusicMetadataReader.readResult(
                data: data,
                formatHint: normalizedFormat,
                displayName: displayName
            )
            throw MetadataReadError.trackAwareResultRequired(result.tracks.first?.document.format.uppercased() ?? "NSF-family")
        }

        if normalizedFormat == "ay" || (normalizedFormat == nil && AYMetadataReader.matches(data)) {
            _ = try AYMetadataReader.readResult(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired("AY")
        }
        if normalizedFormat == "sap" || (normalizedFormat == nil && SAPMetadataReader.matches(data)) {
            _ = try SAPMetadataReader.readResult(data: data, displayName: displayName)
            throw MetadataReadError.trackAwareResultRequired("SAP")
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

        if normalizedFormat == "xmd" || (normalizedFormat == nil && KonamiXMDMetadataReader.matches(data)) {
            return try KonamiXMDMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "ads" || (normalizedFormat == nil && SonySSHDMetadataReader.matches(data)) {
            return try SonySSHDMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "mib" || (normalizedFormat == nil && MIBMetadataReader.matches(data)) {
            return try MIBMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "bika" || (normalizedFormat == nil && BinkAudioMetadataReader.matches(data)) {
            return try BinkAudioMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "adp" || (normalizedFormat == nil && ADPMetadataReader.matches(data)) {
            return try ADPMetadataReader.read(data: data, displayName: displayName, context: context)
        }

        if normalizedFormat == "ahx" || (normalizedFormat == nil && AHXMetadataReader.matches(data)) {
            return try AHXMetadataReader.read(data: data, displayName: displayName)
        }

        if normalizedFormat == "dsp" || (normalizedFormat == nil && NintendoDSPMetadataReader.matches(data)) {
            return try NintendoDSPMetadataReader.read(data: data, displayName: displayName)
        }

        if (normalizedFormat == "strm" || normalizedFormat == "bin" || normalizedFormat == "nds-strm-ffta2")
            && NDSSTRMFFTA2MetadataReader.matches(data) {
            return try NDSSTRMFFTA2MetadataReader.read(data: data, displayName: displayName)
        }
        if normalizedFormat == "strm" || (normalizedFormat == nil && NDSSTRMMetadataReader.matches(data)) {
            return try NDSSTRMMetadataReader.read(data: data, displayName: displayName)
        }
        if normalizedFormat == nil && NDSSTRMFFTA2MetadataReader.matches(data) {
            return try NDSSTRMFFTA2MetadataReader.read(data: data, displayName: displayName)
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

    private static func contextIncludingHESPlaylist(
        for fileURL: URL,
        context: MetadataReadContext
    ) throws -> MetadataReadContext {
        guard fileURL.pathExtension.caseInsensitiveCompare("hes") == .orderedSame,
              !context.containsCompanion(beside: fileURL.lastPathComponent, fileExtension: "m3u") else {
            return context
        }

        let baseURL = fileURL.deletingPathExtension()
        let candidates = [baseURL.appendingPathExtension("m3u"), baseURL.appendingPathExtension("M3U")]
        guard let playlistURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return context
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: playlistURL.path)
        if let size = (attributes[.size] as? NSNumber)?.intValue,
           size > HESMetadataReader.playlistByteLimit {
            throw MetadataReadError.malformedFile(
                "HES companion M3U is invalid or too large: \(fileURL.lastPathComponent)"
            )
        }
        let data = try Data(contentsOf: playlistURL, options: .mappedIfSafe)
        guard data.count <= HESMetadataReader.playlistByteLimit else {
            throw MetadataReadError.malformedFile(
                "HES companion M3U is invalid or too large: \(fileURL.lastPathComponent)"
            )
        }
        return context.appending(
            MetadataCompanionFile(relativePath: playlistURL.lastPathComponent, data: data)
        )
    }
}
