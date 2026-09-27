import CryptoKit
import Foundation

public struct ArchiveCacheUsage: Sendable, Equatable {
    public let fileCount: Int
    public let byteCount: Int64
}

/// Shared identity and policy-facing storage operations for extracted archive
/// material. Frontends provide their policy; they do not reimplement cache
/// identity, root selection, free-space checks, or eviction rules.
public struct ArchiveCacheStore: Sendable {
    public typealias CapacityProvider = @Sendable (URL) -> Int64?

    public enum Error: Swift.Error, Equatable, Sendable {
        case insufficientStorage(requiredBytes: Int64)
        case cacheLimitExceeded(limitBytes: Int64)
    }

    public let lifecycle: ArchiveCacheLifecycle
    private let capacityProvider: CapacityProvider

    public init(
        cacheRootURL: URL,
        capacityProvider: CapacityProvider? = nil
    ) {
        self.lifecycle = ArchiveCacheLifecycle(cacheRootURL: cacheRootURL)
        self.capacityProvider = capacityProvider ?? { url in
            Self.systemAvailableCapacityNear(url)
        }
    }

    public var cacheRootURL: URL { lifecycle.cacheRootURL }

    /// Reports disk usage for the whole archive-cache directory. The usage is
    /// independent of the active policy so turning caching off does not make
    /// already-retained durable entries disappear from the readout.
    public func cacheUsage() -> ArchiveCacheUsage {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: cacheRootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else {
            return ArchiveCacheUsage(fileCount: 0, byteCount: 0)
        }

        var fileCount = 0
        var byteCount: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            ), values.isRegularFile == true else { continue }
            fileCount += 1
            byteCount += Int64(values.fileSize ?? 0)
        }
        return ArchiveCacheUsage(fileCount: fileCount, byteCount: byteCount)
    }

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
        capacityProvider(url)
    }

    private static func systemAvailableCapacityNear(_ url: URL) -> Int64? {
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
        let available = availableCapacityNear(root) ?? 0
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
