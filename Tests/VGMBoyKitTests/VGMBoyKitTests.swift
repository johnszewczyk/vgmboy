import Testing
import AudioToolbox
import AVFoundation
import Foundation
import VGMBoyCAudioUnit
@testable import VGMBoyKit

@Suite("FormatRegistry")
struct FormatRegistryTests {
    @Test("publishes one complete frontend descriptor table")
    func frontendDescriptorsMatchPlaybackRouting() {
        let expectedIDs = [
            "libgme", "libvgm", "standard-audio", "ffmpeg-audio",
            "highly-complete", "twosf", "vgmstream", "lazyusf",
            "playpsf", "qsf", "sidplayfp", "openmpt"
        ]
        #expect(FormatRegistry.playbackDescriptors.map(\.id) == expectedIDs)

        let descriptorExtensions = Set(
            FormatRegistry.playbackDescriptors.flatMap(\.extensions)
        )
        #expect(FormatRegistry.playbackExtensions == descriptorExtensions)

        for descriptor in FormatRegistry.playbackDescriptors {
            for extensionName in descriptor.extensions {
                let path = "/tmp/example.\(extensionName)"
                #expect(FormatRegistry.descriptor(for: path) == descriptor)
                #expect(FormatRegistry.family(for: path)?.id == descriptor.familyID)
            }
        }
    }

    @Test("normalizes shared playback preferences without changing their meaning")
    func sharedPlaybackPreferencesNormalizeValues() {
        let preferences = PlaybackPreferences(
            timing: .init(longPlaySeconds: 180, unknownDurationSeconds: 150, fadeSeconds: 6),
            fadeEnabled: false,
            equalizerEnabled: true,
            equalizerBandGains: [-99, 3.5, 99],
            outputVolume: 2,
            monoEnabled: true,
            libgmeTempo: PlaybackTempo(numerator: 2, denominator: 1),
            libgmeTempoEnabled: true
        )

        #expect(preferences.fadeSeconds == 0)
        #expect(preferences.equalizer.enabled)
        #expect(preferences.equalizer.gainsDecibels[0] == -12)
        #expect(preferences.equalizer.gainsDecibels[1] == 3.5)
        #expect(preferences.equalizer.gainsDecibels[2] == 12)
        #expect(preferences.equalizer.gainsDecibels.count == EqualizerConfiguration.bandCount)
        #expect(preferences.outputVolume == 1)
        #expect(preferences.monoEnabled)
        #expect(preferences.libgmeTempo.multiplier == 2)
        #expect(preferences.libgmeTempoEnabled)
        #expect(!preferences.libvgmTempoEnabled)
    }

