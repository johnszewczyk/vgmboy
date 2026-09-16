import Foundation
import SQLite3
import Testing
@testable import ScanSongKit

@Test("DVI keeps the decoder fallback while routing valid Konami layouts to MetaMan")
func dviRoutingUsesContentAwareDirectReader() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "dvi")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("dvi"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("dvi") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-dvi-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let validURL = directory.appendingPathComponent("Doom.dvi")
    try makeDVI(sampleCount: 1_600, loopStart: 400).write(to: validURL)
    let validRoute = try #require(registry.route(forPath: validURL.path, archiveMember: true))
    #expect(validRoute.pluginID == "dvi-direct")
    let directHandler = try #require(BuiltInFormatInspectors.registry.handler(for: validRoute))
    let inspection = try await directHandler.inspect(fileURL: validURL, route: validRoute)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == "Doom")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 10_063)

    var idvi = makeDVI(sampleCount: 1_600, loopStart: -1)
    idvi[0] = 0x49
    let aliasURL = directory.appendingPathComponent("capcom.dvi")
    try idvi.write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path, archiveMember: true)?.pluginID == "vgmstream")
}

@Test(
    "DVI live rows match the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_DVI_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_DVI_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare the read-only catalog, direct reader, and decoder."
    )
)
func dviLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_DVI_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_DVI_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveDVIArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "dvi",
        structurePolicy: .knownSingle,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream DVI reference",
        supportedExtensions: ["dvi"],
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
            extraction.members.map { (normalizeDVIEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeDVIEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved DVI member") }
                continue
            }
            guard let route = registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "dvi-direct",
                  let directHandler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): expected dvi-direct route") }
                continue
            }

            let expected = expectedRows.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await directHandler.inspect(fileURL: fileURL, route: route)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let direct = directInspection.tracks.map(LiveDVIRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if direct == expected { directExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): saved=\(expected), direct=\(direct)") }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoded = decoderInspection.tracks.map(LiveDVIRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if decoded == expected { decoderExact += expected.count }
            if direct == decoded { pairedExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): direct=\(direct), vgmstream=\(decoded)") }
        }
        print("DVI parity progress: archive \(archiveIndex + 1)/\(archives.count), \(archive.files.count) catalog rows")
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) vgmstream rows match saved metadata")
    #expect(pairedExact == totalRows, "\(pairedExact)/\(totalRows) direct rows match vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(
        String(format: "DVI corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file", totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs)
    )
}

private struct LiveDVIMetadata: Equatable {
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
        game = sqliteDVIText(statement, firstColumn)
        song = sqliteDVIText(statement, firstColumn + 1)
        system = sqliteDVIText(statement, firstColumn + 2)
        author = sqliteDVIText(statement, firstColumn + 3)
        comment = sqliteDVIText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }
}

private struct LiveDVIRow: Equatable {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveDVIMetadata?

    init(trackIndex: Int, trackCount: Int, metadata: LiveDVIMetadata?) {
        self.trackIndex = trackIndex
        self.trackCount = trackCount
        self.metadata = metadata
    }

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveDVIMetadata.init)
    }
}

private struct LiveDVIFile {
    let entryPath: String
    let row: LiveDVIRow
}

private struct LiveDVIArchive {
    let path: String
    var files: [LiveDVIFile]
}

private func readLiveDVIArchives(databaseURL: URL, rootID: Int) throws -> [LiveDVIArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the DVI catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongDVITests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)
    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'dvi'
         ORDER BY 1, 2, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongDVITests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongDVITests", code: 3)
    }

    var archives: [LiveDVIArchive] = []
    var archiveIndices: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let archivePath = sqliteDVIText(statement, 0)
        let entryPath = sqliteDVIText(statement, 1)
        let file = LiveDVIFile(
            entryPath: entryPath,
            row: LiveDVIRow(
                trackIndex: Int(sqlite3_column_int(statement, 2)),
                trackCount: Int(sqlite3_column_int(statement, 3)),
                metadata: LiveDVIMetadata(statement: statement, firstColumn: 4)
            )
        )
        if let index = archiveIndices[archivePath] {
            archives[index].files.append(file)
        } else {
            archiveIndices[archivePath] = archives.count
            archives.append(LiveDVIArchive(path: archivePath, files: [file]))
        }
    }
    return archives
}

private func sqliteDVIText(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private func normalizeDVIEntry(_ value: String) -> String {
    var normalized = value.replacingOccurrences(of: "\\", with: "/")
    while normalized.hasPrefix("./") { normalized.removeFirst(2) }
    return normalized.lowercased()
}

private func makeDVI(sampleCount: Int, loopStart: Int) -> Data {
    var data = Data(repeating: 0, count: 0x800 + sampleCount)
    data[0] = 0x44
    data[1] = 0x56
    data[2] = 0x49
    data[3] = 0x2E
    putInt32BE(Int32(0x800), at: 0x04, in: &data)
    putInt32BE(Int32(sampleCount), at: 0x08, in: &data)
    putInt32BE(Int32(loopStart), at: 0x0C, in: &data)
    return data
}

private func putInt32BE(_ value: Int32, at offset: Int, in data: inout Data) {
    let bits = UInt32(bitPattern: value)
    data[offset] = UInt8((bits >> 24) & 0xFF)
    data[offset + 1] = UInt8((bits >> 16) & 0xFF)
    data[offset + 2] = UInt8((bits >> 8) & 0xFF)
    data[offset + 3] = UInt8(bits & 0xFF)
}
