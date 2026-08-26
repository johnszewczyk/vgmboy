import ArchiveCacheCore
import ArchiveMaterializationCore
import Foundation
import VGMBoyFormatCore

/// SPCBoyWK's archive boundary.
///
/// This is intentionally an adapter, not a second archive engine. VGMBoy
/// decides whether an entry needs one file or a dependency-complete set;
/// FrontendCore owns cache identity, staging, leases, and tool execution.
/// SPCBoyWK supplies only its preference keys and the shared cache location.
enum SPCArchiveMaterialization {
    private static let cacheRootURL: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CocoaSpice", isDirectory: true)
            .appendingPathComponent("ArchiveCache", isDirectory: true)
    }()

    private static let cacheKeys = ArchiveCachePreferenceKeys(
        modeKey: "SPCBoyWK.archiveCacheMode",
        limitKey: "SPCBoyWK.archiveCacheLimitBytes"
    )
    private static let cacheStore = ArchiveCacheStore(cacheRootURL: cacheRootURL)
    private static let playbackMaterializer = ArchivePlaybackMaterializer(
        cacheRootURL: cacheRootURL,
        preferenceKeys: cacheKeys
    )
    private static let exportMaterializer = ArchivePlaybackMaterializer(
        cacheRootURL: cacheRootURL,
        preferenceKeys: cacheKeys
    )

    static func materialize(
        archivePath: String,
        entry: String,
        requirement: VGMArchiveMaterializationRequirement
    ) throws -> URL {
        let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveMaterializationError.missingSource(archiveURL.path)
        }

        let normalizedEntry = ArchiveEntryPath.normalized(entry)
        guard !normalizedEntry.isEmpty, ArchiveEntryPath.isSafe(normalizedEntry) else {
            throw ArchiveMaterializationError.invalidEntry
        }

        return try playbackMaterializer.materialize(
            archiveURL: archiveURL,
            entryPath: normalizedEntry,
            requirement: requirement
        )
    }

    static func release() {
        playbackMaterializer.release()
    }

    static func materializeForExport(
        archivePath: String,
        entry: String,
        requirement: VGMArchiveMaterializationRequirement
    ) throws -> URL {
        let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveMaterializationError.missingSource(archiveURL.path)
        }
        let normalizedEntry = ArchiveEntryPath.normalized(entry)
        guard !normalizedEntry.isEmpty, ArchiveEntryPath.isSafe(normalizedEntry) else {
            throw ArchiveMaterializationError.invalidEntry
        }
        return try exportMaterializer.materialize(
            archiveURL: archiveURL,
            entryPath: normalizedEntry,
            requirement: requirement
        )
    }

    static func releaseExport() {
        exportMaterializer.release()
    }

    static func configure(enabled: Bool, limitBytes: Int64) -> [String: Any] {
        let limit = nearestSupportedLimit(limitBytes)
        ArchiveCachePolicy(
            mode: enabled ? .enabled : .disabled,
            maximumBytes: limit
        ).save(keys: cacheKeys)
        return cacheSummary()
    }

    static func cacheSummary() -> [String: Any] {
        let policy = cachePolicy()
        let rootURL = cacheStore.materializationRootURL(policy: policy)
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
        var result: [String: Any] = [
            "fileCount": fileCount,
            "byteCount": byteCount,
            "enabled": policy.isEnabled,
            "limitBytes": policy.maximumBytes
        ]
        if let available = cacheStore.availableCapacityNear(rootURL) {
            result["availableBytes"] = available
        }
        return result
    }

    static func cacheLocation() -> String {
        cacheRootURL.standardizedFileURL.path
    }

    static func clearCache() throws {
        try playbackMaterializer.clearCache()
    }

    private static func cachePolicy() -> ArchiveCachePolicy {
        ArchiveCachePolicy.load(keys: cacheKeys)
    }

    private static func nearestSupportedLimit(_ requested: Int64) -> Int64 {
        ArchiveCachePolicy.supportedLimits.min {
            abs($0 - requested) < abs($1 - requested)
        } ?? ArchiveCachePolicy.defaultLimitBytes
    }

}
