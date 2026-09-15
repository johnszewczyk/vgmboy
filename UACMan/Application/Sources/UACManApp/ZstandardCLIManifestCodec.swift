import Foundation
import UACWrapperCore
import UACManCore

/// Prototype codec adapter. UACWrapperCore stays independent of process
/// launch and native codec ownership; a packaged libzstd adapter can replace
/// this host adapter without changing the container UI or format contract.
struct ZstandardCLIManifestCodec: Sendable {
    var decoder: UACManifestFrameDecoder {
        { frame, expectedByteCount, maximumMemoryByteCount in
            try decode(frame, expectedByteCount: expectedByteCount, maximumMemoryByteCount: maximumMemoryByteCount)
        }
    }

    var encoder: UACManifestFrameEncoder {
        { manifestJSON in try encode(manifestJSON) }
    }

    var seekableFrameDecoder: @Sendable (Data, UInt32?) throws -> Data {
        { frame, checksum in try decodeSeekableFrame(frame, checksum: checksum) }
    }

    func ensureAvailable() throws {
        _ = try zstandardExecutable()
    }

    func decode(
        _ frame: Data,
        expectedByteCount: Int,
        maximumMemoryByteCount: Int
    ) throws -> Data {
        guard expectedByteCount > 0,
              expectedByteCount <= UACContainerReader.maximumManifestByteCount,
              maximumMemoryByteCount > 0 else {
            throw ZstandardCLIError.invalidLimit
        }
        return try withInputFile(frame) { inputURL in
            let memoryMiB = max(1, maximumMemoryByteCount / (1024 * 1024))
            let arguments = ["-q", "-d", "-c", "--memory=\(memoryMiB)MB", "--", inputURL.path]
            let decoded = try run(arguments, maximumOutputByteCount: expectedByteCount)
            guard decoded.count == expectedByteCount else { throw ZstandardCLIError.decodedSizeMismatch }
            return decoded
        }
    }

    func encode(_ manifestJSON: Data) throws -> Data {
        let maximumOutputByteCount = min(
            UACContainerReader.maximumManifestByteCount + 64 * 1024,
            manifestJSON.count + 64 * 1024
        )
        return try withInputFile(manifestJSON) { inputURL in
            try run(["-q", "-c", "-3", "--", inputURL.path], maximumOutputByteCount: maximumOutputByteCount)
        }
    }

    func decodeSeekableFrame(_ frame: Data, checksum: UInt32?) throws -> Data {
        guard !frame.isEmpty else { throw ZstandardCLIError.invalidLimit }
        let decoded = try withInputFile(frame) { inputURL in
            try run(
                ["-q", "-d", "-c", "--memory=64MB", "--", inputURL.path],
                maximumOutputByteCount: Int(UACZstandardSeekTable.maximumFrameTarByteCount)
            )
        }
        if let checksum,
           !UACWrapperCore.UACSeekableFrameChecksum.matches(decoded, checksum: checksum) {
            throw ZstandardCLIError.seekTableChecksumMismatch
        }
        return decoded
    }

    private func withInputFile<T>(_ data: Data, body: (URL) throws -> T) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("uacman-zstd-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let inputURL = directory.appendingPathComponent("manifest.frame")
        try data.write(to: inputURL, options: [.atomic])
        return try body(inputURL)
    }

    private func run(_ arguments: [String], maximumOutputByteCount: Int) throws -> Data {
        let executable = try zstandardExecutable()
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw ZstandardCLIError.launchFailed(error.localizedDescription)
        }

        let outputHandle = outputPipe.fileHandleForReading
        var output = Data()
        while true {
            let remainingWithSentinel = maximumOutputByteCount - output.count + 1
            let count = min(64 * 1024, max(1, remainingWithSentinel))
            guard let chunk = try outputHandle.read(upToCount: count), !chunk.isEmpty else { break }
            guard chunk.count <= maximumOutputByteCount - output.count else {
                if process.isRunning { process.terminate() }
                process.waitUntilExit()
                throw ZstandardCLIError.outputLimitExceeded
            }
            output.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ZstandardCLIError.commandFailed(process.terminationStatus)
        }
        return output
    }

    private func zstandardExecutable() throws -> URL {
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true).appendingPathComponent("zstd") }
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/zstd"),
            URL(fileURLWithPath: "/usr/local/bin/zstd"),
            URL(fileURLWithPath: "/usr/bin/zstd")
        ] + pathEntries
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw ZstandardCLIError.commandNotFound
        }
        return executable
    }
}

private enum ZstandardCLIError: Error, LocalizedError {
    case commandNotFound
    case invalidLimit
    case launchFailed(String)
    case commandFailed(Int32)
    case outputLimitExceeded
    case decodedSizeMismatch
    case seekTableChecksumMismatch

    var errorDescription: String? {
        switch self {
        case .commandNotFound:
            return "UACMan needs the zstd command-line tool for compressed manifests. Install Zstandard or use a raw-manifest package."
        case .invalidLimit:
            return "The manifest decoder was given an invalid size or memory limit."
        case .launchFailed(let message):
            return "Could not start zstd: \(message)"
        case .commandFailed(let status):
            return "zstd exited with status \(status)."
        case .outputLimitExceeded:
            return "zstd output exceeded the manifest's declared safety limit."
        case .decodedSizeMismatch:
            return "zstd output did not match the manifest's declared length."
        case .seekTableChecksumMismatch:
            return "A seekable Zstandard frame failed its seek-table checksum."
        }
    }
}
