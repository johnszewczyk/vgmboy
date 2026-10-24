import Foundation
import VGMBoyArchiveCore

/// Reads one archive-side manifest into memory without creating playback-cache
/// state. This small helper is for frontend-owned browsing; playable sources
/// are prepared by VGMBoyArchiveCore.
public struct ArchiveManifestReader: Sendable {
    public init() {}

    public func read(
        entryPath: String,
        extract: (URL, URL) throws -> Void
    ) throws -> Data {
        let normalized = ArchiveEntryPath.normalized(entryPath)
        guard !normalized.isEmpty, ArchiveEntryPath.isSafe(normalized) else {
            throw ArchiveMaterializationError.invalidEntry
        }

        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FrontendCore-archive-entry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let memberURL = ArchiveEntryPath.components(normalized).reduce(rootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }
        try FileManager.default.createDirectory(
            at: memberURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try extract(rootURL, memberURL)
        return try Data(contentsOf: memberURL)
    }
}
