import Darwin
import Foundation
import SQLite3
import Testing
import zlib
@testable import ScanSongKit

@Test func multiRootScanPublishesOneStableSourceTotal() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-multi-root-progress-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let firstRoot = directory.appendingPathComponent("First", isDirectory: true)
    let secondRoot = directory.appendingPathComponent("Second", isDirectory: true)
    try FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)
    try makeSPCFile(id666Flag: 0x1A).write(to: firstRoot.appendingPathComponent("First.spc"))
    try makeSPCFile(id666Flag: 0x1A).write(to: secondRoot.appendingPathComponent("Second.spc"))

    let progress = ProgressCapture()
    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    let results = try await CatalogScanner(databaseURL: databaseURL).scan(
        rootURLs: [firstRoot, secondRoot],
        mode: .newScan,
        progress: progress.append
    )
    #expect(results.count == 2)
    #expect(results.allSatisfy { $0.trackCount == 1 })

    let updates = progress.values()
    #expect(updates.contains { $0.phase == .planning && $0.discovered == 2 && $0.processed == 0 })
    #expect(updates.filter { $0.phase != .discovery }.allSatisfy { $0.discovered == 2 })
    #expect(updates.last?.discovered == 2)
    #expect(updates.last?.processed == 2)
    #expect(zip(updates, updates.dropFirst()).allSatisfy { $0.0.processed <= $0.1.processed })
}
@Test func canonicalCatalogValidationAcceptsOnlyTheSharedSchema() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-catalog-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    try createCanonicalCatalog(at: databaseURL)

    let summary = try CanonicalCatalog.inspect(databaseURL: databaseURL)
    #expect(summary.schemaVersion == CanonicalCatalog.schemaVersion)
    #expect(summary.rootCount == 1)
    #expect(summary.trackCount == 2)
    #expect(summary.path == databaseURL.standardizedFileURL.path)
}

@Test func canonicalCatalogValidationRejectsAnUnrelatedSQLiteFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-invalid-catalog-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("Other.sqlite")
    var database: OpaquePointer?
    #expect(sqlite3_open(databaseURL.path, &database) == SQLITE_OK)
    defer { sqlite3_close(database) }
    #expect(sqlite3_exec(database, "PRAGMA user_version = 1;", nil, nil, nil) == SQLITE_OK)

    #expect(throws: Error.self) {
        try CanonicalCatalog.inspect(databaseURL: databaseURL)
    }
}

@Test func catalogScannerCreatesAndPublishesAHostReadableSchema23Catalog() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-writer-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let root = directory.appendingPathComponent("Library", isDirectory: true)
    let game = root
        .appendingPathComponent("Sony PlayStation", isDirectory: true)
        .appendingPathComponent("Castlevania", isDirectory: true)
    try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
    try Data("fixture".utf8).write(to: game.appendingPathComponent("Prologue.wav"))
    let databaseURL = directory.appendingPathComponent("Library.sqlite")

    let result = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)
    #expect(result.discoveredSourceCount == 1)
    #expect(result.trackCount == 1)
    #expect(result.failures.isEmpty)

    let summary = try CanonicalCatalog.inspect(databaseURL: databaseURL)
    #expect(summary.schemaVersion == 23)
    #expect(summary.rootCount == 1)
    #expect(summary.trackCount == 1)

    var database: OpaquePointer?
    #expect(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    let row = try querySingleRow(
        database: try #require(database),
        sql: "SELECT browser_game, browser_system, filename FROM tracks LIMIT 1;"
    )
    let journalMode = try querySingleRow(
        database: try #require(database),
        sql: "PRAGMA journal_mode;"
    )
    sqlite3_close(database)
    #expect(row == ["Castlevania", "Sony PlayStation", "Prologue.wav"])
    #expect(journalMode == ["delete"])
}

@Test func catalogWriterLeaseExcludesOtherScannersButAllowsPlayerReaders() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-writer-lease-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("Library.sqlite")

    do {
        let firstWriter = try CanonicalCatalogWriter(databaseURL: databaseURL)
        _ = try CanonicalCatalogReader(databaseURL: databaseURL)
        #expect(throws: CatalogWriterError.self) {
            _ = try CanonicalCatalogWriter(databaseURL: databaseURL)
        }
        withExtendedLifetime(firstWriter) {}
    }

    _ = try CanonicalCatalogWriter(databaseURL: databaseURL)
}