    @Test("routes libgme extensions to the libgme family")
    func routesLibGME() {
        for ext in FormatRegistry.libgmeExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "libgme")
        }
        #expect(FormatRegistry.family(for: "/tmp/example.unknown") == nil)
    }

    @Test("publishes archive preparation as a format capability")
    func archiveMaterializationRequirements() {
        #expect(
            FormatRegistry.archiveMaterializationRequirement(for: ["music.flac"])
                == .selectedEntry
        )
        #expect(
            FormatRegistry.archiveMaterializationRequirement(for: ["track.psf"])
                == .completeSet
        )
        #expect(
            FormatRegistry.archiveMaterializationRequirement(for: ["track.usf"])
                == .completeSetWithLazyUSFAliases
        )
        #expect(
            FormatRegistry.archiveMaterializationRequirement(for: ["track.miniqsf"])
                == .completeSet
        )
        #expect(
            FormatRegistry.archiveMaterializationRequirement(for: ["track.unknown"]) == nil
        )
    }

    @Test("routes SID extensions to the libsidplayfp family")
    func routesSIDPlayFP() {
        for ext in FormatRegistry.sidplayfpExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "sidplayfp")
        }
        #expect(!FormatRegistry.sidplayfpFamily.supportsTempo)
        #expect(!FormatRegistry.sidplayfpFamily.hasNaturalEnding)
    }

    @Test("routes tracker module extensions to OpenMPT")
    func routesOpenMPT() {
        for ext in FormatRegistry.openMPTExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "openmpt")
        }
        #expect(FormatRegistry.openMPTFamily.supportsLongPlay)
        #expect(!FormatRegistry.openMPTFamily.supportsTempo)
        #expect(FormatRegistry.openMPTFamily.hasNaturalEnding)
    }

    @Test("routes ordinary audio extensions to the standard-audio family")
    func routesStandardAudio() {
        for ext in FormatRegistry.standardAudioExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "standardaudio")
        }
    }

    @Test("routes FFmpeg-only ordinary audio through the core")
    func routesFFmpegAudio() {
        for ext in FormatRegistry.ffmpegAudioExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "ffmpegaudio")
        }
        #expect(!FormatRegistry.ffmpegAudioFamily.supportsLongPlay)
        #expect(!FormatRegistry.ffmpegAudioFamily.supportsTempo)
    }

    @Test("structure API exposes decoder timing but never catalog tags")
    func structureValuesStayDecoderScoped() {
        let structure = PlaybackStructure(
            trackCount: 2,
            tracks: [.init(index: 0, naturalPlayMilliseconds: 1_000, fadeMilliseconds: 0)]
        )
        #expect(structure.trackCount == 2)
        #expect(structure.tracks[0].naturalPlayMilliseconds == 1_000)
    }

    @Test("routes libvgm extensions to the libvgm family")
    func routesLibVGM() {
        for ext in FormatRegistry.libvgmExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "libvgm")
        }
    }

    @Test("routes GSF extensions to the Highly Complete family")
    func routesHighlyComplete() {
        for ext in FormatRegistry.highlyCompleteExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "highlycomplete")
        }
    }

    @Test("routes 2SF extensions to the 2SF family")
    func routesTwoSF() {
        for ext in FormatRegistry.twoSFExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "twosf")
        }
    }

    @Test("routes vgmstream extensions to the vgmstream family")
    func routesVgmstream() {
        for ext in FormatRegistry.vgmstreamExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "vgmstream")
        }
    }

    @Test("routes proven GameCube streams but not their sidecars as playable files")
    func routesGameCubeVgmstream() {
        let expected: Set<String> = ["adp", "agsc", "dsp", "h4m", "ldat", "logg", "rsf", "thp", "txtp"]
        #expect(FormatRegistry.gameCubeVgmstreamExtensions == expected)
        for ext in expected {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "vgmstream")
        }
        #expect(FormatRegistry.family(for: "/tmp/example.txth") == nil)
        #expect(FormatRegistry.family(for: "/tmp/example.sbb") == nil)
    }

    @Test("routes USF extensions to the lazyusf family")
    func routesLazyUSF() {
        for ext in FormatRegistry.lazyusfExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "lazyusf")
        }
    }

    @Test("routes PSF extensions to the playpsf family")
    func routesPlayPSF() {
        for ext in FormatRegistry.playpsfExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "playpsf")
        }
    }

    @Test("routes QSF extensions to the qsf family")
    func routesQSF() {
        for ext in FormatRegistry.qsfExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "qsf")
        }
    }

    @Test("libgme supports long play and tempo")
    func libGmeCapabilities() {
        let family = FormatRegistry.libgmeFamily
        #expect(family.supportsLongPlay)
        #expect(family.supportsTempo)
    }

    @Test("libvgm supports long play and tempo")
    func libVgmCapabilities() {
        let family = FormatRegistry.libvgmFamily
        #expect(family.supportsLongPlay)
        #expect(family.supportsTempo)
    }

    @Test("Highly Complete supports long play but not tempo")
    func highlyCompleteCapabilities() {
        let family = FormatRegistry.highlyCompleteFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
        #expect(family.hasNaturalEnding)
    }

    @Test("2SF supports long play but not tempo")
    func twoSFCapabilities() {
        let family = FormatRegistry.twoSFFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
    }

    @Test("vgmstream supports long play but not tempo")
    func vgmstreamCapabilities() {
        let family = FormatRegistry.vgmstreamFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
    }

    @Test("QSF supports long play but not tempo")
    func qsfCapabilities() {
        let family = FormatRegistry.qsfFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
        #expect(family.hasNaturalEnding)
    }

    @Test("lazyusf supports long play, no tempo, and no natural ending")
    func lazyUSFCapabilities() {
        let family = FormatRegistry.lazyusfFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
        #expect(!family.hasNaturalEnding)
    }

    @Test("playpsf supports long play, no tempo, and a natural ending")
    func playPSFCapabilities() {
        let family = FormatRegistry.playpsfFamily
        #expect(family.supportsLongPlay)
        #expect(!family.supportsTempo)
        #expect(family.hasNaturalEnding)
    }
}

