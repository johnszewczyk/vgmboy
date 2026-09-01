import Darwin
import Foundation
import SQLite3
import Testing
import zlib
@testable import ScanSongKit

enum SchedulerTestError: Error {
    case expected
}
final class ProgressCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var captured: [CatalogScanProgress] = []

    func append(_ update: CatalogScanProgress) {
        lock.withLock { captured.append(update) }
    }

    func values() -> [CatalogScanProgress] {
        lock.withLock { captured }
    }
}

func createCanonicalCatalog(at url: URL) throws {
    var database: OpaquePointer?
    guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
        throw NSError(domain: "ScanSongTests", code: 1)
    }
    defer { sqlite3_close(database) }
    let statements = [
        "PRAGMA user_version = 23;",
        "CREATE TABLE library_roots (id INTEGER PRIMARY KEY, is_attached INTEGER NOT NULL);",
        "CREATE TABLE tracks (id INTEGER PRIMARY KEY);",
        "CREATE TABLE track_metadata (track_id INTEGER PRIMARY KEY);",
        "CREATE TABLE scan_items (id INTEGER PRIMARY KEY);",
        "CREATE TABLE scan_staging_roots (id INTEGER PRIMARY KEY);",
        "CREATE TABLE scan_source_checkpoints (id INTEGER PRIMARY KEY);",
        "CREATE TABLE dead_sources (id INTEGER PRIMARY KEY);",
        "CREATE TABLE game_sidebar_buckets (id INTEGER PRIMARY KEY);",
        "CREATE TABLE file_sidebar_buckets (id INTEGER PRIMARY KEY);",
        "INSERT INTO library_roots (id, is_attached) VALUES (1, 1), (2, 0);",
        "INSERT INTO tracks (id) VALUES (1), (2);"
    ]
    for statement in statements {
        guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
            throw NSError(
                domain: "ScanSongTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
            )
        }
    }
}

func querySingleRow(database: OpaquePointer, sql: String) throws -> [String] {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
        throw NSError(
            domain: "ScanSongTests",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))]
        )
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
        throw NSError(domain: "ScanSongTests", code: 4)
    }
    return (0..<sqlite3_column_count(statement)).map { index in
        sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
    }
}

func makeSPCFile(id666Flag: UInt8) -> Data {
    var data = Data(repeating: 0, count: 0x10200)
    data.replaceSubrange(0..<27, with: Data("SNES-SPC700 Sound File Data".utf8))
    data[0x23] = id666Flag
    return data
}

func writeBytes(_ data: inout Data, at offset: Int, value: String) {
    let bytes = Array(value.utf8)
    data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
}

func writeSPCTestFile(_ data: Data, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-\(UUID().uuidString)-\(name)")
    try data.write(to: url)
    return url
}

func makeXID6Chunk(items: [[UInt8]]) -> Data {
    let payload = items.flatMap { $0 }
    var chunk = Data("xid6".utf8)
    chunk.append(contentsOf: littleEndianBytes(UInt32(payload.count)))
    chunk.append(contentsOf: payload)
    return chunk
}

func makeXID6Item(id: UInt8, type: UInt8, payload: [UInt8]) -> [UInt8] {
    var item = [id, type, UInt8(payload.count & 0xFF), UInt8((payload.count >> 8) & 0xFF)]
    if type != 0 {
        item.append(contentsOf: payload)
        item.append(contentsOf: repeatElement(0, count: (4 - (payload.count % 4)) % 4))
    }
    return item
}

func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
}

func writeLittleEndian(_ data: inout Data, at offset: Int, value: UInt32) {
    data.replaceSubrange(offset..<(offset + 4), with: littleEndianBytes(value))
}

func writeGZip(_ data: Data, to url: URL) throws {
    guard let handle = gzopen(url.path, "wb") else {
        throw NSError(domain: "ScanSongTests", code: 1)
    }
    defer { _ = gzclose(handle) }
    let written = data.withUnsafeBytes { bytes in
        gzwrite(handle, bytes.baseAddress, UInt32(data.count))
    }
    guard written == data.count else {
        throw NSError(domain: "ScanSongTests", code: 2)
    }
}
