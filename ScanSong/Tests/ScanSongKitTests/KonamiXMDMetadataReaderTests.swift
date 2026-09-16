import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("Konami XMD content routing uses MetaMan only for validated v1/v2 layouts")
func konamiXMDContentRoutingUsesValidatedLayouts() async throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "xmd")?.pluginID == "vgmstream")

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-xmd-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for (name, data) in [("silent-hill.xmd", makeXMDV1()), ("castlevania.xmd", makeXMDV2())] {
        let fileURL = directory.appendingPathComponent(name)
        try data.write(to: fileURL)
        let route = try #require(registry.route(forPath: fileURL.path, archiveMember: true))
        #expect(route.pluginID == "xmd-direct")
        #expect(route.metadataPolicy == .direct)
        let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
        let inspection = try await handler.inspect(fileURL: fileURL, route: route)
        #expect(inspection.tracks.count == 1)
        #expect(inspection.tracks[0].trackIndex == 0)
        #expect(inspection.tracks[0].trackCount == 1)
        #expect(inspection.tracks[0].metadata?.comment == "Konami XMD header")

        if ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil,
           let decoderRoute = registry.route(pathExtension: "xmd", archiveMember: true),
           let decoderHandler = BuiltInFormatInspectors.registry.handler(for: decoderRoute) {
            let decoderInspection = try await decoderHandler.inspect(fileURL: fileURL, route: decoderRoute)
            #expect(decoderInspection.tracks.map(LiveXMDRow.init) == inspection.tracks.map(LiveXMDRow.init))
        }
    }

    let aliasURL = directory.appendingPathComponent("alias.xmd")
    try Data("unrecognized XMD alias".utf8).write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path)?.pluginID == "vgmstream")
}

@Test(
    "Konami XMD direct extraction matches saved vgmstream catalog rows",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_XMD_LIVE_DB"] != nil,
        "Set SCANSONG_XMD_LIVE_DB to compare direct XMD extraction with the read-only saved catalog."
    )
)
func konamiXMDLiveCatalogRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_XMD_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_XMD_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveXMDArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!archives.isEmpty)

    let registry = BuiltInScannerPlugins.registry
    let extractor = StandaloneArchiveExtractor()
    let decoderCLIAvailable = ProcessInfo.processInfo.environment["SCANSONG_VGMSTREAM_CLI"] != nil
    let decoderRoute = registry.route(pathExtension: "xmd", archiveMember: true)
    let decoderHandler = decoderCLIAvailable
        ? decoderRoute.flatMap { BuiltInFormatInspectors.registry.handler(for: $0) }
        : nil
    var exactRows = 0
    var decoderExactRows = 0
    var directFiles = 0
    var mismatches: [String] = []
    var directDurationsMs: [Double] = []
    var decoderDurationsMs: [Double] = []
    let sourceFileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }

    for archive in archives {
        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: registry
        )
        defer { extractor.discard(extraction) }
        let members = Dictionary(
            extraction.members.map { (normalizeXMDEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeXMDEntry(entryPath)] else {
                if mismatches.count < 20 {
                    mismatches.append("\(entryPath): archive extractor omitted saved XMD member")
                }
                continue
            }
            let route = registry.route(forPath: fileURL.path, archiveMember: true)
            guard let route, route.pluginID == "xmd-direct",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 20 {
                    mismatches.append("\(entryPath): expected xmd-direct, got \(route?.pluginID ?? "none")")
                }
                continue
            }

            directFiles += 1
            let directStart = ProcessInfo.processInfo.systemUptime
            let inspection = try await handler.inspect(fileURL: fileURL, route: route)
            directDurationsMs.append((ProcessInfo.processInfo.systemUptime - directStart) * 1_000)
            let expected = expectedRows.map(LiveXMDRow.init).sorted { $0.trackIndex < $1.trackIndex }
            let actual = inspection.tracks.map(LiveXMDRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if actual == expected {
                exactRows += expected.count
            } else if mismatches.count < 20 {
                mismatches.append("\(entryPath): saved=\(expected), direct=\(actual)")
            }

            if let decoderRoute, let decoderHandler {
                let decoderStart = ProcessInfo.processInfo.systemUptime
                let decoderInspection = try await decoderHandler.inspect(fileURL: fileURL, route: decoderRoute)
                decoderDurationsMs.append((ProcessInfo.processInfo.systemUptime - decoderStart) * 1_000)
                let decoderRows = decoderInspection.tracks.map(LiveXMDRow.init).sorted { $0.trackIndex < $1.trackIndex }
                if decoderRows == expected {
                    decoderExactRows += expected.count
                } else if mismatches.count < 20 {
                    mismatches.append("\(entryPath): saved=\(expected), vgmstream=\(decoderRows)")
                }
            }
        }
    }

    #expect(exactRows == sourceFileCount, "\(exactRows)/\(sourceFileCount) direct rows match saved metadata")
    #expect(directFiles == sourceFileCount)
    if decoderHandler != nil {
        #expect(decoderExactRows == sourceFileCount, "\(decoderExactRows)/\(sourceFileCount) vgmstream rows match saved metadata")
    }
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))

    let directStats = latencySummary(directDurationsMs)
    let decoderStats = latencySummary(decoderDurationsMs)
    if decoderHandler != nil {
        print("XMD live parity: \(exactRows)/\(sourceFileCount) direct and \(decoderExactRows)/\(sourceFileCount) vgmstream exact; direct median/p95 \(directStats.median)/\(directStats.p95) ms; vgmstream median/p95 \(decoderStats.median)/\(decoderStats.p95) ms")
    } else {
        print("XMD live parity: \(exactRows)/\(sourceFileCount) direct exact; direct median/p95 \(directStats.median)/\(directStats.p95) ms; no vgmstream CLI configured")
    }
}