@Suite("GameCube vgmstream playback")
struct GameCubeVGMStreamPlaybackTests {
    @Test(
        "opens every admitted fixture format and renders non-silent PCM",
        .enabled(
            if: ProcessInfo.processInfo.environment["VGMBoy_GAMECUBE_FIXTURES"] != nil,
            "Set VGMBoy_GAMECUBE_FIXTURES to run the archive-backed GameCube decoder checks."
        )
    )
    func rendersRealFixtures() throws {
        let rootPath = try #require(ProcessInfo.processInfo.environment["VGMBoy_GAMECUBE_FIXTURES"])
        let root = URL(fileURLWithPath: rootPath, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = try #require(FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ))
        let fixtures = enumerator.compactMap { $0 as? URL }.filter {
            FormatRegistry.gameCubeVgmstreamExtensions.contains($0.pathExtension.lowercased())
        }
        let foundExtensions = Set(fixtures.map { $0.pathExtension.lowercased() })
        #expect(foundExtensions == FormatRegistry.gameCubeVgmstreamExtensions)

        for fixture in fixtures.sorted(by: { $0.path < $1.path }) {
            let decoder = try VgmstreamDecoder(path: fixture.path)
            try decoder.startTrack(0)
            let metadata = try decoder.metadata(for: 0)
            #expect(decoder.trackCount > 0, Comment(rawValue: fixture.lastPathComponent))
            #expect(metadata.naturalPlayMs > 0, Comment(rawValue: fixture.lastPathComponent))
            var renderedAudio = false
            for _ in 0..<48 {
                let pcm = decoder.readFrames(4_096)
                if pcm.left.contains(where: { abs($0) > 0.0001 })
                    || pcm.right.contains(where: { abs($0) > 0.0001 }) {
                    renderedAudio = true
                    break
                }
            }
            #expect(renderedAudio, Comment(rawValue: fixture.lastPathComponent))
        }
    }
}

@Suite("QSF playback", .serialized)
struct QSFPlaybackTests {
    @Test(
        "renders non-silent PCM from a real QSF fixture",
        .enabled(
            if: ProcessInfo.processInfo.environment["VGMBoy_QSF_FIXTURE"] != nil,
            "Set VGMBoy_QSF_FIXTURE to run the required archive-backed decoder check."
        )
    )
    func rendersRealFixture() throws {
        let path = try #require(ProcessInfo.processInfo.environment["VGMBoy_QSF_FIXTURE"])
        #expect(FileManager.default.fileExists(atPath: path))
        let decoder = try QSFDecoder(path: path)
        defer { decoder.close() }
        #expect(throws: QSFDecoderError.concurrentUse) {
            try QSFDecoder(path: path)
        }
        try decoder.startTrack(0)
        let metadata = try decoder.metadata(for: 0)
        var pcm = (left: [Float](), right: [Float]())
        for _ in 0..<12 {
            let chunk = decoder.readFrames(4_096)
            pcm.left.append(contentsOf: chunk.left)
            pcm.right.append(contentsOf: chunk.right)
            if pcm.left.contains(where: { abs($0) > 0.0001 }) || pcm.right.contains(where: { abs($0) > 0.0001 }) {
                break
            }
        }
        #expect(decoder.sampleRate == 44_100)
        #expect(metadata.system == "Capcom QSound")
        #expect(pcm.left.contains { abs($0) > 0.0001 } || pcm.right.contains { abs($0) > 0.0001 })
    }

    @Test("process-global QSF ownership fails fast and becomes reusable after release")
    func bridgeLeaseIsExclusive() throws {
        let first = try #require(QSFBridgeLease.acquire())
        #expect(QSFBridgeLease.acquire() == nil)
        first.release()
        let replacement = try #require(QSFBridgeLease.acquire())
        replacement.release()
    }
}

