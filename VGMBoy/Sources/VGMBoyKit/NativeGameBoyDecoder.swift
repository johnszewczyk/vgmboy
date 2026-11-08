import Foundation

enum NativeGameBoyDecoderError: LocalizedError {
    case runtimeUnavailable
    case launchFailed(String)
    case streamEnded(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The SameBoy UACNGB runtime is not installed. Build and stage sameboy-uacngb-host with VGMBoy/scripts/stage-sameboy-uacngb-host.sh."
        case .launchFailed(let message):
            return "The SameBoy UACNGB runtime could not start. \(message)"
        case .streamEnded(let message):
            return "The SameBoy UACNGB runtime stopped while rendering. \(message)"
        }
    }
}

/// Runs a source-derived Game Boy driver payload in a pinned SameBoy host.
/// The host accepts direct-ROM v3 and native-state v4, then streams stereo PCM16LE.
final class NativeGameBoyDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    private let payloadPath: String
    private let helperURL: URL
    private let selectorIDs: [UInt8]
    private var process: Process?
    private var outputPipe: Pipe?
    private var absoluteFrames: Int64 = 0
    private var failureMessage: String?
    private var closed = false
    private var selectedTrackIndex = 0

    init(path: String, sampleRate: Int = 44_100, helperURL: URL? = nil) throws {
        self.payloadPath = path
        self.sampleRate = sampleRate
        self.selectorIDs = try Self.readSelectorIDs(path: path)
        guard let helperURL = helperURL ?? Self.resolveHelper() else {
            throw NativeGameBoyDecoderError.runtimeUnavailable
        }
        self.helperURL = helperURL
    }

    deinit { close() }

    var appliesFadeInternally: Bool { false }
    var trackCount: Int { selectorIDs.count }
    var systemName: String { "Nintendo Game Boy" }
    var absolutePlayedFrames: Int64 { absoluteFrames }
    // The v4 host runs source-native loops and restarts finite cues from the
    // embedded checkpoint after 250 ms of exact digital silence. Transport
    // caps and user stop own the playback window.
    var trackEnded: Bool { closed }

    func startTrack(_ index: Int) throws {
        guard selectorIDs.indices.contains(index) else {
            throw PlaybackControlError.invalidPayload("The UACNGB track index is outside its selector table.")
        }
        stopProcess()
        selectedTrackIndex = index
        absoluteFrames = 0
        failureMessage = nil
        closed = false
        try launch()
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard selectorIDs.indices.contains(index) else {
            throw PlaybackControlError.invalidPayload("The UACNGB track index is outside its selector table.")
        }
        let selector = String(format: "0x%02x", selectorIDs[index])
        return TrackMetadata(
            index: index,
            song: "ROM Selector \(selector)",
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
            throw NativeGameBoyDecoderError.streamEnded(failureMessage)
        }
        do {
            let result = try readNativeFrames(frameCount)
            absoluteFrames += Int64(result.left.count)
            return result
        } catch {
            failureMessage = error.localizedDescription
            stopProcess()
            throw NativeGameBoyDecoderError.streamEnded(failureMessage ?? "Unknown runtime failure.")
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
        let bootROM = helperURL.deletingLastPathComponent().appendingPathComponent("dmg_boot.bin")
        child.arguments = ["stream", payloadPath, String(sampleRate), String(selectedTrackIndex), bootROM.path]
        child.standardOutput = pipe
        child.standardError = FileHandle.nullDevice
        do {
            try child.run()
        } catch {
            try? pipe.fileHandleForReading.close()
            throw NativeGameBoyDecoderError.launchFailed(error.localizedDescription)
        }
        try? pipe.fileHandleForWriting.close()
        process = child
        outputPipe = pipe
    }

    private func readNativeFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float]) {
        guard let outputPipe else {
            throw NativeGameBoyDecoderError.streamEnded("The PCM pipe is closed.")
        }
        let byteCount = frameCount * 4
        var bytes = Data()
        bytes.reserveCapacity(byteCount)
        while bytes.count < byteCount {
            guard let chunk = try outputPipe.fileHandleForReading.read(upToCount: byteCount - bytes.count), !chunk.isEmpty else {
                let status: String
                if let process {
                    status = process.isRunning ? "The PCM pipe closed while the process was running."
                        : "Process exited with status \(process.terminationStatus)."
                } else {
                    status = "The process was released."
                }
                throw NativeGameBoyDecoderError.streamEnded(status)
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
        if let override = ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("sameboy-uacngb/sameboy-uacngb-host"))
        }
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(packageRoot.appendingPathComponent(".build/dependencies/sameboy-uacngb/sameboy-uacngb-host"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func readSelectorIDs(path: String) throws -> [UInt8] {
        let url = URL(fileURLWithPath: path)
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize,
              fileSize >= 85,
              fileSize <= 4 * 1024 * 1024 else {
            throw PlaybackControlError.invalidPayload("The UACNGB member has an unsupported file size.")
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let magic = Data([0x55, 0x41, 0x43, 0x4E, 0x47, 0x42, 0x00, 0x00])
        guard data.count == fileSize, data.prefix(8) == magic else {
            throw PlaybackControlError.invalidPayload("The UACNGB member has an invalid header.")
        }

        func littleEndian16(at offset: Int) -> Int {
            Int(data[offset]) | (Int(data[offset + 1]) << 8)
        }
        func littleEndian32(at offset: Int) -> UInt64 {
            UInt64(data[offset]) | (UInt64(data[offset + 1]) << 8)
                | (UInt64(data[offset + 2]) << 16) | (UInt64(data[offset + 3]) << 24)
        }

        let version = littleEndian16(at: 8)
        let headerBytes = littleEndian16(at: 10)
        let trackCount = littleEndian16(at: 48)
        guard trackCount > 0, trackCount <= 255 else {
            throw PlaybackControlError.invalidPayload("The UACNGB member has an invalid selector count.")
        }
        switch version {
        case 3:
            let payloadBytes = littleEndian32(at: 44)
            guard headerBytes == 84 + trackCount,
                  UInt64(headerBytes) + payloadBytes == UInt64(data.count) else {
                throw PlaybackControlError.invalidPayload("The UACNGB v3 member has malformed lengths.")
            }
            if payloadBytes != 65_536 || littleEndian16(at: 50) != 1 || littleEndian16(at: 14) != 2 {
                throw PlaybackControlError.invalidPayload("The UACNGB v3 member has an invalid ROM payload contract.")
            }
            return Array(data[84..<headerBytes])

        case 4:
            guard data.count >= 160 else {
                throw PlaybackControlError.invalidPayload("The UACNGB v4 member is shorter than its fixed header.")
            }
            let sourceRomBytes = littleEndian32(at: 16)
            let bank = littleEndian16(at: 14)
            let regionOffset = littleEndian32(at: 44)
            let regionBytes = littleEndian32(at: 148)
            let stateBytes = littleEndian32(at: 152)
            let sourceHeaderBytes = UInt64(littleEndian16(at: 156))
            let expectedBytes = UInt64(headerBytes) + sourceHeaderBytes + regionBytes + stateBytes
            guard headerBytes == 160 + trackCount,
                  expectedBytes == UInt64(data.count),
                  sourceRomBytes >= 32_768 && sourceRomBytes <= 8 * 1024 * 1024,
                  bank >= 1 && bank <= 512,
                  regionOffset + regionBytes <= sourceRomBytes,
                  regionBytes > 0,
                  stateBytes > 0,
                  sourceHeaderBytes == 0x150,
                  littleEndian16(at: 50) == 1,
                  littleEndian16(at: 158) == 0 else {
                throw PlaybackControlError.invalidPayload("The UACNGB v4 member has an invalid native-state payload contract.")
            }
            return Array(data[160..<headerBytes])

        case 5:
            guard data.count >= 160 else {
                throw PlaybackControlError.invalidPayload("The UACNGB v5 member is shorter than its fixed header.")
            }
            let regionCount = littleEndian16(at: 158)
            guard regionCount > 0, regionCount <= 32 else {
                throw PlaybackControlError.invalidPayload("The UACNGB v5 member has an invalid region count.")
            }
            guard headerBytes == 160 + trackCount + (regionCount * 8) else {
                throw PlaybackControlError.invalidPayload("The UACNGB v5 member has an invalid header length.")
            }
            return Array(data[160..<(160 + trackCount)])

        default:
            throw PlaybackControlError.invalidPayload("The UACNGB member uses an unsupported format version.")
        }
    }
}
