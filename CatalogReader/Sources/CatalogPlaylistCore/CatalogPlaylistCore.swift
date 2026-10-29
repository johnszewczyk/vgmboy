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
    public let trackNumber: Int?
    /// The source-reported year value, retained in its original form until
    /// the shared presentation layer normalizes it for display and sorting.
    public let year: String
    /// The source-reported dumper/encoder credit retained from its tag.
    public let dumper: String
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
        trackNumber: Int? = nil,
        year: String = "",
        dumper: String = "",
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
        self.trackNumber = trackNumber
        self.year = year
        self.dumper = dumper
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

/// Shared YEAR tag lookup and normalization for catalog playlist projections.
/// YEAR is preferred to date-like tags; a valid four-digit prefix is displayed
/// consistently even when the source stores a full date.
public enum CatalogPlaylistYear {
    public static func sqlExpression(metadataTagsAvailable: Bool) -> String {
        guard metadataTagsAvailable else { return "''" }
        return """
        COALESCE((
            SELECT tags.value
            FROM track_metadata_tags tags
            WHERE tags.track_id=t.id
              AND tags.normalized_name IN (
                  'YEAR', 'COPYRIGHT YEAR', 'COPYRIGHT_YEAR', 'COPYRIGHTYEAR',
                  'RELEASE YEAR', 'RELEASE_YEAR', 'RELEASEYEAR', 'DATE',
                  'RELEASE DATE', 'RELEASE_DATE', 'NSF M3U YEAR'
              )
              AND substr(trim(tags.value), 1, 4) GLOB '[0-9][0-9][0-9][0-9]'
            ORDER BY CASE tags.normalized_name
                WHEN 'YEAR' THEN 0
                WHEN 'COPYRIGHT YEAR' THEN 1
                WHEN 'COPYRIGHT_YEAR' THEN 1
                WHEN 'COPYRIGHTYEAR' THEN 1
                WHEN 'DATE' THEN 2
                WHEN 'RELEASE DATE' THEN 3
                WHEN 'RELEASE_DATE' THEN 3
                ELSE 3
            END, tags.tag_index
            LIMIT 1
        ), '')
        """
    }

    public static func displayText(from value: String?) -> String {
        guard let year = yearValue(from: value) else { return "—" }
        return String(year)
    }

    public static func yearValue(from value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.prefix(4)
        guard prefix.count == 4,
              prefix.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
        return Int(prefix)
    }
}

/// Shared DUMPER tag lookup for catalog playlist projections. UAC member
/// metadata is authoritative because ScanSong projects the UAC manifest as the
/// member's metadata document instead of merging tags from its payload.
public enum CatalogPlaylistDumper {
    public static func sqlExpression(metadataTagsAvailable: Bool) -> String {
        guard metadataTagsAvailable else { return "''" }
        return """
        COALESCE((
            SELECT tags.value
            FROM track_metadata_tags tags
            WHERE tags.track_id=t.id
              AND tags.normalized_name IN (
                  'DUMPER', 'DUMPED BY', 'DUMPED_BY', 'DUMPEDBY', 'RIPPED BY',
                  'RIPPED_BY', 'RIPPEDBY', 'RIPPER', 'CONVERTED BY', 'CONVERTED_BY',
                  'CONVERTEDBY', 'ENCODED BY', 'ENCODED_BY', 'ENCODEDBY', 'PSFBY', 'ENCODER'
              )
              AND trim(tags.value)<>''
            ORDER BY CASE tags.normalized_name
                WHEN 'DUMPER' THEN 0
                WHEN 'RIPPED BY' THEN 1
                WHEN 'RIPPED_BY' THEN 1
                WHEN 'RIPPEDBY' THEN 1
                WHEN 'RIPPER' THEN 2
                WHEN 'CONVERTED BY' THEN 3
                WHEN 'CONVERTED_BY' THEN 3
                ELSE 4
            END, tags.tag_index
            LIMIT 1
        ), '')
        """
    }

    public static func displayText(from value: String?) -> String {
        guard let value else { return "—" }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    public static func sortableValue(from value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "—" ? nil : trimmed
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
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK,
              let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the catalog."
            sqlite3_close(database)
            throw CatalogPlaylistCoreError.sqlite(message)
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 10_000)

        var versionStatement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "PRAGMA user_version;", -1, &versionStatement, nil) == SQLITE_OK,
              let versionStatement else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        let versionStatus = sqlite3_step(versionStatement)
        let schemaVersion = versionStatus == SQLITE_ROW ? Int(sqlite3_column_int(versionStatement, 0)) : 0
        sqlite3_finalize(versionStatement)
        guard versionStatus == SQLITE_ROW else {
            throw CatalogPlaylistCoreError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        let yearProjection = CatalogPlaylistYear.sqlExpression(metadataTagsAvailable: schemaVersion >= 25)
        let dumperProjection = CatalogPlaylistDumper.sqlExpression(metadataTagsAvailable: schemaVersion >= 25)

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
        t.track_number AS track_number,
        COALESCE(m.title, '') AS title,
        COALESCE(NULLIF(m.game, ''), NULLIF(t.browser_game, ''), '') AS game,
        COALESCE(m.author, '') AS author,
        COALESCE(NULLIF(m.system, ''), NULLIF(t.browser_system, ''), '') AS system,
        COALESCE(m.comment, '') AS comment,
        COALESCE(m.intro_length_ms, 0) AS intro_length_ms,
        COALESCE(m.loop_length_ms, 0) AS loop_length_ms,
        COALESCE(m.play_length_ms, 0) AS length_ms,
        COALESCE(m.fade_length_ms, 0) AS fade_length_ms,
        \(yearProjection) AS year_value,
        \(dumperProjection) AS dumper_value,
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
            WHERE r.is_attached = 1
              AND r.is_enabled = 1
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
            track_number,
            title,
            game,
            author,
            system,
            comment,
            intro_length_ms,
            loop_length_ms,
            length_ms,
            fade_length_ms,
            year_value,
            dumper_value
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
                trackNumber: sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 5)),
                year: text(statement, index: 15),
                dumper: text(statement, index: 16),
                title: text(statement, index: 6),
                game: text(statement, index: 7),
                author: text(statement, index: 8),
                system: text(statement, index: 9),
                comment: text(statement, index: 10),
                introLengthMilliseconds: Int(sqlite3_column_int(statement, 11)),
                loopLengthMilliseconds: Int(sqlite3_column_int(statement, 12)),
                lengthMilliseconds: Int(sqlite3_column_int(statement, 13)),
                fadeLengthMilliseconds: Int(sqlite3_column_int(statement, 14))
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