@Suite("PlaybackControlProtocol")
struct PlaybackControlProtocolTests {
    @Test("tempo values preserve exact decimal and fraction input")
    func tempoValuesPreserveExactInput() {
        #expect(PlaybackTempo.parse("1.25") == PlaybackTempo(numerator: 5, denominator: 4))
        #expect(PlaybackTempo.parse(".5") == PlaybackTempo(numerator: 1, denominator: 2))
        #expect(PlaybackTempo.parse("15/12") == PlaybackTempo(numerator: 5, denominator: 4))
        #expect(PlaybackTempo.parse("1/3") == PlaybackTempo(numerator: 11, denominator: 32))
        #expect(PlaybackTempo.parse("1.01") == PlaybackTempo(numerator: 1, denominator: 1))
        #expect(PlaybackTempo(numerator: 5, denominator: 4).displayString == "1.25")
        #expect(PlaybackTempo(numerator: 1, denominator: 3).displayString == "1/3")
        #expect(PlaybackTempo.parse("1.0000001") == nil)
    }

    @Test("v1 load control round-trips through Codable")
    func loadRequestRoundTrip() throws {
        let request = PlaybackControlRequest(
            requestID: "request-1",
            command: .load,
            payload: PlaybackControlPayload(
                path: "/tmp/example.gsf",
                trackIndex: 0,
                playbackMode: .longPlay,
                playMilliseconds: 120_000,
                fadeMilliseconds: 8_000
            )
        )
        let decoded = try JSONDecoder().decode(
            PlaybackControlRequest.self,
            from: JSONEncoder().encode(request)
        )
        #expect(decoded == request)
        #expect(decoded.version == PlaybackControlProtocol.version)
    }

    @Test("equalizer requires ten finite gains")
    func validatesEqualizer() {
        #expect(EqualizerConfiguration(gainsDecibels: Array(repeating: 0, count: 10)).isValid)
        #expect(!EqualizerConfiguration(gainsDecibels: Array(repeating: 0, count: 9)).isValid)
        #expect(!EqualizerConfiguration(gainsDecibels: [Float.nan] + Array(repeating: 0, count: 9)).isValid)
        #expect(!EqualizerConfiguration(gainsDecibels: [12.5] + Array(repeating: 0, count: 9)).isValid)
        #expect(EqualizerConfiguration.bandFrequencies == [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000])
    }

    @Test("AAC export writes ADTS without using the live transport")
    func exportsADTS() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let source = folder.appendingPathComponent("source.wav")
        try writeTestWAV(to: source)

        let result = try AACExporter.export(.init(
            sourcePath: source.path,
            outputDirectory: folder,
            filenameStem: "Test/Track",
            playMilliseconds: 100,
            fadeMilliseconds: 0
        ))
        #expect(result.renderedFrames > 0)
        #expect(result.outputURL.pathExtension == "aac")
        #expect(FileManager.default.fileExists(atPath: result.outputURL.path))
        #expect((try Data(contentsOf: result.outputURL)).count > 0)

        var audioFile: AudioFileID?
        #expect(AudioFileOpenURL(result.outputURL as CFURL, .readPermission, kAudioFileAAC_ADTSType, &audioFile) == noErr)
        if let audioFile { AudioFileClose(audioFile) }
    }

    @Test("live transport preserves its native generation across pause seek resume and fade restore")
    func liveTransportPreservesGenerationAcrossInterruptions() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let source = folder.appendingPathComponent("transport.wav")
        try writeTestWAV(to: source, frameCount: 44_100)

        let controller = PlaybackController()
        defer { _ = controller.perform(.init(command: .stop)) }

        let loaded = controller.perform(.init(command: .load, payload: .init(
            path: source.path,
            playbackMode: .timed,
            playMilliseconds: 2_000,
            fadeMilliseconds: 0
        )))
        #expect(loaded.kind != .error)

        let started = controller.perform(.init(command: .play))
        let generation = try #require(started.status?.diagnostics.generation)
        #expect(started.status?.isPlaying == true)

        let paused = controller.perform(.init(command: .pause))
        #expect(paused.status?.isPlaying == false)
        #expect(paused.status?.diagnostics.generation == generation)

        let seeked = controller.perform(.init(
            command: .seek,
            payload: .init(positionMilliseconds: 250)
        ))
        #expect(seeked.kind != .error)
        #expect(seeked.status?.diagnostics.generation == generation)

        let resumed = controller.perform(.init(command: .play))
        #expect(resumed.kind != .error)
        #expect(resumed.status?.isPlaying == true)
        #expect(resumed.status?.diagnostics.generation == generation)

        let faded = controller.perform(.init(
            command: .rampOutputGain,
            payload: .init(outputGain: 0, rampMilliseconds: 10)
        ))
        #expect(faded.kind != .error)
        let restored = controller.perform(.init(
            command: .rampOutputGain,
            payload: .init(outputGain: 1, rampMilliseconds: 10)
        ))
        #expect(restored.kind != .error)
        #expect(restored.status?.diagnostics.generation == generation)
    }

    private func writeTestWAV(to url: URL, frameCount: AVAudioFrameCount = 4_410) throws {
        let pcm = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: pcm.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try file.write(from: buffer)
    }

}

