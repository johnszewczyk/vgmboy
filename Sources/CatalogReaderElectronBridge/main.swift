import CatalogReader
import Foundation

private struct GameSelection: Decodable {
    let rootID: Int64
    let name: String
    let system: String

    private enum CodingKeys: String, CodingKey { case rootID = "rootId", name, system }
}

private struct FileSelection: Decodable {
    let rootID: Int64
    let path: String

    private enum CodingKeys: String, CodingKey { case rootID = "rootId", path }
}

private struct FolderSelection: Decodable {
    let rootID: Int64
    let folderPath: String

    private enum CodingKeys: String, CodingKey { case rootID = "rootId", folderPath }
}

private struct RootResponse: Encodable {
    let id: Int64
    let path: String
    let isEnabled: Bool
    let trackCount: Int
}

private struct GameResponse: Encodable {
    let rootID: Int64
    let rootPath: String
    let name: String
    let system: String
    let trackCount: Int
    let rootName: String
    let displayName: String

    private enum CodingKeys: String, CodingKey {
        case rootID = "rootId", rootPath, name, system, trackCount, rootName, displayName
    }
}

private struct FileResponse: Encodable {
    let rootID: Int64
    let rootPath: String
    let folderPath: String
    let path: String
    let isArchive: Bool
    let trackCount: Int
    let rootName: String
    let id: String

    private enum CodingKeys: String, CodingKey {
        case rootID = "rootId", rootPath, folderPath, path, isArchive, trackCount, rootName, id
    }
}

private struct TrackResponse: Encodable {
    let rootPath: String
    let path: String
    let filename: String
    let archivePath: String?
    let archiveEntry: String?
    let trackIndex: Int
    let trackCount: Int
    let fileSize: Int
    let modifiedAt: Double
    let sourceSignature: String?
    let scanVersion: Int
    let metadataTrackID: Int64
    let title: String
    let game: String
    let artist: String
    let system: String
    let playLengthMilliseconds: Int

    private enum CodingKeys: String, CodingKey {
        case rootPath, path, filename, archivePath, archiveEntry, trackIndex, trackCount, fileSize, modifiedAt, sourceSignature, scanVersion
        case metadataTrackID = "metadataTrackId"
        case title, game, artist, system
        case playLengthMilliseconds = "playLengthMs"
    }
}

private struct SummaryResponse: Encodable {
    let path: String
    let trackCount: Int
    let rootCount: Int
}

private struct StorageMetricsResponse: Encodable {
    let databaseBytes: Int64
    let walBytes: Int64
    let sharedMemoryBytes: Int64
}

private func rootDisplayName(_ path: String) -> String {
    let parts = URL(fileURLWithPath: path).pathComponents.filter { $0 != "/" }
    if let audioIndex = parts.lastIndex(of: "audio"), audioIndex + 1 < parts.count {
        return parts[(audioIndex + 1)...].joined(separator: "/")
    }
    return URL(fileURLWithPath: path).lastPathComponent.isEmpty ? path : URL(fileURLWithPath: path).lastPathComponent
}

private func naturalCompare(_ left: String, _ right: String) -> ComparisonResult {
    left.compare(right, options: [.caseInsensitive, .numeric], range: nil, locale: .current)
}

private func encodePayload<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

private func writeOK(_ requestID: String, json: String) {
    let bytes = Array(json.utf8)
    print("OK\t\(requestID)\tjson\t\(bytes.count)")
    print(json)
    fflush(stdout)
}

private func writeError(_ requestID: String, _ error: Error) {
    let message = error.localizedDescription.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ")
    print("ERR\t\(requestID)\t\(message)")
    fflush(stdout)
}

private func decodePayload<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
    guard let data = Data(base64Encoded: text) else {
        throw CatalogReaderError.sqlite("Catalog bridge received malformed request data.")
    }
    return try JSONDecoder().decode(type, from: data)
}

private func trackResponse(_ track: CatalogTrack, rootPaths: [Int64: String]) -> TrackResponse {
    TrackResponse(
        rootPath: rootPaths[track.rootID] ?? "",
        path: track.sourcePath,
        filename: URL(fileURLWithPath: track.sourcePath).lastPathComponent,
        archivePath: track.archivePath,
        archiveEntry: track.archiveEntry,
        trackIndex: track.trackIndex,
        trackCount: track.trackCount,
        fileSize: 0,
        modifiedAt: 0,
        sourceSignature: nil,
        scanVersion: 0,
        metadataTrackID: 1,
        title: track.title,
        game: track.game,
        artist: track.author,
        system: track.system,
        playLengthMilliseconds: track.lengthMilliseconds
    )
}

private func storageBytes(at url: URL) -> Int64 {
    Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
}

