import Foundation

/// Persists the WebKit playlist tabs separately from preferences so playlist
/// contents do not inflate the small frontend-preferences record.
final class PlaylistTabsStore: @unchecked Sendable {
    static let shared = PlaylistTabsStore()

    private let lock = NSLock()
    private let maximumFileSize = 256 * 1024 * 1024
    private let maximumTabCount = 64

    private var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ViewBoy", isDirectory: true)
            .appendingPathComponent("playlist-tabs-v1.json")
    }

    func load() throws -> Any {
        lock.lock()
        defer { lock.unlock() }

        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return NSNull() }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= maximumFileSize else {
            throw StoreError.invalidData
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let value = try JSONSerialization.jsonObject(with: data)
        try validate(value)
        return value
    }

    func save(_ value: Any) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        try validate(value)
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard data.count <= maximumFileSize else { throw StoreError.invalidData }
        let url = fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        return true
    }

    private func validate(_ value: Any) throws {
        guard JSONSerialization.isValidJSONObject(value),
              let payload = value as? [String: Any],
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
                  title.utf8.count <= 2_000,
                  let playlist = tab["playlist"] as? [[String: Any]],
                  playlist.allSatisfy({ JSONSerialization.isValidJSONObject($0) }) else {
                throw StoreError.invalidData
            }
        }
        guard identifiers.contains(activeID) else { throw StoreError.invalidData }
    }

    private enum StoreError: Error {
        case invalidData
    }
}
