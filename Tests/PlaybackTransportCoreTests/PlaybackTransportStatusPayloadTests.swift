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

@Test
func transportStartRequestKeepsStableIdentityAndTypedTimingAtTheBridge() throws {
    let request = PlaybackTransportStartRequest(
        trackID: "catalog-track-7",
        sourcePath: "/music/archive.zip",
        archivePath: "/music/archive.zip",
        archiveEntry: "Game/07 - Start.spc",
        trackIndex: 2,
        startMilliseconds: 1_250,
        playMilliseconds: 90_000,
        fadeMilliseconds: 4_000,
        tempo: .init(numerator: 5, denominator: 4),
        longPlayEnabled: false,
        timedOverride: true,
        unknownDurationMilliseconds: 180_000
    )

    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(PlaybackTransportStartRequest.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let start = try request.continuationStart(
        resolvedPath: "/cache/Game/07 - Start.spc",
        requestID: 12
    )

    #expect(decoded == request)
    #expect(object["trackId"] as? String == "catalog-track-7")
    #expect(object["trackID"] == nil)
    #expect(start.track.id == "catalog-track-7")
    #expect(start.track.path == "/cache/Game/07 - Start.spc")
    #expect(start.startMilliseconds == 1_250)
    #expect(start.payload.trackIndex == 2)
    #expect(start.payload.playbackMode == .timed)
    #expect(start.payload.playMilliseconds == 90_000)
    #expect(start.payload.tempo == 1.25)
}

@Test
func timingBridgeContractsKeepPolicyAndControlPayloadOutOfTheFrontend() throws {
    let previewRequest = PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc",
        playMilliseconds: 90_000,
        manualPlayMilliseconds: 240_000,
        fadeMilliseconds: 4_000,
        unknownDurationMilliseconds: 180_000,
        tempo: .init(numerator: 5, denominator: 4),
        longPlayEnabled: false
    )
    let encodedRequest = try JSONEncoder().encode(previewRequest)
    let decodedRequest = try JSONDecoder().decode(
        PlaybackTimingPreviewRequest.self,
        from: encodedRequest
    )
    let requestObject = try #require(
        JSONSerialization.jsonObject(with: encodedRequest) as? [String: Any]
    )
    let preview = try previewRequest.preview()
    let previewObject = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(preview)) as? [String: Any]
    )

    #expect(decodedRequest == previewRequest)
    #expect(requestObject["path"] as? String == "/music/track.spc")
    #expect(requestObject["sourcePath"] == nil)
    #expect(preview.preFadeSeconds == 72)
    #expect(preview.fadeSeconds == 4)
    #expect(preview.totalSeconds == 76)
    #expect(previewObject["pre_fade_seconds"] as? Int == 72)
    #expect(previewObject["total_seconds"] as? Int == 76)

    let reconfiguration = PlaybackTransportReconfigurationRequest(
        longPlayEnabled: true,
        manualPlayMilliseconds: 240_000,
        fadeMilliseconds: 4_000,
        unknownDurationMilliseconds: 180_000,
        tempo: .init(numerator: 3, denominator: 2)
    )
    let reconfigurationPayload = reconfiguration.playbackModePayload
    let tempoRequest = PlaybackTransportTempoRequest(tempo: .init(numerator: 3, denominator: 2))

    #expect(reconfigurationPayload.playbackMode == .longPlay)
    #expect(reconfigurationPayload.playMilliseconds == 240_000)
    #expect(reconfigurationPayload.fadeMilliseconds == 4_000)
    #expect(reconfigurationPayload.unknownDurationMilliseconds == 180_000)
    #expect(reconfiguration.tempo.multiplier == 1.5)
    #expect(tempoRequest.tempo.multiplier == 1.5)
}

@Test
func audioBridgeContractNormalizesOneCompleteOutputSnapshot() throws {
    let request = PlaybackTransportAudioConfigurationRequest(
        outputVolume: 2,
        equalizerEnabled: true,
        equalizerBandGains: [-20, -12, 0, 12, 20],
        monoEnabled: true
    )
    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(
        PlaybackTransportAudioConfigurationRequest.self,
        from: encoded
    )
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(decoded == request)
    #expect(object["appVolume"] as? Float == 1)
    #expect(object["outputVolume"] == nil)
    #expect(request.preferences.outputVolume == 1)
    #expect(request.preferences.equalizer.enabled)
    #expect(request.preferences.equalizer.gainsDecibels.count == 10)
    #expect(request.preferences.equalizer.gainsDecibels.prefix(5) == [-12, -12, 0, 12, 12])
    #expect(request.preferences.monoEnabled)
}

@Test
func aacExportBridgeContractRetainsArchiveReferenceAndBuildsTheCoreRequest() throws {
    let request = PlaybackTransportAACExportRequest(
        sourcePath: "/music/archive.zip",
        archivePath: "/music/archive.zip",
        archiveEntry: "Game/Ending.spc",
        trackIndex: 2,
        outputDirectory: "/exports",
        filenameStem: "Ending",
        playMilliseconds: 90_000,
        fadeMilliseconds: 4_000
    )
    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(PlaybackTransportAACExportRequest.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let coreRequest = try request.exportRequest(resolvedPath: "/cache/Game/Ending.spc")
    let cancellation = PlaybackTransportAACExportCancellationRequest(id: "export-7")

    #expect(decoded == request)
    #expect(object["path"] as? String == "/music/archive.zip")
    #expect(object["sourcePath"] == nil)
    #expect(coreRequest.sourcePath == "/cache/Game/Ending.spc")
    #expect(coreRequest.trackIndex == 2)
    #expect(coreRequest.outputDirectory.path == "/exports")
    #expect(coreRequest.filenameStem == "Ending")
    #expect(coreRequest.playMilliseconds == 90_000)
    #expect(coreRequest.fadeMilliseconds == 4_000)
    #expect(cancellation.id == "export-7")
}

@Test
func directTransportCommandContractsNormalizeNamedBridgeValues() throws {
    let seek = PlaybackTransportSeekRequest(positionMilliseconds: -10)
    let ramp = PlaybackTransportRampGainRequest(outputGain: .infinity, rampMilliseconds: 0)
    let encoded = try JSONEncoder().encode(PlaybackTransportSeekRequest(positionMilliseconds: 1_250))
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(seek.positionMilliseconds == 0)
    #expect(seek.payload.positionMilliseconds == 0)
    #expect(ramp.outputGain == 0)
    #expect(ramp.rampMilliseconds == 1)
    #expect(ramp.payload.outputGain == 0)
    #expect(ramp.payload.rampMilliseconds == 1)
    #expect(object["positionMilliseconds"] as? Int == 1_250)
}