private func serve(databasePath: String) throws {
    let catalog = try ReadOnlyCatalog(databaseURL: URL(fileURLWithPath: databasePath))
    let roots = try catalog.roots()
    let rootPaths = Dictionary(uniqueKeysWithValues: roots.map { ($0.id, $0.path) })

    while let line = readLine(strippingNewline: true) {
        let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else { continue }
        let requestID = parts[0]
        let command = parts[1]
        let payload = parts.count == 3 ? parts[2] : ""
        do {
            switch command {
            case "summary":
                writeOK(requestID, json: try encodePayload(SummaryResponse(path: catalog.databaseURL.path, trackCount: try catalog.activeTrackCount(), rootCount: roots.count)))
            case "roots":
                let values = roots.map { RootResponse(id: $0.id, path: $0.path, isEnabled: $0.isEnabled, trackCount: $0.trackCount) }
                writeOK(requestID, json: try encodePayload(values))
            case "games":
                let query = payload.isEmpty ? "" : try decodePayload(payload, as: String.self)
                let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
                let buckets = try catalog.gameBuckets().filter { bucket in
                    let haystack = "\(bucket.game) \(bucket.system)".lowercased()
                    return terms.allSatisfy(haystack.contains)
                }.sorted {
                    naturalCompare($0.game, $1.game) == .orderedAscending
                        || (naturalCompare($0.game, $1.game) == .orderedSame && naturalCompare($0.system, $1.system) == .orderedAscending)
                        || (naturalCompare($0.game, $1.game) == .orderedSame && naturalCompare($0.system, $1.system) == .orderedSame && naturalCompare($0.rootPath, $1.rootPath) == .orderedAscending)
                }
                let duplicateKeys = Dictionary(grouping: buckets, by: { "\($0.game)\u{0}\($0.system)" }).filter { $0.value.count > 1 }.map(\.key)
                let values = buckets.map { bucket in
                    let rootName = rootDisplayName(bucket.rootPath)
                    let key = "\(bucket.game)\u{0}\(bucket.system)"
                    return GameResponse(
                        rootID: bucket.rootID, rootPath: bucket.rootPath, name: bucket.game, system: bucket.system,
                        trackCount: bucket.trackCount, rootName: rootName,
                        displayName: duplicateKeys.contains(key) ? "\(bucket.game) (\(bucket.system.isEmpty ? "Unknown Console" : bucket.system) • \(rootName))" : bucket.game
                    )
                }
                writeOK(requestID, json: try encodePayload(values))
            case "files":
                let values = try catalog.fileBuckets().sorted {
                    naturalCompare($0.rootPath, $1.rootPath) == .orderedAscending
                        || (naturalCompare($0.rootPath, $1.rootPath) == .orderedSame && naturalCompare($0.folderPath, $1.folderPath) == .orderedAscending)
                        || (naturalCompare($0.rootPath, $1.rootPath) == .orderedSame && naturalCompare($0.folderPath, $1.folderPath) == .orderedSame && naturalCompare($0.path, $1.path) == .orderedAscending)
                }.map { bucket in
                    FileResponse(rootID: bucket.rootID, rootPath: bucket.rootPath, folderPath: bucket.folderPath, path: bucket.path,
                                 isArchive: bucket.isArchive, trackCount: bucket.trackCount, rootName: rootDisplayName(bucket.rootPath),
                                 id: "\(bucket.rootID)\u{0}\(bucket.path)")
                }
                writeOK(requestID, json: try encodePayload(values))
            case "game-tracks":
                let selections = try decodePayload(payload, as: [GameSelection].self)
                let tracks = try selections.flatMap { try catalog.tracks(rootID: $0.rootID, game: $0.name, system: $0.system, preferFoldersOverMetadata: false) }
                let values = tracks.sorted { naturalCompare($0.game, $1.game) == .orderedAscending || (naturalCompare($0.game, $1.game) == .orderedSame && naturalCompare($0.title, $1.title) == .orderedAscending) }.map { trackResponse($0, rootPaths: rootPaths) }
                writeOK(requestID, json: try encodePayload(values))
            case "file-tracks":
                let selections = try decodePayload(payload, as: [FileSelection].self)
                let grouped = Dictionary(grouping: selections, by: \.rootID)
                let tracks = try grouped.flatMap { rootID, values in try catalog.tracks(rootID: rootID, sourcePaths: values.map(\.path)) }
                writeOK(requestID, json: try encodePayload(tracks.map { trackResponse($0, rootPaths: rootPaths) }))
            case "folder-tracks":
                let selections = try decodePayload(payload, as: [FolderSelection].self)
                let grouped = Dictionary(grouping: selections, by: \.rootID)
                let tracks = try grouped.flatMap { rootID, values in try catalog.tracks(rootID: rootID, folderPaths: values.map(\.folderPath)) }
                writeOK(requestID, json: try encodePayload(tracks.map { trackResponse($0, rootPaths: rootPaths) }))
            case "storage-metrics":
                let base = catalog.databaseURL
                writeOK(requestID, json: try encodePayload(StorageMetricsResponse(
                    databaseBytes: storageBytes(at: base), walBytes: storageBytes(at: URL(fileURLWithPath: base.path + "-wal")),
                    sharedMemoryBytes: storageBytes(at: URL(fileURLWithPath: base.path + "-shm"))
                )))
            default:
                throw CatalogReaderError.sqlite("Unknown CatalogReader bridge command '\(command)'.")
            }
        } catch {
            writeError(requestID, error)
        }
    }
}

guard CommandLine.arguments.count == 3, CommandLine.arguments[1] == "serve" else {
    fputs("usage: catalog-reader-electron-bridge serve /absolute/path/to/Library.sqlite\n", stderr)
    exit(64)
}

do {
    try serve(databasePath: CommandLine.arguments[2])
} catch {
    fputs("CatalogReader bridge failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
