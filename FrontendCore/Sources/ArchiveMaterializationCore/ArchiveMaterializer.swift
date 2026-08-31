import Foundation
import VGMBoyFormatCore

/// A shared native materializer for a catalog-selected archive entry.
///
/// CatalogReader remains responsible for archive identity and membership. The
/// decoder core receives a normal playable file, while this type owns the
/// dependency-complete temporary directory and removes the previous one
/// before replacement. The format requirement comes from VGMBoyFormatCore;
/// frontends do not interpret decoder dependencies.
public final class ArchiveMaterializer: @unchecked Sendable {
    public static let shared = ArchiveMaterializer()

    private static let psfExtensions: Set<String> = [
        "psf", "minipsf", "psflib", "psf2", "minipsf2", "psf2lib"
    ]

    private let configuration: ArchiveMaterializerConfiguration
    private let processRunner: ArchiveProcessRunner
    private let session: ArchiveMaterializationSession

    public init(
        configuration: ArchiveMaterializerConfiguration = .default,
        session: ArchiveMaterializationSession = ArchiveMaterializationSession()
    ) {
        self.configuration = configuration
        self.session = session
        self.processRunner = ArchiveProcessRunner(configuration: .init(
            environment: ProcessInfo.processInfo.environment,
            temporaryFilePrefix: "FrontendCore-materializer",
            maxConcurrency: max(1, ProcessInfo.processInfo.activeProcessorCount - 1),
            listingTimeout: 30,
            extractionTimeout: 600,
            capturedOutputMaximumBytes: 64 * 1024 * 1024
        ))
    }

