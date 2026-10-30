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
func timingPreviewRejectsOutOfRangeValuesBeforeScaling() throws {
    let oversized = PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", playMilliseconds: Int.max,
        tempo: .init(numerator: 1, denominator: 32)
    )
    #expect(throws: (any Error).self) { try oversized.preview() }

    let json = #"{"path":"/music/track.spc","playMilliseconds":-1,"manualPlayMilliseconds":1000,"fadeMilliseconds":0,"unknownDurationMilliseconds":1000,"tempo":{"numerator":1,"denominator":1},"longPlayEnabled":false}"#
    let decoded = try JSONDecoder().decode(PlaybackTimingPreviewRequest.self, from: Data(json.utf8))
    #expect(throws: (any Error).self) { try decoded.preview() }

    let boundary = try PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", playMilliseconds: Int(Int32.max), fadeMilliseconds: 0,
        tempo: .init(numerator: 1, denominator: 32)
    ).preview()
    #expect(boundary.preFadeMilliseconds > Int(Int32.max))
}

@Test
func timingPreviewSaturatesOverflowInDirectAndDecodedValues() throws {
    let direct = PlaybackTimingPreview(preFadeSeconds: Int.max, fadeSeconds: 1,
        isLongPlay: false, usesNativeEnding: false)
    #expect(direct.totalSeconds == Int.max)
    #expect(direct.preFadeMilliseconds == Int.max)
    #expect(direct.fadeMilliseconds == 1_000)
    #expect(direct.totalMilliseconds == Int.max)

    let json = """
    {"pre_fade_seconds":\(Int.max),"fade_seconds":1,"is_long_play":false,"uses_native_ending":false}
    """
    let decoded = try JSONDecoder().decode(PlaybackTimingPreview.self, from: Data(json.utf8))
    #expect(decoded == direct)

    let explicit = PlaybackTimingPreview(preFadeSeconds: 1, fadeSeconds: 1,
        isLongPlay: false, usesNativeEnding: false, preFadeMilliseconds: Int.max, fadeMilliseconds: 1)
    #expect(explicit.totalSeconds == 2)
    #expect(explicit.totalMilliseconds == Int.max)
    let unbounded = PlaybackTimingPreview(preFadeSeconds: 0, fadeSeconds: Int.max,
        isLongPlay: true, usesNativeEnding: false)
    #expect(unbounded.totalSeconds == 0 && unbounded.totalMilliseconds == 0)
    #expect(unbounded.fadeMilliseconds == Int.max)
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
        requestID: 12
    )

    #expect(decoded == request)
    #expect(object["trackId"] as? String == "catalog-track-7")
    #expect(object["trackID"] == nil)
    #expect(start.track.id == "catalog-track-7")
    #expect(start.track.path == "/music/archive.zip")
    #expect(start.payload.path == "/music/archive.zip")
    #expect(start.payload.archiveEntry == "Game/07 - Start.spc")
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

    let longPlayPreview = try PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", manualPlayMilliseconds: 90_000,
        fadeMilliseconds: 6_000, tempo: .init(numerator: 2, denominator: 1),
        longPlayEnabled: true
    ).preview()
    #expect(longPlayPreview.preFadeSeconds == 45)
    #expect(longPlayPreview.totalSeconds == 51)
    #expect(longPlayPreview.preFadeMilliseconds == 45_000)
    #expect(longPlayPreview.totalMilliseconds == 51_000)

    let precisePreview = try PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", playMilliseconds: 750,
        fadeMilliseconds: 250, tempo: .init(numerator: 2, denominator: 1)
    ).preview()
    #expect(precisePreview.preFadeMilliseconds == 375)
    #expect(precisePreview.fadeMilliseconds == 250)
    #expect(precisePreview.totalMilliseconds == 625)
    #expect(try JSONDecoder().decode(PlaybackTimingPreview.self, from: JSONEncoder().encode(precisePreview)) == precisePreview)
    let shortLongPlay = try PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", manualPlayMilliseconds: 500,
        fadeMilliseconds: 250, longPlayEnabled: true
    ).preview()
    #expect(shortLongPlay.preFadeMilliseconds == 500)
    #expect(shortLongPlay.totalMilliseconds == 750)
    let unbounded = try PlaybackTimingPreviewRequest(
        sourcePath: "/music/track.spc", manualPlayMilliseconds: 0,
        fadeMilliseconds: 250, longPlayEnabled: true
    ).preview()
    #expect(unbounded.preFadeMilliseconds == 0)
    #expect(unbounded.totalMilliseconds == 0)
    let legacyJSON = #"{"pre_fade_seconds":2,"fade_seconds":1,"total_seconds":3,"is_long_play":false,"uses_native_ending":false}"#
    let legacy = try JSONDecoder().decode(PlaybackTimingPreview.self, from: Data(legacyJSON.utf8))
    #expect(legacy.preFadeMilliseconds == 2_000)
    #expect(legacy.totalMilliseconds == 3_000)

    let reconfiguration = PlaybackTransportReconfigurationRequest(
        longPlayEnabled: true,
        manualPlayMilliseconds: 240_000,
        fadeMilliseconds: 4_000,
        unknownDurationMilliseconds: 180_000,
        tempo: .init(numerator: 3, denominator: 2)
    )
    let legacyRequest = try JSONDecoder().decode(PlaybackTransportReconfigurationRequest.self, from: JSONEncoder().encode(reconfiguration))
    #expect(legacyRequest.expectedGeneration == nil)
    let guardedRequest = PlaybackTransportReconfigurationRequest(longPlayEnabled: false, expectedGeneration: 42, settingsRevision: 7)
    let decodedGuarded = try JSONDecoder().decode(PlaybackTransportReconfigurationRequest.self, from: JSONEncoder().encode(guardedRequest))
    #expect(decodedGuarded.expectedGeneration == 42)
    #expect(decodedGuarded.settingsRevision == 7)
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
        fadeMilliseconds: 4_000,
        tempo: .init(numerator: 2, denominator: 1)
    )
    let encoded = try JSONEncoder().encode(request)
    let decoded = try JSONDecoder().decode(PlaybackTransportAACExportRequest.self, from: encoded)
    let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let coreRequest = try request.exportRequest()
    let cancellation = PlaybackTransportAACExportCancellationRequest(id: "export-7")

    #expect(decoded == request)
    #expect(object["path"] as? String == "/music/archive.zip")
    #expect(object["sourcePath"] == nil)
    #expect(coreRequest.sourcePath == "/music/archive.zip")
    #expect(coreRequest.archiveEntry == "Game/Ending.spc")
    #expect(coreRequest.trackIndex == 2)
    #expect(coreRequest.outputDirectory.path == "/exports")
    #expect(coreRequest.filenameStem == "Ending")
    #expect(coreRequest.playMilliseconds == 90_000)
    #expect(coreRequest.fadeMilliseconds == 4_000)
    #expect(coreRequest.tempo == 2)
    let legacy = Data(#"{"path":"/music/one.spc","trackIndex":0,"outputDirectory":"/exports","filenameStem":"one","playMilliseconds":1000,"fadeMilliseconds":0}"#.utf8)
    let legacyRequest = try JSONDecoder().decode(PlaybackTransportAACExportRequest.self, from: legacy)
    #expect(try legacyRequest.exportRequest().tempo == 1)
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
    let legacyRamp = try JSONDecoder().decode(PlaybackTransportRampGainRequest.self,
        from: Data(#"{"outputGain":1,"rampMilliseconds":10}"#.utf8))
    #expect(legacyRamp.expectedGeneration == nil && legacyRamp.rampRevision == nil)
    let orderedRamp = try JSONDecoder().decode(PlaybackTransportRampGainRequest.self,
        from: Data(#"{"outputGain":1,"rampMilliseconds":10,"expectedGeneration":42,"rampRevision":9}"#.utf8))
    #expect(orderedRamp.expectedGeneration == 42 && orderedRamp.rampRevision == 9)
    let guardedRamp = try JSONDecoder().decode(PlaybackTransportRampGainRequest.self,
        from: Data(#"{"outputGain":0,"rampMilliseconds":10,"expectedGeneration":42}"#.utf8))
    #expect(guardedRamp.expectedGeneration == 42)
    let legacySeek = try JSONDecoder().decode(PlaybackTransportSeekRequest.self,
        from: Data(#"{"positionMilliseconds":1250}"#.utf8))
    #expect(legacySeek.positionMilliseconds == 1_250 && legacySeek.expectedGeneration == nil && legacySeek.seekRevision == nil)
    let orderedSeek = try JSONDecoder().decode(PlaybackTransportSeekRequest.self,
        from: Data(#"{"positionMilliseconds":2000,"expectedGeneration":42,"seekRevision":9}"#.utf8))
    #expect(orderedSeek.expectedGeneration == 42 && orderedSeek.seekRevision == 9)
    let control = try JSONDecoder().decode(PlaybackTransportSessionRequest.self,
        from: Data(#"{"expectedGeneration":42}"#.utf8))
    #expect(control.expectedGeneration == 42)
}
