import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// The identity supplied by a Games-sidebar activation. This is deliberately
/// a database boundary type, not an application or UI model.
public struct CatalogPlaylistGameSelection: Hashable, Sendable {
    public let rootID: Int64
    public let game: String
    public let system: String

    public init(rootID: Int64, game: String, system: String) {
        self.rootID = rootID
        self.game = game
        self.system = system
    }
}

/// The exact Games playlist projection used by CocoaSpice's
/// original reader. It intentionally contains no database row ID or fallback
/// fields: applications derive their own identity from the source tuple.
public struct CatalogPlaylistTrack: Equatable, Sendable {
    public let sourcePath: String
    public let archivePath: String?
    public let archiveEntry: String?
    public let trackIndex: Int
    public let trackCount: Int
    public let title: String
    public let game: String
    public let author: String
    public let dumper: String
    public let system: String
    public let comment: String
    public let introLengthMilliseconds: Int
    public let loopLengthMilliseconds: Int
    public let lengthMilliseconds: Int
    public let fadeLengthMilliseconds: Int

    public init(
        sourcePath: String,
        archivePath: String?,
        archiveEntry: String?,
        trackIndex: Int,
        trackCount: Int,
        title: String,
        game: String,
        author: String,
        system: String,
        comment: String,
        introLengthMilliseconds: Int,
        loopLengthMilliseconds: Int,
        lengthMilliseconds: Int,
        fadeLengthMilliseconds: Int,
        dumper: String = ""
    ) {
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.archiveEntry = archiveEntry
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.title = title
        self.game = game
        self.author = author
        self.dumper = dumper
        self.system = system
        self.comment = comment
        self.introLengthMilliseconds = introLengthMilliseconds
        self.loopLengthMilliseconds = loopLengthMilliseconds
        self.lengthMilliseconds = lengthMilliseconds
        self.fadeLengthMilliseconds = fadeLengthMilliseconds
    }
}

public enum CatalogPlaylistCoreError: LocalizedError {
    case sqlite(String)

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): return message
        }
    }
}

/// Read-only extraction of CocoaSpice's original Games playlist query.
///
/// Keep this query aligned with the source implementation. In particular,
/// the folder-first path uses the same projection as the sidebar: the folder
/// system when present, otherwise the scanned metadata system. A selected
/// sidebar row must therefore produce the same playlist rows as its bucket.
public enum CatalogPlaylistReader {
    public static func tracksForGames(
        databaseURL: URL,
        selections: [CatalogPlaylistGameSelection],
        preferFoldersOverMetadata: Bool = true
    ) throws -> [CatalogPlaylistTrack] {
        guard !selections.isEmpty else { return [] }

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the catalog."
            sqlite3_close(database)
            throw CatalogPlaylistCoreError.sqlite(message)
        }
        defer { sqlite3_close(database) }
        let hasDumperColumn = try tableHasColumn(database, table: "track_metadata", column: "dumper")
        let dumperExpression = hasDumperColumn ? "COALESCE(m.dumper, '')" : "''"

        enum BindValue {
            case integer(Int64)
            case text(String)
        }

        // Keep the folder-backed branch separate from the metadata-derived
        // branch. The equivalent OR predicate is logically correct, but it
        // prevents SQLite from using tracks_game_sidebar_index and turns a
        // one-game activation into a root-wide scan. Arcade buckets commonly
        // need the second branch because their stored folder system is blank.
        var bindValues: [BindValue] = []
        let branchProjection = """
        t.path AS source_path,
        t.archive_path AS archive_path,
        t.archive_entry AS archive_entry,
        t.track_index AS track_index,
        t.track_count AS track_count,
        COALESCE(m.title, '') AS title,
        COALESCE(m.game, '') AS game,
        COALESCE(m.author, '') AS author,
        \(dumperExpression) AS dumper,
        COALESCE(m.system, '') AS system,
        COALESCE(m.comment, '') AS comment,
        COALESCE(m.intro_length_ms, 0) AS intro_length_ms,
        COALESCE(m.loop_length_ms, 0) AS loop_length_ms,
        COALESCE(m.play_length_ms, 0) AS length_ms,
        COALESCE(m.fade_length_ms, 0) AS fade_length_ms,
        t.browser_game AS order_game,
        lower(COALESCE(m.title, '')) AS order_title,
        t.folder_path AS order_folder,
        t.filename AS order_filename,
        t.track_index AS order_index
        """

