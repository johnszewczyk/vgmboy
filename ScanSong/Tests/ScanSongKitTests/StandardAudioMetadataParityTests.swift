import Foundation
import AVFoundation
import MetaManCore
import SQLite3
import Testing
@testable import ScanSongKit

@Test(
    "MetaMan standard-audio results match every saved catalog row",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_STANDARD_AUDIO_LIVE_DB"] != nil,
        "Set SCANSONG_STANDARD_AUDIO_LIVE_DB to compare MetaMan with the read-only live CocoaSpice catalog."
    )
)
func standardAudioMatchesLiveCatalog() async throws {
    let databasePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_STANDARD_AUDIO_LIVE_DB"])
    let archives = try readLiveStandardAudioArchives(databaseURL: URL(fileURLWithPath: databasePath))
    let expectedRowCount = archives.reduce(0) { $0 + $1.files.count }
    #expect(expectedRowCount > 0)

    let extractor = StandaloneArchiveExtractor()
    var exactRows = 0
    var metadataNanoseconds: UInt64 = 0
    var legacyNanoseconds: UInt64 = 0
    var benchmarkFileIndex = 0
    var mismatches: [String] = []

    for archive in archives {
        guard FileManager.default.fileExists(atPath: archive.path) else {
            if mismatches.count < 30 { mismatches.append("Missing source archive: \(archive.path)") }
            continue
        }

        let extraction = try await extractor.extractForScan(
            archiveURL: URL(fileURLWithPath: archive.path),
            registry: BuiltInScannerPlugins.registry
        )
        defer { extractor.discard(extraction) }

        let members = Dictionary(
            extraction.members.map { (normalizeStandardAudioEntry($0.entryPath), $0.fileURL) },
            uniquingKeysWith: { first, _ in first }
        )
        for (entryPath, expected) in Dictionary(grouping: archive.files, by: \.entryPath)
            .sorted(by: { $0.key < $1.key }) {
            guard let fileURL = members[normalizeStandardAudioEntry(entryPath)] else {
                if mismatches.count < 30 {
                    mismatches.append("\(entryPath): archive extraction omitted saved standard-audio member")
                }
                continue
            }
            guard let route = BuiltInScannerPlugins.registry.route(forPath: fileURL.path, archiveMember: true),
                  route.pluginID == "standard-audio",
                  let handler = BuiltInFormatInspectors.registry.handler(for: route) else {
                if mismatches.count < 30 { mismatches.append("\(entryPath): expected standard-audio route") }
                continue
            }

            // Warm both paths before timing, then alternate ordering to reduce
            // filesystem and AVFoundation cache-order bias.
            _ = try await handler.inspect(fileURL: fileURL, route: route)
            _ = try LegacyStandardAudioReference.inspect(fileURL: fileURL)

            var actual: [LiveStandardAudioRow] = []
            var legacy: [LiveStandardAudioRow] = []
            if benchmarkFileIndex.isMultiple(of: 2) {
                let legacyStart = DispatchTime.now().uptimeNanoseconds
                let legacyMetadata = try LegacyStandardAudioReference.inspect(fileURL: fileURL)
                legacyNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- legacyStart
                legacy = [LiveStandardAudioRow(metadata: legacyMetadata)]

                let newStart = DispatchTime.now().uptimeNanoseconds
                let inspection = try await handler.inspect(fileURL: fileURL, route: route)
                metadataNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- newStart
                actual = inspection.tracks.map(LiveStandardAudioRow.init).sorted { $0.trackIndex < $1.trackIndex }
            } else {
                let newStart = DispatchTime.now().uptimeNanoseconds
                let inspection = try await handler.inspect(fileURL: fileURL, route: route)
                metadataNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- newStart
                actual = inspection.tracks.map(LiveStandardAudioRow.init).sorted { $0.trackIndex < $1.trackIndex }

                let legacyStart = DispatchTime.now().uptimeNanoseconds
                let legacyMetadata = try LegacyStandardAudioReference.inspect(fileURL: fileURL)
                legacyNanoseconds &+= DispatchTime.now().uptimeNanoseconds &- legacyStart
                legacy = [LiveStandardAudioRow(metadata: legacyMetadata)]
            }
            benchmarkFileIndex += 1
            let saved = expected.map(\.row).sorted { $0.trackIndex < $1.trackIndex }
            if actual == saved, legacy == saved {
                exactRows += saved.count
            } else if mismatches.count < 30 {
                mismatches.append("\(entryPath): saved=\(saved), MetaMan=\(actual), legacy=\(legacy)")
            }
        }
    }

    #expect(exactRows == expectedRowCount, "\(exactRows)/\(expectedRowCount) catalog rows match MetaMan")
    #expect(mismatches.isEmpty, Comment(rawValue: mismatches.joined(separator: "\n")))
    let fileCount = archives.reduce(0) { $0 + Set($1.files.map(\.entryPath)).count }
    let averageMilliseconds = Double(metadataNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    let legacyAverageMilliseconds = Double(legacyNanoseconds) / Double(max(1, fileCount)) / 1_000_000
    print(String(
        format: "Standard-audio corpus: %d rows / %d files / %d archives; exact MetaMan/legacy=%d; mean MetaMan %.3f ms/file, legacy %.3f ms/file",
        expectedRowCount, fileCount, archives.count, exactRows, averageMilliseconds, legacyAverageMilliseconds
    ))
}

private struct LiveStandardAudioRow: Equatable, CustomStringConvertible {
    let trackIndex: Int
    let trackCount: Int
    let metadata: LiveStandardAudioMetadata?

    init(_ track: ScanTrackMetadata) {
        trackIndex = track.trackIndex
        trackCount = track.trackCount
        metadata = track.metadata.map(LiveStandardAudioMetadata.init)
    }

    init(metadata: ScannerMetadata) {
        trackIndex = 0
        trackCount = 1
        self.metadata = LiveStandardAudioMetadata(metadata)
    }

    init(statement: OpaquePointer) {
        trackIndex = Int(sqlite3_column_int64(statement, 2))
        trackCount = Int(sqlite3_column_int64(statement, 3))
        metadata = LiveStandardAudioMetadata(statement: statement, firstColumn: 4)
    }

    var description: String {
        "index=\(trackIndex)/\(trackCount), metadata=\(String(describing: metadata))"
    }
}

private struct LiveStandardAudioMetadata: Equatable, CustomStringConvertible {
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
        game = sqliteStandardAudioText(statement, firstColumn)
        song = sqliteStandardAudioText(statement, firstColumn + 1)
        system = sqliteStandardAudioText(statement, firstColumn + 2)
        author = sqliteStandardAudioText(statement, firstColumn + 3)
        comment = sqliteStandardAudioText(statement, firstColumn + 4)
        introLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 5))
        loopLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 6))
        playLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 7))
        fadeLengthMs = Int(sqlite3_column_int64(statement, firstColumn + 8))
    }

    var description: String {
        "\(song) [\(playLengthMs) ms, game=\(game), author=\(author)]"
    }
}

