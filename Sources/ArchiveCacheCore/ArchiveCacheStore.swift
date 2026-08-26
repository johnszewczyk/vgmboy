import CryptoKit
import Foundation

/// Shared identity and policy-facing storage operations for extracted archive
/// material. Frontends provide their policy; they do not reimplement cache
/// identity, root selection, free-space checks, or eviction rules.
public struct ArchiveCacheStore: Sendable {
    public enum Error: Swift.Error, Equatable, Sendable {
        case insufficientStorage(requiredBytes: Int64)
        case cacheLimitExceeded(limitBytes: Int64)
    }

    public let lifecycle: ArchiveCacheLifecycle

    public init(cacheRootURL: URL) {
        self.lifecycle = ArchiveCacheLifecycle(cacheRootURL: cacheRootURL)
    }

    public var cacheRootURL: URL { lifecycle.cacheRootURL }

    public func materializationRootURL(policy: ArchiveCachePolicy) -> URL {
        policy.isEnabled ? lifecycle.durableRootURL : lifecycle.disposableRootURL
    }

    /// Returns the stable root for one source archive. The key deliberately
    /// follows CocoaSpice's existing contract: standardized path, file size,
    /// and modification date, with no payload read or decoder involvement.
    public func archiveCacheURL(
        for archiveURL: URL,
        policy: ArchiveCachePolicy
    ) -> URL {
        let standardizedURL = archiveURL.standardizedFileURL
        let attributes = try? FileManager.default.attributesOfItem(atPath: standardizedURL.path)
        let archiveFileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let archiveModifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
        let identity = standardizedURL.path
            + "|"
            + String(archiveFileSize)
            + "|"
            + String(archiveModifiedAt.timeIntervalSinceReferenceDate)
        let key = SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return materializationRootURL(policy: policy)
            .appendingPathComponent(key, isDirectory: true)
    }

    public func availableCapacityNear(_ url: URL) -> Int64? {
        let fileManager = FileManager.default
        var probe = url
        while !fileManager.fileExists(atPath: probe.path), probe.path != "/" {
            probe.deleteLastPathComponent()
        }
        guard let values = try? probe.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ) else {
            return nil
        }
        return values.volumeAvailableCapacityForImportantUsage.map { Int64($0) }
    }

    public func prepareWrite(policy: ArchiveCachePolicy) throws {
        let root = materializationRootURL(policy: policy)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        guard available >= ArchiveCachePolicy.requiredFreeBytes else {
            throw Error.insufficientStorage(requiredBytes: ArchiveCachePolicy.requiredFreeBytes)
        }
    }

    public func enforceLimit(
        policy: ArchiveCachePolicy,
        preserving protectedRoot: URL,
        activePlaybackRoot: URL?
    ) throws {
        let limit = policy.activeLimitBytes
        let fits = try lifecycle.pruneDurableMaterialization(
            maximumBytes: limit,
            preserving: protectedRoot,
            activePlaybackRoot: activePlaybackRoot
        )
        guard fits else {
            throw Error.cacheLimitExceeded(limitBytes: limit)
        }
    }

    public func touch(_ archiveURL: URL, policy: ArchiveCachePolicy) {
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: archiveCacheURL(for: archiveURL, policy: policy).path
        )
    }
}