@Suite("SessionFade")
struct SessionFadeTests {
    @Test("fade gain ramps from 1 down to 0 across the fade window")
    func fadeRamp() {
        let cap: Int64 = 10_000
        let fade: Int64 = 2_000
        #expect(PlaybackSession.fadeGain(position: 7_999, capFrames: cap, fadeFrames: fade) == 1.0)
        let mid = PlaybackSession.fadeGain(position: 9_000, capFrames: cap, fadeFrames: fade)
        #expect(mid > 0 && mid < 1)
        #expect(PlaybackSession.fadeGain(position: 10_000, capFrames: cap, fadeFrames: fade) == 0.0)
        #expect(PlaybackSession.fadeGain(position: 20_000, capFrames: cap, fadeFrames: fade) == 0.0)
    }

    @Test("no fade window means full gain")
    func noFade() {
        #expect(PlaybackSession.fadeGain(position: 9_500, capFrames: 10_000, fadeFrames: 0) == 1.0)
    }
}

@Suite("Realtime Transport")
struct RealtimeTransportTests {
    @Test("direct AudioUnit transport owns the session PCM ring")
    func directTransportBuffersAndClearsPCM() {
        let output = AudioOutput(sampleRate: 10, capacitySeconds: 0.4)
        #expect(output.capacityFrames == 4)
        #expect(output.write(left: [1, 0.5, 0.25], right: [1, 0.5, 0.25]) == 3)
        #expect(output.bufferedFrames == 3)
        #expect(output.write(left: [0.125, 0.0625], right: [0.125, 0.0625]) == 1)
        #expect(output.diagnostics().framesWritten == 4)
        output.clearBuffer()
        #expect(output.bufferedFrames == 0)
    }

    @Test("callback ramps queued PCM before inactive transport retains the ring")
    func callbackEnvelopeAndInactiveRingSemantics() throws {
        var config = VGMBoyAudioUnitConfig(
            sample_rate: 44_100,
            channel_count: 2,
            callback_frames: 8,
            ring_buffer_frames: 16
        )
        var handle: OpaquePointer?
        #expect(vgmboy_audio_unit_create(&handle, &config) == 0)
        let output = try #require(handle)
        defer { vgmboy_audio_unit_destroy(output) }

        var queued = [Int16](repeating: 24_000, count: 16)
        #expect(vgmboy_audio_unit_enqueue_pcm(output, &queued, 8) == 8)
        vgmboy_audio_unit_set_transport_active(output, 1)
        vgmboy_audio_unit_set_transport_gain(output, 1)
        vgmboy_audio_unit_ramp_transport_gain(output, 0, 8)

        var rendered = [Int16](repeating: 0, count: 16)
        #expect(vgmboy_audio_unit_render_offline(output, &rendered, 8) == 8)
        #expect(abs(Int(rendered[0])) > abs(Int(rendered[14])))
        #expect(rendered[14] == 0)

        var pausedPCM = [Int16](repeating: 12_000, count: 4)
        #expect(vgmboy_audio_unit_enqueue_pcm(output, &pausedPCM, 2) == 2)
        vgmboy_audio_unit_set_transport_active(output, 0)
        var silent = [Int16](repeating: 1, count: 4)
        #expect(vgmboy_audio_unit_render_offline(output, &silent, 2) == 2)
        #expect(silent.allSatisfy { $0 == 0 })

        var snapshot = VGMBoyAudioUnitSnapshot()
        #expect(vgmboy_audio_unit_snapshot(output, &snapshot) == 0)
        #expect(snapshot.buffered_frames == 2)
    }
}

