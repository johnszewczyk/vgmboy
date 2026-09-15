import Foundation
import UACWrapperCore

/// Bounded host adapter for UAC's optional compressed manifest frame.
/// UACWrapperCore owns the format; ScanSong supplies Zstandard and enforces
/// the declared output and decoder-memory limits.
enum UACManifestFrameCodec {
    static var decoder: UACManifestFrameDecoder {
        { frame, expectedByteCount, maximumMemoryByteCount in
            try decode(
                frame,
                expectedByteCount: expectedByteCount,
                maximumMemoryByteCount: maximumMemoryByteCount
            )
        }
    }

    private static func decode(
        _ frame: Data,
        expectedByteCount: Int,
        maximumMemoryByteCount: Int
    ) throws -> Data {
        guard expectedByteCount > 0,
              expectedByteCount <= UACContainerReader.maximumManifestByteCount,
              maximumMemoryByteCount > 0 else {
            throw UACManifestFrameCodecError.invalidLimit
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScanSong-UACManifest-\(UUID().uuidString)", isDirectory: true)
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
        process.arguments = [
            "-q", "-d", "-c", "--memory=\(memoryMiB)MB", "--", inputURL.path
        ]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UACManifestFrameCodecError.launchFailed(error.localizedDescription)
        }

        let outputHandle = outputPipe.fileHandleForReading
        var output = Data()
        while true {
            let remainingWithSentinel = expectedByteCount - output.count + 1
            let requestedCount = min(64 * 1024, max(1, remainingWithSentinel))
            guard let chunk = try outputHandle.read(upToCount: requestedCount), !chunk.isEmpty else {
                break
            }
            guard chunk.count <= expectedByteCount - output.count else {
                if process.isRunning { process.terminate() }
                process.waitUntilExit()
                throw UACManifestFrameCodecError.outputLimitExceeded
            }
            output.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UACManifestFrameCodecError.commandFailed(process.terminationStatus)
        }
        guard output.count == expectedByteCount else {
            throw UACManifestFrameCodecError.decodedSizeMismatch
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
            throw UACManifestFrameCodecError.commandNotFound
        }
        return executable
    }
}

private enum UACManifestFrameCodecError: Error, LocalizedError {
    case commandNotFound
    case invalidLimit
    case launchFailed(String)
    case commandFailed(Int32)
    case outputLimitExceeded
    case decodedSizeMismatch

    var errorDescription: String? {
        switch self {
        case .commandNotFound:
            return "ScanSong needs the zstd command-line tool to read compressed UAC manifests."
        case .invalidLimit:
            return "The UAC manifest decoder received an invalid output or memory limit."
        case .launchFailed(let message):
            return "Could not start zstd for the UAC manifest: \(message)"
        case .commandFailed(let status):
            return "zstd could not decode the UAC manifest (exit code \(status))."
        case .outputLimitExceeded:
            return "The UAC manifest exceeded its declared decoded size."
        case .decodedSizeMismatch:
            return "The decoded UAC manifest does not match its declared size."
        }
    }
}
