import Foundation
import UACWrapperCore

public struct UACCollectionEntry: Identifiable, Equatable, Sendable {
    public let relativePath: String
    public let packageID: String
    public let title: String
    public let console: String
    public let totalMemberCount: Int
    public let playableMemberCount: Int
    public let fileByteCount: UInt64

    public var id: String { relativePath }
}

public struct UACCollectionIssue: Identifiable, Equatable, Sendable {
    public let relativePath: String
    public let message: String

    public var id: String { relativePath }
}

public struct UACCollectionScanResult: Equatable, Sendable {
    public let entries: [UACCollectionEntry]
    public let issues: [UACCollectionIssue]
}

public typealias UACCollectionManifestReader = @Sendable (URL) throws -> UACManifest

/// Lists UAC manifests beneath a selected root. The scanner reads package
/// manifests only; it never decompresses or extracts the TAR payload.
public enum UACCollectionScanner {
    public static func scan(
        root: URL,
        manifestReader: UACCollectionManifestReader
    ) throws -> UACCollectionScanResult {
        let root = root.standardizedFileURL
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw UACCollectionScannerError.rootIsNotDirectory
        }

        var pendingDirectories = [root]
        var entries: [UACCollectionEntry] = []
        var issues: [UACCollectionIssue] = []

        while let directory = pendingDirectories.popLast() {
            if Task<Never, Never>.isCancelled { throw CancellationError() }
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                    options: [.skipsHiddenFiles]
                ).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            } catch {
                issues.append(UACCollectionIssue(
                    relativePath: relativePath(for: directory, under: root),
                    message: error.localizedDescription
                ))
                continue
            }

            for child in children {
                if Task<Never, Never>.isCancelled { throw CancellationError() }
                let values: URLResourceValues
                do {
                    values = try child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                } catch {
                    issues.append(UACCollectionIssue(
                        relativePath: relativePath(for: child, under: root),
                        message: error.localizedDescription
                    ))
                    continue
                }
                guard values.isSymbolicLink != true else { continue }
                if values.isDirectory == true {
                    pendingDirectories.append(child)
                    continue
                }
                guard values.isRegularFile == true,
                      child.pathExtension.lowercased() == "uac" else { continue }

                let relativePath = relativePath(for: child, under: root)
                do {
                    let manifest = try manifestReader(child)
                    entries.append(UACCollectionEntry(
                        relativePath: relativePath,
                        packageID: manifest.packageID,
                        title: manifest.game.title,
                        console: manifest.game.console,
                        totalMemberCount: manifest.members.count,
                        playableMemberCount: manifest.members.filter {
                            $0.role == "playable" || $0.role == "track"
                        }.count,
                        fileByteCount: UInt64(max(0, values.fileSize ?? 0))
                    ))
                } catch {
                    issues.append(UACCollectionIssue(
                        relativePath: relativePath,
                        message: error.localizedDescription
                    ))
                }
            }
        }

        entries.sort {
            let titleOrder = $0.title.localizedStandardCompare($1.title)
            return titleOrder == .orderedSame
                ? $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
                : titleOrder == .orderedAscending
        }
        issues.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return UACCollectionScanResult(entries: entries, issues: issues)
    }

    public static func relativePath(for url: URL, under root: URL) -> String {
        let rootComponents = root.standardizedFileURL.pathComponents
        let itemComponents = url.standardizedFileURL.pathComponents
        guard itemComponents.starts(with: rootComponents) else { return url.lastPathComponent }
        let suffix = itemComponents.dropFirst(rootComponents.count)
        return suffix.joined(separator: "/")
    }
}

public enum UACCollectionScannerError: Error, LocalizedError {
    case rootIsNotDirectory

    public var errorDescription: String? {
        switch self {
        case .rootIsNotDirectory:
            return "Choose a collection folder."
        }
    }
}
