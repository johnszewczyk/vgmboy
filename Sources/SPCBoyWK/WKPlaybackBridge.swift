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
            let request: PlaybackTransportAudioConfigurationRequest = try bridgeRequest(
                args,
                errorMessage: "Audio configuration requires complete output settings."
            )
            return statusResponse(try transport.configureAudio(request))
        case "nativePlaybackTiming":
            let request: PlaybackTimingPreviewRequest = try bridgeRequest(
                args,
                errorMessage: "Playback timing requires complete timing settings."
            )
            return try bridgeResponse(request.preview())
        case "nativePlaybackReconfigure":
            let request: PlaybackTransportReconfigurationRequest = try bridgeRequest(
                args,
                errorMessage: "Playback reconfiguration requires complete timing settings."
            )
            try perform(.setTempo, payload: .init(tempo: request.tempo.multiplier))
            try perform(.setPlaybackMode, payload: request.playbackModePayload)
            return statusResponse()
        case "nativePlaybackSetTempo":
            let request: PlaybackTransportTempoRequest = try bridgeRequest(
                args,
                errorMessage: "Tempo update requires a tempo value."
            )
            try perform(.setTempo, payload: .init(tempo: request.tempo.multiplier))
            return statusResponse()
        case "nativePlaybackStart":
            guard requestID.map(transport.isCurrentPlaybackRequest) ?? true else {
                throw PlaybackBridgeError.superseded
            }
            let request: PlaybackTransportStartRequest = try bridgeRequest(
                args,
                errorMessage: "Playback start requires a complete track request."
            )
            let playbackPath: String
            if let archivePath = request.archivePath, !archivePath.isEmpty,
               let archiveEntry = request.archiveEntry, !archiveEntry.isEmpty {
                guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
                    throw PlaybackBridgeError.invalid("VGMBoy does not admit archive member \(archiveEntry).")
                }
                playbackPath = try SPCArchiveMaterialization.materialize(
                    archivePath: archivePath,
                    entry: archiveEntry,
                    requirement: requirement
                ).path
            } else {
                playbackPath = request.sourcePath
            }
            guard requestID.map(transport.isCurrentPlaybackRequest) ?? true else {
                throw PlaybackBridgeError.superseded
            }
            try transport.start(try request.continuationStart(
                resolvedPath: playbackPath,
                requestID: requestID ?? transport.reservePlaybackRequest()
            ))
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
            let request: PlaybackTransportSeekRequest = try bridgeRequest(
                args,
                errorMessage: "Playback seek requires a position."
            )
            try perform(.seek, payload: request.payload)
            return statusResponse()
        case "nativePlaybackRampGain":
            let request: PlaybackTransportRampGainRequest = try bridgeRequest(
                args,
                errorMessage: "Playback output ramp requires gain and duration."
            )
            try perform(.rampOutputGain, payload: request.payload)
            return statusResponse()
        case "nativeExportAAC":
            let request: PlaybackTransportAACExportRequest = try bridgeRequest(
                args,
                errorMessage: "AAC export requires a complete render request."
            )
            return try bridgeResponse(try exportAAC(request))
        case "nativeExportAACCancel":
            let request: PlaybackTransportAACExportCancellationRequest = try bridgeRequest(
                args,
                errorMessage: "AAC export cancellation requires an export identifier."
            )
            return try bridgeResponse(cancelAACExport(request))
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

    private func exportAAC(
        _ request: PlaybackTransportAACExportRequest
    ) throws -> PlaybackTransportAACExportResponse {
        let playbackPath: String
        var materialized = false
        if let archivePath = request.archivePath, !archivePath.isEmpty,
           let archiveEntry = request.archiveEntry, !archiveEntry.isEmpty {
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
            playbackPath = request.sourcePath
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
        publishExport(.init(id: exportID, state: "rendering", renderedFrames: 0, totalFrames: 0, message: request.filenameStem))
        do {
            let outputURL = try transport.exportAAC(
                try request.exportRequest(resolvedPath: playbackPath),
                cancellation: cancellation,
                progress: { [weak self] progress in
                    self?.publishExport(.init(
                        id: exportID,
                        state: "rendering",
                        renderedFrames: progress.renderedFrames,
                        totalFrames: progress.totalFrames,
                        message: request.filenameStem
                    ))
                }
            )
            publishExport(.init(id: exportID, state: "completed", renderedFrames: 0, totalFrames: 0, message: outputURL.path))
            return .init(path: outputURL.path, id: exportID)
        } catch {
            let state = (error as? AACExportError) == .cancelled ? "cancelled" : "failed"
            publishExport(.init(id: exportID, state: state, renderedFrames: 0, totalFrames: 0, message: error.localizedDescription))
            throw error
        }
    }

    private func cancelAACExport(
        _ request: PlaybackTransportAACExportCancellationRequest
    ) -> PlaybackTransportAACExportCancellationResponse {
        exportLock.lock()
        defer { exportLock.unlock() }
        guard let activeExport,
              request.id == nil || request.id == activeExport.id else { return .init(cancelled: false) }
        activeExport.cancellation.cancel()
        return .init(cancelled: true, id: activeExport.id)
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

    private func bridgeRequest<Request: Decodable>(
        _ args: [Any],
        errorMessage: String
    ) throws -> Request {
        guard let payload = args.first as? [String: Any],
              JSONSerialization.isValidJSONObject(payload) else {
            throw PlaybackBridgeError.invalid(errorMessage)
        }
        do {
            return try JSONDecoder().decode(
                Request.self,
                from: JSONSerialization.data(withJSONObject: payload)
            )
        } catch {
            throw PlaybackBridgeError.invalid(errorMessage)
        }
    }

    private func bridgeResponse<Response: Encodable>(_ response: Response) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(response)
        ) as? [String: Any] else {
            throw PlaybackBridgeError.invalid("Playback bridge failed to encode its response.")
        }
        return object
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
