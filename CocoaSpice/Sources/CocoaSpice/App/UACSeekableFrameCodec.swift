import Foundation
import UACContainerCore

/// Decodes one independently compressed UAC TAR frame for the virtual-member
/// reader. Only the compressed frame is staged as a private temporary input;
/// decompressed TAR bytes remain bounded in memory and are never cached on disk.
enum UACSeekableFrameCodec {
    static var decoder: @Sendable (Data, UInt32?) throws -> Data {
        { compressedFrame, checksum in
            let decoded = try decode(compressedFrame)
            if let checksum, !UACSeekableFrameChecksum.matches(decoded, checksum: checksum) {
                throw UACSeekableFrameCodecError.checksumMismatch
            }
            return decoded
        }
    }

    private static func decode(_ compressedFrame: Data) throws -> Data {
        guard !compressedFrame.isEmpty else { throw UACSeekableFrameCodecError.invalidFrame }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CocoaSpice-uac-frame-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputURL = directory.appendingPathComponent("frame.zst")
        try compressedFrame.write(to: inputURL, options: [.atomic])
        let executable = try ZipArchiveSupport.executable(named: "zstd")
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-q", "-d", "-c", "--memory=64MB", "--", inputURL.path]
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw UACSeekableFrameCodecError.launchFailed(error.localizedDescription)
        }

        let maximumOutput = Int(UACZstandardSeekTable.maximumFrameTarByteCount)
        let outputHandle = outputPipe.fileHandleForReading
        var decoded = Data()
        decoded.reserveCapacity(min(maximumOutput, 4 * 1024 * 1024))
        do {
            while true {
                let remainingWithSentinel = maximumOutput - decoded.count + 1
                let count = min(64 * 1024, max(1, remainingWithSentinel))
                guard let chunk = try outputHandle.read(upToCount: count), !chunk.isEmpty else { break }
                guard chunk.count <= maximumOutput - decoded.count else {
                    if process.isRunning { process.terminate() }
                    process.waitUntilExit()
                    throw UACSeekableFrameCodecError.outputLimitExceeded
                }
                decoded.append(chunk)
            }
        } catch {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            if let codecError = error as? UACSeekableFrameCodecError { throw codecError }
            throw UACSeekableFrameCodecError.readFailed(error.localizedDescription)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UACSeekableFrameCodecError.commandFailed(process.terminationStatus)
        }
        return decoded
    }
}

private enum UACSeekableFrameCodecError: Error, LocalizedError {
    case invalidFrame
    case launchFailed(String)
    case readFailed(String)
    case commandFailed(Int32)
    case outputLimitExceeded
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidFrame: "A UAC seekable frame was empty."
        case .launchFailed(let message): "Could not start Zstandard for UAC playback: \(message)"
        case .readFailed(let message): "Could not read a decoded UAC frame: \(message)"
        case .commandFailed(let status): "Zstandard could not decode a UAC frame (exit code \(status))."
        case .outputLimitExceeded: "A decoded UAC frame exceeded the 64 MiB safety limit."
        case .checksumMismatch: "A UAC seekable frame failed its XXH64 checksum."
        }
    }
}
