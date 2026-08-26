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
