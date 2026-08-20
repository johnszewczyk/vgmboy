import Testing
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

    @Test("routes ordinary audio extensions to the standard-audio family")
    func routesStandardAudio() {
        for ext in FormatRegistry.standardAudioExtensions {
            #expect(FormatRegistry.family(for: "/tmp/example.\(ext)")?.id == "standardaudio")
        }
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

@Suite("PlaybackControlProtocol")
struct PlaybackControlProtocolTests {
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
    @Test("ring buffer preserves wrapped producer consumer order without a lock")
    func ringBufferWraps() {
        let buffer = PCMRingBuffer(capacityFrames: 4)
        #expect(buffer.write(left: [1, 2, 3], right: [11, 12, 13]) == 3)
        #expect(read(buffer, count: 2).left == [1, 2])
        #expect(buffer.write(left: [4, 5, 6], right: [14, 15, 16]) == 3)
        let output = read(buffer, count: 4)
        #expect(output.left == [3, 4, 5, 6])
        #expect(output.right == [13, 14, 15, 16])
        let diagnostics = buffer.diagnostics()
        #expect(diagnostics.bufferedFrames == 0)
        #expect(diagnostics.framesRequested == 6)
        #expect(diagnostics.framesSupplied == 6)
        #expect(diagnostics.underrunCount == 0)
    }

    @Test("ring clear rejects stale PCM and reports silence as an underrun")
    func ringBufferClearAndUnderrun() {
        let buffer = PCMRingBuffer(capacityFrames: 4)
        #expect(buffer.write(left: [1, 2], right: [3, 4]) == 2)
        buffer.clear()
        let output = read(buffer, count: 2)
        #expect(output.supplied == 0)
        #expect(output.left == [0, 0])
        #expect(output.right == [0, 0])
        #expect(buffer.diagnostics().underrunCount == 1)
    }

    @Test("transport envelope starts and ends at silence without a musical fade")
    func transportEnvelopeRamps() {
        let envelope = TransportEnvelope()
        let start = envelope.beginPlayback(over: 4)
        let rise = (0..<4).map { _ in envelope.nextGain() }
        #expect(rise[0] > 0)
        #expect(rise[0] < rise[1])
        #expect(rise[3] == 1)
        #expect(envelope.isComplete(start))

        let stop = envelope.fadeOut(over: 4)
        let fall = (0..<4).map { _ in envelope.nextGain() }
        #expect(fall[0] < 1)
        #expect(fall[0] > fall[1])
        #expect(fall[3] == 0)
        #expect(envelope.isComplete(stop))
    }

    private func read(_ buffer: PCMRingBuffer, count: Int) -> (supplied: Int, left: [Float], right: [Float]) {
        var left = [Float](repeating: -1, count: count)
        var right = [Float](repeating: -1, count: count)
        var supplied = 0
        left.withUnsafeMutableBufferPointer { leftPointer in
            right.withUnsafeMutableBufferPointer { rightPointer in
                supplied = buffer.read(into: leftPointer, rightPointer)
            }
        }
        return (supplied, left, right)
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

    @Test("missing timing falls back to a 150s native window")
    func fallbackWithoutTiming() {
        let plan = TimingPolicy.plan(
            supportsLongPlay: true,
            metadata: nil,
            longPlayEnabled: false,
            manualSeconds: 60,
            fadeSeconds: 6
        )
        #expect(plan.preFadeSeconds == 150)
        #expect(plan.usesNativeEnding)
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
