import Foundation
import VGMBoyFormatCore

public struct DecoderFamily: Sendable, Codable {
    public var id: String
    public var supportsLongPlay: Bool
    public var supportsTempo: Bool
    /// Whether the decoder reaches a natural end (USF loops forever, so it
    /// always needs a capped window; everything else ends on its own).
    public var hasNaturalEnding: Bool

    public init(id: String, supportsLongPlay: Bool, supportsTempo: Bool, hasNaturalEnding: Bool = true) {
        self.id = id
        self.supportsLongPlay = supportsLongPlay
        self.supportsTempo = supportsTempo
        self.hasNaturalEnding = hasNaturalEnding
    }
}

public enum FormatRegistry {
    public static let libgmeFamily = DecoderFamily(
        id: "libgme",
        supportsLongPlay: true,
        supportsTempo: true
    )

    public static let libvgmFamily = DecoderFamily(
        id: "libvgm",
        supportsLongPlay: true,
        supportsTempo: true
    )

    public static let standardAudioFamily = DecoderFamily(
        id: "standardaudio",
        supportsLongPlay: false,
        supportsTempo: false
    )

    public static let ffmpegAudioFamily = DecoderFamily(
        id: "ffmpegaudio",
        supportsLongPlay: false,
        supportsTempo: false
    )

    public static let highlyCompleteFamily = DecoderFamily(
        id: "highlycomplete",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let twoSFFamily = DecoderFamily(
        id: "twosf",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let vgmstreamFamily = DecoderFamily(
        id: "vgmstream",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let lazyusfFamily = DecoderFamily(
        id: "lazyusf",
        supportsLongPlay: true,
        supportsTempo: false,
        hasNaturalEnding: false
    )

    public static let playpsfFamily = DecoderFamily(
        id: "playpsf",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let qsfFamily = DecoderFamily(
        id: "qsf",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let sidplayfpFamily = DecoderFamily(
        id: "sidplayfp",
        supportsLongPlay: true,
        supportsTempo: false,
        hasNaturalEnding: false
    )

    public static let openMPTFamily = DecoderFamily(
        id: "openmpt",
        supportsLongPlay: true,
        supportsTempo: false
    )

    public static let libgmeExtensions: Set<String> = [
        "ay", "gbs", "hes", "kss", "nsf", "nsfe", "sap", "spc"
    ]

    public static let libvgmExtensions: Set<String> = [
        "vgm", "vgz", "gym", "s98", "dro"
    ]

    public static let standardAudioExtensions: Set<String> = [
        "aac", "aif", "aiff", "caf", "flac", "m4a", "mp3", "wav", "wave"
    ]

    public static let ffmpegAudioExtensions: Set<String> = ["mp2", "tak"]

    public static let highlyCompleteExtensions: Set<String> = [
        "gsf", "minigsf"
    ]

    public static let twoSFExtensions: Set<String> = [
        "2sf", "mini2sf"
    ]

    public static let gameCubeVgmstreamExtensions = VGMStreamFormatManifest.gameCubePrimaryExtensions

    public static let vgmstreamExtensions = VGMStreamFormatManifest.playbackExtensions

    public static let lazyusfExtensions: Set<String> = [
        "usf", "miniusf"
    ]

    public static let playpsfExtensions: Set<String> = [
        "psf", "minipsf", "psf2", "minipsf2"
    ]

    public static let qsfExtensions: Set<String> = ["qsf", "miniqsf"]

    public static let sidplayfpExtensions: Set<String> = ["sid"]

    public static let openMPTExtensions: Set<String> = [
        "669", "dmf", "far", "it", "mod", "mptm", "mtm", "okt", "ptm", "s3m", "stm", "ult", "xm"
    ]

    public static func family(for path: String) -> DecoderFamily? {
        let ext = (path as NSString).pathExtension.lowercased()
        if libgmeExtensions.contains(ext) {
            return libgmeFamily
        }
        if sidplayfpExtensions.contains(ext) {
            return sidplayfpFamily
        }
        if openMPTExtensions.contains(ext) {
            return openMPTFamily
        }
        if libvgmExtensions.contains(ext) {
            return libvgmFamily
        }
        if standardAudioExtensions.contains(ext) {
            return standardAudioFamily
        }
        if ffmpegAudioExtensions.contains(ext) {
            return ffmpegAudioFamily
        }
        if highlyCompleteExtensions.contains(ext) {
            return highlyCompleteFamily
        }
        if twoSFExtensions.contains(ext) {
            return twoSFFamily
        }
        if vgmstreamExtensions.contains(ext) {
            return vgmstreamFamily
        }
        if lazyusfExtensions.contains(ext) {
            return lazyusfFamily
        }
        if playpsfExtensions.contains(ext) {
            return playpsfFamily
        }
        if qsfExtensions.contains(ext) {
            return qsfFamily
        }
        return nil
    }
}