private struct LiveStandardAudioFile {
    let entryPath: String
    let row: LiveStandardAudioRow
}

private struct LiveStandardAudioArchive {
    let path: String
    var files: [LiveStandardAudioFile]
}

private func readLiveStandardAudioArchives(databaseURL: URL) throws -> [LiveStandardAudioArchive] {
    var database: OpaquePointer?
    let status = sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil)
    guard status == SQLITE_OK, let database else {
        let detail = database.map { String(cString: sqlite3_errmsg($0)) }
            ?? "SQLite could not open the standard-audio catalog."
        sqlite3_close(database)
        throw NSError(domain: "ScanSongStandardAudioParity", code: 1, userInfo: [NSLocalizedDescriptionKey: detail])
    }
    defer { sqlite3_close(database) }
    sqlite3_busy_timeout(database, 10_000)

    let sql = """
        SELECT coalesce(t.archive_path, t.path), coalesce(t.archive_entry, t.filename),
               t.track_index, t.track_count,
               m.game, m.title, m.system, m.author, m.comment,
               m.intro_length_ms, m.loop_length_ms, m.play_length_ms, m.fade_length_ms
          FROM tracks t
          JOIN track_metadata m ON m.track_id = t.id
         WHERE lower(t.extension) IN ('aif','aiff','flac','m4a','mp3','ogg','wav')
         ORDER BY 1, 2, t.track_index;
        """
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
          let statement else {
        throw NSError(
            domain: "ScanSongStandardAudioParity",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
        )
    }
    defer { sqlite3_finalize(statement) }

    var grouped: [String: [LiveStandardAudioFile]] = [:]
    while sqlite3_step(statement) == SQLITE_ROW {
        let sourcePath = sqliteStandardAudioText(statement, 0)
        let entryPath = sqliteStandardAudioText(statement, 1)
        grouped[sourcePath, default: []].append(
            LiveStandardAudioFile(entryPath: entryPath, row: LiveStandardAudioRow(statement: statement))
        )
    }
    return grouped.keys.sorted().map { LiveStandardAudioArchive(path: $0, files: grouped[$0] ?? []) }
}

