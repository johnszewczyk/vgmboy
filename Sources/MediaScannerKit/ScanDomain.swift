import Foundation

public struct ScannerMetadata: Codable, Equatable, Sendable {
    public let game: String
    public let song: String
    public let system: String
    public let author: String
    public let comment: String
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let fadeLengthMs: Int

    public init(
        game: String,
        song: String,
        system: String,
        author: String,
        comment: String,
        introLengthMs: Int,
        loopLengthMs: Int,
        playLengthMs: Int,
        fadeLengthMs: Int
    ) {
        self.game = game
        self.song = song
        self.system = system
        self.author = author
        self.comment = comment
        self.introLengthMs = introLengthMs
        self.loopLengthMs = loopLengthMs
        self.playLengthMs = playLengthMs
        self.fadeLengthMs = fadeLengthMs
    }
}

public struct ScanCandidate: Hashable, Sendable {
    public let identity: ScanItemIdentity
    public let fingerprint: ScanFingerprint
    public let sourceURL: URL
    public let route: ScannerRoute?

    public init(
        identity: ScanItemIdentity,
        fingerprint: ScanFingerprint,
        sourceURL: URL,
        route: ScannerRoute?
    ) {
        self.identity = identity
        self.fingerprint = fingerprint
        self.sourceURL = sourceURL
        self.route = route
    }

    public var isArchiveMember: Bool { identity.archiveEntry != nil }

    public var identityDescription: String {
        identity.archiveEntry.map { "\(identity.path)#\($0)" } ?? identity.path
    }
}

public struct ScanArchiveMember: Hashable, Sendable {
    public let archiveURL: URL
    public let entryPath: String
    public let fingerprint: ScanFingerprint
    public let route: ScannerRoute?

    public init(
        archiveURL: URL,
        entryPath: String,
        fingerprint: ScanFingerprint,
        route: ScannerRoute?
    ) {
        self.archiveURL = archiveURL
        self.entryPath = entryPath
        self.fingerprint = fingerprint
        self.route = route
    }

    public var identityDescription: String { "\(archiveURL.path)#\(entryPath)" }
}

public struct ScanArchiveListing: Sendable {
    public let members: [ScanArchiveMember]
    public let scanSignature: String?

    public init(members: [ScanArchiveMember], scanSignature: String?) {
        self.members = members
        self.scanSignature = scanSignature
    }
}

public struct ScanTrackMetadata: Sendable {
    public let trackIndex: Int
    public let trackCount: Int
    public let metadata: ScannerMetadata?

    public init(trackIndex: Int, trackCount: Int, metadata: ScannerMetadata?) {
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.metadata = metadata
    }
}

public struct ScanInspection: Sendable {
    public let route: ScannerRoute
    public let tracks: [ScanTrackMetadata]

    public init(route: ScannerRoute, tracks: [ScanTrackMetadata]) {
        self.route = route
        self.tracks = tracks
    }
}

public enum ScanFailureStage: String, Codable, Sendable {
    case discovery
    case archiveListing
    case archiveExtraction
    case routing
    case metadata
    case persistence
}

public struct ScanFailure: Sendable {
    public let identity: ScanItemIdentity
    public let fingerprint: ScanFingerprint
    public let route: ScannerRoute?
    public let stage: ScanFailureStage
    public let message: String

    public init(
        identity: ScanItemIdentity,
        fingerprint: ScanFingerprint,
        route: ScannerRoute?,
        stage: ScanFailureStage,
        message: String
    ) {
        self.identity = identity
        self.fingerprint = fingerprint
        self.route = route
        self.stage = stage
        self.message = message
    }
}

public enum ScanPipelineResult: Sendable {
    case success(ScanCandidate, ScanInspection)
    case archiveCompleted(ScanCandidate)
    case unsupported(ScanCandidate)
    case failure(ScanFailure)

    public func persistenceFailure(message: String) -> ScanPipelineResult {
        let failure: ScanFailure
        switch self {
        case .success(let candidate, _), .unsupported(let candidate), .archiveCompleted(let candidate):
            failure = ScanFailure(
                identity: candidate.identity,
                fingerprint: candidate.fingerprint,
                route: candidate.route,
                stage: .persistence,
                message: message
            )
        case .failure(let existing):
            failure = ScanFailure(
                identity: existing.identity,
                fingerprint: existing.fingerprint,
                route: existing.route,
                stage: .persistence,
                message: message
            )
        }
        return .failure(failure)
    }
}

