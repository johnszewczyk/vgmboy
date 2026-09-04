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
            try prepareMDXDependency(
                archiveURL: archiveURL,
                selectedEntry: normalizedEntry,
                memberURL: memberURL
            )

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

    /// MDX modules declare a companion PDX sample bank in their header. A
    /// catalog entry for a standalone `.MDX.zst` contains only that module,
    /// so selected-entry extraction must also stage the explicitly declared
    /// sibling beside it. The same rule applies to MDX members inside normal
    /// archives, where the dependency is another archive member.
    private func prepareMDXDependency(
        archiveURL: URL,
        selectedEntry: String,
        memberURL: URL
    ) throws {
        guard URL(fileURLWithPath: selectedEntry).pathExtension.lowercased() == "mdx" else {
            return
        }
        let data = try Data(contentsOf: memberURL)
        guard let dependencyName = mdxDependencyName(in: data) else { return }
        let dependencyEntry = try resolveMDXDependency(dependencyName, relativeTo: selectedEntry)
        let dependencyURL = memberURL.deletingLastPathComponent()
            .appendingPathComponent(dependencyEntry, isDirectory: false)
        if isNonEmptyFile(dependencyURL) { return }

        try FileManager.default.createDirectory(
            at: dependencyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let temporaryURL = dependencyURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).partial", isDirectory: false)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        if try archiveKind(for: archiveURL) == .singleFileZstandard {
            guard let sourceURL = mdxSiblingURL(named: dependencyName, beside: archiveURL) else {
                throw ArchiveMaterializationError.extractFailed(
                    "Required MDX dependency is missing: \(dependencyName)."
                )
            }
            if ArchiveContainerKind(archiveURL: sourceURL) == .singleFileZstandard {
                try ArchiveMaterializer.shared.execute(
                    ArchiveToolRouting.selectedEntryToStdout(
                        kind: .singleFileZstandard,
                        archiveURL: sourceURL,
                        entryPath: sourceURL.deletingPathExtension().lastPathComponent
                    ),
                    outputURL: temporaryURL
                )
            } else {
                try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
            }
        } else {
            try ArchiveMaterializer.shared.execute(
                ArchiveToolRouting.selectedEntryToStdout(
                    kind: try archiveKind(for: archiveURL),
                    archiveURL: archiveURL,
                    entryPath: dependencyEntry
                ),
                outputURL: temporaryURL
            )
        }

        guard isNonEmptyFile(temporaryURL) else {
            throw ArchiveMaterializationError.emptyOutput
        }
        if FileManager.default.fileExists(atPath: dependencyURL.path) {
            try FileManager.default.removeItem(at: dependencyURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: dependencyURL)
    }

    private func mdxDependencyName(in data: Data) -> String? {
        let marker = Data([0x0D, 0x0A, 0x1A])
        guard let markerRange = data.range(of: marker) else { return nil }
        let remainder = data[markerRange.upperBound...]
        guard let terminator = remainder.firstIndex(of: 0x00) else { return nil }
        let rawName = remainder[..<terminator]
        guard !rawName.isEmpty else { return nil }
        var name = String(data: Data(rawName), encoding: .shiftJIS)
            ?? String(data: Data(rawName), encoding: .utf8)
            ?? String(decoding: rawName, as: UTF8.self)
        while name.hasPrefix("\\") { name.removeFirst() }
        guard !name.isEmpty else { return nil }
        if URL(fileURLWithPath: name).pathExtension.isEmpty { name += ".pdx" }
        return name
    }

    private func resolveMDXDependency(_ dependency: String, relativeTo selectedEntry: String) throws -> String {
        guard !dependency.hasPrefix("/"), !dependency.contains("\\") else {
            throw ArchiveMaterializationError.invalidEntry
        }
        let base = URL(fileURLWithPath: "/\(selectedEntry)").deletingLastPathComponent()
        let resolved = base.appendingPathComponent(dependency).standardizedFileURL.path
        let relative = String(resolved.dropFirst())
        let normalized = ArchiveEntryPath.normalized(relative)
        guard !normalized.isEmpty, ArchiveEntryPath.isSafe(normalized) else {
            throw ArchiveMaterializationError.invalidEntry
        }
        return normalized
    }

    private func mdxSiblingURL(named name: String, beside archiveURL: URL) -> URL? {
        let requestedURL = archiveURL.deletingLastPathComponent().appendingPathComponent(name)
        if isRegularFile(requestedURL) { return requestedURL }
        let directory = requestedURL.deletingLastPathComponent()
        let requestedName = requestedURL.lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let names = [requestedName, "\(requestedName).zst", "\(requestedName).zstd"]
        return entries
            .filter(isRegularFile)
            .first { candidate in
                names.contains { candidate.lastPathComponent.caseInsensitiveCompare($0) == .orderedSame }
            }
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func isNonEmptyFile(_ url: URL) -> Bool {
        guard isRegularFile(url),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let byteCount = (attributes[.size] as? NSNumber)?.int64Value else {
            return false
        }
        return byteCount > 0
    }

    private func validatePlayableOutput(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard byteCount > 0 else { throw ArchiveMaterializationError.emptyOutput }
    }
}
