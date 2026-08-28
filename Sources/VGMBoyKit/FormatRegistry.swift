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

/// The frontend-facing projection of one VGMBoy playback family.
///
/// This is deliberately derived from the same family and extension sets that
/// the playback controller uses. Frontends may format this descriptor for a
/// native or JavaScript UI, but they must not recreate the admission or timing
/// capability table themselves.
public struct PlaybackFormatDescriptor: Sendable, Codable, Equatable, Hashable {
    public let id: String
    public let familyID: String
    public let extensions: Set<String>
    public let supportsLongPlay: Bool
    public let supportsTempo: Bool
    public let hasNaturalEnding: Bool

    public init(id: String, family: DecoderFamily, extensions: Set<String>) {
        self.id = id
        self.familyID = family.id
        self.extensions = extensions
        self.supportsLongPlay = family.supportsLongPlay
        self.supportsTempo = family.supportsTempo
        self.hasNaturalEnding = family.hasNaturalEnding
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

    public static let psgPlayFamily = DecoderFamily(
        id: "psgplay",
        supportsLongPlay: true,
        supportsTempo: false
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

    public static let psgPlayExtensions: Set<String> = ["sndh"]

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

    /// Stable frontend order. Keep this list aligned with the backend order
    /// exposed by the existing CocoaSpice and SPCBoyWK controls.
    public static let playbackDescriptors: [PlaybackFormatDescriptor] = [
        PlaybackFormatDescriptor(id: "libgme", family: libgmeFamily, extensions: libgmeExtensions),
        PlaybackFormatDescriptor(id: "libvgm", family: libvgmFamily, extensions: libvgmExtensions),
        PlaybackFormatDescriptor(id: "psgplay", family: psgPlayFamily, extensions: psgPlayExtensions),
        PlaybackFormatDescriptor(id: "standard-audio", family: standardAudioFamily, extensions: standardAudioExtensions),
        PlaybackFormatDescriptor(id: "ffmpeg-audio", family: ffmpegAudioFamily, extensions: ffmpegAudioExtensions),
        PlaybackFormatDescriptor(id: "highly-complete", family: highlyCompleteFamily, extensions: highlyCompleteExtensions),
        PlaybackFormatDescriptor(id: "twosf", family: twoSFFamily, extensions: twoSFExtensions),
        PlaybackFormatDescriptor(id: "vgmstream", family: vgmstreamFamily, extensions: vgmstreamExtensions),
        PlaybackFormatDescriptor(id: "lazyusf", family: lazyusfFamily, extensions: lazyusfExtensions),
        PlaybackFormatDescriptor(id: "playpsf", family: playpsfFamily, extensions: playpsfExtensions),
        PlaybackFormatDescriptor(id: "qsf", family: qsfFamily, extensions: qsfExtensions),
        PlaybackFormatDescriptor(id: "sidplayfp", family: sidplayfpFamily, extensions: sidplayfpExtensions),
        PlaybackFormatDescriptor(id: "openmpt", family: openMPTFamily, extensions: openMPTExtensions)
    ]

    public static let playbackExtensions: Set<String> = Set(
        playbackDescriptors.flatMap(\.extensions)
    )

    public static func descriptor(for path: String) -> PlaybackFormatDescriptor? {
        let extensionName = normalizedExtension(for: path)
        return playbackDescriptors.first { $0.extensions.contains(extensionName) }
    }

    public static func family(for path: String) -> DecoderFamily? {
        let ext = normalizedExtension(for: path)
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
        if psgPlayExtensions.contains(ext) {
            return psgPlayFamily
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

    /// Returns the format-owned archive preparation requirement for a set of
    /// catalog-selected members. The returned requirement describes only the
    /// clean filesystem input VGMBoyKit needs; archive extraction, caching,
    /// and temporary-file lifetime remain outside the decoder core.
    public static func archiveMaterializationRequirement(
        for entryPaths: [String]
    ) -> VGMArchiveMaterializationRequirement? {
        guard !entryPaths.isEmpty else { return nil }

        var resolved: VGMArchiveMaterializationRequirement = .selectedEntry
        for entryPath in entryPaths {
            let extensionName = normalizedExtension(for: entryPath)
            guard family(for: entryPath) != nil else { return nil }

            if lazyusfExtensions.contains(extensionName) {
                resolved = .completeSetWithLazyUSFAliases
            } else if requiresCompleteSet(extensionName), resolved == .selectedEntry {
                resolved = .completeSet
            }
        }
        return resolved
    }

    private static func requiresCompleteSet(_ extensionName: String) -> Bool {
        highlyCompleteExtensions.contains(extensionName)
            || twoSFExtensions.contains(extensionName)
            || playpsfExtensions.contains(extensionName)
            // QSF/miniQSF files resolve their adjacent .qsflib through the
            // filesystem, so archive playback must stage the complete set.
            || qsfExtensions.contains(extensionName)
            || VGMStreamFormatManifest.dependencyEnumeratedScannerExtensions.contains(extensionName)
    }

    private static func normalizedExtension(for path: String) -> String {
        (path as NSString).pathExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
    }
}
