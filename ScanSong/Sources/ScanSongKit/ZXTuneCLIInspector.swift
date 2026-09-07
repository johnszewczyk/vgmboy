import Foundation

/// ScanSong's ZXTune adapter is the VGMBoy-built inspector. ScanSong does not
/// link the playback package; it only consumes this narrow JSON process
/// boundary, just like the other external decoder inspectors.
public struct ZXTuneCLIInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        let executable = try Self.executableURL(descriptor: descriptor)
        let data = try await InspectorProcessRunner.run(executable: executable, arguments: [fileURL.path])
        let info: ZXTuneInfo
        do {
            info = try JSONDecoder().decode(ZXTuneInfo.self, from: data)
        } catch {
            throw ScannerInspectionError.library(
                "ZXTune inspector returned invalid metadata for \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
        guard info.trackCount == 1 else {
            throw ScannerInspectionError.malformedFile(
                "ZXTune reported an invalid track count (\(info.trackCount)) for \(fileURL.lastPathComponent)."
            )
        }
        let title = info.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(
                trackIndex: 0,
                trackCount: 1,
                metadata: ScannerMetadata(
                    game: "",
                    song: title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : title,
                    system: info.system,
                    author: info.artist,
                    comment: info.program,
                    introLengthMs: max(0, info.introLengthMs),
                    loopLengthMs: max(0, info.loopLengthMs),
                    playLengthMs: max(0, info.playLengthMs),
                    fadeLengthMs: 0
                )
            )]
        )
    }

    private static func executableURL(descriptor: ScannerPluginDescriptor) throws -> URL {
        if let configured = ProcessInfo.processInfo.environment["SCANSONG_ZXTUNE_INSPECT"], !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw ScannerInspectionError.library("Configured ZXTune inspector is not executable: \(url.path)")
            }
            return url
        }
        if let bundled = Bundle.main.url(forResource: "vgmboy-zxtune-inspect", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        throw ScannerInspectionError.missingRequiredAdapter(
            pluginID: descriptor.pluginID,
            extensionName: descriptor.supportedExtensions.sorted().joined(separator: ", ")
        )
    }
}

private struct ZXTuneInfo: Decodable, Sendable {
    let title: String
    let system: String
    let artist: String
    let program: String
    let introLengthMs: Int
    let loopLengthMs: Int
    let playLengthMs: Int
    let trackCount: Int
}
