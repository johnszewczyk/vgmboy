import Foundation

/// Renderer-neutral playlist-tab ordering and selection state.
///
/// The state deliberately contains identifiers only. Each frontend owns its
/// tab payload, persistence location, and rendering, while this value keeps
/// activation, close fallback, insertion, restore, and reorder policy aligned.
public struct PlaylistTabOrderState: Codable, Equatable, Sendable {
    public let orderedIDs: [String]
    public let activeID: String?

    public init(orderedIDs: [String], activeID: String?) {
        let normalizedIDs = Array(Self.uniqueIdentifiers(orderedIDs).prefix(64))
        self.orderedIDs = normalizedIDs
        self.activeID = activeID.flatMap { normalizedIDs.contains($0) ? $0 : nil }
            ?? normalizedIDs.first
    }

    fileprivate static func uniqueIdentifiers(_ identifiers: [String]) -> [String] {
        var seen = Set<String>()
        return identifiers.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

/// Codable action sent by WebKit frontends to the shared native reducer.
public struct PlaylistTabOrderAction: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case activate
        case insert
        case close
        case move
        case restore
    }

    public let kind: Kind
    public let id: String?
    public let index: Int?
    public let activate: Bool?
    public let orderedIDs: [String]?
    public let activeID: String?

    public init(
        kind: Kind,
        id: String? = nil,
        index: Int? = nil,
        activate: Bool? = nil,
        orderedIDs: [String]? = nil,
        activeID: String? = nil
    ) {
        self.kind = kind
        self.id = id
        self.index = index
        self.activate = activate
        self.orderedIDs = orderedIDs
        self.activeID = activeID
    }
}

public struct PlaylistTabOrderTransitionRequest: Codable, Equatable, Sendable {
    public let state: PlaylistTabOrderState
    public let action: PlaylistTabOrderAction

    public init(state: PlaylistTabOrderState, action: PlaylistTabOrderAction) {
        self.state = state
        self.action = action
    }
}

public enum PlaylistTabOrderReducer {
    public static func reduce(
        state: PlaylistTabOrderState,
        action: PlaylistTabOrderAction
    ) -> PlaylistTabOrderState {
        var ids = state.orderedIDs
        var activeID = state.activeID

        switch action.kind {
        case .activate:
            if let id = action.id, ids.contains(id) {
                activeID = id
            }
        case .insert:
            guard let id = action.id, !id.isEmpty, !ids.contains(id), ids.count < 64 else {
                return state
            }
            let index = min(max(action.index ?? ids.count, 0), ids.count)
            ids.insert(id, at: index)
            if action.activate == true || activeID == nil {
                activeID = id
            }
        case .close:
            guard let id = action.id, let index = ids.firstIndex(of: id) else {
                return state
            }
            ids.remove(at: index)
            if activeID == id {
                activeID = ids.isEmpty ? nil : ids[min(index, ids.count - 1)]
            }
        case .move:
            guard let id = action.id,
                  let sourceIndex = ids.firstIndex(of: id),
                  !ids.isEmpty else {
                return state
            }
            let destinationIndex = min(max(action.index ?? sourceIndex, 0), ids.count - 1)
            if sourceIndex != destinationIndex {
                ids.remove(at: sourceIndex)
                ids.insert(id, at: destinationIndex)
            }
        case .restore:
            ids = Array(PlaylistTabOrderState.uniqueIdentifiers(action.orderedIDs ?? []).prefix(64))
            activeID = action.activeID.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
        }

        return PlaylistTabOrderState(orderedIDs: ids, activeID: activeID)
    }
}

/// Shared JSON-file persistence for WebKit playlist-tab snapshots.
///
/// The frontend still owns its payload fields and Application Support path;
/// this type owns the common version-1 envelope checks and bounded atomic I/O.
public final class PlaylistTabsJSONFileStore: @unchecked Sendable {
    public enum StoreError: Error, Equatable {
        case invalidData
    }

    private let lock = NSLock()
    private let fileURL: URL
    private let maximumFileSize: Int
    private let maximumTabCount: Int
    private let maximumTitleUTF8Bytes: Int

    public init(
        fileURL: URL,
        maximumFileSize: Int = 256 * 1_024 * 1_024,
        maximumTabCount: Int = 64,
        maximumTitleUTF8Bytes: Int = 2_000
    ) {
        precondition(maximumFileSize > 0)
        precondition(maximumTabCount > 0)
        precondition(maximumTitleUTF8Bytes > 0)
        self.fileURL = fileURL
        self.maximumFileSize = maximumFileSize
        self.maximumTabCount = maximumTabCount
        self.maximumTitleUTF8Bytes = maximumTitleUTF8Bytes
    }

    /// Returns `nil` when no snapshot has been saved.
    public func load() throws -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue <= maximumFileSize else {
            throw StoreError.invalidData
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        try validate(data)
        return data
    }

    public func save(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        guard data.count <= maximumFileSize else { throw StoreError.invalidData }
        try validate(data)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    private func validate(_ data: Data) throws {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              payload["version"] as? Int == 1,
              let tabs = payload["tabs"] as? [[String: Any]],
              !tabs.isEmpty,
              tabs.count <= maximumTabCount,
              let activeID = payload["activeID"] as? String else {
            throw StoreError.invalidData
        }

        var identifiers = Set<String>()
        for tab in tabs {
            guard let identifier = tab["id"] as? String,
                  !identifier.isEmpty,
                  identifiers.insert(identifier).inserted,
                  let title = tab["title"] as? String,
                  title.utf8.count <= maximumTitleUTF8Bytes,
                  let playlist = tab["playlist"] as? [[String: Any]],
                  playlist.allSatisfy({ JSONSerialization.isValidJSONObject($0) }) else {
                throw StoreError.invalidData
            }
        }
        guard identifiers.contains(activeID) else { throw StoreError.invalidData }
    }
}
