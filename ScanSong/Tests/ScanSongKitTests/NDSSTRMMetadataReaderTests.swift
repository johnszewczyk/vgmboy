import Foundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test("STRM signature routing selects MetaMan only for Nintendo DS streams")
func ndsSTRMRoutingPreservesSharedSuffixAliases() throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "strm")?.pluginID == "vgmstream")
    #expect(!BuiltInScannerPlugins.directVGMStreamExtensions.contains("strm"))
    #expect(registry.descriptors.first(where: { $0.pluginID == "vgmstream" })?.supportedExtensions.contains("strm") == true)

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-nds-strm-route-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let ndsURL = directory.appendingPathComponent("Nintendo.strm")
    try makeNDSSTRM(loopFlag: 1).write(to: ndsURL)
    #expect(registry.route(forPath: ndsURL.path)?.pluginID == "nds-strm-direct")

    let aliasURL = directory.appendingPathComponent("Other.strm")
    try Data("RSTM".utf8 + [UInt8](repeating: 0, count: 100)).write(to: aliasURL)
    #expect(registry.route(forPath: aliasURL.path)?.pluginID == "vgmstream")
}

@Test("NDS STRM direct route projects MetaMan fields into one scanner row")
func ndsSTRMDirectInspectorProjectsMetadata() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-nds-strm-inspect-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("Theme.strm")
    try makeNDSSTRM(loopFlag: 1).write(to: fileURL)
    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)

    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].trackIndex == 0)
    #expect(inspection.tracks[0].trackCount == 1)
    #expect(inspection.tracks[0].metadata?.song == "Theme")
    #expect(inspection.tracks[0].metadata?.comment == "Nintendo STRM header")
    #expect(inspection.tracks[0].metadata?.loopLengthMs == 2_250)
    #expect(inspection.tracks[0].metadata?.playLengthMs == 15_250)
}

@Test(
    "NDS STRM extraction matches saved CocoaSpice scanner rows",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_STRM_LIVE_DB"] != nil,
        "Set SCANSONG_STRM_LIVE_DB to compare direct MetaMan results with read-only saved scanner rows."
    )
)
func ndsSTRMLiveCatalogRowsMatchDirectExtraction() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_STRM_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_STRM_LIVE_ROOT_ID"] ?? "1") ?? 1
    let archives = try readLiveSTRMArchives(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    let requestedEntry = ProcessInfo.processInfo.environment["SCANSONG_STRM_ENTRY"]
    let selectedArchives = requestedEntry.map { entry in
        archives.filter { archive in
            archive.files.contains {
                $0.entryPath == entry || URL(fileURLWithPath: $0.entryPath).lastPathComponent == entry
            }
        }
    } ?? archives
    #expect(!selectedArchives.isEmpty)

    let extractor = StandaloneArchiveExtractor()
    var exactRows = 0
    var directFiles = 0
    var directRows = 0
    var fallbackFiles = 0
    var mismatches: [String] = []
    let sourceFileCount = selectedArchives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }

    for archive in selectedArchives {
        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: BuiltInScannerPlugins.registry
        )
        defer { extractor.discard(extraction) }
        let members = Dictionary(
            extraction.members.map { (normalizeSTRMEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )

        for (entryPath, expectedRows) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeSTRMEntry(entryPath)] else {
                if mismatches.count < 20 { mismatches.append("\(entryPath): archive extractor omitted saved STRM member") }
                continue
            }
            let route = BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true)
            guard let route, route.pluginID == "nds-strm-direct",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                let signature = String(decoding: try Data(contentsOf: fileURL).prefix(4), as: UTF8.self)
                if route?.pluginID == "vgmstream", signature == "RIFF" {
                    fallbackFiles += 1
                    let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
                    let riffSize = readSTRMUInt32LE(data, at: 4)
                    let actualSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.uint64Value
                    let directResult: String
                    do {
                        let document = try MetaManCore.read(data: data, formatHint: "nds-strm-ffta2", displayName: fileURL.lastPathComponent)
                        directResult = "reader accepted \(document.format) with \(document.timing?.playLengthMs ?? -1)ms"
                    } catch {
                        directResult = "reader rejected: \(error.localizedDescription)"
                    }
                    if mismatches.count < 20 {
                        mismatches.append("\(entryPath): RIFF/IMA route stayed on fallback; riffSize=\(riffSize.map(String.init) ?? "nil"), actualSize=\(actualSize.map(String.init) ?? "nil"), \(directResult)")
                    }
                } else if mismatches.count < 20 {
                    mismatches.append("\(entryPath): expected validated NDS STRM or RIFF/vgmstream fallback, got route=\(route?.pluginID ?? "none"), signature=\(signature)")
                }
                continue
            }
            directFiles += 1
            let inspection = try await handler.inspect(fileURL: fileURL, route: route)
            let expected = expectedRows.map(LiveSTRMRow.init).sorted { $0.trackIndex < $1.trackIndex }
            directRows += expected.count
            let actual = inspection.tracks.map(LiveSTRMRow.init).sorted { $0.trackIndex < $1.trackIndex }
            if actual == expected {
                exactRows += expected.count
            } else if mismatches.count < 20 {
                mismatches.append("\(entryPath): direct metadata differs from saved catalog rows: expected=\(expected), actual=\(actual)")
            }
        }
    }

    #expect(exactRows == directRows, "\(exactRows)/\(directRows) direct Nintendo DS STRM rows exactly match saved catalog metadata")
    #expect(directFiles + fallbackFiles == sourceFileCount)
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))
    print("NDS STRM live catalog: \(exactRows)/\(directRows) direct rows exact; \(fallbackFiles) RIFF aliases kept on vgmstream; \(selectedArchives.count) archives")
}