public struct ScanPlan: Sendable {
    public let mode: ScanMode
    public let candidates: [ScanCandidate]

    public init(mode: ScanMode, candidates: [ScanCandidate]) {
        self.mode = mode
        self.candidates = candidates
    }

    public var count: Int { candidates.count }
}

public enum ScanPlanner {
    public static func makePlan(
        mode: ScanMode,
        items: [ScanInventoryItem],
        sourceURLs: [ScanItemIdentity: URL],
        currentFingerprints: [ScanItemIdentity: ScanFingerprint]
    ) -> ScanPlan {
        let candidates = items.compactMap { item -> ScanCandidate? in
            guard let sourceURL = sourceURLs[item.identity] else { return nil }
            let fingerprint = currentFingerprints[item.identity] ?? item.fingerprint
            guard ScanSelection.includes(item, mode: mode, currentFingerprint: fingerprint) else { return nil }
            return ScanCandidate(
                identity: item.identity,
                fingerprint: fingerprint,
                sourceURL: sourceURL,
                route: item.route
            )
        }
        return ScanPlan(mode: mode, candidates: candidates.sorted {
            if $0.identity.path != $1.identity.path {
                return $0.identity.path.localizedStandardCompare($1.identity.path) == .orderedAscending
            }
            return ($0.identity.archiveEntry ?? "") < ($1.identity.archiveEntry ?? "")
        })
    }
}

public protocol ScanArchiveProvider: Sendable {
    func listMembers(in archiveURL: URL, supportedExtensions: Set<String>) async throws -> ScanArchiveListing
    func materialize(archiveURL: URL, entryPath: String) async throws -> URL
    func materializeEntries(archiveURL: URL, entryPaths: [String]) async throws -> URL
    func materializeArchive(at archiveURL: URL) async throws -> URL
    func materializeEntriesForScan(archiveURL: URL, entryPaths: [String]) async throws -> URL
    func materializeArchiveForScan(at archiveURL: URL) async throws -> URL
    func discardScanMaterialization(at rootURL: URL) async
}

public extension ScanArchiveProvider {
    func materializeEntriesForScan(archiveURL: URL, entryPaths: [String]) async throws -> URL {
        try await materializeEntries(archiveURL: archiveURL, entryPaths: entryPaths)
    }

    func materializeArchiveForScan(at archiveURL: URL) async throws -> URL {
        try await materializeArchive(at: archiveURL)
    }

    func discardScanMaterialization(at rootURL: URL) async {}
}

public protocol ScanFormatHandler: Sendable {
    var descriptor: ScannerPluginDescriptor { get }
    func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection
}

public struct ScanPluginHandlerRegistry: Sendable {
    private let handlers: [String: any ScanFormatHandler]

    public init(handlers: [any ScanFormatHandler]) {
        self.handlers = Dictionary(
            handlers.map { ($0.descriptor.pluginID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public func handler(for route: ScannerRoute) -> (any ScanFormatHandler)? {
        handlers[route.pluginID]
    }
}

public protocol ScanResultSink: Sendable {
    func accept(_ result: ScanPipelineResult) async throws
}

public enum ScanFilesystemDiscovery {
    public static func discover(
        rootID: Int64,
        rootURL: URL,
        registry: ScannerPluginRegistry,
        isArchive: @escaping @Sendable (URL) -> Bool
    ) async throws -> [ScanCandidate] {
        let task = Task.detached(priority: .utility) {
            var candidates: [ScanCandidate] = []
            try walk(
                rootID: rootID,
                folderURL: rootURL.standardizedFileURL,
                registry: registry,
                isArchive: isArchive,
                candidates: &candidates
            )
            try Task.checkCancellation()
            return candidates.sorted {
                $0.identity.path.localizedStandardCompare($1.identity.path) == .orderedAscending
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func walk(
        rootID: Int64,
        folderURL: URL,
        registry: ScannerPluginRegistry,
        isArchive: @Sendable (URL) -> Bool,
        candidates: inout [ScanCandidate]
    ) throws {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let child as URL in enumerator {
            try Task.checkCancellation()
            let values = try? child.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            let route = registry.route(for: child.pathExtension)
            guard isArchive(child) || route != nil else { continue }
            candidates.append(ScanCandidate(
                identity: ScanItemIdentity(rootID: rootID, path: child.path, archiveEntry: nil),
                fingerprint: ScanFingerprint(
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate ?? .distantPast
                ),
                sourceURL: child,
                route: route
            ))
        }
    }
}
