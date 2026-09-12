import FavoriteTrackCore
import Foundation
import SQLite3

public struct FavoriteTrackSnapshot: Codable, Equatable, Sendable {
    public let identity: FavoriteTrackIdentity
    public let filename: String
    public let title: String
    public let game: String
    public let author: String
    public let system: String
    public let playLengthMilliseconds: Int

    public init(
        identity: FavoriteTrackIdentity,
        filename: String = "",
        title: String = "",
        game: String = "",
        author: String = "",
        system: String = "",
        playLengthMilliseconds: Int = 0
    ) {
        self.identity = identity
        self.filename = filename
        self.title = title
        self.game = game
        self.author = author
        self.system = system
        self.playLengthMilliseconds = max(0, playLengthMilliseconds)
    }
}

public enum FavoriteSortOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case historical
    case alphabetical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .historical: "Historical"
        case .alphabetical: "Alphabetical"
        }
    }
}

/// Shared favorite-list presentation for both native skins. Storage always
/// retains insertion order; alphabetical display is a reversible view over
/// the same durable rows.
public enum FavoriteListPresentation {
    public static func ordered(
        _ snapshots: [FavoriteTrackSnapshot],
        by order: FavoriteSortOrder
    ) -> [FavoriteTrackSnapshot] {
        guard order == .alphabetical else { return snapshots }
        return snapshots.sorted {
            let comparison = displayName(for: $0).localizedStandardCompare(displayName(for: $1))
            return comparison == .orderedSame
                ? $0.identity.id < $1.identity.id
                : comparison == .orderedAscending
        }
    }

    /// Compact, path-free sidebar copy in GAME-NN-SONG form. NN is taken
    /// from the source filename when available and otherwise from a declared
    /// multi-track index. Empty metadata is omitted rather than replaced by a
    /// full path.
    public static func displayName(for snapshot: FavoriteTrackSnapshot) -> String {
        let sourceName = snapshot.filename.isEmpty
            ? snapshot.identity.archiveEntry.map { URL(fileURLWithPath: $0).lastPathComponent }
                ?? URL(fileURLWithPath: snapshot.identity.sourcePath).lastPathComponent
            : snapshot.filename
        let sourceStem = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
        let parsed = leadingTrackNumber(in: sourceStem)
        let number = parsed.number
            ?? (snapshot.identity.trackCount > 1 ? snapshot.identity.trackIndex + 1 : nil)
        let title = firstNonEmpty(snapshot.title, parsed.remainder, sourceStem)
        let game = snapshot.game.trimmingCharacters(in: .whitespacesAndNewlines)

        var components: [String] = []
        if !game.isEmpty { components.append(game) }
        if let number { components.append(String(format: "%02d", number)) }
        if !title.isEmpty, title.localizedCaseInsensitiveCompare(game) != .orderedSame {
            components.append(title)
        }
        return components.isEmpty ? "Favorite" : components.joined(separator: "-")
    }

    private static func leadingTrackNumber(in value: String) -> (number: Int?, remainder: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.prefix(while: \.isNumber)
        guard !digits.isEmpty,
              let number = Int(digits),
              digits.count < trimmed.count else {
            return (nil, trimmed)
        }
        let suffix = trimmed.dropFirst(digits.count)
        guard let first = suffix.first, first.isWhitespace || "-_.".contains(first) else {
            return (nil, trimmed)
        }
        return (
            number,
            String(suffix.drop(while: { $0.isWhitespace || "-_.".contains($0) }))
        )
    }

    private static func firstNonEmpty(_ values: String...) -> String {
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }
}

public struct FavoriteStoreMutation: Equatable, Sendable {
    public let added: Bool
    public let revision: Int64

    public init(added: Bool, revision: Int64) {
        self.added = added
        self.revision = revision
    }
}

public enum FavoriteStoreError: LocalizedError {
    case open(String)
    case sqlite(String)
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .open(let path): "Could not open the shared Favorites store at \(path)."
        case .sqlite(let message): "Shared Favorites store error: \(message)"
        case .unsupportedSchema(let version): "Shared Favorites schema \(version) is newer than this application supports."
        }
    }
}

