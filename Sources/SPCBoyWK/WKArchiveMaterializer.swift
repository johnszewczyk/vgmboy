import Foundation

/// Minimal selected-entry materialization for the WK host. The catalog owns
/// archive identity; this host owns only the temporary playable file lifetime.
final class WKArchiveMaterializer: @unchecked Sendable {
    static let shared = WKArchiveMaterializer()

    private let lock = NSLock()
    private var activeDirectory: URL?

    private init() {}

    func materialize(archivePath: String, entry: String) throws -> URL {
        let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw WKArchiveError.missingSource(archiveURL.path)
        }
        guard !entry.isEmpty else { throw WKArchiveError.invalidEntry }

        release()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SPCBoyWK", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let extensionName = URL(fileURLWithPath: entry).pathExtension
        let output = directory.appendingPathComponent("track\(extensionName.isEmpty ? "" : ".\(extensionName)")")

        do {
            if archiveURL.path.lowercased().hasSuffix(".tar.zst") || archiveURL.path.lowercased().hasSuffix(".tar.zstd") {
                try extractTarZstd(archiveURL: archiveURL, entry: entry, output: output)
            } else {
                try extractWithBSDTar(archiveURL: archiveURL, entry: entry, output: output)
            }
            guard FileManager.default.fileExists(atPath: output.path), (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? NSNumber)?.intValue ?? 0 > 0 else {
                throw WKArchiveError.emptyOutput
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        lock.lock()
        activeDirectory = directory
        lock.unlock()
        return output
    }

    func release() {
        lock.lock()
        let directory = activeDirectory
        activeDirectory = nil
        lock.unlock()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func extractWithBSDTar(archiveURL: URL, entry: String, output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        process.arguments = ["-xOf", archiveURL.path, entry]
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: output)
        defer { try? outputHandle.close() }
        process.standardOutput = outputHandle
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw WKArchiveError.extractFailed(String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))
        }
    }

    private func extractTarZstd(archiveURL: URL, entry: String, output: URL) throws {
        let transport = Pipe()
        let decompressor = Process()
        decompressor.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/zstd")
        decompressor.arguments = ["-d", "-q", "-c", archiveURL.path]
        decompressor.standardOutput = transport
        let decompressorError = Pipe()
        decompressor.standardError = decompressorError

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/bsdtar")
        tar.arguments = ["-xOf", "-", entry]
        tar.standardInput = transport
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: output)
        defer { try? outputHandle.close() }
        tar.standardOutput = outputHandle
        let tarError = Pipe()
        tar.standardError = tarError

        try tar.run()
        try decompressor.run()
        decompressor.waitUntilExit()
        tar.waitUntilExit()
        guard decompressor.terminationStatus == 0, tar.terminationStatus == 0 else {
            let detail = String(decoding: decompressorError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                + String(decoding: tarError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw WKArchiveError.extractFailed(detail)
        }
    }
}

private enum WKArchiveError: LocalizedError {
    case invalidEntry
    case missingSource(String)
    case emptyOutput
    case extractFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidEntry: return "The catalog archive entry is empty."
        case .missingSource(let path): return "The catalog source is missing: \(path)"
        case .emptyOutput: return "The selected archive entry produced no playable file."
        case .extractFailed(let detail): return "Archive extraction failed. \(detail.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
    }
}
