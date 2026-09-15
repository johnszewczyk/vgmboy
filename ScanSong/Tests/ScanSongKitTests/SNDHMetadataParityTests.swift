import Foundation
import MetaManCore
import SQLite3
import Testing
import VGMBoySNDH
@testable import ScanSongKit

private struct LiveSNDHTrack {
    let trackIndex: Int
    let trackCount: Int
    let title: String
    let game: String
    let system: String
    let author: String
    let comment: String
    let introLengthMs: Int
    let loopLengthMs: Int
    let playLengthMs: Int
    let fadeLengthMs: Int
}

private struct LiveSNDHFile {
    let path: String
    var tracks: [LiveSNDHTrack]
}

@Test("MetaMan ICE expansion matches the PSGPlay oracle through the scanner route")
func sndhICEExpansionMatchesDecoderAndProductionScanner() async throws {
    let expanded = makeICEParitySNDH()
    #expect(expanded.count == 65)
    let source = makeLiteralICEContainer(expanding: expanded)

    let direct = try MetaManCore.readResult(data: source, formatHint: "sndh", displayName: "packed.sndh")
    let oracle = try SNDHMetadataReader.read(data: source)
    #expect(direct.tracks.count == oracle.tracks.count)
    #expect(direct.tracks.map { $0.document.fields.title ?? "" } == [oracle.tracks[0].subtuneName.isEmpty ? oracle.title : oracle.tracks[0].subtuneName])
    #expect(direct.tracks[0].document.fields.artist == oracle.composer)
    #expect(direct.tracks[0].document.fields.year == oracle.year)
    #expect(direct.tracks[0].document.timing?.playLengthMs == oracle.tracks[0].durationMilliseconds)
    #expect(direct.tracks[0].document.technicalFacts["iceCompressed"] == "true")

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-ice-parity-\(UUID().uuidString).sndh")
    try source.write(to: fileURL, options: .atomic)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks[0].metadata?.song == oracle.title)
    #expect(inspection.tracks[0].metadata?.author == oracle.composer)
    #expect(inspection.tracks[0].metadata?.comment == oracle.year)
    #expect(inspection.tracks[0].metadata?.playLengthMs == oracle.tracks[0].durationMilliseconds)
}

