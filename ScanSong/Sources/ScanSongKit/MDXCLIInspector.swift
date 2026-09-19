import Foundation
import MetaManCore

/// ScanSong-owned MDX structure/dependency adapter. MetaMan owns title and
/// bounded MML timing; the VGMBoy helper only validates that the player can
/// open the module and its required dependency set.
public struct MDXCLIInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        let document: MetadataDocument
        do {
            document = try MetaManCore.read(fileURL: fileURL)
        } catch let error as MetadataReadError {
            throw ScannerInspectionError.malformedFile(error.localizedDescription)
        }
        if let dependencyName = MDXDependencyReader.dependencyName(in: document) {
            guard StandaloneArchiveExtractor.isSafeRelativePath(dependencyName) else {
                throw ScannerInspectionError.malformedFile(
                    "MDX declares an unsafe dependency path: \(dependencyName)."
                )
            }
            guard MDXDependencyReader.siblingURL(named: dependencyName, beside: fileURL) != nil else {
                throw ScannerInspectionError.missingDependency(dependencyName)
            }
        }

        let executable = try Self.executableURL(descriptor: descriptor)
        let data = try await InspectorProcessRunner.run(executable: executable, arguments: [fileURL.path])
        let info: MDXInfo
        do {
            info = try JSONDecoder().decode(MDXInfo.self, from: data)
        } catch {
            throw ScannerInspectionError.library(
                "MDX inspector returned invalid metadata for \(fileURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
        guard info.trackCount == 1 else {
            throw ScannerInspectionError.malformedFile(
                "MDX reported an invalid track count (\(info.trackCount)) for \(fileURL.lastPathComponent)."
            )
        }
        let title = document.fields.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let timing = document.timing
        let metadata = ScannerMetadata(
            game: document.fields.game ?? "",
            song: title.isEmpty ? fileURL.deletingPathExtension().lastPathComponent : title,
            system: document.fields.system ?? "",
            author: document.fields.artist ?? "",
            comment: document.fields.comment ?? "",
            introLengthMs: max(0, timing?.introLengthMs ?? 0),
            loopLengthMs: max(0, timing?.loopLengthMs ?? 0),
            playLengthMs: max(0, timing?.playLengthMs ?? 0),
            fadeLengthMs: max(0, timing?.fadeLengthMs ?? 0)
        )
        return ScanInspection(route: route, tracks: [
            ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)
        ])
    }

    private static func executableURL(descriptor: ScannerPluginDescriptor) throws -> URL {
        if let configured = ProcessInfo.processInfo.environment["SCANSONG_MDX_INSPECT"], !configured.isEmpty {
            let url = URL(fileURLWithPath: configured)
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw ScannerInspectionError.library("Configured MDX inspector is not executable: \(url.path)")
            }
            return url
        }
        if let bundled = Bundle.main.url(forResource: "vgmboy-mdx-inspect", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        throw ScannerInspectionError.missingRequiredAdapter(
            pluginID: descriptor.pluginID,
            extensionName: descriptor.supportedExtensions.joined(separator: ", ")
        )
    }
}

private struct MDXInfo: Decodable, Sendable {
    let trackCount: Int
}
