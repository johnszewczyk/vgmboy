import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("DSP content routing selects the complete MetaMan layout and preserves decoder fallback")
func dspContentRoutingSelectsRecognizedLayoutsOnly() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "dsp")?.pluginID == "vgmstream")
    #expect(registry.route(pathExtension: "thp")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("thp"))

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-dsp-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fixtures: [(String, Data, String)] = [
        ("standard.dsp", makeStandardDSP(), "Nintendo DSP header"),
        ("rs03.dsp", makeRS03(), "Retro Studios RS03 header"),
        ("thp-audio.dsp", makeTHP(), "Nintendo THP header"),
        ("movie.thp", makeTHP(), "Nintendo THP header")
    ]
    for (name, data, expectedComment) in fixtures {
        let fileURL = directory.appendingPathComponent(name)
        try data.write(to: fileURL)
        let route = try #require(registry.route(forPath: fileURL.path, archiveMember: true))
        #expect(route.pluginID == "dsp-direct")
        let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
        let inspection = try await handler.inspect(fileURL: fileURL, route: route)
        #expect(inspection.tracks.count == 1)
        #expect(inspection.tracks[0].trackCount == 1)
        #expect(inspection.tracks[0].metadata?.comment == expectedComment)
    }

    let aliasURL = directory.appendingPathComponent("unrecognized.dsp")
    try Data("unknown DSP alias".utf8).write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path)?.pluginID == "vgmstream")

    let thpAliasURL = directory.appendingPathComponent("unrecognized.thp")
    try Data("not a THP movie".utf8).write(to: thpAliasURL)
    #expect(registry.route(forPath: thpAliasURL.path)?.pluginID == "vgmstream")
}

@Test(
    "DSP extraction matches saved CocoaSpice scanner rows",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_DSP_LIVE_DB"] != nil,
        "Set SCANSONG_DSP_LIVE_DB to compare direct MetaMan rows with the read-only saved scanner catalog."
    )
)
func dspLiveCatalogRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_DSP_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_DSP_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveDSPArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    let requestedEntry = ProcessInfo.processInfo.environment["SCANSONG_DSP_ENTRY"]
    let selectedArchives = archives.compactMap { archive -> LiveDSPArchive? in
        guard let requestedEntry else { return archive }
        let files = archive.files.filter {
            $0.entryPath == requestedEntry
                || URL(fileURLWithPath: $0.entryPath).lastPathComponent == requestedEntry
        }
        return files.isEmpty ? nil : LiveDSPArchive(path: archive.path, files: files)
    }
    #expect(!selectedArchives.isEmpty)

    let extractor = StandaloneArchiveExtractor()
    var exactRows = 0
    var directFiles = 0
    var directRows = 0
    var mismatches: [String] = []
    let sourceFileCount = selectedArchives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }

    for archive in selectedArchives {
        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: BuiltInScannerPlugins.registry
        )
        defer { extractor.discard(extraction) }
        let members = Dictionary(
            extraction.members.map { (normalizeDSPEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeDSPEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extractor omitted saved DSP member") }
                continue
            }
            let route = BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true)
            guard let route, route.pluginID == "dsp-direct",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 {
                    mismatches.append("\(entryPath): expected a direct DSP/RS03/THP route, got \(route?.pluginID ?? "none")")
                }
                continue
            }
            if requestedEntry != nil {
                FileHandle.standardError.write(Data("DSP live probe: \(entryPath) -> \(route.pluginID)\n".utf8))
            }
            directFiles += 1
            let inspection = try await handler.inspect(fileURL: fileURL, route: route)
            let expected = expectedRows.map(LiveDSPRow.init).sorted { $0.trackIndex < $1.trackIndex }
            directRows += expected.count
            let actual = inspection.tracks.map(LiveDSPRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if actual == expected {
                exactRows += expected.count
            } else if mismatches.count < 20 {
                mismatches.append("\(entryPath): expected=\(expected), actual=\(actual)")
            }
        }
    }

    #expect(exactRows == directRows, "\(exactRows)/\(directRows) direct DSP rows exactly match saved catalog metadata")
    #expect(directFiles == sourceFileCount)
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))
    print("DSP live catalog: \(exactRows)/\(directRows) direct rows exact; \(directFiles) files across \(selectedArchives.count) archives")
}

