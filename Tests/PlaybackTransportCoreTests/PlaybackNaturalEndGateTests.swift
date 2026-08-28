import Testing
@testable import PlaybackTransportCore

@Test
func naturalEndPublishesOnceForTheActiveGeneration() {
    var gate = PlaybackNaturalEndGate()

    let first = gate.shouldPublish(generation: 4, currentGeneration: 4)
    let duplicate = gate.shouldPublish(generation: 4, currentGeneration: 4)
    let stale = gate.shouldPublish(generation: 3, currentGeneration: 4)
    #expect(first)
    #expect(!duplicate)
    #expect(!stale)

    gate.reset()
    let afterReset = gate.shouldPublish(generation: 4, currentGeneration: 4)
    #expect(afterReset)
}

@Test
func staleNaturalEndCannotPublishAfterReplacement() {
    var gate = PlaybackNaturalEndGate()

    let stale = gate.shouldPublish(generation: 7, currentGeneration: 8)
    let current = gate.shouldPublish(generation: 8, currentGeneration: 8)
    #expect(!stale)
    #expect(current)
}

@Test
func transportStatusCarriesPresentationNeutralDiagnostics() {
    let status = PlaybackTransportStatus(
        currentTrackID: "track-a",
        generation: 12,
        isPlaying: true,
        elapsedSeconds: 42.5,
        reachedEnd: false,
        trackLoaded: true,
        outputIsRunning: true,
        errorMessage: nil,
        bufferedFrames: 2_048,
        ringBufferFrames: 8_192,
        underrunCount: 3,
        framesRequested: 5_000,
        framesSupplied: 4_800,
        decoderFamily: "libgme",
        trackIndex: 2,
        decoderSampleRate: 32_000,
        outputSampleRate: 44_100,
        decodedFrames: 88_200,
        audiblePositionFrames: 86_152,
        tempo: 1.25
    )

    #expect(status.outputIsRunning)
    #expect(status.bufferedFrames == 2_048)
    #expect(status.framesRequested == 5_000)
    #expect(status.decoderFamily == "libgme")
    #expect(status.audiblePositionFrames == 86_152)
}
