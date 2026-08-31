import ArchiveCacheCore
import Foundation
import VGMBoyFormatCore

/// Cache-backed materialization for a catalog-selected archive member.
///
/// Both frontends need the same boundary: catalog metadata identifies the
/// archive member, VGMBoyFormatCore identifies whether that member needs a
/// selected file or a dependency-complete set, and VGMBoy receives a normal
/// playable path. The frontend supplies only cache preference names and a
/// cache root; archive-tool routing, staging, and dependency preparation stay
/// in shared native code.
public final class ArchivePlaybackMaterializer: @unchecked Sendable {
    private let cacheStore: ArchiveCacheStore
    private let cacheMaterializer: ArchiveCacheMaterializer
    private let playbackLease: ArchivePlaybackLease
    private let preferenceKeys: ArchiveCachePreferenceKeys

    public init(
        cacheRootURL: URL,
        preferenceKeys: ArchiveCachePreferenceKeys,
        playbackLease: ArchivePlaybackLease = ArchivePlaybackLease(),
        capacityProvider: ArchiveCacheStore.CapacityProvider? = nil
    ) {
        let cacheStore = ArchiveCacheStore(
            cacheRootURL: cacheRootURL,
            capacityProvider: capacityProvider
        )
        self.cacheStore = cacheStore
        self.playbackLease = playbackLease
        self.cacheMaterializer = ArchiveCacheMaterializer(
            cacheStore: cacheStore,
            playbackLease: playbackLease
        )
        self.preferenceKeys = preferenceKeys
    }

    /// Returns the selected playable file, never the cache root directory.
    /// Complete-set requirements still return the selected member inside the
    /// prepared set, so callers can pass the result directly to VGMBoy.
    public func materialize(
        archiveURL: URL,
        entryPath: String,
        requirement: VGMArchiveMaterializationRequirement
    ) throws -> URL {
        let archiveURL = archiveURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveMaterializationError.missingSource(archiveURL.path)
        }

        let normalizedEntry = ArchiveEntryPath.normalized(entryPath)
        guard !normalizedEntry.isEmpty, ArchiveEntryPath.isSafe(normalizedEntry) else {
            throw ArchiveMaterializationError.invalidEntry
        }

        let policy = ArchiveCachePolicy.load(keys: preferenceKeys)
        let memberURL: URL
        switch requirement {
        case .selectedEntry:
            memberURL = try cacheMaterializer.materializeEntry(
                archiveURL: archiveURL,
                entryPath: normalizedEntry,
                policy: policy
            ) { temporaryURL in
                try ArchiveMaterializer.shared.execute(
                    ArchiveToolRouting.selectedEntryToStdout(
                        kind: try archiveKind(for: archiveURL),
                        archiveURL: archiveURL,
                        entryPath: normalizedEntry
                    ),
                    outputURL: temporaryURL
                )
            }

        case .completeSet, .completeSetWithLazyUSFAliases:
            if try archiveKind(for: archiveURL) == .singleFileZstandard {
                throw ArchiveMaterializationError.extractFailed(
                    "Standalone Zstandard input cannot provide the complete decoder set required by this format."
                )
            }
            let rootURL = try cacheMaterializer.materializeCompleteSet(
                archiveURL: archiveURL,
                policy: policy,
                activePlaybackRoot: playbackLease.path.map(URL.init(fileURLWithPath:)),
                isValid: { rootURL in
                    let selectedURL = self.cacheMaterializer.archiveMemberURL(
                        in: rootURL,
                        entryPath: normalizedEntry
                    )
                    guard let attributes = try? FileManager.default.attributesOfItem(atPath: selectedURL.path),
                          let byteCount = (attributes[.size] as? NSNumber)?.int64Value else {
                        return false
                    }
                    return byteCount > 0
                }
            ) { stagingURL in
                try ArchiveMaterializer.shared.execute(
                    ArchiveToolRouting.completeSet(
                        kind: try archiveKind(for: archiveURL),
                        archiveURL: archiveURL,
                        destinationURL: stagingURL
                    )
                )
            }
            if requirement == .completeSetWithLazyUSFAliases {
                try ArchiveDependencyPreparation.prepareLazyUSFAliases(in: rootURL)
            }
            if URL(fileURLWithPath: normalizedEntry).pathExtension.lowercased() == "txtp" {
                try ArchiveDependencyPreparation.prepareTXTPDependencies(in: rootURL)
            }
            memberURL = cacheMaterializer.archiveMemberURL(in: rootURL, entryPath: normalizedEntry)
        }

        try validatePlayableOutput(memberURL)
        return memberURL
    }

    public func release() {
        playbackLease.clear()
        cacheStore.lifecycle.discardDisposablePlaybackMaterialization()
    }

    public func cacheSummary() -> (fileCount: Int, byteCount: Int64, availableBytes: Int64?) {
        let rootURL = cacheStore.materializationRootURL(policy: ArchiveCachePolicy.load(keys: preferenceKeys))
        var fileCount = 0
        var byteCount: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(
                    forKeys: [.isRegularFileKey, .fileSizeKey]
                ), values.isRegularFile == true else { continue }
                fileCount += 1
                byteCount += Int64(values.fileSize ?? 0)
            }
        }
        return (fileCount, byteCount, cacheStore.availableCapacityNear(rootURL))
    }

    public func clearCache() throws {
        try cacheStore.lifecycle.clearAllPlaybackMaterialization()
    }

    private func archiveKind(for archiveURL: URL) throws -> ArchiveContainerKind {
        guard let kind = ArchiveContainerKind(archiveURL: archiveURL) else {
            throw ArchiveMaterializationError.toolUnavailable("supported archive format")
        }
        return kind
    }

    private func validatePlayableOutput(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard byteCount > 0 else { throw ArchiveMaterializationError.emptyOutput }
    }
}
