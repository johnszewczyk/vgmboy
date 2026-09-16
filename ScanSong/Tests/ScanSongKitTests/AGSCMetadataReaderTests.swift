import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("AGSC routes complete Retro Studios banks through MetaMan with decoder fallback")
func agscRoutingUsesContentAwareMetaManReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "agsc")?.pluginID == "agsc-direct")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("agsc"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("agsc") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-agsc-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let validURL = directory.appendingPathComponent("FrontEndMusic.agsc")
    try makeAGSCScannerFixture().write(to: validURL)
    let route = try #require(registry.route(forPath: validURL.path, archiveMember: true))
    #expect(route.pluginID == "agsc-direct")
    #expect(route.structurePolicy == .enumerate)
    #expect(route.metadataPolicy == .direct)
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: validURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].trackCount == 1)
    #expect(inspection.tracks[0].metadata?.song == "FrontEndMusic")
    #expect(inspection.tracks[0].metadata?.comment == "Retro Studios AGSC header")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 2)

    let aliasURL = directory.appendingPathComponent("unrelated.agsc")
    try Data("not an AGSC bank".utf8).write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path, archiveMember: true)?.pluginID == "vgmstream")
}

@Test(
    "AGSC MetaMan rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_AGSC_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_AGSC_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare MetaMan, the saved catalog, and vgmstream."
    )
)
func agscLiveRowsMatchDirectExtractionAndVGMStream() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_AGSC_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_AGSC_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveAGSCArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "agsc",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream AGSC reference",
        supportedExtensions: ["agsc"],
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
            extraction.members.map { (normalizeAGSCEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeAGSCEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved AGSC member") }
                continue
            }
            guard let route = BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "agsc-direct",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): expected agsc-direct route") }
                continue
            }

            let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await handler.inspect(fileURL: fileURL, route: route)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let direct = directInspection.tracks.map(LiveAGSCRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if direct == expected { directExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), MetaMan=\(direct)") }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoded = decoderInspection.tracks.map(LiveAGSCRow.init).sorted { $0.trackIndex < $1.trackIndex }
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
        format: "AGSC corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file",
        totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs
    ))
}

private struct LiveAGSCMetadata: Equatable {
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
        game = sqliteAGSCText(statement, firstColumn)
        song = sqliteAGSCText(statement, firstColumn + 1)
        system = sqliteAGSCText(statement, firstColumn + 2)
        author = sqliteAGSCText(statement, firstColumn + 3)
        comment = sqliteAGSCText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveAGSCRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveAGSCMetadata?

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveAGSCMetadata.init)
    }

    init(statement: OpaquePointer) {
        trackIndex = Int(sqlite3_column_int64(statement, 2))
        trackCount = Int(sqlite3_column_int64(statement, 3))
        metadata = LiveAGSCMetadata(statement: statement, firstColumn: 4)
    }

    var description: String {
        "index=\(trackIndex)/\(trackCount), metadata=\(String(describing: metadata))"
    }
}

private struct LiveAGSCFile {
    let entryPath: String
    let row: LiveAGSCRow
}

private struct LiveAGSCArchive {
    let path: String
    var files: [LiveAGSCFile]
}

private func readLiveAGSCArchives(databaseURL: URL, rootID: Int) throws -> [LiveAGSCArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the AGSC catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongAGSCParity", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'agsc'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongAGSCParity", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongAGSCParity", code: 3)
    }

    var archives: [LiveAGSCArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteAGSCText(statement, 0)
        let file = LiveAGSCFile(entryPath: sqliteAGSCText(statement, 1), row: LiveAGSCRow(statement: statement))
        if let index = indexes[path] {
            archives[index].files.append(file)
        } else {
            indexes[path] = archives.count
            archives.append(LiveAGSCArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongAGSCParity", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeAGSCEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteAGSCText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func makeAGSCScannerFixture() -> Data {
    var header = Data(repeating: 0, count: 0x20 + 4 + 0x28)
    let sampleCount: UInt32 = 14
    setAGSCScanner32(0, in: &header, at: 4)
    header[0x0E] = 0x1B
    header[0x0F] = 0x58
    setAGSCScanner32(sampleCount, in: &header, at: 0x10)
    setAGSCScanner32(0, in: &header, at: 0x14)
    setAGSCScanner32(0, in: &header, at: 0x18)
    setAGSCScanner32(0x20 + 4 - 8, in: &header, at: 0x1C)
    setAGSCScanner32(UInt32.max, in: &header, at: 0x20)

    var data = Data()
    appendAGSCScanner32(1, to: &data)
    data.append(contentsOf: "FrontEndMusic\0".utf8)
    data.append(contentsOf: [0, 1])
    appendAGSCScanner32(0, to: &data)
    appendAGSCScanner32(0, to: &data)
    appendAGSCScanner32(UInt32(header.count), to: &data)
    appendAGSCScanner32(8, to: &data)
    data.append(header)
    data.append(Data(repeating: 0, count: 8))
    return data
}

private func appendAGSCScanner32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value >> 24))
    data.append(UInt8(truncatingIfNeeded: value >> 16))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
    data.append(UInt8(truncatingIfNeeded: value))
}

private func setAGSCScanner32(_ value: UInt32, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 24)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 3] = UInt8(truncatingIfNeeded: value)
}
