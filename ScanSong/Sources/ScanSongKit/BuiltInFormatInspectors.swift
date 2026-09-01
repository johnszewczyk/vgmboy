import Foundation

/// The registry is intentionally the only central format wiring point. The
/// format implementations live in one handler file per decoder family.
public enum BuiltInFormatInspectors {
    public static let registry = ScanPluginHandlerRegistry(
        handlers: BuiltInScannerPlugins.registry.descriptors.map(makeHandler)
    )

    private static func makeHandler(descriptor: ScannerPluginDescriptor) -> any ScanFormatHandler {
        switch descriptor.pluginID {
        case "gme", "gme-multitrack":
            return GameMusicEmuFormatInspector(descriptor: descriptor)
        case "highly-theoretical", "lazyusf", "twosf", "play-psf1", "play-psf2":
            return PSFFormatInspector(descriptor: descriptor)
        case "libvgm":
            return VGMFormatInspector(descriptor: descriptor)
        case "psgplay":
            return SNDHFormatInspector(descriptor: descriptor)
        case "standard-audio":
            return StandardAudioFormatInspector(descriptor: descriptor)
        case "openmpt":
            return SingleTrackFormatInspector(descriptor: descriptor)
        case "sid":
            return SIDFormatInspector(descriptor: descriptor)
        case "vgmstream", "vgmstream-txtp", "vgmstream-hd-bank":
            return VGMStreamCLIInspector(descriptor: descriptor)
        case "highly-complete":
            return HighlyCompleteCLIInspector(descriptor: descriptor)
        case "qsf", "qsf-mini":
            return QSFCLIInspector(descriptor: descriptor)
        case "mdx":
            return MDXCLIInspector(descriptor: descriptor)
        case "amiga-uade":
            return AmigaCLIInspector(descriptor: descriptor)
        case "ffmpeg-audio":
            return FFmpegCLIInspector(descriptor: descriptor)
        default:
            return UnsupportedBuiltInFormatInspector(descriptor: descriptor)
        }
    }
}

/// Keeps an unimplemented built-in route explicit rather than silently
/// flattening it into a fake playable track.
public struct UnsupportedBuiltInFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        if route.structurePolicy != .knownSingle {
            throw ScannerInspectionError.missingRequiredAdapter(
                pluginID: route.pluginID,
                extensionName: route.formatExtension
            )
        }
        throw ScannerInspectionError.unsupportedRoute(route.pluginID)
    }
}
