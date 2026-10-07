import Foundation

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