@Suite("TimingPolicy")
struct TimingPolicyTests {
    private let metadata = TrackMetadata(
        index: 0,
        song: "Title",
        game: "Game",
        author: "Author",
        system: "NES",
        lengthMs: 120_000,
        introMs: 30_000,
        loopMs: 60_000,
        playMs: 150_000,
        fadeMs: 8_000
    )

    @Test("long play caps at manual plus fade")
    func longPlayWindow() {
        let plan = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: metadata,
            longPlayEnabled: true,
            manualSeconds: 105,
            fadeSeconds: 6
        )
        #expect(plan.isLongPlay)
        #expect(plan.preFadeSeconds == 105)
        #expect(plan.fadeSeconds == 6)
        #expect(plan.totalSeconds == 111)
        #expect(!plan.usesNativeEnding)
    }

    @Test("natural play uses tagged play length")
    func naturalWindow() {
        let plan = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: metadata,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 6
        )
        #expect(!plan.isLongPlay)
        #expect(plan.preFadeSeconds == 150)
        #expect(!plan.usesNativeEnding)
    }

    @Test("zero fade defers to the native ending")
    func nativeEndingWithZeroFade() {
        let plan = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: metadata,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 0
        )
        #expect(plan.usesNativeEnding)
    }

    @Test("missing timing falls back to a 150s bounded window when fading")
    func fallbackWithoutTiming() {
        let plan = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: nil,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 6
        )
        #expect(plan.preFadeSeconds == 150)
        #expect(!plan.usesNativeEnding)
    }

    @Test("no-natural-ending family always gets a capped window")
    func noNaturalEndingAlwaysCapped() {
        let withMetadata = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: metadata,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 0,
            hasNaturalEnding: false
        )
        #expect(!withMetadata.usesNativeEnding)
        #expect(withMetadata.preFadeSeconds == 150)

        let withoutMetadata = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: nil,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 0,
            hasNaturalEnding: false
        )
        #expect(!withoutMetadata.usesNativeEnding)
        #expect(withoutMetadata.preFadeSeconds == 150)
    }
}

@Suite("PlaybackController timing contract")
struct PlaybackControllerTimingTests {
    @Test("standard finite audio keeps decoder-natural duration")
    func standardFiniteAudioUsesFileDefaultWithoutPlayLength() throws {
        let request = try PlaybackTimingRequest.standard(
            path: "/tmp/song.flac",
            longPlayEnabled: false,
            manualPlayMilliseconds: 150_000,
            fadeMilliseconds: 6_000
        )
        #expect(request.playbackMode == .fileDefault)
        #expect(request.playMilliseconds == nil)
        #expect(request.fadeMilliseconds == 6_000)
    }

    @Test("standard requests carry the configured unknown-duration window")
    func standardRequestsCarryUnknownDurationWindow() throws {
        let request = try PlaybackTimingRequest.standard(
            path: "/tmp/song.sid",
            longPlayEnabled: false,
            manualPlayMilliseconds: 240_000,
            fadeMilliseconds: 6_000,
            unknownDurationMilliseconds: 300_000
        )
        #expect(request.playbackMode == .fileDefault)
        #expect(request.playMilliseconds == nil)
        #expect(request.unknownDurationMilliseconds == 300_000)
    }

    @Test("standard Long Play supplies the explicit manual duration")
    func standardLongPlayUsesManualDuration() throws {
        let request = try PlaybackTimingRequest.standard(
            path: "/tmp/song.spc",
            longPlayEnabled: true,
            manualPlayMilliseconds: 240_000,
            fadeMilliseconds: 6_000
        )
        #expect(request.playbackMode == .longPlay)
        #expect(request.playMilliseconds == 240_000)
    }

