import Foundation

/// Archive containers understood by the native CocoaSpice archive engine.
public enum ArchiveContainerKind: String, CaseIterable, Equatable, Sendable {
    case zip
    case sevenZip
    case rsn
    case tar
    case tarZstandard

    public init?(archiveURL: URL) {
        let url = archiveURL.standardizedFileURL
        let extensionName = url.pathExtension.lowercased()
        if extensionName == "zst",
           url.deletingPathExtension().pathExtension.lowercased() == "tar" {
            self = .tarZstandard
            return
        }
        if extensionName == "zstd",
           url.deletingPathExtension().pathExtension.lowercased() == "tar" {
            self = .tarZstandard
            return
        }
        switch extensionName {
        case "zip": self = .zip
        case "7z": self = .sevenZip
        case "rsn": self = .rsn
        case "tar": self = .tar
        case "tzst": self = .tarZstandard
        default: return nil
        }
    }
}

/// A format-specific process or connected-process specification. The
/// frontend remains responsible for executable discovery, process execution,
/// output routing, and app-specific error mapping.
public enum ArchiveToolInvocation: Equatable, Sendable {
    case process(executableName: String, arguments: [String])
    case zstandardTar(
        zstdExecutableName: String,
        zstdArguments: [String],
        tarExecutableName: String,
        tarArguments: [String],
        allowEarlyConsumerExit: Bool
    )
}

/// Exact command specifications extracted from CocoaSpice's archive engine.
public enum ArchiveToolRouting {
    public static func selectedEntryToStdout(
        kind: ArchiveContainerKind,
        archiveURL: URL,
        entryPath: String
    ) -> ArchiveToolInvocation {
        switch kind {
        case .rsn:
            return .process(
                executableName: "unar",
                arguments: ["-q", "-f", "-o", "-", archiveURL.path, entryPath]
            )
        case .zip, .sevenZip:
            return .process(
                executableName: "7zz",
                arguments: ["x", "-mmt=1", "-so", archiveURL.path, entryPath]
            )
        case .tar:
            return .process(
                executableName: "tar",
                arguments: ["-xOf", archiveURL.path, entryPath]
            )
        case .tarZstandard:
            return .zstandardTar(
                zstdExecutableName: "zstd",
                zstdArguments: ["-d", "-q", "-c", archiveURL.path],
                tarExecutableName: "tar",
                tarArguments: ["-xOf", "-", entryPath],
                allowEarlyConsumerExit: true
            )
        }
    }

    public static func completeSet(
        kind: ArchiveContainerKind,
        archiveURL: URL,
        destinationURL: URL
    ) -> ArchiveToolInvocation {
        switch kind {
        case .rsn:
            return .process(
                executableName: "unar",
                arguments: ["-q", "-f", "-D", "-o", destinationURL.path, archiveURL.path]
            )
        case .zip, .sevenZip:
            return .process(
                executableName: "7zz",
                arguments: ["x", "-mmt=1", "-y", "-o\(destinationURL.path)", archiveURL.path]
            )
        case .tar:
            return .process(
                executableName: "tar",
                arguments: ["-xf", archiveURL.path, "-C", destinationURL.path]
            )
        case .tarZstandard:
            return .zstandardTar(
                zstdExecutableName: "zstd",
                zstdArguments: ["-d", "-q", "-c", archiveURL.path],
                tarExecutableName: "tar",
                tarArguments: ["-xf", "-", "-C", destinationURL.path],
                allowEarlyConsumerExit: false
            )
        }
    }

    public static func selectedEntries(
        kind: ArchiveContainerKind,
        archiveURL: URL,
        entryPaths: [String],
        destinationURL: URL
    ) -> ArchiveToolInvocation {
        switch kind {
        case .rsn:
            return .process(
                executableName: "unar",
                arguments: ["-q", "-f", "-D", "-o", destinationURL.path, archiveURL.path] + entryPaths
            )
        case .zip, .sevenZip:
            return .process(
                executableName: "7zz",
                arguments: ["x", "-mmt=1", "-y", "-o\(destinationURL.path)", archiveURL.path] + entryPaths
            )
        case .tar:
            return .process(
                executableName: "tar",
                arguments: ["-xf", archiveURL.path, "-C", destinationURL.path]
                    + ArchiveEntryPath.tarMemberSelectionPatterns(entryPaths)
            )
        case .tarZstandard:
            return .zstandardTar(
                zstdExecutableName: "zstd",
                zstdArguments: ["-d", "-q", "-c", archiveURL.path],
                tarExecutableName: "tar",
                tarArguments: ["-xf", "-", "-C", destinationURL.path]
                    + ArchiveEntryPath.tarMemberSelectionPatterns(entryPaths),
                allowEarlyConsumerExit: true
            )
        }
    }
}
