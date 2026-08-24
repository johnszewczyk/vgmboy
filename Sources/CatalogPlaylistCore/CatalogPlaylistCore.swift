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

/// The exact fourteen-column Games playlist projection used by CocoaSpice's
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
        fadeLengthMilliseconds: Int
    ) {
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
/// the folder-first path is an exact `t.browser_system = ?` predicate so the
/// published browser-bucket index remains usable. There is intentionally no
/// fallback predicate here.
public enum CatalogPlaylistReader {
    public static func tracksForGames(
        databaseURL: URL,
        selections: [CatalogPlaylistGameSelection],
        preferFoldersOverMetadata: Bool = true
    ) throws -> [CatalogPlaylistTrack] {
        guard !selections.isEmpty else { return [] }

        let systemPredicate = preferFoldersOverMetadata
            ? "t.browser_system = ?"
            : "COALESCE(NULLIF(m.system, ''), NULLIF(t.browser_system, ''), '') = ?"
        let bucketPredicate = Array(
            repeating: "(t.root_id = ? AND t.browser_game = ? AND \(systemPredicate))",
            count: selections.count
        ).joined(separator: " OR ")
        let sql = """
        SELECT
            t.path,
            t.archive_path,
            t.archive_entry,
            t.track_index,
            t.track_count,
            COALESCE(m.title, ''),
            COALESCE(m.game, ''),
            COALESCE(m.author, ''),
            COALESCE(m.system, ''),
            COALESCE(m.comment, ''),
            COALESCE(m.intro_length_ms, 0),
            COALESCE(m.loop_length_ms, 0),
            COALESCE(m.play_length_ms, 0),
            COALESCE(m.fade_length_ms, 0)
        FROM tracks t
        INNER JOIN library_roots r ON r.id = t.root_id
        LEFT JOIN track_metadata m ON m.track_id = t.id
        WHERE r.is_enabled = 1
          AND NOT EXISTS (SELECT 1 FROM dead_sources d WHERE d.root_id = t.root_id AND d.path = t.path)
          AND (\(bucketPredicate))
        ORDER BY t.browser_game ASC, lower(COALESCE(m.title, '')) ASC, t.folder_path ASC, t.filename ASC, t.track_index ASC;
        """

        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the catalog."
            sqlite3_close(database)
            throw CatalogPlaylistCoreError.sqlite(message)
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        for (index, selection) in selections.enumerated() {
            let baseIndex = Int32(index * 3)
            guard sqlite3_bind_int64(statement, baseIndex + 1, selection.rootID) == SQLITE_OK,
                  sqlite3_bind_text(statement, baseIndex + 2, selection.game, -1, sqliteTransient) == SQLITE_OK,
                  sqlite3_bind_text(statement, baseIndex + 3, selection.system, -1, sqliteTransient) == SQLITE_OK else {
                throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
            }
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
                system: text(statement, index: 8),
                comment: text(statement, index: 9),
                introLengthMilliseconds: Int(sqlite3_column_int(statement, 10)),
                loopLengthMilliseconds: Int(sqlite3_column_int(statement, 11)),
                lengthMilliseconds: Int(sqlite3_column_int(statement, 12)),
                fadeLengthMilliseconds: Int(sqlite3_column_int(statement, 13))
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
}
