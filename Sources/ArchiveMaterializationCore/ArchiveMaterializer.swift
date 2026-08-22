import Foundation

/// A frontend-owned temporary materializer for a catalog-selected archive entry.
///
/// CatalogReader remains responsible for archive identity and membership. The
/// decoder core receives a normal playable file, while this type owns only the
/// short-lived extracted file and removes the previous one before replacement.
public final class ArchiveMaterializer: @unchecked Sendable {
    public static let shared = ArchiveMaterializer()

    private let lock = NSLock()
    private let configuration: ArchiveMaterializerConfiguration
    private var activeDirectory: URL?

    public init(configuration: ArchiveMaterializerConfiguration = .default) {
        self.configuration = configuration
    }

    @discardableResult
    public func materialize(archivePath: String, entry: String) throws -> URL {
        let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ArchiveMaterializationError.missingSource(archiveURL.path)
        }
        guard !entry.isEmpty else { throw ArchiveMaterializationError.invalidEntry }

        release()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(configuration.temporaryDirectoryName, isDirectory: true)
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
            let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount > 0 else { throw ArchiveMaterializationError.emptyOutput }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        lock.lock()
        activeDirectory = directory
        lock.unlock()
        return output
    }

    /// Removes the currently materialized entry, if any.
    public func release() {
        lock.lock()
        let directory = activeDirectory
        activeDirectory = nil
        lock.unlock()
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    private func extractWithBSDTar(archiveURL: URL, entry: String, output: URL) throws {
        let process = Process()
        process.executableURL = try configuration.bsdtarURL()
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
            throw ArchiveMaterializationError.extractFailed(Self.errorText(from: errorPipe))
        }
    }

    private func extractTarZstd(archiveURL: URL, entry: String, output: URL) throws {
        let transport = Pipe()
        let decompressor = Process()
        decompressor.executableURL = try configuration.zstdURL()
        decompressor.arguments = ["-d", "-q", "-c", archiveURL.path]
        decompressor.standardOutput = transport
        let decompressorError = Pipe()
        decompressor.standardError = decompressorError

        let tar = Process()
        tar.executableURL = try configuration.bsdtarURL()
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
            let detail = Self.errorText(from: decompressorError) + Self.errorText(from: tarError)
            throw ArchiveMaterializationError.extractFailed(detail)
        }
    }

    private static func errorText(from pipe: Pipe) -> String {
        String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ArchiveMaterializerConfiguration: Sendable {
    public var temporaryDirectoryName: String
    public var bsdtarCandidates: [String]
    public var zstdCandidates: [String]

    public static let `default` = ArchiveMaterializerConfiguration(
        temporaryDirectoryName: "FrontendCore",
        bsdtarCandidates: ["/usr/bin/bsdtar", "/opt/homebrew/bin/bsdtar", "/usr/local/bin/bsdtar"],
        zstdCandidates: ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
    )

    public init(temporaryDirectoryName: String, bsdtarCandidates: [String], zstdCandidates: [String]) {
        self.temporaryDirectoryName = temporaryDirectoryName
        self.bsdtarCandidates = bsdtarCandidates
        self.zstdCandidates = zstdCandidates
    }

    fileprivate func bsdtarURL() throws -> URL {
        try executableURL(from: bsdtarCandidates, name: "bsdtar")
    }

    fileprivate func zstdURL() throws -> URL {
        try executableURL(from: zstdCandidates, name: "zstd")
    }

    private func executableURL(from candidates: [String], name: String) throws -> URL {
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }
        throw ArchiveMaterializationError.toolUnavailable(name)
    }
}

public enum ArchiveMaterializationError: LocalizedError, Equatable {
    case invalidEntry
    case missingSource(String)
    case emptyOutput
    case toolUnavailable(String)
    case extractFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEntry: return "The catalog archive entry is empty."
        case .missingSource(let path): return "The catalog source is missing: \(path)"
        case .emptyOutput: return "The selected archive entry produced no playable file."
        case .toolUnavailable(let name): return "The archive tool is unavailable: \(name)"
        case .extractFailed(let detail):
            return detail.isEmpty ? "Archive extraction failed." : "Archive extraction failed. \(detail)"
        }
    }
}
