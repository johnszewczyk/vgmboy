import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("Headerless MIB route uses MetaMan and preserves fallback for invalid payloads")
func mibRoutingUsesValidatedHeaderlessReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "mib")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("mib"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("mib") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-mib-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let knownURL = directory.appendingPathComponent("known.mib")
    let aliasURL = directory.appendingPathComponent("alias.mib")
    try makeMIBRouteTestData().write(to: knownURL)
    try Data(repeating: 0xF0, count: 0x40).write(to: aliasURL)

    let directRoute = try #require(registry.route(forPath: knownURL.path, archiveMember: true))
    #expect(directRoute.pluginID == "mib-direct")
    #expect(directRoute.metadataPolicy == .direct)
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: directRoute))
    let inspection = try await handler.inspect(fileURL: knownURL, route: directRoute)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == "known")
    #expect(inspection.tracks[0].metadata?.comment == "Headerless PS-ADPCM raw header")
    #expect(registry.route(forPath: aliasURL.path)?.pluginID == "vgmstream")
}

@Test(
    "Headerless MIB rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_MIB_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_MIB_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare the read-only catalog, direct reader, and decoder."
    )
)
func mibLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_MIB_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_MIB_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveMIBArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "mib",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream headerless MIB reference",
        supportedExtensions: ["mib"],
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

    for (archiveIndex, archive) in archives.enumerated() {
        do {
            let extraction = try await extractor.extractForScan(
                archiveURL: URL(fileURLWithPath: archive.path),
                registry: registry
            )
            defer { extractor.discard(extraction) }
            let members = Dictionary(
                extraction.members.map { (normalizeMIBEntry($0.entryPath), $0.fileURL) },
                uniquingKeysWith: { first, _ in first }
            )

            for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
                .sorted(by: { $0.key < $1.key }) {
                guard let fileURL = members[normalizeMIBEntry(entryPath)] else {
                    if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved MIB member") }
                    continue
                }
                guard let route = registry.route(forPath: fileURL.path, archiveMember: true),
                      route.pluginID == "mib-direct",
                      let directHandler = BuiltInFormatInspectors.registry.handler(for: route) else {
                    if mismatches.count < 20 { mismatches.append("\(entryPath): expected mib-direct route") }
                    continue
                }

                let directStart = DispatchTime.now().uptimeNanoseconds
                let directInspection = try await directHandler.inspect(fileURL: fileURL, route: route)
                directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
                let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
                let direct = directInspection.tracks.map(LiveMIBRow.init).sorted { $0.trackIndex < $1.trackIndex }
                if direct == expected {
                    directExact += expected.count
                } else if mismatches.count < 20 {
                    mismatches.append("\(entryPath): saved=\(expected), direct=\(direct)")
                }

                let decoderStart = DispatchTime.now().uptimeNanoseconds
                let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
                decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
                let decoded = decoderInspection.tracks.map(LiveMIBRow.init).sorted { $0.trackIndex < $1.trackIndex }
                if decoded == expected { decoderExact += expected.count }
                if direct == decoded {
                    pairedExact += expected.count
                } else if mismatches.count < 20 {
                    mismatches.append("\(entryPath): direct=\(direct), vgmstream=\(decoded)")
                }
            }
            print("MIB parity progress: archive \(archiveIndex + 1)/\(archives.count), \(archive.files.count) catalog rows")
        }
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) vgmstream rows match saved metadata")
    #expect(pairedExact == totalRows, "\(pairedExact)/\(totalRows) direct rows match vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(
        String(format: "MIB corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file", totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs)
    )
}

private struct LiveMIBMetadata: Equatable {
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
        game = sqliteMIBText(statement, firstColumn)
        song = sqliteMIBText(statement, firstColumn + 1)
        system = sqliteMIBText(statement, firstColumn + 2)
        author = sqliteMIBText(statement, firstColumn + 3)
        comment = sqliteMIBText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveMIBRow: Equatable {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveMIBMetadata?

    init(trackIndex: Int, trackCount: Int, metadata: LiveMIBMetadata?) {
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.metadata = metadata
    }

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveMIBMetadata.init)
    }
}

private struct LiveMIBFile {
    let entryPath: String
    let row: LiveMIBRow
}

private struct LiveMIBArchive {
    let path: String
    var files: [LiveMIBFile]
}

private func readLiveMIBArchives(databaseURL: URL, rootID: Int) throws -> [LiveMIBArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the MIB catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongMIBTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'mib'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongMIBTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongMIBTests", code: 3)
    }

    var archives: [LiveMIBArchive] = []
    var archiveIndices: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let archivePath = sqliteMIBText(statement, 0)
        let entryPath = sqliteMIBText(statement, 1)
        let file = LiveMIBFile(
            entryPath: entryPath,
            row: LiveMIBRow(
                trackIndex: Int(sqlite3_column_int(statement, 2)),
                trackCount: Int(sqlite3_column_int(statement, 3)),
                metadata: LiveMIBMetadata(statement: statement, firstColumn: 4)
            )
        )
        if let index = archiveIndices[archivePath] {
            archives[index].files.append(file)
        } else {
            archiveIndices[archivePath] = archives.count
            archives.append(LiveMIBArchive(path: archivePath, files: [file]))
        }
    }
    return archives
}

private func sqliteMIBText(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private func normalizeMIBEntry(_ value: String) -> String {
    var normalized = value.replacingOccurrences(of: "\\", with: "/")
    while normalized.hasPrefix("./") { normalized.removeFirst(2) }
    return normalized.lowercased()
}

private func makeMIBRouteTestData() -> Data {
    var data = Data(repeating: 0, count: 40_000)
    for offset in stride(from: 16, to: data.count, by: 16) {
        data[offset] = 0x0C
        data[offset + 1] = 0x02
    }
    for offset in stride(from: 2_592, to: 16_384, by: 16) {
        data[offset] = 0x37
        data[offset + 1] = 0x02
        data[offset + 2] = 0x01
    }
    data[16_384] = 0
    data[16_385] = 0
    data[16_400] = 0x0C
    data[16_401] = 0x06
    data[18_976] = 0x07
    data[18_977] = 0x02
    data[18_978] = 0x02
    data[32_768] = 0x07
    data[32_769] = 0x02
    data[32_770] = 0x03
    return data
}