private struct LiveSTRMRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata?

    init(_ row: LiveSTRMFile) {
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

private struct LiveSTRMFile {
    let entryPath: String
    let trackIndex: Int
    let trackCount: Int
    let metadata: ScannerMetadata
}

private struct LiveSTRMArchive {
    let path: String
    var files: [LiveSTRMFile]
}

private func readLiveSTRMArchives(databaseURL: URL, rootID: Int) throws -> [LiveSTRMArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the STRM catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongSTRMTests", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT COALESCE(t.archive_path, t.path), COALESCE(t.archive_entry, t.filename),
               t.track_index, t.track_count, m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE t.root_id = ?1 AND lower(t.extension) = 'strm'
         ORDER BY t.path, t.filename, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw NSError(domain: "ScanSongSTRMTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongSTRMTests", code: 3)
    }

    var archives: [LiveSTRMArchive] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sqliteSTRMText(statement, 0)
        let file = LiveSTRMFile(
            entryPath: sqliteSTRMText(statement, 1),
            trackIndex: Int(sqlite3_column_int64(statement, 2)),
            trackCount: Int(sqlite3_column_int64(statement, 3)),
            metadata: ScannerMetadata(
                game: sqliteSTRMText(statement, 4),
                song: sqliteSTRMText(statement, 5),
                system: sqliteSTRMText(statement, 6),
                author: sqliteSTRMText(statement, 7),
                comment: sqliteSTRMText(statement, 8),
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
            archives.append(LiveSTRMArchive(path: path, files: [file]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongSTRMTests", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return archives
}

private func normalizeSTRMEntry(_ entry: String) -> String {
    entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
}

private func sqliteSTRMText(_ statement: OpaquePointer, _ index: Int32) -> String {
    sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
}

private func readSTRMUInt32LE(_ data: Data, at offset: Int) -> UInt32? {
    guard offset >= 0, offset + 4 <= data.count else { return nil }
    return UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}

private func makeNDSSTRM(loopFlag: UInt8) -> Data {
    let payloadOffset = 0x68
    var data = Data(repeating: 0, count: payloadOffset + 64)
    data.replaceSubrange(0..<4, with: Data("STRM".utf8))
    ndsSTRMSetUInt32BE(0xFFFE0001, in: &data, at: 0x04)
    ndsSTRMSetUInt32LE(UInt32(data.count), in: &data, at: 0x08)
    ndsSTRMSetUInt16LE(0x10, in: &data, at: 0x0C)
    ndsSTRMSetUInt16LE(1, in: &data, at: 0x0E)
    data.replaceSubrange(0x10..<0x14, with: Data("HEAD".utf8))
    ndsSTRMSetUInt32LE(0x50, in: &data, at: 0x14)
    data[0x18] = 1
    data[0x19] = loopFlag
    data[0x1A] = 2
    ndsSTRMSetUInt16LE(32_000, in: &data, at: 0x1C)
    ndsSTRMSetUInt32LE(24_000, in: &data, at: 0x20)
    ndsSTRMSetUInt32LE(96_000, in: &data, at: 0x24)
    ndsSTRMSetUInt32LE(UInt32(payloadOffset), in: &data, at: 0x28)
    ndsSTRMSetUInt32LE(0x2000, in: &data, at: 0x30)
    ndsSTRMSetUInt32LE(0x2000, in: &data, at: 0x38)
    data.replaceSubrange(0x60..<0x64, with: Data("DATA".utf8))
    ndsSTRMSetUInt32LE(64, in: &data, at: 0x64)
    return data
}

private func ndsSTRMSetUInt16LE(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func ndsSTRMSetUInt32LE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for byteIndex in 0..<4 {
        data[offset + byteIndex] = UInt8(truncatingIfNeeded: value >> (byteIndex * 8))
    }
}

private func ndsSTRMSetUInt32BE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for byteIndex in 0..<4 {
        data[offset + byteIndex] = UInt8(truncatingIfNeeded: value >> ((3 - byteIndex) * 8))
    }
}