/// Cross-process Favorites persistence shared by the native and WebKit skins.
/// Every operation opens a short-lived SQLite connection so no app owns a
/// process-global writer. SQLite serializes mutations with BEGIN IMMEDIATE.
public final class FavoriteStore: @unchecked Sendable {
    public static let schemaVersion = 1
    public let databaseURL: URL

    public init(databaseURL: URL = FavoriteStore.defaultDatabaseURL()) throws {
        self.databaseURL = databaseURL.standardizedFileURL
        try prepareDirectory()
        try withConnection { handle in
            try Self.prepareSchema(handle)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.databaseURL.path)
    }

    public static func defaultDatabaseURL(fileManager: FileManager = .default) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base
            .appendingPathComponent("VGMMan", isDirectory: true)
            .appendingPathComponent("UserData.sqlite", isDirectory: false)
    }

    public func snapshots() throws -> [FavoriteTrackSnapshot] {
        try withConnection { handle in try Self.readSnapshots(handle) }
    }

    public func revision() throws -> Int64 {
        try withConnection { handle in try Self.metadataInt(handle, key: "revision") }
    }

    /// Imports legacy app-local arrays without changing existing shared order.
    /// Calling this repeatedly is safe: existing identities are only refreshed.
    @discardableResult
    public func importLegacy(_ snapshots: [FavoriteTrackSnapshot]) throws -> Int64 {
        let unique = Self.unique(snapshots)
        guard !unique.isEmpty else { return try revision() }
        return try withConnection { handle in
            try Self.transaction(handle) {
                var changed = false
                var nextPosition = try Self.nextPosition(handle)
                for snapshot in unique {
                    if let existing = try Self.snapshot(handle, id: snapshot.identity.id) {
                        if existing != snapshot {
                            try Self.updateSnapshot(handle, snapshot)
                            changed = true
                        }
                    } else {
                        try Self.insertSnapshot(handle, snapshot, position: nextPosition)
                        nextPosition += 1
                        changed = true
                    }
                }
                return changed ? try Self.incrementRevision(handle) : try Self.metadataInt(handle, key: "revision")
            }
        }
    }

    @discardableResult
    public func toggle(_ snapshots: [FavoriteTrackSnapshot]) throws -> FavoriteStoreMutation {
        let unique = Self.unique(snapshots)
        guard !unique.isEmpty else { return FavoriteStoreMutation(added: false, revision: try revision()) }
        return try withConnection { handle in
            try Self.transaction(handle) {
                let allPresent = try unique.allSatisfy { try Self.contains(handle, id: $0.identity.id) }
                if allPresent {
                    for snapshot in unique { try Self.delete(handle, id: snapshot.identity.id) }
                } else {
                    var nextPosition = try Self.nextPosition(handle)
                    for snapshot in unique {
                        if try Self.contains(handle, id: snapshot.identity.id) {
                            try Self.updateSnapshot(handle, snapshot)
                        } else {
                            try Self.insertSnapshot(handle, snapshot, position: nextPosition)
                            nextPosition += 1
                        }
                    }
                }
                return FavoriteStoreMutation(added: !allPresent, revision: try Self.incrementRevision(handle))
            }
        }
    }

    private func prepareDirectory() throws {
        let directory = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func withConnection<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let handle else {
            if let handle { sqlite3_close(handle) }
            throw FavoriteStoreError.open(databaseURL.path)
        }
        defer { sqlite3_close(handle) }
        sqlite3_busy_timeout(handle, 5_000)
        try Self.execute(handle, "PRAGMA journal_mode=WAL;")
        try Self.execute(handle, "PRAGMA synchronous=FULL;")
        return try body(handle)
    }

    private static func prepareSchema(_ handle: OpaquePointer) throws {
        try execute(handle, "CREATE TABLE IF NOT EXISTS favorite_store_metadata (key TEXT PRIMARY KEY, value INTEGER NOT NULL);")
        let version = try metadataInt(handle, key: "schema_version", missing: 0)
        guard version <= schemaVersion else { throw FavoriteStoreError.unsupportedSchema(Int(version)) }
        if version == 0 {
            try transaction(handle) {
                try execute(handle, """
                    CREATE TABLE IF NOT EXISTS favorite_tracks (
                        id TEXT PRIMARY KEY,
                        source_path TEXT NOT NULL,
                        archive_entry TEXT,
                        track_index INTEGER NOT NULL CHECK(track_index >= 0),
                        track_count INTEGER NOT NULL CHECK(track_count >= 1),
                        filename TEXT NOT NULL,
                        title TEXT NOT NULL,
                        game TEXT NOT NULL,
                        author TEXT NOT NULL,
                        system TEXT NOT NULL,
                        play_length_ms INTEGER NOT NULL CHECK(play_length_ms >= 0),
                        position INTEGER NOT NULL UNIQUE
                    );
                    """)
                try setMetadataInt(handle, key: "schema_version", value: Int64(schemaVersion))
                try setMetadataInt(handle, key: "revision", value: 0)
            }
        }
    }

    private static func readSnapshots(_ handle: OpaquePointer) throws -> [FavoriteTrackSnapshot] {
        let statement = try prepare(handle, "SELECT source_path, archive_entry, track_index, track_count, filename, title, game, author, system, play_length_ms FROM favorite_tracks ORDER BY position;")
        defer { sqlite3_finalize(statement) }
        var result: [FavoriteTrackSnapshot] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            result.append(FavoriteTrackSnapshot(
                identity: FavoriteTrackIdentity(
                    sourcePath: text(statement, 0),
                    archiveEntry: nullableText(statement, 1),
                    trackIndex: Int(sqlite3_column_int64(statement, 2)),
                    trackCount: Int(sqlite3_column_int64(statement, 3))
                ),
                filename: text(statement, 4),
                title: text(statement, 5),
                game: text(statement, 6),
                author: text(statement, 7),
                system: text(statement, 8),
                playLengthMilliseconds: Int(sqlite3_column_int64(statement, 9))
            ))
        }
        return result
    }

    private static func unique(_ snapshots: [FavoriteTrackSnapshot]) -> [FavoriteTrackSnapshot] {
        var seen = Set<String>()
        return snapshots.filter { seen.insert($0.identity.id).inserted }
    }

    private static func contains(_ handle: OpaquePointer, id: String) throws -> Bool {
        let statement = try prepare(handle, "SELECT 1 FROM favorite_tracks WHERE id=? LIMIT 1;")
        defer { sqlite3_finalize(statement) }
        bind(id, statement, 1)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func snapshot(_ handle: OpaquePointer, id: String) throws -> FavoriteTrackSnapshot? {
        let statement = try prepare(handle, "SELECT source_path, archive_entry, track_index, track_count, filename, title, game, author, system, play_length_ms FROM favorite_tracks WHERE id=? LIMIT 1;")
        defer { sqlite3_finalize(statement) }
        bind(id, statement, 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return FavoriteTrackSnapshot(
            identity: FavoriteTrackIdentity(
                sourcePath: text(statement, 0),
                archiveEntry: nullableText(statement, 1),
                trackIndex: Int(sqlite3_column_int64(statement, 2)),
                trackCount: Int(sqlite3_column_int64(statement, 3))
            ),
            filename: text(statement, 4),
            title: text(statement, 5),
            game: text(statement, 6),
            author: text(statement, 7),
            system: text(statement, 8),
            playLengthMilliseconds: Int(sqlite3_column_int64(statement, 9))
        )
    }

    private static func nextPosition(_ handle: OpaquePointer) throws -> Int64 {
        let statement = try prepare(handle, "SELECT COALESCE(MAX(position), -1) + 1 FROM favorite_tracks;")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw sqliteError(handle) }
        return sqlite3_column_int64(statement, 0)
    }

    private static func insertSnapshot(_ handle: OpaquePointer, _ snapshot: FavoriteTrackSnapshot, position: Int64) throws {
        let statement = try prepare(handle, "INSERT INTO favorite_tracks (id, source_path, archive_entry, track_index, track_count, filename, title, game, author, system, play_length_ms, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);")
        defer { sqlite3_finalize(statement) }
        bind(snapshot.identity.id, statement, 1)
        bind(snapshot.identity.sourcePath, statement, 2)
        bind(snapshot.identity.archiveEntry, statement, 3)
        sqlite3_bind_int64(statement, 4, Int64(snapshot.identity.trackIndex))
        sqlite3_bind_int64(statement, 5, Int64(snapshot.identity.trackCount))
        bind(snapshot.filename, statement, 6)
        bind(snapshot.title, statement, 7)
        bind(snapshot.game, statement, 8)
        bind(snapshot.author, statement, 9)
        bind(snapshot.system, statement, 10)
        sqlite3_bind_int64(statement, 11, Int64(snapshot.playLengthMilliseconds))
        sqlite3_bind_int64(statement, 12, position)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(handle) }
    }

    private static func updateSnapshot(_ handle: OpaquePointer, _ snapshot: FavoriteTrackSnapshot) throws {
        let statement = try prepare(handle, "UPDATE favorite_tracks SET source_path=?, archive_entry=?, track_index=?, track_count=?, filename=?, title=?, game=?, author=?, system=?, play_length_ms=? WHERE id=?;")
        defer { sqlite3_finalize(statement) }
        bind(snapshot.identity.sourcePath, statement, 1)
        bind(snapshot.identity.archiveEntry, statement, 2)
        sqlite3_bind_int64(statement, 3, Int64(snapshot.identity.trackIndex))
        sqlite3_bind_int64(statement, 4, Int64(snapshot.identity.trackCount))
        bind(snapshot.filename, statement, 5)
        bind(snapshot.title, statement, 6)
        bind(snapshot.game, statement, 7)
        bind(snapshot.author, statement, 8)
        bind(snapshot.system, statement, 9)
        sqlite3_bind_int64(statement, 10, Int64(snapshot.playLengthMilliseconds))
        bind(snapshot.identity.id, statement, 11)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(handle) }
    }

    private static func delete(_ handle: OpaquePointer, id: String) throws {
        let statement = try prepare(handle, "DELETE FROM favorite_tracks WHERE id=?;")
        defer { sqlite3_finalize(statement) }
        bind(id, statement, 1)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(handle) }
    }

    private static func incrementRevision(_ handle: OpaquePointer) throws -> Int64 {
        let next = try metadataInt(handle, key: "revision") + 1
        try setMetadataInt(handle, key: "revision", value: next)
        return next
    }

    private static func metadataInt(_ handle: OpaquePointer, key: String, missing: Int64? = nil) throws -> Int64 {
        let statement = try prepare(handle, "SELECT value FROM favorite_store_metadata WHERE key=?;")
        defer { sqlite3_finalize(statement) }
        bind(key, statement, 1)
        if sqlite3_step(statement) == SQLITE_ROW { return sqlite3_column_int64(statement, 0) }
        if let missing { return missing }
        throw sqliteError(handle)
    }

    private static func setMetadataInt(_ handle: OpaquePointer, key: String, value: Int64) throws {
        let statement = try prepare(handle, "INSERT INTO favorite_store_metadata (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value=excluded.value;")
        defer { sqlite3_finalize(statement) }
        bind(key, statement, 1)
        sqlite3_bind_int64(statement, 2, value)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(handle) }
    }

    private static func transaction<T>(_ handle: OpaquePointer, _ body: () throws -> T) throws -> T {
        try execute(handle, "BEGIN IMMEDIATE;")
        do {
            let value = try body()
            try execute(handle, "COMMIT;")
            return value
        } catch {
            try? execute(handle, "ROLLBACK;")
            throw error
        }
    }

    private static func execute(_ handle: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw sqliteError(handle) }
    }

    private static func prepare(_ handle: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw sqliteError(handle) }
        return statement
    }

    private static func bind(_ value: String?, _ statement: OpaquePointer, _ index: Int32) {
        guard let value else { sqlite3_bind_null(statement, index); return }
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private static func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private static func nullableText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return text(statement, index)
    }

    private static func sqliteError(_ handle: OpaquePointer) -> FavoriteStoreError {
        FavoriteStoreError.sqlite(String(cString: sqlite3_errmsg(handle)))
    }
}