        func branch(systemPredicate: String, selection: CatalogPlaylistGameSelection, systemBind: String?) -> String {
            bindValues.append(.integer(selection.rootID))
            bindValues.append(.text(selection.game))
            if let systemBind {
                bindValues.append(.text(systemBind))
            }
            return """
            SELECT \(branchProjection)
            FROM tracks t
            INNER JOIN library_roots r ON r.id = t.root_id
            LEFT JOIN track_metadata m ON m.track_id = t.id
            WHERE r.is_enabled = 1
              AND NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id = t.root_id AND d.path = t.path)
              AND t.root_id = ?
              AND t.browser_game = ?
              AND \(systemPredicate)
            """
        }

        var branches: [String] = []
        for selection in selections {
            if selection.system.isEmpty {
                let predicate = preferFoldersOverMetadata
                    ? "t.browser_system = '' AND NULLIF(m.system, '') IS NULL"
                    : "NULLIF(m.system, '') IS NULL AND t.browser_system = ''"
                branches.append(branch(systemPredicate: predicate, selection: selection, systemBind: nil))
                continue
            }

            if preferFoldersOverMetadata {
                branches.append(branch(
                    systemPredicate: "t.browser_system = ?",
                    selection: selection,
                    systemBind: selection.system
                ))
                branches.append(branch(
                    systemPredicate: "t.browser_system = '' AND NULLIF(m.system, '') = ?",
                    selection: selection,
                    systemBind: selection.system
                ))
            } else {
                branches.append(branch(
                    systemPredicate: "NULLIF(m.system, '') = ?",
                    selection: selection,
                    systemBind: selection.system
                ))
                branches.append(branch(
                    systemPredicate: "NULLIF(m.system, '') IS NULL AND t.browser_system = ?",
                    selection: selection,
                    systemBind: selection.system
                ))
            }
        }

        let sql = """
        SELECT
            source_path,
            archive_path,
            archive_entry,
            track_index,
            track_count,
            title,
            game,
            author,
            dumper,
            system,
            comment,
            intro_length_ms,
            loop_length_ms,
            length_ms,
            fade_length_ms
        FROM (\(branches.joined(separator: " UNION ALL ")))
        ORDER BY order_game ASC, order_title ASC, order_folder ASC, order_filename ASC, order_index ASC;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var bindIndex: Int32 = 1
        for bindValue in bindValues {
            let result: Int32
            switch bindValue {
            case .integer(let value):
                result = sqlite3_bind_int64(statement, bindIndex, value)
            case .text(let value):
                result = sqlite3_bind_text(statement, bindIndex, value, -1, sqliteTransient)
            }
            guard result == SQLITE_OK else {
                throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
            }
            bindIndex += 1
        }

        var tracks: [CatalogPlaylistTrack] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            tracks.append(CatalogPlaylistTrack(
                sourcePath: text(statement, index: 0),
                archivePath: nullableText(statement, index: 1),
                archiveEntry: nullableText(statement, index: 2),
                trackIndex: Int(sqlite3_column_int(statement, 3)),
                trackCount: Int(sqlite3_column_int(statement, 4)),
                title: text(statement, index: 5),
                game: text(statement, index: 6),
                author: text(statement, index: 7),
                system: text(statement, index: 9),
                comment: text(statement, index: 10),
                introLengthMilliseconds: Int(sqlite3_column_int(statement, 11)),
                loopLengthMilliseconds: Int(sqlite3_column_int(statement, 12)),
                lengthMilliseconds: Int(sqlite3_column_int(statement, 13)),
                fadeLengthMilliseconds: Int(sqlite3_column_int(statement, 14)),
                dumper: text(statement, index: 8)
            ))
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return tracks
    }

    private static func text(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private static func nullableText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: value)
    }

    private static func tableHasColumn(_ database: OpaquePointer, table: String, column: String) throws -> Bool {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if text(statement, index: 1) == column { return true }
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return false
    }
}
