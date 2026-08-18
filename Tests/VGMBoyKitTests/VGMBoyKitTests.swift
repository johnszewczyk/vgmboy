import Testing
@testable import VGMBoyKit

@Suite("FormatRegistry")
struct FormatRegistryTests {
    @Test("routes libgme extensions to the libgme family")
    func routesLibGME() {
        for ext in FormatRegistry.libgmeExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "libgme")
        }
        #expect(FormatRegistry.family(for: "/tmp/example.psf2") == nil)
    }

    @Test("routes libvgm extensions to the libvgm family")
    func routesLibVGM() {
        for ext in FormatRegistry.libvgmExtensions {
            let path = "/tmp/example.\(ext)"
            #expect(FormatRegistry.family(for: path)?.id == "libvgm")
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