    @Test("unsupported Long Play falls back to natural file-default timing")
    func unsupportedLongPlayDoesNotForceManualDuration() throws {
        let request = try PlaybackTimingRequest.standard(
            path: "/tmp/song.flac",
            longPlayEnabled: true,
            manualPlayMilliseconds: 240_000,
            fadeMilliseconds: 6_000
        )
        #expect(request.playbackMode == .fileDefault)
        #expect(request.playMilliseconds == nil)
    }

    @Test("explicit timed requests require an actual duration")
    func timedRequestsCannotInventTheDefaultDuration() {
        #expect(throws: PlaybackControlError.self) {
            try PlaybackTimingRequest.timed(playMilliseconds: 0, fadeMilliseconds: 6_000)
        }
    }

    @Test("file default with a requested fade uses the bounded shared path")
    func fileDefaultFadeIsNotNative() {
        let plan = PlaybackController.plan(
            mode: .fileDefault,
            playMilliseconds: 150_000,
            fadeMilliseconds: 6_000,
            family: FormatRegistry.libgmeFamily
        )
        #expect(plan.preFadeSeconds == 150)
        #expect(plan.fadeSeconds == 6)
        #expect(!plan.usesNativeEnding)
    }

    @Test("file default fade lets the decoder own natural duration")
    func fileDefaultFadeUsesDecoderDurationWhenPlayIsOmitted() {
        let plan = PlaybackController.plan(
            mode: .fileDefault,
            playMilliseconds: nil,
            fadeMilliseconds: 6_000,
            family: FormatRegistry.standardAudioFamily
        )
        #expect(!plan.isLongPlay)
        #expect(!plan.usesNativeEnding)
        #expect(plan.usesDecoderNaturalDuration)
    }

    @Test("file default uses the configured unknown-duration window")
    func fileDefaultUsesConfiguredUnknownDuration() {
        let plan = PlaybackController.plan(
            mode: .fileDefault,
            playMilliseconds: nil,
            fadeMilliseconds: 6_000,
            unknownDurationMilliseconds: 300_000,
            family: FormatRegistry.sidplayfpFamily
        )
        #expect(plan.preFadeSeconds == 300)
        #expect(plan.totalSeconds == 306)
        #expect(plan.usesDecoderNaturalDuration)
    }

    @Test("zero fade preserves native ending for natural formats")
    func zeroFadeRemainsNative() {
        let plan = PlaybackController.plan(
            mode: .fileDefault,
            playMilliseconds: 150_000,
            fadeMilliseconds: 0,
            family: FormatRegistry.libgmeFamily
        )
        #expect(plan.usesNativeEnding)
    }

    @Test("file default fade also caps non-natural formats")
    func fileDefaultFadeCapsNonNaturalFormat() {
        let plan = PlaybackController.plan(
            mode: .fileDefault,
            playMilliseconds: 150_000,
            fadeMilliseconds: 6_000,
            family: FormatRegistry.lazyusfFamily
        )
        #expect(!plan.usesNativeEnding)
        #expect(plan.totalSeconds == 156)
    }
}

@Test(
    "FLAC opens, reports its full duration, and renders PCM",
    .enabled(
        if: ProcessInfo.processInfo.environment["VGMBoy_FLAC_FIXTURE"] != nil,
        "Set VGMBoy_FLAC_FIXTURE to run the archive-backed FLAC decoder check."
    )
)
func flacFixtureUsesSafeSequentialReader() throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBoy_FLAC_FIXTURE"])
    let decoder = try DecoderFactory.make(path: path)
    try decoder.startTrack(0)
    let metadata = try decoder.metadata(for: 0)
    #expect(metadata.playMs > 0)
    let frames = decoder.readFrames(4_096)
    #expect(frames.left.count > 0)
    var renderedFrames = frames.left.count
    while !decoder.trackEnded {
        let chunk = decoder.readFrames(4_096)
        if chunk.left.isEmpty { break }
        renderedFrames += chunk.left.count
    }
    let expectedFrames = Int((Double(metadata.playMs) / 1_000.0 * 44_100.0).rounded())
    #expect(abs(renderedFrames - expectedFrames) < 256)
    decoder.seek(milliseconds: min(metadata.playMs / 2, 1_000))
    #expect(decoder.absolutePlayedFrames > 0)
}
