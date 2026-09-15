import Foundation
import MetaManCore
import UACWrapperCore

public struct MetaManMetadataHarvestOutcome: Sendable {
    public let memberMetadata: [String: [String: UACJSONValue]]
    public let failures: [String]
    public let diagnosticCount: Int

    public init(
        memberMetadata: [String: [String: UACJSONValue]],
        failures: [String],
        diagnosticCount: Int
    ) {
        self.memberMetadata = memberMetadata
        self.failures = failures
        self.diagnosticCount = diagnosticCount
    }
}

public enum MetaManMetadataHarvester {
    private static let maximumMemberSize: UInt64 = 64 * 1024 * 1024

    /// Harvests a directory for one MetaMan-supported file extension.
    /// Track-aware results are rejected until UAC has an explicit mapping from
    /// one source member to its ordered logical tracks.
    public static func harvest(
        directoryURL: URL,
        formatExtension: String
    ) throws -> MetaManMetadataHarvestOutcome {
        let ext = formatExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        guard !ext.isEmpty,
              MetaManCore.supportedFormats.contains(where: { $0.fileExtensions.contains(ext) }) else {
            throw MetaManMetadataHarvesterError.unsupportedFormat(ext)
        }

        let root = directoryURL.standardizedFileURL
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw MetaManMetadataHarvesterError.notDirectory(root.path)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw MetaManMetadataHarvesterError.cannotEnumerate(root.path)
        }

        var files: [(url: URL, path: String)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == ext else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw MetaManMetadataHarvesterError.notRegularFile(url.path)
            }
            let path = String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
            guard !path.isEmpty, !path.hasPrefix("../"), !path.contains("\\") else {
                throw MetaManMetadataHarvesterError.unsafeRelativePath(path)
            }
            files.append((url, path))
        }
        files.sort { $0.path < $1.path }

        var memberMetadata: [String: [String: UACJSONValue]] = [:]
        var failures: [String] = []
        var diagnosticCount = 0
        for file in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
                guard let size = attributes[.size] as? NSNumber,
                      size.uint64Value <= maximumMemberSize else {
                    throw MetaManMetadataHarvesterError.memberTooLarge(file.path)
                }
                let result = try MetaManCore.readResult(fileURL: file.url)
                guard result.tracks.count == 1, let track = result.tracks.first else {
                    throw MetaManMetadataHarvesterError.trackAwareResultRequired(file.path, result.tracks.count)
                }
                diagnosticCount += track.document.diagnostics.count
                memberMetadata[file.path] = MetaManMetadataProjector.memberFields(from: track.document)
            } catch {
                failures.append("\(file.path): \(error.localizedDescription)")
            }
        }

        return MetaManMetadataHarvestOutcome(
            memberMetadata: memberMetadata,
            failures: failures,
            diagnosticCount: diagnosticCount
        )
    }
}

private enum MetaManMetadataHarvesterError: Error, LocalizedError {
    case unsupportedFormat(String)
    case notDirectory(String)
    case cannotEnumerate(String)
    case notRegularFile(String)
    case unsafeRelativePath(String)
    case memberTooLarge(String)
    case trackAwareResultRequired(String, Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format): "MetaMan does not advertise direct metadata support for .\(format) files."
        case .notDirectory(let path): "Metadata input is not a real directory: \(path)"
        case .cannotEnumerate(let path): "Cannot enumerate metadata input: \(path)"
        case .notRegularFile(let path): "Metadata input is not a regular file: \(path)"
        case .unsafeRelativePath(let path): "Metadata input has an unsafe member path: \(path)"
        case .memberTooLarge(let path): "Member is larger than the 64 MiB metadata-reader safety limit: \(path)"
        case .trackAwareResultRequired(let path, let count):
            "\(path) has \(count) logical tracks; UAC format harvesting does not flatten track-aware MetaMan results."
        }
    }
}
