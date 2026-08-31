import Foundation
import PlaybackQueueCore
import PlaybackTransportCore
import VGMBoyKit

/// Thin WK adapter over the shared in-process VGMBoy control surface.
/// Queue selection remains in the web frontend; completion claiming/decision,
/// decoder transport, and audio configuration remain behind the shared native
/// transport boundary.
final class WKPlaybackBridge: @unchecked Sendable {
    struct AACExportEvent: Sendable {
        let id: String
        let state: String
        let renderedFrames: Int64
        let totalFrames: Int64
        let message: String?
    }

    static let shared = WKPlaybackBridge()

    private let transport = PlaybackTransportCoordinator(label: "SPCBoyWK.vgmboy-playback")
    private let handlerLock = NSLock()
    private var statusHandler: (@Sendable (PlaybackTransportStatus) -> Void)?
    private var naturalEndHandler: (@Sendable (PlaybackTransportStatus) -> Void)?
    private var exportEventHandler: (@Sendable (AACExportEvent) -> Void)?
    private let exportLock = NSLock()
    private var activeExport: (id: String, cancellation: AACExportCancellation)?

    private init() {
        transport.setStatusHandler { [weak self] status in
            self?.publishStatus(status)
        }
        transport.setNaturalEndHandler { [weak self] status in
            self?.publishNaturalEnd(status)
        }
    }

    func setStatusHandler(_ handler: (@Sendable (PlaybackTransportStatus) -> Void)?) {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        statusHandler = handler
    }

    func setNaturalEndHandler(_ handler: (@Sendable (PlaybackTransportStatus) -> Void)?) {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        naturalEndHandler = handler
    }

    func setExportEventHandler(_ handler: (@Sendable (AACExportEvent) -> Void)?) {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        exportEventHandler = handler
    }

    func retireCompletedPlayback(
        _ request: PlaybackContinuationRequest
    ) -> PlaybackContinuationDecision? {
        transport.retireCompletedPlayback(request)
    }

