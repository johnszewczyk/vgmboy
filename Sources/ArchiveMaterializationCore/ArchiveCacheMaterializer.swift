import ArchiveCacheCore
import CryptoKit
import Darwin
import Foundation

/// Shared cache-backed orchestration for archive materialization.
///
/// Archive format/tool execution remains supplied by the frontend through the
/// extraction closures. This type owns only the common cache lifecycle:
/// warm-hit validation, atomic staging, completion markers, selection identity,
/// and limit enforcement.
public struct ArchiveCacheMaterializer: Sendable {
    private let cacheStore: ArchiveCacheStore
    private let playbackLease: ArchivePlaybackLease?

    public init(cacheStore: ArchiveCacheStore, playbackLease: ArchivePlaybackLease? = nil) {
        self.cacheStore = cacheStore
        self.playbackLease = playbackLease
    }

    public func materializeEntry(
        archiveURL: URL,
        entryPath: String,
        policy: ArchiveCachePolicy,
        extract: (URL) throws -> Void
    ) throws -> URL {
        let archiveURL = archiveURL.standardizedFileURL
        let normalizedEntry = try normalizedEntryPath(entryPath)
        let destinationURL = cacheStore.archiveCacheURL(for: archiveURL, policy: policy)
            .appendingPathComponent(normalizedEntry, isDirectory: false)
        let fileManager = FileManager.default
        let archiveModifiedAt =
            (try? archiveURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast

        if fileManager.fileExists(atPath: destinationURL.path),
           let extractedModifiedAt = try? destinationURL.resourceValues(
               forKeys: [.contentModificationDateKey]
            ).contentModificationDate,
           extractedModifiedAt >= archiveModifiedAt {
            cacheStore.touch(archiveURL, policy: policy)
            activateLease(for: archiveURL, policy: policy)
            return destinationURL
        }

        try cacheStore.prepareWrite(policy: policy)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).partial", isDirectory: false)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try extract(temporaryURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            activateLease(for: archiveURL, policy: policy)
            return destinationURL
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        activateLease(for: archiveURL, policy: policy)
        return destinationURL
    }

    public func materializeCompleteSet(
        archiveURL: URL,
        policy: ArchiveCachePolicy,
        activePlaybackRoot: URL?,
        isValid: (URL) -> Bool = { _ in true },
        extract: (URL) throws -> Void
    ) throws -> URL {
        let archiveURL = archiveURL.standardizedFileURL
        let archiveRoot = cacheStore.archiveCacheURL(for: archiveURL, policy: policy)
        let rootURL = archiveRoot.appendingPathComponent("set", isDirectory: true)
        let completionURL = rootURL.appendingPathComponent(".complete", isDirectory: false)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: completionURL.path) {
            // Older cache entries may have inherited non-traversable directory
            // modes from the source archive. Repair them before validating a
            // warm hit so housekeeping can replace or remove the set.
            try? normalizeExtractedDirectoryPermissions(at: rootURL)
            if isValid(rootURL) {
                cacheStore.touch(archiveURL, policy: policy)
                activateLease(for: archiveURL, policy: policy)
                return rootURL
            }
            // A marker only proves that a prior extraction process finished,
            // not that its selected decoder input survived. Never hand a
            // missing dependency-set member to a frontend while an earlier
            // track keeps playing; remove this invalid cache entry and stage
            // the complete archive again.
            try? fileManager.removeItem(at: rootURL)
        }

        try cacheStore.prepareWrite(policy: policy)
        let stagingURL = archiveRoot
            .deletingLastPathComponent()
            .appendingPathComponent(".set-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingURL) }
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try extract(stagingURL)
        try normalizeExtractedDirectoryPermissions(at: stagingURL)
        try Data().write(to: stagingURL.appendingPathComponent(".complete"))
        try fileManager.createDirectory(
            at: rootURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // A previous interrupted extraction can leave `set` behind without a
        // completion marker. It is not a warm hit and must not block the
        // atomic replacement with the newly validated staging directory.
        if fileManager.fileExists(atPath: rootURL.path) {
            try? normalizeExtractedDirectoryPermissions(at: rootURL)
            try fileManager.removeItem(at: rootURL)
        }
        try fileManager.moveItem(at: stagingURL, to: rootURL)
        try cacheStore.enforceLimit(
            policy: policy,
            preserving: archiveRoot,
            activePlaybackRoot: activePlaybackRoot
        )
        activateLease(for: archiveURL, policy: policy)
        return rootURL
    }

    public func materializeEntries(
        archiveURL: URL,
        entryPaths: [String],
        policy: ArchiveCachePolicy,
        extract: (URL, [String]) throws -> Void
    ) throws -> URL {
        let archiveURL = archiveURL.standardizedFileURL
        let normalizedPaths = try normalizedEntryPaths(entryPaths)
        let selectionKey = SHA256.hash(data: Data(normalizedPaths.joined(separator: "\n").utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let archiveRoot = cacheStore.archiveCacheURL(for: archiveURL, policy: policy)
        let rootURL = archiveRoot
            .appendingPathComponent("selection-\(selectionKey)", isDirectory: true)
        let completionURL = rootURL.appendingPathComponent(".complete", isDirectory: false)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: completionURL.path) {
            cacheStore.touch(archiveURL, policy: policy)
            activateLease(for: archiveURL, policy: policy)
            return rootURL
        }

        try cacheStore.prepareWrite(policy: policy)
        let stagingURL = archiveRoot
            .deletingLastPathComponent()
            .appendingPathComponent(".selection-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: stagingURL) }
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        try extract(stagingURL, normalizedPaths)
        try normalizeExtractedDirectoryPermissions(at: stagingURL)
        try Data().write(to: stagingURL.appendingPathComponent(".complete"))
        try fileManager.createDirectory(
            at: rootURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.moveItem(at: stagingURL, to: rootURL)
        }
        activateLease(for: archiveURL, policy: policy)
        return rootURL
    }

    public func archiveMemberURL(in rootURL: URL, entryPath: String) -> URL {
        ArchiveEntryPath.components(entryPath).reduce(rootURL) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }
    }

    private func normalizedEntryPath(_ entryPath: String) throws -> String {
        let normalized = ArchiveEntryPath.normalized(entryPath)
        guard !normalized.isEmpty, ArchiveEntryPath.isSafe(normalized) else {
            throw ArchiveMaterializationError.invalidEntry
        }
        return normalized
    }

    private func normalizedEntryPaths(_ entryPaths: [String]) throws -> [String] {
        let normalized = try Array(Set(entryPaths.map { try normalizedEntryPath($0) })).sorted()
        guard !normalized.isEmpty else { throw ArchiveMaterializationError.invalidEntry }
        return normalized
    }

    private func activateLease(for archiveURL: URL, policy: ArchiveCachePolicy) {
        playbackLease?.replace(
            with: cacheStore.archiveCacheURL(for: archiveURL, policy: policy).standardizedFileURL.path
        )
    }

    /// Some source archives carry directory mode bits without the execute bit
    /// (for example `0644`). Preserve file contents but make the extracted
    /// cache traversable and removable by the owning process.
    private func normalizeExtractedDirectoryPermissions(at rootURL: URL) throws {
        let fileManager = FileManager.default
        func normalize(_ directoryURL: URL) throws {
            guard chmod(directoryURL.path, mode_t(0o755)) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            let children = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            for child in children {
                guard (try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    continue
                }
                try normalize(child)
            }
        }
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        try normalize(rootURL)
    }
}
