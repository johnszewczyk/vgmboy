import ArchiveCacheCore
import ArchiveMaterializationCore
import Foundation
import VGMBoyFormatCore

/// SPCBoyWK's retained archive-cache preferences. Playback and AAC export pass
/// original source identity to VGMBoyArchiveCore.
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
    private static let cacheMaterializer = FrontendArchiveCacheMaterializer(
        cacheRootURL: cacheRootURL,
        preferenceKeys: cacheKeys
    )
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
        let usage = cacheStore.cacheUsage()
        var result: [String: Any] = [
            "fileCount": usage.fileCount,
            "byteCount": usage.byteCount,
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
        try cacheMaterializer.clearCache()
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
