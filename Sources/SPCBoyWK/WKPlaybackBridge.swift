import Foundation
import PlaybackRequestCore
import VGMBoyKit

/// Thin WK adapter over the shared in-process VGMBoy control surface.
/// Queue/catalog policy remains in the web frontend; this object owns only
/// decoder transport and audio configuration.
final class WKPlaybackBridge: @unchecked Sendable {
    static let shared = WKPlaybackBridge()

    private let controller = PlaybackController()
    private let commandQueue = PlaybackSerialExecutor(label: "SPCBoyWK.vgmboy-playback", qos: .userInitiated)
    private let lock = NSLock()
    private var latestRequestID = 0
    private var trackLoaded = false

    private init() {}

    func handle(method: String, args: [Any]) throws -> Any {
        let requestID: Int?
        if method == "nativePlaybackStart" {
            requestID = beginRequest()
        } else {
            requestID = nil
            if ["nativePlaybackStop", "nativePlaybackClose", "nativePlaybackUnload"].contains(method) {
                cancelRequest()
            }
        }
        return try commandQueue.sync {
            try handleSerialized(method: method, args: args, requestID: requestID)
        }
    }

    private func handleSerialized(method: String, args: [Any], requestID: Int? = nil) throws -> Any {
        switch method {
        case "nativePlaybackInit", "nativePlaybackState":
            return statusResponse()
        case "nativePlaybackAudioConfig":
            let rawVolume = number(args.first).map(Float.init)
            let rawGains = (args.count > 2 ? args[2] as? [Any] : nil)?.compactMap(number).map(Float.init)
            let preferences = PlaybackPreferences(
                equalizerEnabled: args.count > 1 ? (args[1] as? Bool) ?? false : false,
                equalizerBandGains: rawGains ?? Array(repeating: 0, count: EqualizerConfiguration.bandCount),
                outputVolume: rawVolume ?? PlaybackPreferences.defaultValue.outputVolume,
                monoEnabled: args.count > 3 ? (args[3] as? Bool) ?? false : false
            )
            if rawVolume != nil {
                try perform(.setOutputVolume, payload: .init(outputVolume: preferences.outputVolume))
            }
            if args.count > 1 {
                try perform(.setEqualizer, payload: .init(equalizer: preferences.equalizer))
            }
            if args.count > 3 {
                try perform(.setMonoEnabled, payload: .init(monoEnabled: preferences.monoEnabled))
            }
            return statusResponse()
        case "nativePlaybackTiming":
            guard let request = args.first as? [String: Any],
                  let path = request["path"] as? String,
                  !path.isEmpty,
                  let family = FormatRegistry.family(for: path) else {
                throw PlaybackBridgeError.invalid("Playback timing requires a supported file path.")
            }
            let metadata = PlaybackTimingMetadata(
                playMilliseconds: max(0, int(request["playMilliseconds"]) ?? 0)
            )
            let preferences = PlaybackTimingPreferences(
                longPlaySeconds: max(
                    1,
                    int(request["manualPlayMilliseconds"]).map { $0 / 1_000 }
                        ?? PlaybackTimingPreferences.defaultLongPlaySeconds
                ),
                unknownDurationSeconds: max(
                    1,
                    int(request["unknownDurationMilliseconds"]).map { $0 / 1_000 }
                        ?? PlaybackTimingPreferences.defaultUnknownDurationSeconds
                ),
                fadeSeconds: max(
                    0,
                    int(request["fadeMilliseconds"]).map { $0 / 1_000 }
                        ?? PlaybackTimingPreferences.defaultFadeSeconds
                )
            )
            let plan = PlaybackTimingPolicy.plan(
                metadata: metadata,
                family: family,
                longPlayEnabled: request["longPlayEnabled"] as? Bool ?? false,
                preferences: preferences
            )
            let tempo = tempoMultiplier(request["tempo"])
            let scaledPreFadeSeconds = max(
                1,
                Int((Double(plan.preFadeSeconds) / tempo).rounded(.down))
            )
            return [
                "pre_fade_seconds": scaledPreFadeSeconds,
                "fade_seconds": plan.fadeSeconds,
                "total_seconds": scaledPreFadeSeconds + plan.fadeSeconds,
                "is_long_play": plan.isLongPlay,
                "uses_native_ending": plan.usesNativeEnding
            ]
        case "nativePlaybackStart":
            guard let request = args.first as? [String: Any],
                  let sourcePath = request["path"] as? String,
                  !sourcePath.isEmpty else {
                throw PlaybackBridgeError.invalid("Playback start requires a file path.")
            }
            guard requestID.map(isCurrentRequest) ?? true else {
                throw PlaybackBridgeError.superseded
            }
            let archivePath = request["archivePath"] as? String
            let archiveEntry = request["archiveEntry"] as? String
            let playbackPath: String
            if let archivePath, !archivePath.isEmpty, let archiveEntry, !archiveEntry.isEmpty {
                guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
                    throw PlaybackBridgeError.invalid("VGMBoy does not admit archive member \(archiveEntry).")
                }
                playbackPath = try SPCArchiveMaterialization.materialize(
                    archivePath: archivePath,
                    entry: archiveEntry,
                    requirement: requirement
                ).path
            } else {
                playbackPath = sourcePath
            }
            guard requestID.map(isCurrentRequest) ?? true else {
                throw PlaybackBridgeError.superseded
            }
            let index = max(0, int(request["trackIndex"]) ?? 0)
            let startMilliseconds = max(0, int(request["startMilliseconds"]) ?? 0)
            let requestedPlayMilliseconds = int(request["playMilliseconds"])
            let fadeMilliseconds = max(0, int(request["fadeMilliseconds"]) ?? 6_000)
            let tempo = tempoMultiplier(request["tempo"])
            let longPlayEnabled = request["longPlayEnabled"] as? Bool ?? false
            let timedOverride = request["timedOverride"] as? Bool ?? false
            let unknownDurationMilliseconds = max(
                1_000,
                int(request["unknownDurationMilliseconds"])
                    ?? PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000
            )
            let timing: PlaybackTimingRequest
            if timedOverride {
                timing = try PlaybackTimingRequest.timed(
                    playMilliseconds: requestedPlayMilliseconds ?? 0,
                    fadeMilliseconds: fadeMilliseconds
                )
            } else {
                timing = try PlaybackTimingRequest.standard(
                    path: playbackPath,
                    longPlayEnabled: longPlayEnabled,
                    manualPlayMilliseconds: requestedPlayMilliseconds ?? 0,
                    fadeMilliseconds: fadeMilliseconds,
                    unknownDurationMilliseconds: unknownDurationMilliseconds
                )
            }
            let payload = PlaybackControlPayload(
                path: playbackPath,
                trackIndex: index,
                tempo: tempo,
                playbackMode: timing.playbackMode,
                playMilliseconds: timing.playMilliseconds,
                fadeMilliseconds: timing.fadeMilliseconds,
                unknownDurationMilliseconds: timing.unknownDurationMilliseconds
            )
            try perform(.load, payload: payload)
            if startMilliseconds > 0 { try perform(.seek, payload: .init(positionMilliseconds: startMilliseconds)) }
            try perform(.play)
            lock.lock(); trackLoaded = true; lock.unlock()
            return statusResponse()
        case "nativePlaybackResume":
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
        case "releaseMaterializedTrack":
            SPCArchiveMaterialization.release()
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
            "generation": diagnostics?.generation ?? 0,
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

    private func tempoMultiplier(_ value: Any?) -> Double {
        if let scalar = number(value), scalar.isFinite, scalar > 0 {
            return scalar
        }
        guard let ratio = value as? [String: Any],
              let numerator = number(ratio["numerator"]),
              let denominator = number(ratio["denominator"]),
              numerator.isFinite,
              denominator.isFinite,
              numerator > 0,
              denominator > 0 else {
            return 1
        }
        return numerator / denominator
    }

    private func beginRequest() -> Int {
        lock.lock()
        latestRequestID += 1
        let requestID = latestRequestID
        lock.unlock()
        return requestID
    }

    private func cancelRequest() {
        lock.lock()
        latestRequestID += 1
        lock.unlock()
    }

    private func isCurrentRequest(_ requestID: Int) -> Bool {
        lock.lock()
        let isCurrent = requestID == latestRequestID
        lock.unlock()
        return isCurrent
    }
}

private enum PlaybackBridgeError: LocalizedError {
    case invalid(String)
    case superseded

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        case .superseded: return "Playback request was superseded."
        }
    }
}