@Test(
    "MetaMan SNDH reader matches the legacy reader and live CocoaSpice catalog",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_SNDH_LIVE_DB"] != nil,
        "Set SCANSONG_SNDH_LIVE_DB to run the read-only SNDH corpus comparison."
    )
)
func sndhReaderMatchesLiveCocoaSpiceCatalog() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_SNDH_LIVE_DB"])
    let rootID = Int(ProcessInfo.processInfo.environment["SCANSONG_SNDH_LIVE_ROOT_ID"] ?? "26") ?? 26
    let files = try readLiveSNDHFiles(databaseURL: URL(fileURLWithPath: databasePath), rootID: rootID)
    #expect(!files.isEmpty)
    let requestedLimit = Int(ProcessInfo.processInfo.environment["SCANSONG_SNDH_LIVE_LIMIT"] ?? "")
    let filesToCompare = Array(files.prefix(max(0, requestedLimit ?? files.count)))

    let extractor = StandaloneArchiveExtractor()
    let registry = BuiltInScannerPlugins.registry
    var comparedFiles = 0
    var comparedTracks = 0
    var exactCatalogFields = 0
    var iceCompressedFiles = 0
    var directNanoseconds: UInt64 = 0
    var oracleNanoseconds: UInt64 = 0
    var directScannerNanoseconds: UInt64 = 0
    var legacyScannerNanoseconds: UInt64 = 0
    var mismatches: [String] = []

    for (fileIndex, file) in filesToCompare.enumerated() {
        let archiveURL = URL(fileURLWithPath: file.path)
        let extracted: ExtractedScanArchive
        do {
            extracted = try await extractor.extractForScan(archiveURL: archiveURL, registry: registry)
        } catch {
            mismatches.append("\(file.path): extraction failed: \(error.localizedDescription)")
            continue
        }
        defer { extractor.discard(extracted) }
        guard extracted.members.count == 1, let member = extracted.members.first else {
            mismatches.append("\(file.path): expected one standalone SNDH member, got \(extracted.members.count)")
            continue
        }

        let sourceReadStarted = DispatchTime.now().uptimeNanoseconds
        let source = try Data(contentsOf: member.fileURL, options: .mappedIfSafe)
        let sourceReadNanoseconds = DispatchTime.now().uptimeNanoseconds &- sourceReadStarted
        let direct: MetadataReadResult
        let oracle: VGMBoySNDH.SNDHMetadata
        var directElapsed: UInt64 = 0
        var oracleElapsed: UInt64 = 0
        if fileIndex.isMultiple(of: 2) {
            var started = DispatchTime.now().uptimeNanoseconds
            direct = try MetaManCore.readResult(data: source, formatHint: "sndh", displayName: member.fileURL.lastPathComponent)
            directElapsed = DispatchTime.now().uptimeNanoseconds &- started
            directNanoseconds &+= directElapsed
            started = DispatchTime.now().uptimeNanoseconds
            oracle = try SNDHMetadataReader.read(data: source)
            oracleElapsed = DispatchTime.now().uptimeNanoseconds &- started
            oracleNanoseconds &+= oracleElapsed
        } else {
            var started = DispatchTime.now().uptimeNanoseconds
            oracle = try SNDHMetadataReader.read(data: source)
            oracleElapsed = DispatchTime.now().uptimeNanoseconds &- started
            oracleNanoseconds &+= oracleElapsed
            started = DispatchTime.now().uptimeNanoseconds
            direct = try MetaManCore.readResult(data: source, formatHint: "sndh", displayName: member.fileURL.lastPathComponent)
            directElapsed = DispatchTime.now().uptimeNanoseconds &- started
            directNanoseconds &+= directElapsed
        }

        let route = member.route
        guard let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
            mismatches.append("\(file.path): no scanner handler for \(route.pluginID)")
            continue
        }
        let legacyProjectionStarted = DispatchTime.now().uptimeNanoseconds
        let legacyInspection = legacySNDHInspection(oracle, route: route)
        let legacyProjectionNanoseconds = DispatchTime.now().uptimeNanoseconds &- legacyProjectionStarted
        legacyScannerNanoseconds &+= sourceReadNanoseconds + oracleElapsed + legacyProjectionNanoseconds
        let inspection: ScanInspection
        let directInspectionStarted = DispatchTime.now().uptimeNanoseconds
        do {
            inspection = try await handler.inspect(fileURL: member.fileURL, route: route)
        } catch {
            mismatches.append("\(file.path): scanner projection failed: \(error.localizedDescription)")
            continue
        }
        directScannerNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- directInspectionStarted

        comparedFiles += 1
        comparedTracks += file.tracks.count
        if direct.tracks.first?.document.technicalFacts["iceCompressed"] == "true" {
            iceCompressedFiles += 1
        }
        guard oracle.tracks.count == file.tracks.count,
              direct.tracks.count == file.tracks.count,
              legacyInspection.tracks.count == file.tracks.count,
              inspection.tracks.count == file.tracks.count else {
            mismatches.append("\(file.path): tracks live/decoder/MetaMan/legacy-route/direct-route = \(file.tracks.count)/\(oracle.tracks.count)/\(direct.tracks.count)/\(legacyInspection.tracks.count)/\(inspection.tracks.count)")
            continue
        }

        for index in file.tracks.indices {
            let live = file.tracks[index]
            let old = oracle.tracks[index]
            let document = direct.tracks[index].document
            let legacyScanner = legacyInspection.tracks[index]
            let scanner = inspection.tracks[index]
            let expectedTitle = old.subtuneName.isEmpty ? oracle.title : old.subtuneName
            let expectedAuthor = oracle.composer
            let expectedYear = oracle.year
            let expectedDuration = max(0, old.durationMilliseconds)
            let directTitle = document.fields.title ?? ""
            let directAuthor = document.fields.artist ?? ""
            let directYear = document.fields.year ?? ""
            let directDuration = max(0, document.timing?.playLengthMs ?? 0)

            let checks: [(String, String, String)] = [
                ("title vs decoder", directTitle, expectedTitle),
                ("author vs decoder", directAuthor, expectedAuthor),
                ("year vs decoder", directYear, expectedYear),
                ("title vs catalog", directTitle, live.title),
                ("game", "", live.game),
                ("system", document.fields.system ?? "", live.system),
                ("author vs catalog", directAuthor, live.author),
                ("comment vs catalog", directYear, live.comment)
            ]
            for (field, actual, expected) in checks {
                if actual == expected {
                    exactCatalogFields += 1
                } else if mismatches.count < 40 {
                    mismatches.append("\(file.path) #\(index) \(field): direct=\(actual.debugDescription), expected=\(expected.debugDescription)")
                }
            }

            let scannerTextParity: [(String, String, String)] = [
                ("scanner title parity", scanner.metadata?.song ?? "", legacyScanner.metadata?.song ?? ""),
                ("scanner author parity", scanner.metadata?.author ?? "", legacyScanner.metadata?.author ?? ""),
                ("scanner comment parity", scanner.metadata?.comment ?? "", legacyScanner.metadata?.comment ?? "")
            ]
            for (field, actual, expected) in scannerTextParity where actual != expected {
                if mismatches.count < 40 {
                    mismatches.append("\(file.path) #\(index) \(field): \(actual.debugDescription) != \(expected.debugDescription)")
                }
            }

            let timingChecks: [(String, Int, Int)] = [
                ("decoder duration", directDuration, expectedDuration),
                ("catalog intro", 0, live.introLengthMs),
                ("catalog loop", 0, live.loopLengthMs),
                ("catalog play", directDuration, live.playLengthMs),
                ("catalog fade", 0, live.fadeLengthMs),
                ("scanner play", scanner.metadata?.playLengthMs ?? -1, directDuration)
            ]
            for (field, actual, expected) in timingChecks where actual != expected {
                if mismatches.count < 40 {
                    mismatches.append("\(file.path) #\(index) \(field): \(actual) != \(expected)")
                }
            }

            if live.trackIndex != index
                || live.trackCount != file.tracks.count
                || scanner.trackIndex != index
                || scanner.trackCount != file.tracks.count {
                if mismatches.count < 40 {
                    mismatches.append("\(file.path) #\(index) track identity/count differs from catalog or scanner")
                }
            }
        }
    }

    let directMilliseconds = Double(directNanoseconds) / 1_000_000
    let oracleMilliseconds = Double(oracleNanoseconds) / 1_000_000
    let directScannerMilliseconds = Double(directScannerNanoseconds) / 1_000_000
    let legacyScannerMilliseconds = Double(legacyScannerNanoseconds) / 1_000_000
    print("SNDH live parity: files=\(comparedFiles)/\(filesToCompare.count) selected of \(files.count), tracks=\(comparedTracks), ICE=\(iceCompressedFiles), exactTextFields=\(exactCatalogFields), MetaManParseMs=\(directMilliseconds), legacyParseMs=\(oracleMilliseconds), directScannerRouteMs=\(directScannerMilliseconds), legacyScannerRouteMs=\(legacyScannerMilliseconds), mismatches=\(mismatches.count)")
    for mismatch in mismatches.prefix(40) { print("SNDH live parity mismatch: \(mismatch)") }
    #expect(comparedFiles == filesToCompare.count)
    #expect(mismatches.isEmpty)
}