@Test func catalogWriterPreservesWALForConcurrentPlayerReads() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-wal-writer-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    let firstRoot = directory.appendingPathComponent("First", isDirectory: true)
    let secondRoot = directory.appendingPathComponent("Second", isDirectory: true)
    let thirdRoot = directory.appendingPathComponent("Third", isDirectory: true)
    try FileManager.default.createDirectory(at: firstRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondRoot, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: thirdRoot, withIntermediateDirectories: true)

    do {
        let writer = try CanonicalCatalogWriter(databaseURL: databaseURL)
        _ = try writer.addRoot(path: firstRoot.path)
        withExtendedLifetime(writer) {}
    }

    var setup: OpaquePointer?
    #expect(sqlite3_open(databaseURL.path, &setup) == SQLITE_OK)
    let setupDatabase = try #require(setup)
    #expect(sqlite3_exec(setupDatabase, "PRAGMA journal_mode=WAL;", nil, nil, nil) == SQLITE_OK)

    // Keep the setup connection open while the first WAL transaction creates
    // the sidecars required by a query-only player connection.
    do {
        let writer = try CanonicalCatalogWriter(databaseURL: databaseURL)
        _ = try writer.addRoot(path: secondRoot.path)
        withExtendedLifetime(writer) {}
    }

    var player: OpaquePointer?
    #expect(sqlite3_open_v2(databaseURL.path, &player, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    let playerDatabase = try #require(player)
    defer { sqlite3_close(playerDatabase) }
    #expect(sqlite3_exec(playerDatabase, "BEGIN;", nil, nil, nil) == SQLITE_OK)
    _ = try querySingleRow(database: playerDatabase, sql: "SELECT COUNT(*) FROM library_roots;")
    sqlite3_close(setupDatabase)

    do {
        let writer = try CanonicalCatalogWriter(databaseURL: databaseURL)
        _ = try writer.addRoot(path: thirdRoot.path)
        withExtendedLifetime(writer) {}
    }
    #expect(sqlite3_exec(playerDatabase, "COMMIT;", nil, nil, nil) == SQLITE_OK)

    var verification: OpaquePointer?
    #expect(sqlite3_open_v2(databaseURL.path, &verification, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    let verificationDatabase = try #require(verification)
    defer { sqlite3_close(verificationDatabase) }
    #expect(try querySingleRow(database: verificationDatabase, sql: "PRAGMA journal_mode;") == ["wal"])
}

@Test func linkTestingRetainsMissingRowsAndClearDeadLinksPurgesThem() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-links-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let root = directory.appendingPathComponent("Library", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let media = root.appendingPathComponent("Track.wav")
    try Data("fixture".utf8).write(to: media)
    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    _ = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)

    let writer = try CanonicalCatalogWriter(databaseURL: databaseURL)
    let reader = try CanonicalCatalogReader(databaseURL: databaseURL)
    let rootID = try #require(try reader.roots().first?.id)
    let beforeLinkCheck = try reader.scanTally(rootID: rootID)
    #expect(beforeLinkCheck.sourceCount == 1)
    #expect(beforeLinkCheck.activeSourceCount == 1)
    #expect(beforeLinkCheck.successfulSourceCount == 1)
    #expect(beforeLinkCheck.failedSourceCount == 0)
    #expect(beforeLinkCheck.inactiveSourceCount == 0)
    try FileManager.default.removeItem(at: media)
    let tested = try writer.testFiles()
    #expect(tested.testedSourceCount == 1)
    #expect(tested.missingSourceCount == 1)
    #expect(try writer.roots().first?.deadSourceCount == 1)
    #expect(try CanonicalCatalog.inspect(databaseURL: databaseURL).trackCount == 1)

    let afterLinkCheck = try CanonicalCatalogReader(databaseURL: databaseURL).scanTally(rootID: rootID)
    #expect(afterLinkCheck.sourceCount == 1)
    #expect(afterLinkCheck.activeSourceCount == 0)
    #expect(afterLinkCheck.inactiveSourceCount == 1)

    #expect(try writer.clearDeadLinks() == 1)
    #expect(try writer.roots().first?.deadSourceCount == 0)
    #expect(try CanonicalCatalog.inspect(databaseURL: databaseURL).trackCount == 0)
}

