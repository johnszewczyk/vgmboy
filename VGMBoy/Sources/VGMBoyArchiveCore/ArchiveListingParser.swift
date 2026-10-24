import Foundation

public struct ArchiveListing: Sendable, Equatable {
    public let entries: [String]
    public let scanSignature: String?

    public init(entries: [String], scanSignature: String?) {
        self.entries = entries
        self.scanSignature = scanSignature
    }
}

public enum ArchiveListingParserError: Error, Equatable, Sendable {
    case outputLimitExceeded
    case entryCountLimitExceeded
    case entryNameLimitExceeded(String)
    case invalidListing
}

/// Pure bounded parsers for archive-tool listing output. Process execution,
/// executable discovery, and frontend error vocabulary remain outside this
/// type.
public enum ArchiveListingParser {
    public static let maximumOutputBytes = 64 * 1024 * 1024
    public static let maximumEntries = 250_000
    public static let maximumEntryNameBytes = 32 * 1024

    public static func parseSevenZipReport(_ data: Data) throws -> ArchiveListing {
        try validateOutput(data)
        let report = String(decoding: data, as: UTF8.self)
        let entries: [String] = report
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let value = String(line)
                guard value.hasPrefix("Path = ") else { return nil }
                return String(value.dropFirst("Path = ".count))
            }
        return try validated(
            entries: entries,
            scanSignature: report.isEmpty ? nil : "7zz-report:\n\(report)"
        )
    }

    public static func parseTarListing(_ data: Data) throws -> ArchiveListing {
        try validateOutput(data)
        return try validated(entries: tarListingEntryPaths(from: data), scanSignature: nil)
    }

    public static func parseRSNListing(_ data: Data) throws -> ArchiveListing {
        try validateOutput(data)
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let contents = object["lsarContents"] as? [[String: Any]]
        else {
            throw ArchiveListingParserError.invalidListing
        }
        return try validated(
            entries: contents.compactMap { $0["XADFileName"] as? String },
            scanSignature: nil
        )
    }

    public static func validate(
        entries: [String],
        scanSignature: String?
    ) throws -> ArchiveListing {
        try validated(entries: entries, scanSignature: scanSignature)
    }

    private static func validateOutput(_ data: Data) throws {
        guard data.count <= maximumOutputBytes else {
            throw ArchiveListingParserError.outputLimitExceeded
        }
    }

    private static func validated(
        entries: [String],
        scanSignature: String?
    ) throws -> ArchiveListing {
        guard entries.count <= maximumEntries else {
            throw ArchiveListingParserError.entryCountLimitExceeded
        }
        if let oversized = entries.first(where: { $0.utf8.count > maximumEntryNameBytes }) {
            throw ArchiveListingParserError.entryNameLimitExceeded(String(oversized.prefix(80)))
        }
        return ArchiveListing(entries: entries, scanSignature: scanSignature)
    }

    /// Keeps valid UTF-8 intact and renders malformed pathname bytes using
    /// BSD tar's reversible octal display form.
    private static func tarListingEntryPaths(from data: Data) -> [String] {
        data.split(separator: 0x0A, omittingEmptySubsequences: true).map { line in
            var output = ""
            var index = line.startIndex
            while index < line.endIndex {
                var decoded: String?
                for length in 1...4 where line.distance(from: index, to: line.endIndex) >= length {
                    let end = line.index(index, offsetBy: length)
                    if let string = String(bytes: line[index..<end], encoding: .utf8),
                       string.utf8.count == length {
                        decoded = string
                        index = end
                        break
                    }
                }
                if let decoded {
                    output.append(decoded)
                } else {
                    output += String(format: "\\%03o", line[index])
                    index = line.index(after: index)
                }
            }
            return output
        }
    }
}