private func sqliteStandardAudioText(_ statement: OpaquePointer, _ column: Int32) -> String {
    guard let value = sqlite3_column_text(statement, column) else { return "" }
    return String(cString: value)
}

private func normalizeStandardAudioEntry(_ path: String) -> String {
    path.replacingOccurrences(of: "\\", with: "/").lowercased()
}

/// Frozen test-only copy of the pre-extraction implementation, retained only
/// as an output and speed oracle. Production ScanSong has no standard-audio
/// parser; MetaMan owns that implementation now.
private enum LegacyStandardAudioReference {
    static func inspect(fileURL: URL) throws -> ScannerMetadata {
        let durationMilliseconds = try durationMilliseconds(for: fileURL)
        let asset = AVURLAsset(url: fileURL)
        let values: [String: String] = asset.commonMetadata.reduce(into: [:]) { values, item in
            guard let key = item.commonKey?.rawValue,
                  let value = item.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return }
            values[key] = value
        }
        let flacValues = fileURL.pathExtension.caseInsensitiveCompare("flac") == .orderedSame
            ? (try? flacVorbisComments(fileURL: fileURL)) ?? [:]
            : [:]

        return ScannerMetadata(
            game: flacValues["ALBUM"] ?? values[AVMetadataKey.commonKeyAlbumName.rawValue] ?? "",
            song: flacValues["TITLE"] ?? values[AVMetadataKey.commonKeyTitle.rawValue] ?? "",
            system: "Standard audio",
            author: flacValues["ARTIST"] ?? flacValues["ALBUMARTIST"]
                ?? flacValues["COMPOSER"] ?? values[AVMetadataKey.commonKeyArtist.rawValue]
                ?? values[AVMetadataKey.commonKeyAuthor.rawValue]
                ?? "",
            comment: flacValues["COMMENT"] ?? values[AVMetadataKey.commonKeyDescription.rawValue] ?? "",
            introLengthMs: 0,
            loopLengthMs: 0,
            playLengthMs: durationMilliseconds,
            fadeLengthMs: 0
        )
    }

    private static func durationMilliseconds(for fileURL: URL) throws -> Int {
        if let file = try? AVAudioFile(forReading: fileURL),
           file.processingFormat.sampleRate > 0,
           file.length >= 0 {
            return max(0, Int((Double(file.length) / file.processingFormat.sampleRate * 1_000).rounded()))
        }
        let seconds = AVURLAsset(url: fileURL).duration.seconds
        guard seconds.isFinite, seconds >= 0 else {
            throw MetadataReadError.malformedFile(
                "Core Audio could not determine the duration of \(fileURL.lastPathComponent)."
            )
        }
        return max(0, Int((seconds * 1_000).rounded()))
    }

    private static func flacVorbisComments(fileURL: URL) throws -> [String: String] {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        guard try handle.read(upToCount: 4) == Data("fLaC".utf8) else { return [:] }

        while true {
            guard let header = try handle.read(upToCount: 4), header.count == 4 else { break }
            let isLast = (header[0] & 0x80) != 0
            let blockType = header[0] & 0x7F
            let blockLength = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            guard let block = try handle.read(upToCount: blockLength), block.count == blockLength else { break }
            if blockType == 4 { return parseVorbisCommentBlock(block) }
            if isLast { break }
        }
        return [:]
    }

    private static func parseVorbisCommentBlock(_ block: Data) -> [String: String] {
        var offset = 0
        guard let vendorLength = littleEndianUInt32(block, offset: &offset),
              offset + Int(vendorLength) <= block.count else { return [:] }
        offset += Int(vendorLength)
        guard let commentCount = littleEndianUInt32(block, offset: &offset) else { return [:] }

        var values: [String: String] = [:]
        for _ in 0..<commentCount {
            guard let length = littleEndianUInt32(block, offset: &offset),
                  offset + Int(length) <= block.count else { break }
            let comment = String(decoding: block[offset..<(offset + Int(length))], as: UTF8.self)
            offset += Int(length)
            guard let separator = comment.firstIndex(of: "=") else { continue }
            let key = String(comment[..<separator]).uppercased()
            let value = String(comment[comment.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty { values[key] = value }
        }
        return values
    }

    private static func littleEndianUInt32(_ data: Data, offset: inout Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
        offset += 4
        return value
    }
}
