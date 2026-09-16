import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("Bink audio route uses MetaMan without the vgmstream fallback")
func binkAudioRoutingUsesDirectReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "bika")?.pluginID == "bink-audio-direct")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("bika"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("bika") == false)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-bika-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let knownURL = directory.appendingPathComponent("known.bika")
    try makeBinkAudioRouteTestData().write(to: knownURL)
    let route = try #require(registry.route(forPath: knownURL.path, archiveMember: true))
    #expect(route.pluginID == "bink-audio-direct")
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: knownURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == "known")
    #expect(inspection.tracks[0].metadata?.comment == "RAD Game Tools Bink header")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 200)
}

@Test(
    "Bink audio rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_BIKA_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_BIKA_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare the read-only catalog, direct reader, and decoder."
    )
)
func binkAudioLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_BIKA_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_BIKA_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveBinkArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "bika",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream Bink audio reference",
        supportedExtensions: ["bika"],
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
                extraction.members.map { (normalizeBinkEntry($0.entryPath), $0.fileURL) },
                uniquingKeysWith: { first, _ in first }
            )

            for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
                .sorted(by: { $0.key < $1.key }) {
                guard let fileURL = members[normalizeBinkEntry(entryPath)] else {
                    if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved BIKA member") }
                    continue
                }
                guard let route = registry.route(forPath: fileURL.path, archiveMember: true),
                      route.pluginID == "bink-audio-direct",
                      let directHandler = BuiltInFormatInspectors.registry.handler(for: route) else {
                    if mismatches.count < 20 { mismatches.append("\(entryPath): expected bink-audio-direct route") }
                    continue
                }

                let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
                let directStart = DispatchTime.now().uptimeNanoseconds
                let directInspection = try await directHandler.inspect(fileURL: fileURL, route: route)
                directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
                let direct = directInspection.tracks.map(LiveBinkRow.init).sorted { $0.trackIndex < $1.trackIndex }
                if direct == expected { directExact += expected.count }
                else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), direct=\(direct)") }

                let decoderStart = DispatchTime.now().uptimeNanoseconds
                let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
                decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
                let decoded = decoderInspection.tracks.map(LiveBinkRow.init).sorted { $0.trackIndex < $1.trackIndex }
                if decoded == expected { decoderExact += expected.count }
                if direct == decoded { pairedExact += expected.count }
                else if mismatches.count < 20 { mismatches.append("\(entryPath): direct=\(direct), vgmstream=\(decoded)") }
            }
            print("BIKA parity progress: archive \(archiveIndex + 1)/\(archives.count), \(archive.files.count) catalog rows")
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
        String(format: "BIKA corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file", totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs)
    )
}

private struct LiveBinkMetadata: Equatable {
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
        game = sqliteBinkText(statement, firstColumn)
        song = sqliteBinkText(statement, firstColumn + 1)
        system = sqliteBinkText(statement, firstColumn + 2)
        author = sqliteBinkText(statement, firstColumn + 3)
        comment = sqliteBinkText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveBinkRow: Equatable {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveBinkMetadata?

    init(trackIndex: Int, trackCount: Int, metadata: LiveBinkMetadata?) {
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.metadata = metadata
    }

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveBinkMetadata.init)
    }
}

private struct LiveBinkFile {
    let entryPath: String
    let row: LiveBinkRow
}

private struct LiveBinkArchive {
    let path: String
    var files: [LiveBinkFile]
}

private func readLiveBinkArchives(databaseURL: URL, rootID: Int) throws -> [LiveBinkArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the BIKA catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongBIKATests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)
    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'bika'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongBIKATests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongBIKATests", code: 3)
    }

    var archives: [LiveBinkArchive] = []
    var archiveIndices: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let archivePath = sqliteBinkText(statement, 0)
        let entryPath = sqliteBinkText(statement, 1)
        let file = LiveBinkFile(
            entryPath: entryPath,
            row: LiveBinkRow(
                trackIndex: Int(sqlite3_column_int(statement, 2)),
                trackCount: Int(sqlite3_column_int(statement, 3)),
                metadata: LiveBinkMetadata(statement: statement, firstColumn: 4)
            )
        )
        if let index = archiveIndices[archivePath] {
            archives[index].files.append(file)
        } else {
            archiveIndices[archivePath] = archives.count
            archives.append(LiveBinkArchive(path: archivePath, files: [file]))
        }
    }
    return archives
}

private func sqliteBinkText(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private func normalizeBinkEntry(_ value: String) -> String {
    var normalized = value.replacingOccurrences(of: "\\", with: "/")
    while normalized.hasPrefix("./") { normalized.removeFirst(2) }
    return normalized.lowercased()
}

private func makeBinkAudioRouteTestData() -> Data {
    let headerEnd = 0x44
    var data = Data(repeating: 0, count: headerEnd + 16)
    data.replaceSubrange(0..<4, with: Data("BIKi".utf8))
    writeBinkLE32(UInt32(data.count - 8), into: &data, at: 0x04)
    writeBinkLE32(1, into: &data, at: 0x08)
    writeBinkLE32(16, into: &data, at: 0x0C)
    writeBinkLE32(1, into: &data, at: 0x10)
    writeBinkLE32(1, into: &data, at: 0x14)
    writeBinkLE32(1, into: &data, at: 0x18)
    writeBinkLE32(30, into: &data, at: 0x1C)
    writeBinkLE32(1, into: &data, at: 0x20)
    writeBinkLE32(0x1000_0000, into: &data, at: 0x24)
    writeBinkLE32(1, into: &data, at: 0x28)
    writeBinkLE32(16, into: &data, at: 0x2C)
    writeBinkLE32(24_000, into: &data, at: 0x30)
    writeBinkLE32(0x1234, into: &data, at: 0x34)
    writeBinkLE32(UInt32(headerEnd), into: &data, at: 0x38)
    writeBinkLE32(UInt32(data.count), into: &data, at: 0x3C)
    writeBinkLE32(12, into: &data, at: headerEnd)
    writeBinkLE32(9_600, into: &data, at: headerEnd + 4)
    return data
}

private func writeBinkLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
