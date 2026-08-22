import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Schema-only, query-only access to a catalog published by MediaScanner.
/// This package contains no scanner, writer, decoder, or application target.
public struct CatalogSummary: Codable, Equatable, Sendable {
    public let path: String
    public let schemaVersion: Int
    public let trackCount: Int

    public init(path: String, schemaVersion: Int, trackCount: Int) {
        self.path = path
        self.schemaVersion = schemaVersion
        self.trackCount = trackCount
    }
}

public struct CatalogRoot: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let path: String
    public let isEnabled: Bool
    public let trackCount: Int

    public init(id: Int64, path: String, isEnabled: Bool, trackCount: Int) {
        self.id = id
        self.path = path
        self.isEnabled = isEnabled
        self.trackCount = trackCount
    }
}

/// A compact, published Games-sidebar row. MediaScanner maintains this
/// projection; readers only consume it.
public struct CatalogGameBucket: Identifiable, Equatable, Sendable {
    public let rootID: Int64
    public let rootPath: String
    public let game: String
    public let system: String
    public let trackCount: Int

    public init(rootID: Int64, rootPath: String, game: String, system: String, trackCount: Int) {
        self.rootID = rootID
        self.rootPath = rootPath
        self.game = game
        self.system = system
        self.trackCount = trackCount
    }

    public var id: String { "\(rootID)\u{1F}\(game)\u{1F}\(system)" }
}

/// One published Files-sidebar source leaf. This is intentionally a source
/// projection, not one row per playable subtrack.
public struct CatalogFileBucket: Identifiable, Equatable, Sendable {
    public let rootID: Int64
    public let rootPath: String
    public let folderPath: String
    public let path: String
    public let isArchive: Bool
    public let trackCount: Int

    public init(rootID: Int64, rootPath: String, folderPath: String, path: String, isArchive: Bool, trackCount: Int) {
        self.rootID = rootID
        self.rootPath = rootPath
        self.folderPath = folderPath
        self.path = path
        self.isArchive = isArchive
        self.trackCount = trackCount
    }

    public var id: String { "\(rootID)\u{1F}\(path)" }
}

/// A published playlist leaf. It deliberately represents only catalog facts;
/// decoder inspection results and playback state belong to VGMBoyKit.
public struct CatalogTrack: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let rootID: Int64
    public let sourcePath: String
    /// The physical container when this row is an archive member. `sourcePath`
    /// is the catalogue identity and may not be the path CocoaSpice must open.
    public let archivePath: String?
    public let archiveEntry: String?
    public let trackIndex: Int
    public let trackCount: Int
    public let title: String
    public let game: String
    public let author: String
    public let system: String
    public let comment: String
    public let browserGame: String
    public let browserSystem: String
    public let introLengthMilliseconds: Int
    public let loopLengthMilliseconds: Int
    public let lengthMilliseconds: Int
    public let fadeLengthMilliseconds: Int

    public init(id: Int64, rootID: Int64, sourcePath: String, archivePath: String?, archiveEntry: String?, trackIndex: Int, trackCount: Int, title: String, game: String, author: String, system: String, comment: String, browserGame: String, browserSystem: String, introLengthMilliseconds: Int, loopLengthMilliseconds: Int, lengthMilliseconds: Int, fadeLengthMilliseconds: Int) {
        self.id = id
        self.rootID = rootID
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.archiveEntry = archiveEntry
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.title = title
        self.game = game
        self.author = author
        self.system = system
        self.comment = comment
        self.browserGame = browserGame
        self.browserSystem = browserSystem
        self.introLengthMilliseconds = introLengthMilliseconds
        self.loopLengthMilliseconds = loopLengthMilliseconds
        self.lengthMilliseconds = lengthMilliseconds
        self.fadeLengthMilliseconds = fadeLengthMilliseconds
    }
}

public enum CatalogReaderError: LocalizedError {
    case sqlite(String)
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): return message
        case .unsupportedSchema(let version): return "Unsupported catalog schema \(version)."
        }
    }
}