private struct LiveXMDRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata?

    init(_ row: LiveXMDFile) {
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

private struct LiveXMDFile {
    let entryPath: String
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata
}

private struct LiveXMDArchive {
    let path: String
    var files: [LiveXMDFile]
}

private func readLiveXMDArchives(databaseURL: URL, rootID: Int) throws -> [LiveXMDArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the XMD catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongXMDTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'xmd'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(domain: "ScanSongXMDTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongXMDTests", code: 3)
    }

    var archives: [LiveXMDArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteXMDText(statement, 0)
        let file = LiveXMDFile(
            entryPath: sqliteXMDText(statement, 1),
            trackIndex: Int(sqlite3_column_int64(statement, 2)),
            trackCount: Int(sqlite3_column_int64(statement, 3)),
            metadata: ScannerMetadata(
                game: sqliteXMDText(statement, 4),
                song: sqliteXMDText(statement, 5),
                system: sqliteXMDText(statement, 6),
                author: sqliteXMDText(statement, 7),
                comment: sqliteXMDText(statement, 8),
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
            archives.append(LiveXMDArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongXMDTests", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeXMDEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteXMDText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func latencySummary(_ values: [Double]) -> (median: String, p95: String) {
    guard !values.isEmpty else { return ("n/a", "n/a") }
    let sorted = values.sorted()
    let median = sorted[sorted.count / 2]
    let p95 = sorted[min(sorted.count - 1, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)]
    return (String(format: "%.3f", median), String(format: "%.3f", p95))
}

private func makeXMDV1() -> Data {
    var data = Data(repeating: 0, count: 0x0C + 260)
    data[0] = 2
    setXMD16(48_000, in: &data, at: 0x01)
    setXMD32(260, in: &data, at: 0x03)
    data[0x07] = 1
    setXMD32(26, in: &data, at: 0x08)
    return data
}

private func makeXMDV2() -> Data {
    var data = Data(repeating: 0, count: 0x11 + 168)
    data.replaceSubrange(0..<3, with: Data("xmd".utf8))
    data[0x03] = 2
    setXMD16(22_050, in: &data, at: 0x04)
    setXMD32(168, in: &data, at: 0x06)
    data[0x0A] = 1
    setXMD32(42, in: &data, at: 0x0B)
    return data
}

private func setXMD16(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func setXMD32(_ value: UInt32, in data: inout Data, at offset: Int) {
    for index in 0..<4 {
        data[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8))
    }
}
