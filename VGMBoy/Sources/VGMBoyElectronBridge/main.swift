import AppKit
import Foundation
import VGMBoyKit

/// Embedded Electron-only host for VGMBoyKit. This is a bundled child process,
/// not a discoverable server: SPCBoy owns its lifetime and queue policy while
/// VGMBoy owns exactly one local audio session.
@main
struct VGMBoyElectronBridge {
    static func main() {
        guard CommandLine.arguments.dropFirst() == ["serve"] else {
            writeError(requestID: "0", message: "usage: vgmboy-electron-bridge serve")
            exit(2)
        }

        // AVAudioUnitEQ needs an AppKit application context even though this
        // bundled helper has no windows or menus.
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let bridge = BridgeSession()
        while let line = readLine(strippingNewline: true) {
            bridge.handle(line: line)
        }
        bridge.shutdown()
    }

    private static func writeError(requestID: String, message: String) {
        let safeMessage = message.replacingOccurrences(of: "\n", with: " ")
        FileHandle.standardOutput.write(Data("ERR\t\(requestID)\t\(safeMessage)\n".utf8))
    }
}

private final class BridgeSession {
    private let controller = PlaybackController()
    private var trackLoaded = false
    private var decodeError = false

    func handle(line: String) {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2 else {
            writeError(requestID: "0", message: "invalid bridge request")
            return
        }
        let requestID = parts[0]
        let command = parts[1]
        let arguments = Array(parts.dropFirst(2))

        do {
            switch command {
            case "player-init", "player-state":
                try writeSnapshot(requestID: requestID)
            case "player-structure":
                guard let path = arguments.first, !path.isEmpty else {
                    throw BridgeError.invalidArguments("player-structure requires a path")
                }
                writeJSON(requestID: requestID, value: try PlaybackStructureReader.read(path: path))
            case "player-load":
                try load(arguments: arguments)
                try writeSnapshot(requestID: requestID)
            case "player-play":
                try requireSuccess(controller.perform(.init(command: .play)))
                try writeSnapshot(requestID: requestID)
            case "player-pause":
                try requireSuccess(controller.perform(.init(command: .pause)))
                try writeSnapshot(requestID: requestID)
            case "player-stop", "player-unload":
                try requireSuccess(controller.perform(.init(command: .stop)))
                trackLoaded = false
                try writeSnapshot(requestID: requestID)
            case "player-seek":
                guard let milliseconds = arguments.first.flatMap(Int.init), milliseconds >= 0 else {
                    throw BridgeError.invalidArguments("player-seek requires a non-negative millisecond offset")
                }
                try requireSuccess(controller.perform(.init(
                    command: .seek,
                    payload: .init(positionMilliseconds: milliseconds)
                )))
                try writeSnapshot(requestID: requestID)
            case "player-audio-config":
                try configureAudio(arguments: arguments)
                writeJSON(requestID: requestID, value: EmptyResponse())
            case "player-close":
                try requireSuccess(controller.perform(.init(command: .stop)))
                trackLoaded = false
                writeJSON(requestID: requestID, value: EmptyResponse())
            case "player-ramp-gain":
                try rampTransportGain(arguments: arguments)
                try writeSnapshot(requestID: requestID)
            default:
                throw BridgeError.unsupported("unknown bridge command \(command)")
            }
        } catch {
            decodeError = true
            writeError(requestID: requestID, message: error.localizedDescription)
        }
    }

    func shutdown() {
        _ = controller.perform(.init(command: .stop))
    }

    private func load(arguments: [String]) throws {
        guard arguments.count >= 5,
              let trackIndex = Int(arguments[1]), trackIndex >= 0,
              let startMilliseconds = Int(arguments[2]), startMilliseconds >= 0,
              let playMilliseconds = Int(arguments[3]), playMilliseconds >= 0,
              let fadeMilliseconds = Int(arguments[4]), fadeMilliseconds >= 0 else {
            throw BridgeError.invalidArguments("player-load requires path, track, start, play, and fade milliseconds")
        }
        let suppliedMode = arguments.count > 5 ? PlaybackMode(rawValue: arguments[5]) : nil
        let playbackMode = suppliedMode ?? .fileDefault
        let speedOffset = suppliedMode == nil ? 5 : 6
        let numerator = arguments.count > speedOffset ? Double(arguments[speedOffset]) ?? 1 : 1
        let denominator = arguments.count > speedOffset + 1 ? Double(arguments[speedOffset + 1]) ?? 1 : 1
        let tempo = numerator / denominator
        guard tempo.isFinite, tempo > 0 else {
            throw BridgeError.invalidArguments("player-load received an invalid tempo ratio")
        }

        try requireSuccess(controller.perform(.init(
            command: .load,
            payload: .init(
                path: arguments[0],
                trackIndex: trackIndex,
                tempo: tempo,
                playbackMode: playbackMode,
                playMilliseconds: playMilliseconds > 0 ? playMilliseconds : nil,
                fadeMilliseconds: fadeMilliseconds
            )
        )))
        if startMilliseconds > 0 {
            try requireSuccess(controller.perform(.init(
                command: .seek,
                payload: .init(positionMilliseconds: startMilliseconds)
            )))
        }
        trackLoaded = true
        decodeError = false
    }

