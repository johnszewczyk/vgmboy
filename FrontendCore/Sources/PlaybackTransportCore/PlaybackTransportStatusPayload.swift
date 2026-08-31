import Foundation

/// Stable JSON-facing projection of the shared transport status.
///
/// WebKit command replies and native event broadcasts must expose the same
/// fields. Keeping this projection beside the transport status prevents a
/// frontend bridge from silently dropping elapsed position or diagnostics.
public struct PlaybackTransportStatusPayload: Equatable, Sendable, Codable {
    public let transportState: String
    public let outputState: String
    public let generation: Int
    public let statusSequence: UInt64
    public let trackLoaded: Bool
    public let decodeError: Bool
    public let reachedEnd: Bool
    public let bufferedFrames: Int
    public let ringBufferFrames: Int
    public let underrunCount: Int64
    public let framesRequested: Int64
    public let framesSupplied: Int64
    public let decoderFamily: String?
    public let trackIndex: Int?
    public let decoderSampleRate: Int
    public let outputSampleRate: Int
    public let decodedFrames: Int64
    public let audiblePositionFrames: Int64
    public let tempo: Double
    public let positionMilliseconds: Int
    public let error: String?

    public init(
        status: PlaybackTransportStatus,
        forcedTransportState: String? = nil,
        forcedReachedEnd: Bool? = nil
    ) {
        if let forcedTransportState {
            transportState = forcedTransportState
        } else if status.isPlaying {
            transportState = "playing"
        } else if status.reachedEnd {
            transportState = "ended"
        } else if status.trackLoaded {
            transportState = "paused"
        } else {
            transportState = "stopped"
        }
        outputState = status.outputIsRunning ? "running" : "idle"
        generation = status.generation
        statusSequence = status.statusSequence
        trackLoaded = status.trackLoaded
        decodeError = status.errorMessage != nil
        reachedEnd = forcedReachedEnd ?? status.reachedEnd
        bufferedFrames = status.bufferedFrames
        ringBufferFrames = status.ringBufferFrames
        underrunCount = status.underrunCount
        framesRequested = status.framesRequested
        framesSupplied = status.framesSupplied
        decoderFamily = status.decoderFamily
        trackIndex = status.trackIndex
        decoderSampleRate = status.decoderSampleRate
        outputSampleRate = status.outputSampleRate
        decodedFrames = status.decodedFrames
        audiblePositionFrames = status.audiblePositionFrames
        tempo = status.tempo
        positionMilliseconds = Int((status.elapsedSeconds * 1_000).rounded())
        error = status.errorMessage
    }

    /// Foundation object values suitable for `JSONSerialization`.
    public func jsonObject() -> [String: Any] {
        [
            "transport_state": transportState,
            "output_state": outputState,
            "generation": generation,
            "status_sequence": statusSequence,
            "track_loaded": trackLoaded,
            "decode_error": decodeError,
            "reached_end": reachedEnd,
            "buffered_frames": bufferedFrames,
            "ring_buffer_frames": ringBufferFrames,
            "underrun_count": underrunCount,
            "frames_requested": framesRequested,
            "frames_supplied": framesSupplied,
            "decoder_family": decoderFamily ?? NSNull(),
            "track_index": trackIndex ?? NSNull(),
            "decoder_sample_rate": decoderSampleRate,
            "output_sample_rate": outputSampleRate,
            "decoded_frames": decodedFrames,
            "audible_position_frames": audiblePositionFrames,
            "tempo": tempo,
            "position_ms": positionMilliseconds,
            "error": error ?? NSNull()
        ]
    }
}
