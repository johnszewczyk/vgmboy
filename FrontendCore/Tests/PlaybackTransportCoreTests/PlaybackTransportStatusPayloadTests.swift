import Foundation
import Testing
@testable import PlaybackTransportCore

@Test
func statusPayloadKeepsReplyAndEventFieldsIdentical() throws {
    let status = PlaybackTransportStatus(
        currentTrackID: "track-a",
        generation: 7,
        statusSequence: 42,
        isPlaying: true,
        elapsedSeconds: 12.3456,
        reachedEnd: false,
        trackLoaded: true,
        outputIsRunning: true,
        errorMessage: "decode warning",
        bufferedFrames: 4_096,
        ringBufferFrames: 88_200,
        underrunCount: 2,
        framesRequested: 12_000,
        framesSupplied: 11_900,
        decoderFamily: "spc",
        trackIndex: 3,
        decoderSampleRate: 32_000,
        outputSampleRate: 44_100,
        decodedFrames: 600_000,
        audiblePositionFrames: 595_904,
        tempo: 1.25
    )

    let reply = PlaybackTransportStatusPayload(status: status).jsonObject()
    let event = PlaybackTransportStatusPayload(status: status).jsonObject()

    #expect(reply["transport_state"] as? String == "playing")
    #expect(reply["status_sequence"] as? UInt64 == 42)
    #expect(reply["position_ms"] as? Int == 12_346)
    #expect(reply["decoder_family"] as? String == "spc")
    #expect(reply["track_index"] as? Int == 3)
    #expect(NSDictionary(dictionary: reply).isEqual(to: NSDictionary(dictionary: event)))
}

@Test
func statusPayloadCanRepresentDrainedNaturalEnd() {
    let status = PlaybackTransportStatus(
        currentTrackID: "track-a",
        generation: 7,
        isPlaying: false,
        elapsedSeconds: 19,
        reachedEnd: false,
        trackLoaded: true,
        outputIsRunning: false
    )

    let payload = PlaybackTransportStatusPayload(
        status: status,
        forcedTransportState: "ended",
        forcedReachedEnd: true
    ).jsonObject()

    #expect(payload["transport_state"] as? String == "ended")
    #expect(payload["reached_end"] as? Bool == true)
}
