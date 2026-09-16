import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("Sony SSHD content routing uses MetaMan and preserves non-SSHD ADS fallback")
func sonySSHDRoutingUsesValidatedHeaders() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "ads")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("ads"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("ads") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-sshd-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let knownURL = directory.appendingPathComponent("known.ads")
    let aliasURL = directory.appendingPathComponent("alias.ads")
    try makeSonySSHDTestData().write(to: knownURL)
    try Data("OggS alias".utf8).write(to: aliasURL)

    let directRoute = try #require(registry.route(forPath: knownURL.path, archiveMember: true))
    #expect(directRoute.pluginID == "sshd-direct")
    #expect(directRoute.metadataPolicy == .direct)
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: directRoute))
    let inspection = try await handler.inspect(fileURL: knownURL, route: directRoute)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == "known")
    #expect(inspection.tracks[0].metadata?.comment == "Sony SSHD header")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 10_700)
    #expect(registry.route(forPath: aliasURL.path)?.pluginID == "vgmstream")
}

@Test(
    "Sony SSHD rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_ADS_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_ADS_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare the read-only catalog, direct reader, and decoder."
    )
)
func sonySSHDLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_ADS_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_ADS_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveADSArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "ads",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream Sony SSHD reference",
        supportedExtensions: ["ads"],
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    ))
    let extractor = StandaloneArchiveExtractor()
    var directExact = 0
    var decoderExact = 0
    var directDecoderExact = 0
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
            extraction.members.map { (normalizeADSEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeADSEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved ADS member") }
                continue
            }
            guard let route = registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "sshd-direct",
                  let directHandler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): expected sshd-direct route") }
                continue
            }

            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await directHandler.inspect(fileURL: fileURL, route: route)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let expected = expectedRows.map(LiveADSRow.init).sorted { $0.trackIndex < $1.trackIndex }
            let directRows = directInspection.tracks.map(LiveADSRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if directRows == expected {
                directExact += expected.count
            } else if mismatches.count < 20 {
                mismatches.append("\(entryPath): saved=\(expected), direct=\(directRows)")
            }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoderRows = decoderInspection.tracks.map(LiveADSRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if decoderRows == expected { decoderExact += expected.count }
            if directRows == decoderRows {
                directDecoderExact += expected.count
            } else if mismatches.count < 20 {
                mismatches.append("\(entryPath): direct=\(directRows), vgmstream=\(decoderRows)")
            }
        }
        print("SSHD/ADS parity progress: archive \(archiveIndex + 1)/\(archives.count), \(archive.files.count) catalog rows")
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) vgmstream rows match saved metadata")
    #expect(directDecoderExact == totalRows, "\(directDecoderExact)/\(totalRows) direct rows match vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(
        String(format: "SSHD/ADS corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file", totalRows, fileCount, directExact, decoderExact, directDecoderExact, directAverageMs, decoderAverageMs)
    )
}

private struct LiveADSMetadata: Equatable {
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
        game = sqliteADSText(statement, firstColumn)
        song = sqliteADSText(statement, firstColumn + 1)
        system = sqliteADSText(statement, firstColumn + 2)
        author = sqliteADSText(statement, firstColumn + 3)
        comment = sqliteADSText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveADSRow: Equatable {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveADSMetadata?

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveADSMetadata.init)
    }

    init(_ file: LiveADSFile) {
        trackIndex = file.trackIndex
        trackCount = file.trackCount
        metadata = file.metadata
    }
}

private struct LiveADSFile {
    let entryPath: String
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveADSMetadata
}

private struct LiveADSArchive {
    let path: String
    var files: [LiveADSFile]
}

private func readLiveADSArchives(databaseURL: URL, rootID: Int) throws -> [LiveADSArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the ADS catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongADSTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'ads'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongADSTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongADSTests", code: 3)
    }

    var archives: [LiveADSArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteADSText(statement, 0)
        let file = LiveADSFile(
            entryPath: sqliteADSText(statement, 1),
            trackIndex: Int(sqlite3_column_int64(statement, 2)),
            trackCount: Int(sqlite3_column_int64(statement, 3)),
            metadata: LiveADSMetadata(statement: statement, firstColumn: 4)
        )
        if let index = indexes[path] {
            archives[index].files.append(file)
        } else {
            indexes[path] = archives.count
            archives.append(LiveADSArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongADSTests", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeADSEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteADSText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func makeSonySSHDTestData() -> Data {
    var data = Data(repeating: 0x55, count: 0x28 + 32_000)
    data.replaceSubrange(0..<4, with: Data("SShd".utf8))
    putUInt32LE(0x18, into: &data, at: 0x04)
    putUInt32LE(0x02, into: &data, at: 0x08)
    putUInt32LE(48_000, into: &data, at: 0x0C)
    putUInt32LE(2, into: &data, at: 0x10)
    putUInt32LE(0x20, into: &data, at: 0x14)
    putUInt32LE(1_600, into: &data, at: 0x18)
    putUInt32LE(UInt32.max, into: &data, at: 0x1C)
    data.replaceSubrange(0x20..<0x24, with: Data("SSbd".utf8))
    putUInt32LE(32_000, into: &data, at: 0x24)
    return data
}

private func putUInt32LE(_ value: UInt32, into data: inout Data, at offset: Int) {
    data.replaceSubrange(
        offset..<(offset + 4),
        with: [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8(value >> 24)
        ]
    )
}
