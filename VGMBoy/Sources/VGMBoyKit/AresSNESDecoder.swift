import Foundation

enum AresSNESDecoderError: LocalizedError {
    case runtimeUnavailable
    case launchFailed(String)
    case streamEnded(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The ares SNES runtime is not installed. Stage ares-agent-host and its Database resources with VGMBoy/scripts/stage-ares-snes-host.sh."
        case .launchFailed(let message):
            return "The ares SNES runtime could not start. \(message)"
        case .streamEnded(let message):
            return "The ares SNES runtime stopped while rendering. \(message)"
        }
    }
}

/// Restores one ROM-free ares SFC audio state and streams its live PCM output.
/// The helper process owns the emulator instance; the decoder owns its lifetime
/// and converts the helper's explicitly little-endian stereo PCM16 stream.
final class AresSNESDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let statePath: String
    private let helperURL: URL
    private var process: Process?
    private var outputPipe: Pipe?
    private var absoluteFrames: Int64 = 0
    private var failureMessage: String?
    private var closed = false

    init(path: String, sampleRate: Int = 44_100) throws {
        self.statePath = path
        self.sampleRate = sampleRate
        guard let helperURL = Self.resolveHelper() else {
            throw AresSNESDecoderError.runtimeUnavailable
        }
        self.helperURL = helperURL
        try launch()
    }

    deinit { close() }

    var appliesFadeInternally: Bool { false }
    var trackCount: Int { 1 }
    var systemName: String { "Nintendo SNES" }
    var absolutePlayedFrames: Int64 { absoluteFrames }
    var trackEnded: Bool { closed || failureMessage != nil || !(process?.isRunning ?? false) }

    func startTrack(_ index: Int) throws {
        guard index == 0 else {
            throw PlaybackControlError.invalidPayload("A native SNES state exposes one playable cue.")
        }
        stopProcess()
        absoluteFrames = 0
        failureMessage = nil
        closed = false
        try launch()
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else {
            throw PlaybackControlError.invalidPayload("A native SNES state exposes one playable cue.")
        }
        let title = URL(fileURLWithPath: statePath).deletingPathExtension().lastPathComponent
        return TrackMetadata(
            index: 0,
            song: title,
            game: "",
            author: "",
            system: systemName,
            lengthMs: 0,
            introMs: 0,
            loopMs: 0,
            playMs: 0,
            fadeMs: 0
        )
    }

    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        stopProcess()
        absoluteFrames = 0
        failureMessage = nil
        closed = false
        do {
            try launch()
            var framesToSkip = Int64(max(0, milliseconds)) * Int64(sampleRate) / 1_000
            while framesToSkip > 0 {
                let count = Int(min(framesToSkip, 16_384))
                _ = try readNativeFrames(count)
                framesToSkip -= Int64(count)
                absoluteFrames += Int64(count)
            }
        } catch {
            failureMessage = error.localizedDescription
            stopProcess()
        }
    }

    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard frameCount > 0 else { return ([], []) }
        guard !closed else { return ([], []) }
        if let failureMessage {
            throw AresSNESDecoderError.streamEnded(failureMessage)
        }
        do {
            let result = try readNativeFrames(frameCount)
            absoluteFrames += Int64(result.left.count)
            return result
        } catch {
            failureMessage = error.localizedDescription
            stopProcess()
            throw AresSNESDecoderError.streamEnded(failureMessage ?? "Unknown runtime failure.")
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        stopProcess()
    }

    private func launch() throws {
        let pipe = Pipe()
        let child = Process()
        child.executableURL = helperURL
        child.arguments = ["stream", statePath, String(sampleRate)]
        child.standardOutput = pipe
        child.standardError = FileHandle.nullDevice
        do {
            try child.run()
        } catch {
            try? pipe.fileHandleForReading.close()
            throw AresSNESDecoderError.launchFailed(error.localizedDescription)
        }
        try? pipe.fileHandleForWriting.close()
        process = child
        outputPipe = pipe
    }

    private func readNativeFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard let outputPipe else {
            throw AresSNESDecoderError.streamEnded("The PCM pipe is closed.")
        }
        let byteCount = frameCount * 4
        var bytes = Data()
        bytes.reserveCapacity(byteCount)
        while bytes.count < byteCount {
            guard let chunk = try outputPipe.fileHandleForReading.read(upToCount: byteCount - bytes.count), !chunk.isEmpty else {
                let status = process.map { "Process exited with status \($0.terminationStatus)." } ?? "The process was released."
                throw AresSNESDecoderError.streamEnded(status)
            }
            bytes.append(chunk)
        }

        var left = [Float](repeating: 0, count: frameCount)
        var right = [Float](repeating: 0, count: frameCount)
        bytes.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for frame in 0..<frameCount {
                let offset = frame * 4
                let leftBits = UInt16(base[offset]) | (UInt16(base[offset + 1]) << 8)
                let rightBits = UInt16(base[offset + 2]) | (UInt16(base[offset + 3]) << 8)
                left[frame] = Float(Int16(bitPattern: leftBits)) / 32_768.0
                right[frame] = Float(Int16(bitPattern: rightBits)) / 32_768.0
            }
        }
        return (left, right)
    }

    private func stopProcess() {
        if let outputPipe {
            try? outputPipe.fileHandleForReading.close()
            try? outputPipe.fileHandleForWriting.close()
        }
        if let process, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        process = nil
        outputPipe = nil
    }

    private static func resolveHelper() -> URL? {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment["VGMBoyAresSNESHostPath"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("ares-snes/ares-agent-host"))
        }
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(packageRoot.appendingPathComponent(".build/dependencies/ares-snes/ares-agent-host"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
