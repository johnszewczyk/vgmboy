import Foundation

/// Stable frontend identity for one playable song. It deliberately uses the
/// physical source plus archive member and track index, not a database row ID,
/// so favorites survive catalog republishing.
public struct FavoriteTrackIdentity: Codable, Equatable, Hashable, Sendable {
    public let sourcePath: String
    public let archiveEntry: String?
    public let trackIndex: Int
    public let trackCount: Int

    public init(sourcePath: String, archiveEntry: String? = nil, trackIndex: Int = 0, trackCount: Int = 1) {
        self.sourcePath = URL(fileURLWithPath: sourcePath).standardizedFileURL.path
        self.archiveEntry = archiveEntry?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? archiveEntry
            : nil
        self.trackIndex = max(0, trackIndex)
        self.trackCount = max(1, trackCount)
    }

    public var id: String {
        let entry = archiveEntry ?? ""
        return "fav1|\(sourcePath.utf16.count)|\(sourcePath)|\(entry.utf16.count)|\(entry)|\(trackIndex)"
    }
}

/// Keeps favorite history in insertion order. Toggling an individual song
/// removes or appends that song. Toggling a selected album removes the whole
/// album only when every song is already present; otherwise it adds missing
/// songs in the album's published order.
public struct FavoriteTrackCollection: Codable, Equatable, Sendable {
    public private(set) var entries: [FavoriteTrackIdentity]

    public init(entries: [FavoriteTrackIdentity] = []) {
        var seen = Set<String>()
        self.entries = entries.filter { seen.insert($0.id).inserted }
    }

    public func contains(_ identity: FavoriteTrackIdentity) -> Bool {
        entries.contains { $0.id == identity.id }
    }

    @discardableResult
    public mutating func toggle(_ identity: FavoriteTrackIdentity) -> Bool {
        if let index = entries.firstIndex(where: { $0.id == identity.id }) {
            entries.remove(at: index)
            return false
        }
        entries.append(identity)
        return true
    }

    @discardableResult
    public mutating func toggleGroup(_ identities: [FavoriteTrackIdentity]) -> Bool {
        var unique: [FavoriteTrackIdentity] = []
        var seen = Set<String>()
        for identity in identities where seen.insert(identity.id).inserted {
            unique.append(identity)
        }
        guard !unique.isEmpty else { return false }

        if unique.allSatisfy(contains) {
            let ids = Set(unique.map(\.id))
            entries.removeAll { ids.contains($0.id) }
            return false
        }

        let existing = Set(entries.map(\.id))
        entries.append(contentsOf: unique.filter { !existing.contains($0.id) })
        return true
    }
}
