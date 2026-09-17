import Foundation
import MetaManCore

/// The CLI supplies the optional UAC manifest codec. The reusable MetaManCore
/// library remains process-free and lets applications provide their own codec.
enum UACManifestZstandardDecoder {
    static let decode: MetadataContainerFrameDecoder = { frame, expectedByteCount, maximumMemoryByteCount in
        guard expectedByteCount > 0, maximumMemoryByteCount > 0 else {
            throw DecoderError.invalidLimit
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetaMan-UACManifest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let inputURL = directoryURL.appendingPathComponent("manifest.zst")
        try frame.write(to: inputURL, options: [.atomic])

        let memoryMiB = max(1, maximumMemoryByteCount / (1024 * 1024))
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = try zstandardExecutable()
        process.arguments = ["-q", "-d", "-c", "--memory=\(memoryMiB)MB", "--", inputURL.path]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw DecoderError.launchFailed(error.localizedDescription)
        }

        let outputHandle = outputPipe.fileHandleForReading
        var output = Data()
        while true {
            let remainingWithSentinel = expectedByteCount - output.count + 1
            let count = min(64 * 1024, max(1, remainingWithSentinel))
            guard let chunk = try outputHandle.read(upToCount: count), !chunk.isEmpty else { break }
            guard chunk.count <= expectedByteCount - output.count else {
                if process.isRunning { process.terminate() }
                process.waitUntilExit()
                throw DecoderError.outputLimitExceeded
            }
            output.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DecoderError.commandFailed(process.terminationStatus)
        }
        guard output.count == expectedByteCount else {
            throw DecoderError.decodedSizeMismatch
        }
        return output
    }

    private static func zstandardExecutable() throws -> URL {
        let pathEntries = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0), isDirectory: true).appendingPathComponent("zstd") }
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/zstd"),
            URL(fileURLWithPath: "/usr/local/bin/zstd"),
            URL(fileURLWithPath: "/usr/bin/zstd")
        ] + pathEntries
        guard let executable = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw DecoderError.commandNotFound
        }
        return executable
    }
}

private enum DecoderError: Error, LocalizedError {
    case commandNotFound
    case invalidLimit
    case launchFailed(String)
    case commandFailed(Int32)
    case outputLimitExceeded
    case decodedSizeMismatch

    var errorDescription: String? {
        switch self {
        case .commandNotFound:
            "metaman requires the zstd command-line tool for compressed UAC manifests."
        case .invalidLimit:
            "The UAC manifest decoder received an invalid output or memory limit."
        case .launchFailed(let message):
            "Could not start zstd for the UAC manifest: \(message)"
        case .commandFailed(let status):
            "zstd could not decode the UAC manifest (exit code \(status))."
        case .outputLimitExceeded:
            "The UAC manifest exceeded its declared decoded size."
        case .decodedSizeMismatch:
            "The decoded UAC manifest does not match its declared size."
        }
    }
}