@Test func resetCatalogEmptiesRootsAndIndexedTracksWithoutDeletingTheDatabaseFile() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-reset-catalog-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let root = directory.appendingPathComponent("Library", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("fixture".utf8).write(to: root.appendingPathComponent("Track.wav"))
    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    _ = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)

    let writer = try CanonicalCatalogWriter(databaseURL: databaseURL)
    try writer.resetCatalog()

    #expect(FileManager.default.fileExists(atPath: databaseURL.path))
    #expect(try writer.roots().isEmpty)
    #expect(try CanonicalCatalog.inspect(databaseURL: databaseURL).trackCount == 0)
}

@Test func scannerMetadataRoundTripsWithoutAHostModel() throws {
    let metadata = ScannerMetadata(
        game: "Castlevania",
        song: "Prologue",
        system: "Sony PlayStation",
        author: "Konami",
        comment: "",
        introLengthMs: 1_000,
        loopLengthMs: 2_000,
        playLengthMs: 180_000,
        fadeLengthMs: 5_000
    )
    let encoded = try JSONEncoder().encode(metadata)
    #expect(try JSONDecoder().decode(ScannerMetadata.self, from: encoded) == metadata)
}

@Test func catalogBrowserSystemComesOnlyFromTheCollectionPath() {
    let source = "/Audio/Sony PlayStation 2/Castlevania/track.psf2"
    #expect(CatalogIdentity.browserSystem(sourcePath: source, rootPath: "/Audio") == "Sony PlayStation 2")
}

@Test func catalogBrowserSystemUsesTheParentConsoleFolderForGameArchives() {
    let source = "/Audio/JoshW/Nintendo DS/Castlevania.tar.zst"
    #expect(CatalogIdentity.browserSystem(sourcePath: source, rootPath: "/Audio/JoshW") == "Nintendo DS")
}

@Test func incrementalRescanReusesAnUnchangedCompletedSource() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-reuse-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let root = directory.appendingPathComponent("Library", isDirectory: true)
    let game = root.appendingPathComponent("Nintendo NES", isDirectory: true)
    try FileManager.default.createDirectory(at: game, withIntermediateDirectories: true)
    try Data("fixture".utf8).write(to: game.appendingPathComponent("Castlevania.wav"))
    let databaseURL = directory.appendingPathComponent("Library.sqlite")

    let first = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)
    #expect(first.scannedSourceCount == 1)
    #expect(first.reusedSourceCount == 0)
    #expect(first.failures.isEmpty)

    let second = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .incremental)
    #expect(second.reusedSourceCount == 1)
    #expect(second.scannedSourceCount == 0)
    #expect(second.trackCount == 1)
    #expect(second.failures.isEmpty)

    let full = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)
    #expect(full.scannedSourceCount == 1)
    #expect(full.reusedSourceCount == 0)
    #expect(full.failures.isEmpty)
}

@Test func sharedDiscoveryFindsSupportedFilesAndHostRecognizedArchives() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-discovery-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data().write(to: root.appendingPathComponent("game.nsf"))
    try Data().write(to: root.appendingPathComponent("album.customarchive"))
    try Data().write(to: root.appendingPathComponent("notes.txt"))

    let discovered = try await ScanFilesystemDiscovery.discover(
        rootID: 3,
        rootURL: root,
        registry: BuiltInScannerPlugins.registry,
        isArchive: { $0.pathExtension == "customarchive" }
    )
    #expect(discovered.map(\.sourceURL.lastPathComponent) == ["album.customarchive", "game.nsf"])
    #expect(discovered.first?.route == nil)
    #expect(discovered.last?.route?.structurePolicy == .enumerate)
}
