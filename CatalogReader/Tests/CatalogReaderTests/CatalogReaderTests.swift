import CatalogReader
import CatalogPlaylistCore
import Foundation
import SQLite3
import Testing

private func execute(_ database: OpaquePointer?, _ sql: String) throws {
    var error: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(database, sql, nil, nil, &error) == SQLITE_OK else {
        defer { sqlite3_free(error) }
        throw NSError(domain: "CatalogReaderTests", code: 1, userInfo: [NSLocalizedDescriptionKey: error.map { String(cString: $0) } ?? "SQLite fixture failed."])
    }
}

private func fixtureCatalog() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("CatalogReaderTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let url = root.appendingPathComponent("Library.sqlite")
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw NSError(domain: "CatalogReaderTests", code: 2) }
    defer { sqlite3_close(database) }
    try execute(database, """
        PRAGMA user_version = 23;
        CREATE TABLE library_roots (id INTEGER PRIMARY KEY, path TEXT NOT NULL, is_enabled INTEGER NOT NULL, is_attached INTEGER NOT NULL, last_scan_track_count INTEGER NOT NULL, game_sidebar_buckets_dirty INTEGER NOT NULL DEFAULT 0, file_sidebar_buckets_dirty INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE tracks (id INTEGER PRIMARY KEY, root_id INTEGER NOT NULL, folder_path TEXT NOT NULL, path TEXT NOT NULL, filename TEXT NOT NULL, browser_game TEXT NOT NULL, browser_system TEXT NOT NULL, track_index INTEGER NOT NULL, track_count INTEGER NOT NULL, archive_path TEXT, archive_entry TEXT);
        CREATE INDEX tracks_browser_bucket_index ON tracks(root_id, browser_game, browser_system);
        CREATE TABLE track_metadata (track_id INTEGER PRIMARY KEY, title TEXT, game TEXT, author TEXT, system TEXT, comment TEXT, intro_length_ms INTEGER, loop_length_ms INTEGER, play_length_ms INTEGER, fade_length_ms INTEGER);
        CREATE TABLE dead_sources (root_id INTEGER NOT NULL, path TEXT NOT NULL);
        CREATE TABLE game_sidebar_buckets (root_id INTEGER, browser_game TEXT, browser_system TEXT, track_count INTEGER);
        CREATE TABLE file_sidebar_buckets (root_id INTEGER, folder_path TEXT, path TEXT, is_archive INTEGER, track_count INTEGER);
        INSERT INTO library_roots VALUES (1, '/music', 1, 1, 2, 0, 0);
        INSERT INTO tracks VALUES (1, 1, '/music/Game', '/music/Game/Track 9.spc', 'Track 9.spc', 'Game', 'SNES', 0, 1, NULL, NULL);
        INSERT INTO tracks VALUES (2, 1, '/music/Game', '/music/Game/Track 10.spc', 'Track 10.spc', 'Game', 'SNES', 0, 1, NULL, NULL);
        INSERT INTO tracks VALUES (3, 1, '/music/TG16', '/music/TG16/Chew-Man-Fu.tar.zst', 'Chew-Man-Fu.tar.zst', 'Chew Man Fu', '', 0, 1, '/music/TG16/Chew-Man-Fu.tar.zst', NULL);
        INSERT INTO track_metadata VALUES (1, 'Track 9', 'Game', 'Composer', 'SNES', '', 0, 0, 90000, 0);
        INSERT INTO track_metadata VALUES (2, 'Track 10', 'Game', 'Composer', 'SNES', '', 0, 0, 100000, 0);
        INSERT INTO track_metadata VALUES (3, 'Chew Man Fu', 'Chew Man Fu', 'Composer', 'PC Engine', '', 0, 0, 120000, 0);
        INSERT INTO game_sidebar_buckets VALUES (1, 'Game', 'SNES', 2);
        INSERT INTO game_sidebar_buckets VALUES (1, 'Chew Man Fu', '', 1);
        INSERT INTO file_sidebar_buckets VALUES (1, '/music/Game', '/music/Game/Track 9.spc', 0, 1);
        INSERT INTO file_sidebar_buckets VALUES (1, '/music/Game', '/music/Game/Track 10.spc', 0, 1);
        """)
    return url
}

