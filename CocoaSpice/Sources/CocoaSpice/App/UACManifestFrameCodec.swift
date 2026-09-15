import Foundation
import UACWrapperCore

/// Host-side Zstandard adapter for UAC's independently compressed manifest.
/// UACWrapperCore owns the format contract; CocoaSpice owns executable
/// discovery and enforces the declared output and decoder-memory bounds.
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
        guard !frame.isEmpty,
              expectedByteCount > 0,
              expectedByteCount <= UACContainerReader.maximumManifestByteCount,
              maximumMemoryByteCount > 0 else {
            throw UACManifestFrameCodecError.invalidBounds
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CocoaSpice-uac-manifest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputURL = directory.appendingPathComponent("manifest.frame")
        try frame.write(to: inputURL, options: [.atomic])

        let memoryMiB = max(1, maximumMemoryByteCount / (1024 * 1024))
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: try ZipArchiveSupport.executable(named: "zstd"))
        process.arguments = ["-q", "-d", "-c", "--memory=\(memoryMiB)MB", "--", inputURL.path]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UACManifestFrameCodecError.launchFailed(error.localizedDescription)
        }

        var decoded = Data()
        decoded.reserveCapacity(expectedByteCount)
        let outputHandle = outputPipe.fileHandleForReading
        do {
            while true {
                let remainingWithSentinel = expectedByteCount - decoded.count + 1
                let readLimit = min(64 * 1024, max(1, remainingWithSentinel))
                guard let chunk = try outputHandle.read(upToCount: readLimit), !chunk.isEmpty else { break }
                guard chunk.count <= expectedByteCount - decoded.count else {
                    if process.isRunning { process.terminate() }
                    process.waitUntilExit()
                    throw UACManifestFrameCodecError.outputLimitExceeded
                }
                decoded.append(chunk)
            }
        } catch {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            if let codecError = error as? UACManifestFrameCodecError { throw codecError }
            throw UACManifestFrameCodecError.readFailed(error.localizedDescription)
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UACManifestFrameCodecError.commandFailed(process.terminationStatus)
        }
        guard decoded.count == expectedByteCount else {
            throw UACManifestFrameCodecError.decodedSizeMismatch
        }
        return decoded
    }
}

private enum UACManifestFrameCodecError: Error, LocalizedError {
    case invalidBounds
    case launchFailed(String)
    case outputLimitExceeded
    case readFailed(String)
    case commandFailed(Int32)
    case decodedSizeMismatch

    var errorDescription: String? {
        switch self {
        case .invalidBounds:
            "The compressed UAC manifest has invalid decoder bounds."
        case .launchFailed(let message):
            "Could not launch Zstandard to read the UAC manifest: \(message)"
        case .outputLimitExceeded:
            "The compressed UAC manifest exceeded its declared size."
        case .readFailed(let message):
            "Could not read the decompressed UAC manifest: \(message)"
        case .commandFailed(let status):
            "Zstandard could not decompress the UAC manifest (exit code \(status))."
        case .decodedSizeMismatch:
            "The decompressed UAC manifest does not match its declared size."
        }
    }
}