    func handle(method: String, args: [Any]) throws -> Any {
        let requestID: Int?
        if method == "nativePlaybackStart" {
            requestID = transport.reservePlaybackRequest()
        } else {
            requestID = nil
            if ["nativePlaybackStop", "nativePlaybackClose", "nativePlaybackUnload"].contains(method) {
                transport.invalidatePlaybackRequests()
            }
        }
        return try handleSerialized(method: method, args: args, requestID: requestID)
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
                    0,
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
            let scaledPreFadeSeconds = plan.preFadeSeconds <= 0
                ? 0
                : max(1, Int((Double(plan.preFadeSeconds) / tempo).rounded(.down)))
            return [
                "pre_fade_seconds": scaledPreFadeSeconds,
                "fade_seconds": plan.fadeSeconds,
                "total_seconds": scaledPreFadeSeconds > 0 ? scaledPreFadeSeconds + plan.fadeSeconds : 0,
                "is_long_play": plan.isLongPlay,
                "uses_native_ending": plan.usesNativeEnding
            ]
        case "nativePlaybackReconfigure":
            guard let request = args.first as? [String: Any] else {
                throw PlaybackBridgeError.invalid("Playback reconfiguration requires timing settings.")
            }
            let mode: PlaybackMode = (request["longPlayEnabled"] as? Bool == true) ? .longPlay : .fileDefault
            let payload = PlaybackControlPayload(
                playbackMode: mode,
                playMilliseconds: mode == .longPlay ? max(0, int(request["manualPlayMilliseconds"]) ?? 0) : nil,
                fadeMilliseconds: max(0, int(request["fadeMilliseconds"]) ?? 0),
                unknownDurationMilliseconds: max(
                    1_000,
                    int(request["unknownDurationMilliseconds"])
                    ?? PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000
                )
            )
            try perform(.setTempo, payload: .init(tempo: tempoMultiplier(request["tempo"])))
            try perform(.setPlaybackMode, payload: payload)
            return statusResponse()
        case "nativePlaybackSetTempo":
            guard let request = args.first as? [String: Any] else {
                throw PlaybackBridgeError.invalid("Tempo update requires a tempo value.")
            }
            try perform(.setTempo, payload: .init(tempo: tempoMultiplier(request["tempo"])))
            return statusResponse()
        case "nativePlaybackStart":
            guard let request = args.first as? [String: Any],
                  let sourcePath = request["path"] as? String,
                  !sourcePath.isEmpty else {
                throw PlaybackBridgeError.invalid("Playback start requires a file path.")
            }
            guard requestID.map(transport.isCurrentPlaybackRequest) ?? true else {
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
            guard requestID.map(transport.isCurrentPlaybackRequest) ?? true else {
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
            return statusResponse()
        case "nativePlaybackResume":
            try perform(.play)
            return statusResponse()
        case "nativePlaybackPause":
            try perform(.pause)
            return statusResponse()
        case "nativePlaybackStop", "nativePlaybackClose", "nativePlaybackUnload":
            defer { SPCArchiveMaterialization.release() }
            try perform(.stop)
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
        case "nativeExportAAC":
            return try exportAAC(args)
        case "nativeExportAACCancel":
            return cancelAACExport(args)
        case "setPlaybackPowerSaveBlocker":
            return NSNull()
        default:
            throw PlaybackBridgeError.invalid("Unknown playback request \(method).")
        }
    }

    private func perform(_ command: PlaybackControlCommand, payload: PlaybackControlPayload = .init()) throws {
        let event = transport.perform(.init(command: command, payload: payload))
        if event.kind == .error {
            throw PlaybackBridgeError.invalid(event.message ?? "VGMBoy playback request failed.")
        }
    }

    private func exportAAC(_ args: [Any]) throws -> [String: Any] {
        guard let request = args.first as? [String: Any],
              let sourcePath = request["path"] as? String, !sourcePath.isEmpty,
              let outputDirectory = request["outputDirectory"] as? String, !outputDirectory.isEmpty,
              let filenameStem = request["filenameStem"] as? String,
              let playMilliseconds = int(request["playMilliseconds"]), playMilliseconds > 0 else {
            throw PlaybackBridgeError.invalid("AAC export requires a playable path, output folder, filename, and positive play length.")
        }
        let archivePath = request["archivePath"] as? String
        let archiveEntry = request["archiveEntry"] as? String
        let playbackPath: String
        var materialized = false
        if let archivePath, !archivePath.isEmpty, let archiveEntry, !archiveEntry.isEmpty {
            guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
                throw PlaybackBridgeError.invalid("VGMBoy does not admit archive member \(archiveEntry).")
            }
            playbackPath = try SPCArchiveMaterialization.materializeForExport(
                archivePath: archivePath,
                entry: archiveEntry,
                requirement: requirement
            ).path
            materialized = true
        } else {
            playbackPath = sourcePath
        }
        let exportID = UUID().uuidString
        let cancellation = AACExportCancellation()
        exportLock.lock()
        guard activeExport == nil else {
            exportLock.unlock()
            throw PlaybackBridgeError.invalid("AAC export already in progress.")
        }
        activeExport = (exportID, cancellation)
        exportLock.unlock()
        defer {
            if materialized { SPCArchiveMaterialization.releaseExport() }
            exportLock.lock()
            if activeExport?.id == exportID { activeExport = nil }
            exportLock.unlock()
        }
        publishExport(.init(id: exportID, state: "rendering", renderedFrames: 0, totalFrames: 0, message: filenameStem))
        do {
            let outputURL = try transport.exportAAC(.init(
                sourcePath: playbackPath,
                trackIndex: max(0, int(request["trackIndex"]) ?? 0),
                outputDirectory: URL(fileURLWithPath: outputDirectory),
                filenameStem: filenameStem,
                playMilliseconds: playMilliseconds,
                fadeMilliseconds: max(0, int(request["fadeMilliseconds"]) ?? 0)
            ),
                cancellation: cancellation,
                progress: { [weak self] progress in
                    self?.publishExport(.init(
                        id: exportID,
                        state: "rendering",
                        renderedFrames: progress.renderedFrames,
                        totalFrames: progress.totalFrames,
                        message: filenameStem
                    ))
                }
            )
            publishExport(.init(id: exportID, state: "completed", renderedFrames: 0, totalFrames: 0, message: outputURL.path))
            return ["path": outputURL.path, "id": exportID]
        } catch {
            let state = (error as? AACExportError) == .cancelled ? "cancelled" : "failed"
            publishExport(.init(id: exportID, state: state, renderedFrames: 0, totalFrames: 0, message: error.localizedDescription))
            throw error
        }
    }

    private func cancelAACExport(_ args: [Any]) -> [String: Any] {
        let requestedID = (args.first as? [String: Any])?["id"] as? String
        exportLock.lock()
        defer { exportLock.unlock() }
        guard let activeExport,
              requestedID == nil || requestedID == activeExport.id else { return ["cancelled": false] }
        activeExport.cancellation.cancel()
        return ["cancelled": true, "id": activeExport.id]
    }

    private func publishExport(_ event: AACExportEvent) {
        handlerLock.lock()
        let handler = exportEventHandler
        handlerLock.unlock()
        handler?(event)
    }

    private func publishStatus(_ status: PlaybackTransportStatus) {
        handlerLock.lock()
        let handler = statusHandler
        handlerLock.unlock()
        handler?(status)
    }

    private func publishNaturalEnd(_ status: PlaybackTransportStatus) {
        handlerLock.lock()
        let handler = naturalEndHandler
        handlerLock.unlock()
        handler?(status)
    }

    private func statusResponse() -> [String: Any] {
        return statusResponse(transport.statusSync())
    }

    private func statusResponse(_ status: PlaybackTransportStatus) -> [String: Any] {
        // reachedEnd means the decoder has no more source frames; output may
        // still be draining its buffered fade. The shared projection keeps
        // this reply identical to native status broadcasts.
        return PlaybackTransportStatusPayload(status: status).jsonObject()
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