@Test func readerDerivesBucketsWhileScanProjectionsAreDirty() throws {
    let url = try fixtureCatalog()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw NSError(domain: "CatalogReaderTests", code: 3) }
    defer { sqlite3_close(database) }
    try execute(database, "UPDATE library_roots SET game_sidebar_buckets_dirty=1, file_sidebar_buckets_dirty=1;")

    let reader = try ReadOnlyCatalog(databaseURL: url)
    #expect(Set(try reader.gameBuckets().map(\.game)) == Set(["Chew Man Fu", "Game"]))
    #expect(try reader.gameBuckets().first(where: { $0.game == "Chew Man Fu" })?.system == "PC Engine")
    #expect(Set(try reader.fileBuckets().map(\.path)) == Set([
        "/music/Game/Track 9.spc",
        "/music/Game/Track 10.spc",
        "/music/TG16/Chew-Man-Fu.tar.zst"
    ]))
}

@Test func readerReturnsOnlyPublishedReadOnlySelections() throws {
    let url = try fixtureCatalog()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let reader = try ReadOnlyCatalog(databaseURL: url)

    #expect(try reader.activeTrackCount() == 3)
    #expect(try reader.deadSourceCount() == 0)
    #expect(Set(try reader.gameBuckets().map(\.game)) == Set(["Chew Man Fu", "Game"]))
    #expect(try reader.tracks(rootID: 1, game: "Game", system: "SNES", preferFoldersOverMetadata: false).count == 2)
    #expect(try reader.gameBuckets().first(where: { $0.game == "Chew Man Fu" })?.system == "PC Engine")
    #expect(try reader.tracks(rootID: 1, game: "Chew Man Fu", system: "PC Engine", preferFoldersOverMetadata: true).count == 1)
    #expect(try reader.tracks(rootID: 1, sourcePaths: ["/music/Game/Track 10.spc"]).map(\.title) == ["Track 10"])
    #expect(try reader.tracks(rootID: 1, folderPaths: ["/music/Game"]).map(\.title) == ["Track 9", "Track 10"])
    #expect(try reader.tracks(sourceSelections: [
        CatalogSourceSelection(rootID: 1, path: "/music/Game/Track 9.spc")
    ]).map(\.title) == ["Track 9"])
    #expect(try reader.tracks(rootPath: "/music", folderPath: "/music/Game").map(\.title) == ["Track 10", "Track 9"])
    #expect(try reader.tracks(paths: ["/music/Game/Track 9.spc", "/music/Game/Track 10.spc"]).map(\.title) == ["Track 10", "Track 9"])
}

@Test func playlistGameProjectionUsesFolderFirstSystemProjection() throws {
    let url = try fixtureCatalog()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let tracks = try CatalogPlaylistReader.tracksForGames(
        databaseURL: url,
        selections: [
            CatalogPlaylistGameSelection(rootID: 1, game: "Game", system: "SNES"),
            CatalogPlaylistGameSelection(rootID: 1, game: "Chew Man Fu", system: "PC Engine")
        ],
        preferFoldersOverMetadata: true
    )

    #expect(tracks.map(\.title) == ["Chew Man Fu", "Track 10", "Track 9"])
    #expect(tracks.map(\.lengthMilliseconds) == [120000, 100000, 90000])

    let metadataFallbackTracks = try CatalogPlaylistReader.tracksForGames(
        databaseURL: url,
        selections: [CatalogPlaylistGameSelection(rootID: 1, game: "Chew Man Fu", system: "PC Engine")],
        preferFoldersOverMetadata: false
    )
    #expect(metadataFallbackTracks.map(\.title) == ["Chew Man Fu"])
}

@Test func playlistGameProjectionMatchesMetadataBackedSidebarSystems() throws {
    let url = try fixtureCatalog()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let reader = try ReadOnlyCatalog(databaseURL: url)
    let selections = try reader.gameBuckets().map {
        CatalogPlaylistGameSelection(rootID: $0.rootID, game: $0.game, system: $0.system)
    }

    let tracks = try CatalogPlaylistReader.tracksForGames(
        databaseURL: url,
        selections: selections,
        preferFoldersOverMetadata: true
    )

    #expect(tracks.map(\.title) == ["Chew Man Fu", "Track 10", "Track 9"])
}
