import Darwin
import FavoriteStoreCore
import Foundation

public struct PlaybackHistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let timestampMilliseconds: Int64
    public let snapshot: FavoriteTrackSnapshot

    public init(
        id: String = UUID().uuidString,
        timestampMilliseconds: Int64,
        snapshot: FavoriteTrackSnapshot
    ) {
        self.id = id
        self.timestampMilliseconds = timestampMilliseconds
        self.snapshot = snapshot
    }

    public static func timestampText(for milliseconds: Int64, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy.MM.dd-HH.mm.ss.SSS"
        return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1_000))
    }
}

public enum PlaybackHistoryStoreError: LocalizedError {
    case lock(String)
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case .lock(let path): "Could not lock playback history at \(path)."
        case .unsupportedSchema(let version): "Playback history schema \(version) is newer than this application supports."
        }
    }
}

/// Shared append-only playback history persisted as one coordinated JSON file.
/// The sidecar lock serializes read-modify-write operations across the player apps.
public final class PlaybackHistoryStore: @unchecked Sendable {
    public static let schemaVersion = 1
    public let fileURL: URL

    private let lockURL: URL
    private static let localLock = NSLock()

    public init(fileURL: URL = PlaybackHistoryStore.defaultFileURL()) throws {
        self.fileURL = fileURL.standardizedFileURL
        self.lockURL = self.fileURL.appendingPathExtension("lock")
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )) ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )
        return base
            .appendingPathComponent("VGMMan", isDirectory: true)
            .appendingPathComponent("PlaybackHistory.json", isDirectory: false)
    }

    public func records() throws -> [PlaybackHistoryRecord] {
        try withExclusiveLock { try readDocument().entries }
    }

    @discardableResult
    public func record(
        _ snapshot: FavoriteTrackSnapshot,
        at date: Date = Date()
    ) throws -> PlaybackHistoryRecord {
        try withExclusiveLock {
            var document = try readDocument()
            let record = PlaybackHistoryRecord(
                timestampMilliseconds: Int64((date.timeIntervalSince1970 * 1_000).rounded()),
                snapshot: snapshot
            )
            document.entries.insert(record, at: 0)
            document.entries = Self.newestFirst(document.entries)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(document)
            try data.write(to: fileURL, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return record
        }
    }

    private func readDocument() throws -> PlaybackHistoryDocument {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PlaybackHistoryDocument(entries: [])
        }
        let document = try JSONDecoder().decode(PlaybackHistoryDocument.self, from: Data(contentsOf: fileURL))
        guard document.schemaVersion <= Self.schemaVersion else {
            throw PlaybackHistoryStoreError.unsupportedSchema(document.schemaVersion)
        }
        guard document.schemaVersion == Self.schemaVersion else {
            return PlaybackHistoryDocument(entries: document.entries)
        }
        return PlaybackHistoryDocument(entries: Self.newestFirst(document.entries))
    }

    private func withExclusiveLock<T>(_ operation: () throws -> T) throws -> T {
        Self.localLock.lock()
        defer { Self.localLock.unlock() }

        let descriptor = lockURL.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR, mode_t(S_IRUSR | S_IWUSR))
        }
        guard descriptor >= 0 else {
            throw PlaybackHistoryStoreError.lock(lockURL.path)
        }
        defer { _ = Darwin.close(descriptor) }
        var fileLock = Darwin.flock()
        fileLock.l_type = Int16(F_WRLCK)
        fileLock.l_whence = Int16(SEEK_SET)
        fileLock.l_start = 0
        fileLock.l_len = 0
        guard Darwin.fcntl(descriptor, F_SETLKW, &fileLock) == 0 else {
            throw PlaybackHistoryStoreError.lock(lockURL.path)
        }
        defer {
            fileLock.l_type = Int16(F_UNLCK)
            _ = Darwin.fcntl(descriptor, F_SETLK, &fileLock)
        }
        return try operation()
    }

    private static func newestFirst(_ records: [PlaybackHistoryRecord]) -> [PlaybackHistoryRecord] {
        records.enumerated().sorted { lhs, rhs in
            lhs.element.timestampMilliseconds == rhs.element.timestampMilliseconds
                ? lhs.offset < rhs.offset
                : lhs.element.timestampMilliseconds > rhs.element.timestampMilliseconds
        }.map(\.element)
    }
}

private struct PlaybackHistoryDocument: Codable {
    var schemaVersion = PlaybackHistoryStore.schemaVersion
    var entries: [PlaybackHistoryRecord]
}