    @discardableResult
    public func materialize(
        archivePath: String,
        entry: String,
        requirement: VGMArchiveMaterializationRequirement
    ) throws -> URL {
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
        let normalizedEntry: String
        do {
            normalizedEntry = try normalizedArchiveEntry(entry)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        let output = directory.appendingPathComponent(normalizedEntry)

        do {
            switch requirement {
            case .selectedEntry:
                try extractArchiveEntry(archiveURL: archiveURL, entry: normalizedEntry, output: output)
                try materializeDependencies(
                    archiveURL: archiveURL,
                    selectedEntry: normalizedEntry,
                    directory: directory
                )
            case .completeSet, .completeSetWithLazyUSFAliases:
                try extractCompleteSet(archiveURL: archiveURL, destination: directory)
                if requirement == .completeSetWithLazyUSFAliases {
                    try ArchiveDependencyPreparation.prepareLazyUSFAliases(in: directory)
                }
                if URL(fileURLWithPath: normalizedEntry).pathExtension.lowercased() == "txtp" {
                    try ArchiveDependencyPreparation.prepareTXTPDependencies(in: directory)
                }
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard byteCount > 0 else { throw ArchiveMaterializationError.emptyOutput }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        session.replace(with: directory)
        return output
    }

    /// Removes the currently materialized entry, if any.
    public func release() {
        session.clear()
    }

    /// Executes a shared archive-tool invocation without changing the
    /// materializer's temporary playback session. Cache-backed frontends use
    /// this as their extraction adapter so process topology and TZST handling
    /// remain identical to the reference materializer.
    public func execute(
        _ invocation: ArchiveToolInvocation,
        outputURL: URL? = nil
    ) throws {
        try runArchiveTool(invocation, outputURL: outputURL)
    }

    private func extractArchiveEntry(archiveURL: URL, entry: String, output: URL) throws {
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        do {
            try extractArchiveEntryOnce(archiveURL: archiveURL, entry: entry, output: output)
        } catch {
            // tar archives commonly store paths with a leading "./" even
            // when the catalog records the normalized path.
            guard !entry.hasPrefix("./") else { throw error }
            try extractArchiveEntryOnce(archiveURL: archiveURL, entry: "./\(entry)", output: output)
        }
    }

    private func extractArchiveEntryOnce(archiveURL: URL, entry: String, output: URL) throws {
        try? FileManager.default.removeItem(at: output)
        guard let kind = ArchiveContainerKind(archiveURL: archiveURL) else {
            throw ArchiveMaterializationError.toolUnavailable("supported archive format")
        }
        if kind == .tarZstandard {
            try extractTarZstd(archiveURL: archiveURL, entry: entry, output: output)
        } else {
            try extractWithArchiveTool(
                ArchiveToolRouting.selectedEntryToStdout(
                    kind: kind,
                    archiveURL: archiveURL,
                    entryPath: entry
                ),
                outputURL: output
            )
        }
    }

    private func extractCompleteSet(archiveURL: URL, destination: URL) throws {
        guard let kind = ArchiveContainerKind(archiveURL: archiveURL) else {
            throw ArchiveMaterializationError.toolUnavailable("supported archive format")
        }
        guard kind != .singleFileZstandard else {
            throw ArchiveMaterializationError.extractFailed(
                "Standalone Zstandard input cannot provide a complete decoder set."
            )
        }
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try runArchiveTool(
            ArchiveToolRouting.completeSet(
                kind: kind,
                archiveURL: archiveURL,
                destinationURL: destination
            )
        )
    }

    private func materializeDependencies(archiveURL: URL, selectedEntry: String, directory: URL) throws {
        guard Self.psfExtensions.contains(URL(fileURLWithPath: selectedEntry).pathExtension.lowercased()) else { return }

        var pending = [selectedEntry]
        var visited = Set<String>()
        while let currentEntry = pending.first {
            pending.removeFirst()
            guard visited.insert(currentEntry).inserted else { continue }

            let currentURL = directory.appendingPathComponent(currentEntry)
            let data = try Data(contentsOf: currentURL)
            for dependency in psfDependencies(in: data) {
                let dependencyEntry = try resolveDependency(dependency, relativeTo: currentEntry)
                guard !visited.contains(dependencyEntry) else { continue }
                let dependencyURL = directory.appendingPathComponent(dependencyEntry)
                try extractArchiveEntry(archiveURL: archiveURL, entry: dependencyEntry, output: dependencyURL)
                pending.append(dependencyEntry)
            }
        }
    }

    private func psfDependencies(in data: Data) -> [String] {
        let marker = Data("[TAG]".utf8)
        guard let range = data.range(of: marker) else { return [] }
        let tagText = String(decoding: data[range.lowerBound...], as: UTF8.self)
        return tagText
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
                guard line.hasPrefix("_lib"), let equals = line.firstIndex(of: "=") else { return nil }
                let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
    }

    private func resolveDependency(_ dependency: String, relativeTo currentEntry: String) throws -> String {
        guard !dependency.hasPrefix("/") else { throw ArchiveMaterializationError.invalidEntry }
        let base = URL(fileURLWithPath: "/\(currentEntry)").deletingLastPathComponent()
        let resolved = base.appendingPathComponent(dependency).standardizedFileURL.path
        let relative = String(resolved.dropFirst())
        return try normalizedArchiveEntry(relative)
    }

    private func normalizedArchiveEntry(_ entry: String) throws -> String {
        let normalized = ArchiveEntryPath.normalized(entry)
        guard !normalized.isEmpty, ArchiveEntryPath.isSafe(normalized) else {
            throw ArchiveMaterializationError.invalidEntry
        }
        return normalized
    }

    private func extractWithArchiveTool(
        _ invocation: ArchiveToolInvocation,
        outputURL: URL
    ) throws {
        try runArchiveTool(invocation, outputURL: outputURL)
    }

    private func runArchiveTool(
        _ invocation: ArchiveToolInvocation,
        outputURL: URL? = nil
    ) throws {
        do {
            switch invocation {
            case let .process(executableName, arguments):
                let executable = try configuration.executableURL(named: executableName).path
                if let outputURL {
                    try processRunner.runWritingOutput(
                        executable: executable,
                        arguments: arguments,
                        outputURL: outputURL,
                        operation: .extraction
                    )
                } else {
                    _ = try processRunner.run(
                        executable: executable,
                        arguments: arguments,
                        operation: .extraction
                    )
                }
            case let .zstandardTar(
                zstdExecutableName,
                zstdArguments,
                tarExecutableName,
                tarArguments,
                allowEarlyConsumerExit
            ):
                try runZstandardTarPipeline(
                    zstdExecutable: try configuration.executableURL(named: zstdExecutableName).path,
                    zstdArguments: zstdArguments,
                    tarExecutable: try configuration.executableURL(named: tarExecutableName).path,
                    tarArguments: tarArguments,
                    outputURL: outputURL,
                    allowEarlyConsumerExit: allowEarlyConsumerExit
                )
            }
        } catch let error as ArchiveMaterializationError {
            throw error
        } catch {
            throw ArchiveMaterializationError.extractFailed(Self.errorText(from: error))
        }
    }

    private func extractTarZstd(archiveURL: URL, entry: String, output: URL) throws {
        try runZstandardTarPipeline(
            zstdExecutable: try configuration.zstdURL().path,
            zstdArguments: ["-d", "-q", "-c", archiveURL.path],
            tarExecutable: try configuration.bsdtarURL().path,
            tarArguments: ["-xOf", "-", entry],
            outputURL: output,
            allowEarlyConsumerExit: true
        )
    }

    private func runZstandardTarPipeline(
        zstdExecutable: String,
        zstdArguments: [String],
        tarExecutable: String,
        tarArguments: [String],
        outputURL: URL?,
        allowEarlyConsumerExit: Bool
    ) throws {
        do {
            try processRunner.acquirePermit()
        } catch {
            throw ArchiveMaterializationError.extractFailed(Self.errorText(from: error))
        }
        defer { processRunner.releasePermit() }

        let environment = ProcessInfo.processInfo.environment
        let transport = Pipe()
        let zstd = Process()
        zstd.executableURL = URL(fileURLWithPath: zstdExecutable)
        zstd.arguments = zstdArguments
        zstd.environment = environment
        zstd.standardOutput = transport

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: tarExecutable)
        tar.arguments = tarArguments
        tar.environment = environment
        tar.standardInput = transport

        var outputHandle: FileHandle?
        if let outputURL {
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: outputURL)
            tar.standardOutput = handle
            outputHandle = handle
        } else {
            tar.standardOutput = FileHandle.nullDevice
        }
        defer { try? outputHandle?.close() }

        let zstdError = Pipe()
        let tarError = Pipe()
        zstd.standardError = zstdError
        tar.standardError = tarError

        let zstdCompletion = DispatchSemaphore(value: 0)
        let tarCompletion = DispatchSemaphore(value: 0)
        zstd.terminationHandler = { _ in zstdCompletion.signal() }
        tar.terminationHandler = { _ in tarCompletion.signal() }
        defer {
            zstd.terminationHandler = nil
            tar.terminationHandler = nil
        }

        let zstdCollector = ArchiveProcessOutputCollector()
        let tarCollector = ArchiveProcessOutputCollector()
        let readers = DispatchGroup()
        for (handle, collector) in [
            (zstdError.fileHandleForReading, zstdCollector),
            (tarError.fileHandleForReading, tarCollector)
        ] {
            readers.enter()
            DispatchQueue.global(qos: .utility).async {
                collector.set(handle.readDataToEndOfFile())
                try? handle.close()
                readers.leave()
            }
        }

        do {
            try tar.run()
            try zstd.run()
            try transport.fileHandleForWriting.close()
            try zstdError.fileHandleForWriting.close()
            try tarError.fileHandleForWriting.close()
            try processRunner.waitForProcess(
                zstd,
                completion: zstdCompletion,
                executable: zstdExecutable,
                timeout: 600
            )
            try processRunner.waitForProcess(
                tar,
                completion: tarCompletion,
                executable: tarExecutable,
                timeout: 600
            )
        } catch {
            if zstd.isRunning { zstd.terminate() }
            if tar.isRunning { tar.terminate() }
            readers.wait()
            throw ArchiveMaterializationError.extractFailed(Self.errorText(from: error))
        }
        readers.wait()

        guard tar.terminationStatus == 0 else {
            throw ArchiveMaterializationError.extractFailed(
                Self.processErrorText(tarCollector.value, status: tar.terminationStatus)
            )
        }
        let zstdStderr = String(decoding: zstdCollector.value, as: UTF8.self)
        let zstdSucceeded = zstd.terminationStatus == 0
            || (allowEarlyConsumerExit && Self.isExpectedZstandardPipeClosure(
                exitStatus: zstd.terminationStatus,
                terminationReason: zstd.terminationReason,
                stderr: zstdStderr
            ))
        guard zstdSucceeded else {
            throw ArchiveMaterializationError.extractFailed(
                Self.processErrorText(zstdCollector.value, status: zstd.terminationStatus)
            )
        }
    }

    private static func isExpectedZstandardPipeClosure(
        exitStatus: Int32,
        terminationReason: Process.TerminationReason,
        stderr: String
    ) -> Bool {
        (terminationReason == .uncaughtSignal && exitStatus == SIGPIPE)
            || (terminationReason == .exit
                && exitStatus == 70
                && stderr.localizedCaseInsensitiveContains("write error")
                && stderr.localizedCaseInsensitiveContains("broken pipe"))
    }

    private static func processErrorText(_ data: Data, status: Int32) -> String {
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "exit code \(status)" : text
    }

    private static func errorText(from pipe: Pipe) -> String {
        String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func errorText(from error: Error) -> String {
        let description = (error as? LocalizedError)?.errorDescription
            ?? String(describing: error)
        return description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ArchiveMaterializerConfiguration: Sendable {
    public var temporaryDirectoryName: String
    public var bsdtarCandidates: [String]
    public var zstdCandidates: [String]
    public var sevenZipCandidates: [String]
    public var unarCandidates: [String]

    public static var `default`: ArchiveMaterializerConfiguration {
        let environment = ProcessInfo.processInfo.environment
        return ArchiveMaterializerConfiguration(
            temporaryDirectoryName: "FrontendCore",
            bsdtarCandidates: [
                environment["COCOASPICE_TAR_BINARY"],
                "/usr/bin/bsdtar", "/opt/homebrew/bin/bsdtar", "/usr/local/bin/bsdtar"
            ].compactMap { $0 },
            zstdCandidates: [
                environment["COCOASPICE_ZSTD_BINARY"],
                "/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"
            ].compactMap { $0 },
            sevenZipCandidates: [
                environment["COCOASPICE_7Z_BINARY"],
                "/opt/homebrew/bin/7zz", "/usr/local/bin/7zz", "/usr/bin/7zz"
            ].compactMap { $0 },
            unarCandidates: [
                environment["COCOASPICE_UNAR_BINARY"],
                "/opt/homebrew/bin/unar", "/usr/local/bin/unar", "/usr/bin/unar"
            ].compactMap { $0 }
        )
    }

    public init(
        temporaryDirectoryName: String,
        bsdtarCandidates: [String],
        zstdCandidates: [String],
        sevenZipCandidates: [String] = ["/opt/homebrew/bin/7zz", "/usr/local/bin/7zz", "/usr/bin/7zz"],
        unarCandidates: [String] = ["/opt/homebrew/bin/unar", "/usr/local/bin/unar", "/usr/bin/unar"]
    ) {
        self.temporaryDirectoryName = temporaryDirectoryName
        self.bsdtarCandidates = bsdtarCandidates
        self.zstdCandidates = zstdCandidates
        self.sevenZipCandidates = sevenZipCandidates
        self.unarCandidates = unarCandidates
    }

    fileprivate func bsdtarURL() throws -> URL {
        try executableURL(from: bsdtarCandidates, name: "bsdtar")
    }

    fileprivate func zstdURL() throws -> URL {
        try executableURL(from: zstdCandidates, name: "zstd")
    }

    fileprivate func executableURL(named name: String) throws -> URL {
        switch name {
        case "7zz": return try executableURL(from: sevenZipCandidates, name: name)
        case "unar": return try executableURL(from: unarCandidates, name: name)
        case "tar": return try bsdtarURL()
        case "zstd": return try zstdURL()
        default: throw ArchiveMaterializationError.toolUnavailable(name)
        }
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
