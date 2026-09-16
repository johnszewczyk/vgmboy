import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("Valid GENH headers use MetaMan while malformed aliases retain vgmstream fallback")
func genhRoutingUsesCompleteMetaManHeaderReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "genh")?.pluginID == "genh-direct")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("genh"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("genh") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-genh-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let validURL = directory.appendingPathComponent("DIGEST.genh")
    try makeGENHScannerFixture().write(to: validURL)
    let route = try #require(registry.route(forPath: validURL.path, archiveMember: true))
    #expect(route.pluginID == "genh-direct")
    #expect(route.structurePolicy == .knownSingle)
    #expect(route.metadataPolicy == .direct)
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: validURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].trackIndex == 0)
    #expect(inspection.tracks[0].trackCount == 1)
    #expect(inspection.tracks[0].metadata?.song == "DIGEST")
    #expect(inspection.tracks[0].metadata?.comment == "GENH generic header")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 1_000)

    let aliasURL = directory.appendingPathComponent("unrelated.genh")
    try Data("not a GENH source".utf8).write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path, archiveMember: true)?.pluginID == "vgmstream")

    var unknownCodec = makeGENHScannerFixture()
    setGENHScanner32(29, in: &unknownCodec, at: 0x18)
    let unknownCodecURL = directory.appendingPathComponent("unknown-codec.genh")
    try unknownCodec.write(to: unknownCodecURL)
    #expect(registry.route(forPath: unknownCodecURL.path, archiveMember: true)?.pluginID == "vgmstream")
}

@Test(
    "GENH MetaMan rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_GENH_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_GENH_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare MetaMan, the saved catalog, and vgmstream."
    )
)
func genhLiveRowsMatchDirectExtractionAndVGMStream() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_GENH_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_GENH_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveGENHArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "genh",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream GENH reference",
        supportedExtensions: ["genh"],
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    ))
    let extractor = StandaloneArchiveExtractor()
    var directExact = 0
    var decoderExact = 0
    var pairedExact = 0
    var directNanoseconds: UInt64 = 0
    var decoderNanoseconds: UInt64 = 0
    var mismatches: [String] = []
    let totalRows = archives.reduce(0) { $0 + $1.files.count }

    for archive in archives {
        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: BuiltInScannerPlugins.registry
        )
        defer { extractor.discard(extraction) }
        let members = Dictionary(
            extraction.members.map { (normalizeGENHEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeGENHEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved GENH member") }
                continue
            }
            guard let route = BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "genh-direct",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): expected genh-direct route") }
                continue
            }

            let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await handler.inspect(fileURL: fileURL, route: route)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let direct = directInspection.tracks.map(LiveGENHRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if direct == expected { directExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), MetaMan=\(direct)") }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoded = decoderInspection.tracks.map(LiveGENHRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if decoded == expected { decoderExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), vgmstream=\(decoded)") }
            if direct == decoded { pairedExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): MetaMan=\(direct), vgmstream=\(decoded)") }
        }
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) fresh vgmstream rows match saved metadata")
    #expect(pairedExact == totalRows, "\(pairedExact)/\(totalRows) direct rows match fresh vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(String(
        format: "GENH corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file",
        totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs
    ))
}

private struct LiveGENHMetadata: Equatable, CustomStringConvertible {
    let game: String
    let song: String
    let system: String
    let author: String
    let comment: String
    let introLengthMs: Int
    let loopLengthMs: Int
    let playLengthMs: Int
    let fadeLengthMs: Int

    init(_ metadata: ScannerMetadata) {
        game = metadata.game
        song = metadata.song
        system = metadata.system
        author = metadata.author
        comment = metadata.comment
        introLengthMs = metadata.introLengthMs
        loopLengthMs = metadata.loopLengthMs
        playLengthMs = metadata.playLengthMs
        fadeLengthMs = metadata.fadeLengthMs
    }

    init(statement: OpaquePointer, firstColumn: Int32) {
        game = sqliteGENHText(statement, firstColumn)
        song = sqliteGENHText(statement, firstColumn + 1)
        system = sqliteGENHText(statement, firstColumn + 2)
        author = sqliteGENHText(statement, firstColumn + 3)
        comment = sqliteGENHText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }

    var description: String {
        "\(song) [\(playLengthMs) ms, loop \(loopLengthMs) ms]"
    }
}

private struct LiveGENHRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveGENHMetadata?

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveGENHMetadata.init)
    }

    init(statement: OpaquePointer) {
        trackIndex = Int(sqlite3_column_int64(statement, 2))
        trackCount = Int(sqlite3_column_int64(statement, 3))
        metadata = LiveGENHMetadata(statement: statement, firstColumn: 4)
    }

    var description: String {
        "index=\(trackIndex)/\(trackCount), metadata=\(String(describing: metadata))"
    }
}

private struct LiveGENHFile {
    let entryPath: String
    let row: LiveGENHRow
}

private struct LiveGENHArchive {
    let path: String
    var files: [LiveGENHFile]
}

private func readLiveGENHArchives(databaseURL: URL, rootID: Int) throws -> [LiveGENHArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the GENH catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongGENHParity", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'genh'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongGENHParity", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongGENHParity", code: 3)
    }

    var archives: [LiveGENHArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteGENHText(statement, 0)
        let file = LiveGENHFile(entryPath: sqliteGENHText(statement, 1), row: LiveGENHRow(statement: statement))
        if let index = indexes[path] {
            archives[index].files.append(file)
        } else {
            indexes[path] = archives.count
            archives.append(LiveGENHArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongGENHParity", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeGENHEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteGENHText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func makeGENHScannerFixture() -> Data {
    var data = Data(repeating: 0, count: 0x100 + 64_000)
    data.replaceSubrange(0..<4, with: Data("GENH".utf8))
    setGENHScanner32(1, in: &data, at: 0x04)
    setGENHScanner32(0, in: &data, at: 0x08)
    setGENHScanner32(32_000, in: &data, at: 0x0C)
    setGENHScanner32(UInt32.max, in: &data, at: 0x10)
    setGENHScanner32(32_000, in: &data, at: 0x14)
    setGENHScanner32(3, in: &data, at: 0x18)
    setGENHScanner32(0x100, in: &data, at: 0x1C)
    setGENHScanner32(0x100, in: &data, at: 0x20)
    setGENHScanner32(32_000, in: &data, at: 0x40)
    setGENHScanner32(0, in: &data, at: 0x50)
    return data
}

private func setGENHScanner32(_ value: UInt32, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