public final class ReadOnlyCatalog: @unchecked Sendable {
    public static let supportedSchemaVersion = 23
    private let database: OpaquePointer
    public let databaseURL: URL

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL.standardizedFileURL
        var handle: OpaquePointer?
        guard sqlite3_open_v2(
            self.databaseURL.path,
            &handle,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the catalog."
            sqlite3_close(handle)
            throw CatalogReaderError.sqlite(message)
        }
        var established = false
        defer {
            if !established { sqlite3_close(handle) }
        }
        database = handle
        sqlite3_busy_timeout(handle, 10_000)
        let schema = try scalarInt("PRAGMA user_version;")
        guard schema == Self.supportedSchemaVersion else {
            throw CatalogReaderError.unsupportedSchema(schema)
        }
        established = true
    }

    deinit { sqlite3_close(database) }

    public func summary() throws -> CatalogSummary {
        CatalogSummary(
            path: databaseURL.path,
            schemaVersion: try scalarInt("PRAGMA user_version;"),
            trackCount: try scalarInt("SELECT COUNT(*) FROM tracks;")
        )
    }

    /// Counts only the rows a player is permitted to present. This is distinct
    /// from `summary()` because detached roots and retained dead sources remain
    /// durable catalog history.
    public func activeTrackCount() throws -> Int {
        try scalarInt(
            """
            SELECT COUNT(*) FROM tracks t
            INNER JOIN library_roots r ON r.id=t.root_id
            WHERE r.is_attached=1 AND r.is_enabled=1
              AND NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id=t.root_id AND d.path=COALESCE(t.archive_path, t.path));
            """
        )
    }

    public func deadSourceCount() throws -> Int {
        try scalarInt("SELECT COUNT(*) FROM dead_sources;")
    }

    public func deadTrackCount() throws -> Int {
        try scalarInt(
            """
            SELECT COUNT(*) FROM tracks t
            WHERE EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id=t.root_id AND d.path=COALESCE(t.archive_path, t.path));
            """
        )
    }

    public func roots() throws -> [CatalogRoot] {
        try query(
            "SELECT id, path, is_enabled, last_scan_track_count FROM library_roots WHERE is_attached=1 ORDER BY lower(path), path;"
        ) { statement in
            CatalogRoot(
                id: sqlite3_column_int64(statement, 0),
                path: Self.string(statement, 1),
                isEnabled: sqlite3_column_int(statement, 2) != 0,
                trackCount: Int(sqlite3_column_int64(statement, 3))
            )
        }.sorted { Self.naturalCompare($0.path, $1.path) == .orderedAscending }
    }

    public func gameBuckets() throws -> [CatalogGameBucket] {
        try query(
            """
            SELECT b.root_id, r.path, b.browser_game, b.browser_system, b.track_count
            FROM game_sidebar_buckets b
            INNER JOIN library_roots r ON r.id=b.root_id
            WHERE r.is_attached=1 AND r.is_enabled=1
            ORDER BY lower(b.browser_game), b.browser_game, lower(b.browser_system), b.browser_system, lower(r.path), r.path;
            """
        ) { statement in
            CatalogGameBucket(
                rootID: sqlite3_column_int64(statement, 0),
                rootPath: Self.string(statement, 1),
                game: Self.string(statement, 2),
                system: Self.string(statement, 3),
                trackCount: Int(sqlite3_column_int64(statement, 4))
            )
        }.sorted {
            Self.naturalCompare($0.game, $1.game) == .orderedAscending
                || (Self.naturalCompare($0.game, $1.game) == .orderedSame && Self.naturalCompare($0.system, $1.system) == .orderedAscending)
                || (Self.naturalCompare($0.game, $1.game) == .orderedSame && Self.naturalCompare($0.system, $1.system) == .orderedSame && Self.naturalCompare($0.rootPath, $1.rootPath) == .orderedAscending)
        }
    }

    public func fileBuckets() throws -> [CatalogFileBucket] {
        try query(
            """
            SELECT b.root_id, r.path, b.folder_path, b.path, b.is_archive, b.track_count
            FROM file_sidebar_buckets b
            INNER JOIN library_roots r ON r.id=b.root_id
            WHERE r.is_attached=1 AND r.is_enabled=1
            ORDER BY lower(b.path), b.path;
            """
        ) { statement in
            CatalogFileBucket(
                rootID: sqlite3_column_int64(statement, 0),
                rootPath: Self.string(statement, 1),
                folderPath: Self.string(statement, 2),
                path: Self.string(statement, 3),
                isArchive: sqlite3_column_int(statement, 4) != 0,
                trackCount: Int(sqlite3_column_int64(statement, 5))
            )
        }.sorted {
            Self.naturalCompare($0.rootPath, $1.rootPath) == .orderedAscending
                || (Self.naturalCompare($0.rootPath, $1.rootPath) == .orderedSame && Self.naturalCompare($0.folderPath, $1.folderPath) == .orderedAscending)
                || (Self.naturalCompare($0.rootPath, $1.rootPath) == .orderedSame && Self.naturalCompare($0.folderPath, $1.folderPath) == .orderedSame && Self.naturalCompare($0.path, $1.path) == .orderedAscending)
        }
    }

    public func tracks(rootID: Int64? = nil) throws -> [CatalogTrack] {
        let filters = [
            "r.is_attached=1",
            "r.is_enabled=1",
            "NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id=t.root_id AND d.path=t.path)",
            rootID == nil ? nil : "t.root_id=?"
        ].compactMap { $0 }.joined(separator: " AND ")
        var statement: OpaquePointer?
        let sql = """
        SELECT t.id, t.root_id, t.path, NULLIF(t.archive_path, ''), NULLIF(t.archive_entry, ''), t.track_index, t.track_count,
               COALESCE(m.title, ''), COALESCE(m.game, ''), COALESCE(m.author, ''),
               COALESCE(m.system, ''), COALESCE(m.comment, ''),
               COALESCE(t.browser_game, ''), COALESCE(t.browser_system, ''),
               COALESCE(m.intro_length_ms, 0), COALESCE(m.loop_length_ms, 0),
               COALESCE(m.play_length_ms, 0), COALESCE(m.fade_length_ms, 0)
        FROM tracks t
        INNER JOIN library_roots r ON r.id=t.root_id
        LEFT JOIN track_metadata m ON m.track_id=t.id
        WHERE \(filters)
        ORDER BY lower(t.path), t.path, t.archive_entry, t.track_index;
        """
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        if let rootID, sqlite3_bind_int64(statement, 1, rootID) != SQLITE_OK {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        var records: [CatalogTrack] = []
        while sqlite3_step(statement) == SQLITE_ROW { records.append(Self.track(statement)) }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return records.sorted(by: Self.trackComesBefore)
    }

    /// Fetch one visible sidebar group directly. This avoids rebuilding the
    /// whole catalogue merely to activate a selected game.
    public func tracks(rootID: Int64, game: String, system: String, preferFoldersOverMetadata: Bool) throws -> [CatalogTrack] {
        _ = preferFoldersOverMetadata // Buckets are published in the active browser preference.
        let sql = """
        SELECT t.id, t.root_id, t.path, NULLIF(t.archive_path, ''), NULLIF(t.archive_entry, ''), t.track_index, t.track_count,
               COALESCE(m.title, ''), COALESCE(m.game, ''), COALESCE(m.author, ''),
               COALESCE(m.system, ''), COALESCE(m.comment, ''),
               COALESCE(t.browser_game, ''), COALESCE(t.browser_system, ''),
               COALESCE(m.intro_length_ms, 0), COALESCE(m.loop_length_ms, 0),
               COALESCE(m.play_length_ms, 0), COALESCE(m.fade_length_ms, 0)
        FROM tracks t INDEXED BY tracks_browser_bucket_index
        INNER JOIN library_roots r ON r.id=t.root_id
        LEFT JOIN track_metadata m ON m.track_id=t.id
        WHERE r.is_attached=1 AND r.is_enabled=1
          AND NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id=t.root_id AND d.path=t.path)
          AND t.root_id=?
          AND t.browser_game=?
          AND t.browser_system=?
        ORDER BY lower(t.path), t.path, t.archive_entry, t.track_index;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_int64(statement, 1, rootID) == SQLITE_OK,
              sqlite3_bind_text(statement, 2, game, -1, SQLITE_TRANSIENT) == SQLITE_OK,
              sqlite3_bind_text(statement, 3, system, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        var records: [CatalogTrack] = []
        while sqlite3_step(statement) == SQLITE_ROW { records.append(Self.track(statement)) }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return records.sorted(by: Self.trackComesBefore)
    }

    /// Fetches exact visible source leaves without materializing an entire
    /// root. Electron uses this through the bridge for Files-view activation.
    public func tracks(rootID: Int64, sourcePaths: [String]) throws -> [CatalogTrack] {
        let paths = Array(Set(sourcePaths.filter { !$0.isEmpty })).sorted()
        guard !paths.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: paths.count).joined(separator: ", ")
        return try filteredTracks(
            whereClause: "t.root_id=? AND t.path IN (\(placeholders))",
            bindings: [.int(rootID)] + paths.map(QueryBinding.text)
        )
    }

    /// Fetches the exact folder projection selected by a player, including its
    /// descendants, through source indexes rather than a full-root traversal.
    public func tracks(rootID: Int64, folderPaths: [String]) throws -> [CatalogTrack] {
        let folders = Array(Set(folderPaths.map { $0.replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression) }.filter { !$0.isEmpty })).sorted()
        guard !folders.isEmpty else { return [] }
        let clauses = Array(repeating: "(t.folder_path=? OR t.folder_path LIKE ?)", count: folders.count).joined(separator: " OR ")
        var bindings: [QueryBinding] = [.int(rootID)]
        for folder in folders {
            bindings.append(.text(folder))
            bindings.append(.text("\(folder)/%"))
        }
        return try filteredTracks(
            whereClause: "t.root_id=? AND (\(clauses))",
            bindings: bindings
        )
    }

    private enum QueryBinding {
        case int(Int64)
        case text(String)
    }

    private func filteredTracks(whereClause: String, bindings: [QueryBinding]) throws -> [CatalogTrack] {
        let sql = """
        SELECT t.id, t.root_id, t.path, NULLIF(t.archive_path, ''), NULLIF(t.archive_entry, ''), t.track_index, t.track_count,
               COALESCE(m.title, ''), COALESCE(m.game, ''), COALESCE(m.author, ''),
               COALESCE(m.system, ''), COALESCE(m.comment, ''),
               COALESCE(t.browser_game, ''), COALESCE(t.browser_system, ''),
               COALESCE(m.intro_length_ms, 0), COALESCE(m.loop_length_ms, 0),
               COALESCE(m.play_length_ms, 0), COALESCE(m.fade_length_ms, 0)
        FROM tracks t
        INNER JOIN library_roots r ON r.id=t.root_id
        LEFT JOIN track_metadata m ON m.track_id=t.id
        WHERE r.is_attached=1 AND r.is_enabled=1
          AND NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id=t.root_id AND d.path=COALESCE(t.archive_path, t.path))
          AND \(whereClause)
        ORDER BY lower(t.folder_path), t.folder_path, lower(t.filename), t.filename, t.archive_entry, t.track_index;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch binding {
            case .int(let value): status = sqlite3_bind_int64(statement, index, value)
            case .text(let value): status = sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
            }
            guard status == SQLITE_OK else {
                throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
            }
        }
        var records: [CatalogTrack] = []
        while sqlite3_step(statement) == SQLITE_ROW { records.append(Self.track(statement)) }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return records.sorted(by: Self.trackComesBefore)
    }

    private func scalarInt(_ sql: String) throws -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func query<T>(_ sql: String, map: (OpaquePointer) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        var values: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW { values.append(try map(statement)) }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogReaderError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return values
    }

    private static func string(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private static func nullableString(_ statement: OpaquePointer, _ index: Int32) -> String? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : string(statement, index)
    }

    private static func naturalCompare(_ left: String, _ right: String) -> ComparisonResult {
        left.compare(right, options: [.caseInsensitive, .numeric], range: nil, locale: .current)
    }

    private static func trackComesBefore(_ left: CatalogTrack, _ right: CatalogTrack) -> Bool {
        naturalCompare(left.sourcePath, right.sourcePath) == .orderedAscending
            || (naturalCompare(left.sourcePath, right.sourcePath) == .orderedSame && naturalCompare(left.archiveEntry ?? "", right.archiveEntry ?? "") == .orderedAscending)
            || (naturalCompare(left.sourcePath, right.sourcePath) == .orderedSame && naturalCompare(left.archiveEntry ?? "", right.archiveEntry ?? "") == .orderedSame && left.trackIndex < right.trackIndex)
    }

    private static func track(_ statement: OpaquePointer) -> CatalogTrack {
        CatalogTrack(
            id: sqlite3_column_int64(statement, 0), rootID: sqlite3_column_int64(statement, 1),
            sourcePath: string(statement, 2), archivePath: nullableString(statement, 3), archiveEntry: nullableString(statement, 4),
            trackIndex: Int(sqlite3_column_int64(statement, 5)), trackCount: Int(sqlite3_column_int64(statement, 6)),
            title: string(statement, 7), game: string(statement, 8), author: string(statement, 9),
            system: string(statement, 10), comment: string(statement, 11),
            browserGame: string(statement, 12), browserSystem: string(statement, 13),
            introLengthMilliseconds: Int(sqlite3_column_int64(statement, 14)), loopLengthMilliseconds: Int(sqlite3_column_int64(statement, 15)),
            lengthMilliseconds: Int(sqlite3_column_int64(statement, 16)), fadeLengthMilliseconds: Int(sqlite3_column_int64(statement, 17))
        )
    }
}
