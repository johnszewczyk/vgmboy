import Foundation
import SQLite3
import Testing
@testable import ScanSongKit

@Test("AHX keeps the decoder fallback while routing valid CRI layouts to MetaMan")
func ahxRoutingUsesContentAwareDirectReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "ahx")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("ahx"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("ahx") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-ahx-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let validURL = directory.appendingPathComponent("dm1.ahx")
    try makeAHX(payloadBytes: 1_600).write(to: validURL)
    let validRoute = try #require(registry.route(forPath: validURL.path, archiveMember: true))
    #expect(validRoute.pluginID == "ahx-direct")
    let directHandler = try #require(BuiltInFormatInspectors.registry.handler(for: validRoute))
    let inspection = try await directHandler.inspect(fileURL: validURL, route: validRoute)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == "dm1")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 80)

    let unknownURL = directory.appendingPathComponent("unknown.ahx")
    try Data(repeating: 0x7F, count: 0x80).write(to: unknownURL)
    #expect(registry.route(forPath: unknownURL.path, archiveMember: true)?.pluginID == "vgmstream")
}

@Test(
    "AHX live rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_AHX_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_AHX_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare the read-only catalog, direct reader, and decoder."
    )
)
func ahxLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_AHX_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_AHX_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveAHXArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "ahx",
        structurePolicy: .knownSingle,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream AHX reference",
        supportedExtensions: ["ahx"],
        structurePolicy: .knownSingle,
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

    for (archiveIndex, archive) in archives.enumerated() {
        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: registry
        )
        defer { extractor.discard(extraction) }
        let members = Dictionary(
            extraction.members.map { (normalizeAHXEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeAHXEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved AHX member") }
                continue
            }
            guard let route = registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "ahx-direct",
                  let directHandler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): expected ahx-direct route") }
                continue
            }

            let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await directHandler.inspect(fileURL: fileURL, route: route)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let direct = directInspection.tracks.map(LiveAHXRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if direct == expected { directExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), direct=\(direct)") }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoded = decoderInspection.tracks.map(LiveAHXRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if decoded == expected { decoderExact += expected.count }
            if direct == decoded { pairedExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): direct=\(direct), vgmstream=\(decoded)") }
        }
        print("AHX parity progress: archive \(archiveIndex + 1)/\(archives.count), \(archive.files.count) catalog rows")
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) vgmstream rows match saved metadata")
    #expect(pairedExact == totalRows, "\(pairedExact)/\(totalRows) direct rows match vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(
        String(format: "AHX corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file", totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs)
    )
}

private struct LiveAHXMetadata: Equatable {
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

    init(statement: OpaquePointer?, firstColumn: Int32) {
        game = sqliteAHXText(statement, firstColumn)
        song = sqliteAHXText(statement, firstColumn + 1)
        system = sqliteAHXText(statement, firstColumn + 2)
        author = sqliteAHXText(statement, firstColumn + 3)
        comment = sqliteAHXText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveAHXRow: Equatable {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveAHXMetadata?

    init(trackIndex: Int, trackCount: Int, metadata: LiveAHXMetadata?) {
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.metadata = metadata
    }

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveAHXMetadata.init)
    }
}

private struct LiveAHXFile {
    let entryPath: String
    let row: LiveAHXRow
}

private struct LiveAHXArchive {
    let path: String
    var files: [LiveAHXFile]
}

private func readLiveAHXArchives(databaseURL: URL, rootID: Int) throws -> [LiveAHXArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the AHX catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongAHXTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)
    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'ahx'
         ORDER BY 1, 2, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongAHXTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongAHXTests", code: 3)
    }

    var archives: [LiveAHXArchive] = []
    var archiveIndices: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let archivePath = sqliteAHXText(statement, 0)
        let entryPath = sqliteAHXText(statement, 1)
        let file = LiveAHXFile(
            entryPath: entryPath,
            row: LiveAHXRow(
                trackIndex: Int(sqlite3_column_int(statement, 2)),
                trackCount: Int(sqlite3_column_int(statement, 3)),
                metadata: LiveAHXMetadata(statement: statement, firstColumn: 4)
            )
        )
        if let index = archiveIndices[archivePath] {
            archives[index].files.append(file)
        } else {
            archiveIndices[archivePath] = archives.count
            archives.append(LiveAHXArchive(path: archivePath, files: [file]))
        }
    }
    return archives
}

private func sqliteAHXText(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private func normalizeAHXEntry(_ value: String) -> String {
    var normalized = value.replacingOccurrences(of: "\\", with: "/")
    while normalized.hasPrefix("./") { normalized.removeFirst(2) }
    return normalized.lowercased()
}

private func makeAHX(payloadBytes: Int) -> Data {
    var data = Data(repeating: 0, count: 0x24 + payloadBytes)
    data[0] = 0x80
    data[1] = 0x00
    data[2] = 0x00
    data[3] = 0x20
    data[4] = 0x10
    data[7] = 0x01
    putUInt32BE(21_819, at: 0x08, in: &data)
    putUInt32BE(123_456, at: 0x0C, in: &data)
    data[0x12] = 0x06
    data[0x1E] = 0x28
    data[0x1F] = 0x63
    data[0x20] = 0x29
    data[0x21] = 0x43
    data[0x22] = 0x52
    data[0x23] = 0x49
    data[0x24] = 0xFF
    data[0x25] = 0xF5
    data[0x26] = 0xE0
    data[0x27] = 0xC0
    return data
}

private func putUInt32BE(_ value: UInt32, at offset: Int, in data: inout Data) {
    data[offset] = UInt8((value >> 24) & 0xFF)
    data[offset + 1] = UInt8((value >> 16) & 0xFF)
    data[offset + 2] = UInt8((value >> 8) & 0xFF)
    data[offset + 3] = UInt8(value & 0xFF)
}