@Test(
    "THP metadata matches the saved catalog and fresh vgmstream inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_THP_LIVE_DB"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
        "Set SCANSONG_THP_LIVE_DB and SCANSONG_VGMSTREAM_CLI to compare direct metadata, the saved catalog, and vgmstream."
    )
)
func thpLiveRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_THP_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_THP_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveDSPArchives(
        databaseURL: URL(fileURLWithPath: databasePath),
        rootID: rootID,
        extensionName: "thp"
    )
    #expect(!archives.isEmpty)

    let decoderRoute = ScannerRoute(
        pluginID: "vgmstream",
        formatExtension: "thp",
        structurePolicy: .enumerate,
        metadataPolicy: .decoder
    )
    let decoder = VGMStreamCLIInspector(descriptor: ScannerPluginDescriptor(
        pluginID: "vgmstream",
        displayName: "vgmstream THP reference",
        supportedExtensions: ["thp"],
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
            extraction.members.map { (normalizeDSPEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeDSPEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extraction omitted saved THP member") }
                continue
            }
            guard let directRoute = BuiltInScannerPlugins.registry.route(
                forPath: fileURL.path,
                archiveMember: true
            ), directRoute.pluginID == "dsp-direct",
                  let directHandler = BuiltInFormatInspectors.registry.handler(for: directRoute) else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): content route did not select MetaMan's THP reader") }
                continue
            }

            let expected = expectedRows.map(LiveDSPRow.init).sorted { $0.trackIndex < $1.trackIndex }
            let directStart = DispatchTime.now().uptimeNanoseconds
            let directInspection = try await directHandler.inspect(fileURL: fileURL, route: directRoute)
            directNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directStart
            let directRows = directInspection.tracks.map(LiveDSPRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if directRows == expected { directExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): direct reader differs from saved catalog: \(directRows)") }

            let decoderStart = DispatchTime.now().uptimeNanoseconds
            let decoderInspection = try await decoder.inspect(fileURL: fileURL, route: decoderRoute)
            decoderNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- decoderStart
            let decoderRows = decoderInspection.tracks.map(LiveDSPRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if decoderRows == expected { decoderExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): fresh vgmstream differs from saved catalog: \(decoderRows)") }
            if directRows == decoderRows { pairedExact += expected.count }
            else if mismatches.count < 20 { mismatches.append("\(entryPath): direct reader differs from fresh vgmstream: \(directRows) vs \(decoderRows)") }
        }
    }

    #expect(directExact == totalRows, "\(directExact)/\(totalRows) direct rows match saved THP metadata")
    #expect(decoderExact == totalRows, "\(decoderExact)/\(totalRows) fresh vgmstream rows match saved THP metadata")
    #expect(pairedExact == totalRows, "\(pairedExact)/\(totalRows) direct rows match fresh vgmstream")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let directAverageMs = Double(directNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let decoderAverageMs = Double(decoderNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(String(
        format: "THP corpus: %d rows / %d files; exact direct/decoder/paired %d/%d/%d; mean direct %.3f ms/file, vgmstream CLI %.3f ms/file",
        totalRows, fileCount, directExact, decoderExact, pairedExact, directAverageMs, decoderAverageMs
    ))
}

private struct LiveDSPRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata?

    init(_ row: LiveDSPFile) {
        trackIndex = row.trackIndex
        trackCount = row.trackCount
        metadata = row.metadata
    }

    init(_ row: ScanTrackMetadata) {
        trackIndex = row.trackIndex
        trackCount = row.trackCount
        metadata = row.metadata
    }

    var description: String {
        "index=\(trackIndex)/\(trackCount), metadata=\(String(describing: metadata))"
    }
}

private struct LiveDSPFile {
    let entryPath: String
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata
}

private struct LiveDSPArchive {
    let path: String
    var files: [LiveDSPFile]
}

