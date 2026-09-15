import Foundation
import MetaManCore
import UACWrapperCore

public struct SPCMetadataHarvestOutcome: Sendable {
    public let items: [SPCMetadataHarvestItem]
    public let failures: [String]
    public let diagnosticCount: Int
    public let wasCancelled: Bool

    public init(items: [SPCMetadataHarvestItem], failures: [String], diagnosticCount: Int, wasCancelled: Bool) {
        self.items = items
        self.failures = failures
        self.diagnosticCount = diagnosticCount
        self.wasCancelled = wasCancelled
    }
}

public enum SPCMetadataHarvester {
    /// Reads raw SPC files from a directory before they have been packaged.
    /// Paths in the result are stable, relative paths suitable for matching
    /// against the packer's member records.
    public static func harvest(
        directoryURL: URL,
        progress: @Sendable (Int, Int, String) -> Void = { _, _, _ in }
    ) throws -> SPCMetadataHarvestOutcome {
        let root = directoryURL.standardizedFileURL
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw SPCMetadataDirectoryError.notDirectory(root.path)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw SPCMetadataDirectoryError.cannotEnumerate(root.path)
        }

        var files: [(url: URL, path: String)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "spc" else { continue }
            let itemValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard itemValues.isSymbolicLink != true, itemValues.isRegularFile == true else {
                throw SPCMetadataDirectoryError.notRegularFile(url.path)
            }
            let path = String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
            guard !path.isEmpty, !path.hasPrefix("../"), !path.contains("\\") else {
                throw SPCMetadataDirectoryError.unsafeRelativePath(path)
            }
            files.append((url, path))
        }
        files.sort { $0.path < $1.path }

        var items: [SPCMetadataHarvestItem] = []
        var failures: [String] = []
        var diagnosticCount = 0
        for (index, file) in files.enumerated() {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
                guard let size = attributes[.size] as? NSNumber,
                      size.uint64Value <= 64 * 1024 * 1024 else {
                    throw SPCMetadataHarvesterError.memberTooLarge(file.path)
                }
                let data = try Data(contentsOf: file.url, options: [.mappedIfSafe])
                let document = try MetaManCore.read(
                    data: data,
                    formatHint: "spc",
                    displayName: file.url.lastPathComponent
                )
                diagnosticCount += document.diagnostics.count
                items.append(SPCMetadataHarvestItem(
                    memberPath: file.path,
                    projection: SPCMetadataProjector.project(document)
                ))
            } catch {
                failures.append("\(file.path): \(error.localizedDescription)")
            }
            progress(index + 1, files.count, file.path)
        }

        return SPCMetadataHarvestOutcome(
            items: items,
            failures: failures,
            diagnosticCount: diagnosticCount,
            wasCancelled: false
        )
    }

    public static func harvest(
        packageURL: URL,
        memberPaths: [String],
        decompressManifestFrame: @escaping UACManifestFrameDecoder,
        decompressFrame: @escaping @Sendable (Data, UInt32?) throws -> Data,
        progress: @escaping @Sendable (Int, Int, String) -> Void = { _, _, _ in }
    ) throws -> SPCMetadataHarvestOutcome {
        var items: [SPCMetadataHarvestItem] = []
        var failures: [String] = []
        var diagnosticCount = 0
        var wasCancelled = false

        for (index, path) in memberPaths.enumerated() {
            if Task.isCancelled {
                wasCancelled = true
                break
            }
            do {
                let virtualFile = try UACSeekableMemberFile(
                    url: packageURL,
                    memberPath: path,
                    decompressManifestFrame: decompressManifestFrame,
                    decompressFrame: decompressFrame
                )
                guard virtualFile.size <= UInt64(Int.max),
                      virtualFile.size <= 64 * 1024 * 1024 else {
                    throw SPCMetadataHarvesterError.memberTooLarge(path)
                }
                let data = try virtualFile.read(at: 0, byteCount: Int(virtualFile.size))
                let document = try MetaManCore.read(
                    data: data,
                    formatHint: "spc",
                    displayName: URL(fileURLWithPath: path).lastPathComponent
                )
                diagnosticCount += document.diagnostics.count
                items.append(SPCMetadataHarvestItem(
                    memberPath: path,
                    projection: SPCMetadataProjector.project(document)
                ))
            } catch {
                failures.append("\(path): \(error.localizedDescription)")
            }
            progress(index + 1, memberPaths.count, path)
        }
        return SPCMetadataHarvestOutcome(
            items: items,
            failures: failures,
            diagnosticCount: diagnosticCount,
            wasCancelled: wasCancelled
        )
    }
}

private enum SPCMetadataDirectoryError: Error, LocalizedError {
    case notDirectory(String)
    case cannotEnumerate(String)
    case notRegularFile(String)
    case unsafeRelativePath(String)

    var errorDescription: String? {
        switch self {
        case .notDirectory(let path): "SPC metadata input is not a real directory: \(path)"
        case .cannotEnumerate(let path): "Cannot enumerate SPC metadata input: \(path)"
        case .notRegularFile(let path): "SPC metadata input is not a regular file: \(path)"
        case .unsafeRelativePath(let path): "SPC metadata input has an unsafe member path: \(path)"
        }
    }
}

private enum SPCMetadataHarvesterError: Error, LocalizedError {
    case memberTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .memberTooLarge(let path):
            "SPC member is larger than the 64 MiB metadata-reader safety limit: \(path)"
        }
    }
}
