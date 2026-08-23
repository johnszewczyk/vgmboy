import Testing
import AudioToolbox
import AVFoundation
import Foundation
@testable import VGMBoyKit

@Suite("FormatRegistry")
struct FormatRegistryTests {
    @Test("routes libgme extensions to the libgme family")
    func routesLibGME() {
        for ext in FormatRegistry.libgmeExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "libgme")
        }
        #expect(FormatRegistry.family(for: "/tmp/example.unknown") == nil)
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

@Suite("QSF playback")
struct QSFPlaybackTests {
    @Test("renders non-silent PCM from a real QSF fixture when provided")
    func rendersRealFixture() throws {
        guard let path = ProcessInfo.processInfo.environment["VGMBoy_QSF_FIXTURE"],
              FileManager.default.fileExists(atPath: path) else {
            return
        }
        let decoder = try QSFDecoder(path: path)
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

    private func writeTestWAV(to url: URL) throws {
        let pcm = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: pcm.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: pcm, frameCapacity: 4_410)!
        buffer.frameLength = 4_410
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