    private func configureAudio(arguments: [String]) throws {
        guard arguments.count >= 12,
              let volume = Float(arguments[0]), volume.isFinite, (0...1).contains(volume),
              let enabledValue = Int(arguments[1]) else {
            throw BridgeError.invalidArguments("player-audio-config requires volume, EQ enabled, and ten gains")
        }
        let gains = try arguments.dropFirst(2).prefix(EqualizerConfiguration.bandCount).map { value -> Float in
            guard let gain = Float(value), gain.isFinite else {
                throw BridgeError.invalidArguments("player-audio-config contains an invalid EQ gain")
            }
            return gain
        }
        let equalizer = EqualizerConfiguration(enabled: enabledValue != 0, gainsDecibels: gains)
        guard equalizer.isValid else {
            throw BridgeError.invalidArguments("player-audio-config requires ten gains between -12 and +12 dB")
        }
        try requireSuccess(controller.perform(.init(command: .setOutputVolume, payload: .init(outputVolume: volume))))
        try requireSuccess(controller.perform(.init(command: .setEqualizer, payload: .init(equalizer: equalizer))))
    }

    private func rampTransportGain(arguments: [String]) throws {
        guard arguments.count == 2,
              let gain = Float(arguments[0]), gain.isFinite, (0...1).contains(gain),
              let duration = Int(arguments[1]), duration > 0 else {
            throw BridgeError.invalidArguments("player-ramp-gain requires a gain between zero and one and a positive duration")
        }
        try requireSuccess(controller.perform(.init(
            command: .rampOutputGain,
            payload: .init(outputGain: gain, rampMilliseconds: duration)
        )))
    }

    private func writeSnapshot(requestID: String) throws {
        let status = controller.perform(.init(command: .status)).status
        writeJSON(requestID: requestID, value: BridgeSnapshot(status: status, trackLoaded: trackLoaded, decodeError: decodeError))
    }

    private func requireSuccess(_ event: PlaybackControlEvent) throws {
        guard event.kind != .error else {
            throw BridgeError.core(event.message ?? "VGMBoy playback command failed")
        }
    }

    private func writeJSON<Value: Encodable>(requestID: String, value: Value) {
        do {
            let payload = try JSONEncoder().encode(value)
            let header = Data("OK\t\(requestID)\tjson\t\(payload.count)\n".utf8)
            FileHandle.standardOutput.write(header)
            FileHandle.standardOutput.write(payload)
            FileHandle.standardOutput.write(Data("\n".utf8))
        } catch {
            writeError(requestID: requestID, message: "could not encode bridge response")
        }
    }

    private func writeError(requestID: String, message: String) {
        let safeMessage = message.replacingOccurrences(of: "\n", with: " ")
        FileHandle.standardOutput.write(Data("ERR\t\(requestID)\t\(safeMessage)\n".utf8))
    }
}

private struct BridgeSnapshot: Encodable {
    let transport_state: String
    let output_state: String
    let track_loaded: Bool
    let decode_error: Bool
    let position_ms: Int
    let buffered_frames: Int
    let ring_buffer_frames: Int
    let underrun_count: Int64
    let sample_rate: Int
    let reached_end: Bool

    init(status: PlaybackStatus?, trackLoaded: Bool, decodeError: Bool) {
        let diagnostics = status?.diagnostics
        self.transport_state = status?.isPlaying == true ? "playing" : (trackLoaded ? "paused" : "stopped")
        self.output_state = diagnostics?.isOutputRunning == true ? "running" : "idle"
        self.track_loaded = trackLoaded
        self.decode_error = decodeError
        self.position_ms = Int(((status?.elapsedSeconds ?? 0) * 1_000).rounded())
        self.buffered_frames = diagnostics?.bufferedFrames ?? 0
        self.ring_buffer_frames = diagnostics?.capacityFrames ?? 0
        self.underrun_count = diagnostics?.underrunCount ?? 0
        self.sample_rate = diagnostics?.sampleRate ?? 44_100
        self.reached_end = status?.reachedEnd ?? false
    }
}

private struct EmptyResponse: Encodable {}

private enum BridgeError: LocalizedError {
    case invalidArguments(String)
    case unsupported(String)
    case core(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message), .unsupported(let message), .core(let message): return message
        }
    }
}