private func readLiveDSPArchives(
    databaseURL: URL,
    rootID: Int,
    extensionName: String = "dsp"
) throws -> [LiveDSPArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the DSP catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongDSPTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = ?2
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongDSPTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK,
          extensionName.withCString({ sqlite3_bind_text(statement, 2, $0, -1, SQLITE_TRANSIENT_DSP_TEST) }) == SQLITE_OK else {
        throw NSError(domain: "ScanSongDSPTests", code: 3)
    }

    var archives: [LiveDSPArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteDSPText(statement, 0)
        let file = LiveDSPFile(
            entryPath: sqliteDSPText(statement, 1),
            trackIndex: Int(sqlite3_column_int64(statement, 2)),
            trackCount: Int(sqlite3_column_int64(statement, 3)),
            metadata: ScannerMetadata(
                game: sqliteDSPText(statement, 4),
                song: sqliteDSPText(statement, 5),
                system: sqliteDSPText(statement, 6),
                author: sqliteDSPText(statement, 7),
                comment: sqliteDSPText(statement, 8),
                introLengthMs: Int(sqlite3_column_int64(statement, 9)),
                loopLengthMs: Int(sqlite3_column_int64(statement, 10)),
                playLengthMs: Int(sqlite3_column_int64(statement, 11)),
                fadeLengthMs: Int(sqlite3_column_int64(statement, 12))
            )
        )
        if let index = indexes[path] {
            archives[index].files.append(file)
        } else {
            indexes[path] = archives.count
            archives.append(LiveDSPArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongDSPTests", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeDSPEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteDSPText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func makeStandardDSP() -> Data {
    var data = Data(repeating: 0, count: 0x60 + 64)
    setDSP32(96_000, in: &data, at: 0x00)
    setDSP32(192_000, in: &data, at: 0x04)
    setDSP32(32_000, in: &data, at: 0x08)
    setDSP16(1, in: &data, at: 0x0C)
    setDSP32(1_600, in: &data, at: 0x10)
    setDSP32(16_000, in: &data, at: 0x14)
    setDSP32(2, in: &data, at: 0x18)
    setDSP16(1, in: &data, at: 0x1C)
    return data
}

private func makeRS03() -> Data {
    var data = Data(repeating: 0, count: 0x60 + 0x200)
    data.replaceSubrange(0..<4, with: Data([0x52, 0x53, 0x00, 0x03]))
    setDSP32(2, in: &data, at: 0x04)
    setDSP32(96_000, in: &data, at: 0x08)
    setDSP32(32_000, in: &data, at: 0x0C)
    setDSP16(1, in: &data, at: 0x14)
    setDSP32(1_600, in: &data, at: 0x18)
    setDSP32(9_600, in: &data, at: 0x1C)
    return data
}

private func makeTHP() -> Data {
    var data = Data(repeating: 0, count: 0xA0)
    data.replaceSubrange(0..<4, with: Data([0x54, 0x48, 0x50, 0x00]))
    setDSP32(0x00011000, in: &data, at: 0x04)
    setDSP32(0x1000, in: &data, at: 0x08)
    setDSP32(0x800, in: &data, at: 0x0C)
    setDSP32(1, in: &data, at: 0x14)
    setDSP32(0x20, in: &data, at: 0x18)
    setDSP32(0x20, in: &data, at: 0x1C)
    setDSP32(0x40, in: &data, at: 0x20)
    setDSP32(0x80, in: &data, at: 0x28)
    setDSP32(2, in: &data, at: 0x40)
    data[0x44] = 0x00
    data[0x45] = 0x01
    setDSP32(2, in: &data, at: 0x60)
    setDSP32(32_000, in: &data, at: 0x64)
    setDSP32(64_000, in: &data, at: 0x68)
    return data
}

private func setDSP16(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 1] = UInt8(truncatingIfNeeded: value)
}

private func setDSP32(_ value: UInt32, in data: inout Data, at offset: Int) {
    for index in 0..<4 {
        data[offset + index] = UInt8(truncatingIfNeeded: value >> ((3 - index) * 8))
    }
}

private let SQLITE_TRANSIENT_DSP_TEST = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
