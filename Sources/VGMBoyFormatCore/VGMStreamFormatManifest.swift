public enum VGMStreamScannerAdmission: Hashable, Sendable {
    case direct
    case dependencyEnumerated
    case playbackOnly
}

public struct VGMStreamFormat: Hashable, Sendable {
    public let pathExtension: String
    public let scannerAdmission: VGMStreamScannerAdmission
    public let isGameCubePrimary: Bool

    public init(
        pathExtension: String,
        scannerAdmission: VGMStreamScannerAdmission,
        isGameCubePrimary: Bool = false
    ) {
        self.pathExtension = pathExtension
        self.scannerAdmission = scannerAdmission
        self.isGameCubePrimary = isGameCubePrimary
    }
}

/// Decoder-owned source of truth for vgmstream playback and scanner admission.
///
/// A format appearing here is not proof by extension alone: SongScan still
/// requires its native inspector to open and enumerate the payload before it
/// publishes a track. The admission role only describes how that attempt is
/// routed and whether sibling files must first be materialized.
public enum VGMStreamFormatManifest {
    public static let formats: [VGMStreamFormat] = {
        entries(
            [
                "aa3", "adx", "ads", "ahx", "aifc", "at3", "aus", "bik", "bika",
                "bnk", "dvi", "fsb", "genh", "int", "mib", "msf", "mtaf", "rws",
                "ss2", "stream", "strm", "svag", "vag", "xa", "xmd"
            ],
            admission: .direct
        ) + entries(
            ["adp", "agsc", "dsp", "h4m", "ldat", "logg", "rsf", "thp"],
            admission: .direct,
            isGameCubePrimary: true
        ) + entries(
            ["hd", "hbd", "iecs"],
            admission: .dependencyEnumerated
        ) + entries(
            ["txtp"],
            admission: .dependencyEnumerated,
            isGameCubePrimary: true
        ) + entries(
            ["adpcm", "bk2", "ogg", "ps3", "s14", "swav", "xvag"],
            admission: .playbackOnly
        )
    }()

    public static let playbackExtensions = Set(formats.map(\.pathExtension))

    public static let directScannerExtensions = Set(
        formats.lazy
            .filter { $0.scannerAdmission == .direct }
            .map(\.pathExtension)
    )

    public static let dependencyEnumeratedScannerExtensions = Set(
        formats.lazy
            .filter { $0.scannerAdmission == .dependencyEnumerated }
            .map(\.pathExtension)
    )

    public static let gameCubePrimaryExtensions = Set(
        formats.lazy
            .filter(\.isGameCubePrimary)
            .map(\.pathExtension)
    )

    private static func entries(
        _ extensions: [String],
        admission: VGMStreamScannerAdmission,
        isGameCubePrimary: Bool = false
    ) -> [VGMStreamFormat] {
        extensions.map {
            VGMStreamFormat(
                pathExtension: $0,
                scannerAdmission: admission,
                isGameCubePrimary: isGameCubePrimary
            )
        }
    }
}
