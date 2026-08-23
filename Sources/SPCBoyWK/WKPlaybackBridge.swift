import Foundation
import ArchiveMaterializationCore
import VGMBoyKit

/// Thin WK adapter over the shared in-process VGMBoy control surface.
/// Queue/catalog policy remains in the web frontend; this object owns only
/// decoder transport and audio configuration.
final class WKPlaybackBridge: @unchecked Sendable {
    static let shared = WKPlaybackBridge()

    private let controller = PlaybackController()
    private let lock = NSLock()
    private var trackLoaded = false

    private init() {}

    func handle(method: String, args: [Any]) throws -> Any {
        switch method {
        case "nativePlaybackInit", "nativePlaybackState":
            return statusResponse()
        case "nativePlaybackAudioConfig":
            if let volume = number(args.first) {
                try perform(.setOutputVolume, payload: .init(outputVolume: Float(max(0, min(1, volume)))))
            }
            if args.count > 1, let enabled = args[1] as? Bool {
                let gains = (args.count > 2 ? args[2] as? [Any] : nil)?.compactMap(number) ?? Array(repeating: 0, count: EqualizerConfiguration.bandCount)
                let normalized = Array(gains.prefix(EqualizerConfiguration.bandCount)) + Array(repeating: 0, count: max(0, EqualizerConfiguration.bandCount - gains.count))
                try perform(.setEqualizer, payload: .init(equalizer: .init(enabled: enabled, gainsDecibels: normalized.map(Float.init))))
            }
            if args.count > 3, let monoEnabled = args[3] as? Bool {
                try perform(.setMonoEnabled, payload: .init(monoEnabled: monoEnabled))
            }
            return statusResponse()
        case "nativePlaybackLoad":
            guard let path = args.first as? String, !path.isEmpty else {
                throw PlaybackBridgeError.invalid("Playback load requires a file path.")
            }
            let index = max(0, int(args.count > 1 ? args[1] : nil) ?? 0)
            let startMilliseconds = max(0, int(args.count > 2 ? args[2] : nil) ?? 0)
            let playMilliseconds = max(1, int(args.count > 3 ? args[3] : nil) ?? 150_000)
            let fadeMilliseconds = max(0, int(args.count > 4 ? args[4] : nil) ?? 6_000)
            let tempo = number(args.count > 5 ? args[5] : nil) ?? 1
            let mode: PlaybackMode = fadeMilliseconds > 0 ? .timed : .fileDefault
            let payload = PlaybackControlPayload(
                path: path,
                trackIndex: index,
                tempo: tempo,
                playbackMode: mode,
                playMilliseconds: playMilliseconds,
                fadeMilliseconds: fadeMilliseconds
            )
            try perform(.load, payload: payload)
            if startMilliseconds > 0 { try perform(.seek, payload: .init(positionMilliseconds: startMilliseconds)) }
            lock.lock(); trackLoaded = true; lock.unlock()
            return statusResponse()
        case "nativePlaybackPlay":
            try perform(.play)
            return statusResponse()
        case "nativePlaybackPause":
            try perform(.pause)
            return statusResponse()
        case "nativePlaybackStop", "nativePlaybackClose", "nativePlaybackUnload":
            try perform(.stop)
            lock.lock(); trackLoaded = false; lock.unlock()
            return statusResponse()
        case "nativePlaybackSeek":
            let milliseconds = max(0, int(args.first) ?? 0)
            try perform(.seek, payload: .init(positionMilliseconds: milliseconds))
            return statusResponse()
        case "nativePlaybackRampGain":
            let gain = Float(number(args.first) ?? 0)
            let duration = max(1, int(args.count > 1 ? args[1] : nil) ?? 1)
            try perform(.rampOutputGain, payload: .init(outputGain: gain, rampMilliseconds: duration))
            return statusResponse()
        case "setPlaybackPowerSaveBlocker":
            return NSNull()
        case "materializeTrack":
            guard let archivePath = args.first as? String, let entry = args.dropFirst().first as? String else {
                throw PlaybackBridgeError.invalid("Archive playback requires a source archive and entry.")
            }
            return try ArchiveMaterializer.shared.materialize(archivePath: archivePath, entry: entry).path
        case "releaseMaterializedTrack":
            ArchiveMaterializer.shared.release()
            return NSNull()
        default:
            throw PlaybackBridgeError.invalid("Unknown playback request \(method).")
        }
    }

    private func perform(_ command: PlaybackControlCommand, payload: PlaybackControlPayload = .init()) throws {
        let event = controller.perform(.init(command: command, payload: payload))
        if event.kind == .error {
            throw PlaybackBridgeError.invalid(event.message ?? "VGMBoy playback request failed.")
        }
    }

    private func statusResponse() -> [String: Any] {
        let event = controller.perform(.init(command: .status))
        let status = event.status
        let diagnostics = status?.diagnostics
        let statistics = status?.statistics
        lock.lock(); let loaded = trackLoaded; lock.unlock()
        return [
            // reachedEnd means the decoder has no more source frames; output
            // may still be draining its buffered fade. Report ended only
            // after the audio device has stopped so the frontend does not
            // advance over the remaining audible tail.
            "transport_state": status?.isPlaying == true ? "playing" : (status?.reachedEnd == true ? "ended" : "stopped"),
            "output_state": diagnostics?.isOutputRunning == true ? "running" : "idle",
            "track_loaded": loaded,
            "decode_error": false,
            "reached_end": status?.reachedEnd ?? false,
            "buffered_frames": diagnostics?.bufferedFrames ?? 0,
            "ring_buffer_frames": diagnostics?.capacityFrames ?? 0,
            "underrun_count": diagnostics?.underrunCount ?? 0,
            "frames_requested": diagnostics?.framesRequested ?? 0,
            "frames_supplied": diagnostics?.framesSupplied ?? 0,
            "decoder_family": statistics?.decoderFamily ?? NSNull(),
            "track_index": statistics?.trackIndex ?? NSNull(),
            "decoder_sample_rate": statistics?.decoderSampleRate ?? 0,
            "output_sample_rate": statistics?.outputSampleRate ?? diagnostics?.sampleRate ?? 0,
            "decoded_frames": statistics?.decodedFrames ?? 0,
            "audible_position_frames": statistics?.audiblePositionFrames ?? 0,
            "tempo": statistics?.tempo ?? 1,
            "position_ms": Int((status?.elapsedSeconds ?? 0) * 1_000),
            "error": NSNull()
        ]
    }

    private func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func int(_ value: Any?) -> Int? {
        number(value).map(Int.init)
    }
}

private enum PlaybackBridgeError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}