private func legacySNDHInspection(
    _ source: VGMBoySNDH.SNDHMetadata,
    route: ScannerRoute
) -> ScanInspection {
    let tracks = source.tracks.map { track in
        let song = track.subtuneName.isEmpty ? source.title : track.subtuneName
        let metadata = ScannerMetadata(
            game: "",
            song: song,
            system: "Atari ST",
            author: source.composer,
            comment: source.year,
            introLengthMs: 0,
            loopLengthMs: 0,
            playLengthMs: max(0, track.durationMilliseconds),
            fadeLengthMs: 0
        )
        return ScanTrackMetadata(
            trackIndex: track.index,
            trackCount: source.tracks.count,
            metadata: metadata
        )
    }
    return ScanInspection(route: route, tracks: tracks)
}

private func readLiveSNDHFiles(databaseURL: URL, rootID: Int) throws -> [LiveSNDHFile] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite could not open the live catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongSNDHParity", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT t.path, t.track_index, t.track_count,
               m.title, m.game, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id=t.id
         WHERE t.root_id=?1 AND lower(t.extension)='sndh'
         ORDER BY t.path, t.track_index
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw NSError(domain: "ScanSongSNDHParity", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_bind_int(statement, 1, Int32(rootID)) == SQLITE_OK else {
        throw NSError(domain: "ScanSongSNDHParity", code: 3)
    }

    var files: [LiveSNDHFile] = []
    var indexes: [String: Int] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let path = sndhSQLiteText(statement, 0)
        let track = LiveSNDHTrack(
            trackIndex: Int(sqlite3_column_int64(statement, 1)),
            trackCount: Int(sqlite3_column_int64(statement, 2)),
            title: sndhSQLiteText(statement, 3),
            game: sndhSQLiteText(statement, 4),
            system: sndhSQLiteText(statement, 5),
            author: sndhSQLiteText(statement, 6),
            comment: sndhSQLiteText(statement, 7),
            introLengthMs: Int(sqlite3_column_int64(statement, 8)),
            loopLengthMs: Int(sqlite3_column_int64(statement, 9)),
            playLengthMs: Int(sqlite3_column_int64(statement, 10)),
            fadeLengthMs: Int(sqlite3_column_int64(statement, 11))
        )
        if let index = indexes[path] {
            files[index].tracks.append(track)
        } else {
            indexes[path] = files.count
            files.append(LiveSNDHFile(path: path, tracks: [track]))
        }
    }
    guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
        throw NSError(domain: "ScanSongSNDHParity", code: 4, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
    return files
}

