import Foundation
import PlaylistTabsPersistenceCore

/// Owns the SB2 storage location while FrontendCore validates and writes the
/// shared playlist-tab snapshot envelope.
final class PlaylistTabsStore: @unchecked Sendable {
    static let shared = PlaylistTabsStore()

    private let store: PlaylistTabsJSONFileStore

    private init() {
        let fileURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SB2", isDirectory: true)
            .appendingPathComponent("playlist-tabs-v1.json")
        store = PlaylistTabsJSONFileStore(fileURL: fileURL)
    }

    func load() throws -> Any {
        guard let data = try store.load() else { return NSNull() }
        return try JSONSerialization.jsonObject(with: data)
    }

    func save(_ value: Any) throws -> Bool {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try store.save(data)
        return true
    }
}