private func sndhSQLiteText(_ statement: OpaquePointer?, _ column: Int32) -> String {
    guard let pointer = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: pointer)
}

private func makeICEParitySNDH() -> Data {
    var data = Data(repeating: 0, count: 12)
    data.append(contentsOf: "SNDH".utf8)
    appendSNDHStringTag("TITL", value: "Packed", to: &data)
    appendSNDHStringTag("COMM", value: "Coder", to: &data)
    appendSNDHStringTag("YEAR", value: "1994", to: &data)
    data.append(contentsOf: "##01!#1\0TIME".utf8)
    appendSNDHBE16(7, to: &data)
    data.append(contentsOf: "HDNS".utf8)
    data.append(0)
    return data
}

private func makeLiteralICEContainer(expanding payload: Data) -> Data {
    // This reverse ICE bitstream is a single 65-byte literal run. Its 17 code
    // bits are read backward from FF, then CC, then the high two bits of 80.
    var data = Data("ICE!".utf8)
    appendSNDHBE32(UInt32(payload.count + 15), to: &data)
    appendSNDHBE32(UInt32(payload.count), to: &data)
    data.append(payload)
    data.append(contentsOf: [0x80, 0xCC, 0xFF])
    return data
}

private func appendSNDHStringTag(_ name: String, value: String, to data: inout Data) {
    data.append(contentsOf: name.utf8)
    data.append(contentsOf: value.utf8)
    data.append(0)
}

private func appendSNDHBE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value >> 8))
    data.append(UInt8(value & 0xFF))
}

private func appendSNDHBE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8(value & 0xFF))
}
