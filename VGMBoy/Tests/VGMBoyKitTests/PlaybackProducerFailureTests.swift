import Foundation
import Testing
@testable import VGMBoyKit

private enum ProducerFixtureError: Error { case injected }
private final class ScriptedProducerDecoder: AudioDecoder {
    enum Step { case empty, pcm, failure, mismatched }
    let sampleRate = 44_100
    let trackCount = 1
    let systemName = "fixture"
    let appliesFadeInternally = false
    var absolutePlayedFrames: Int64 = 0
    var trackEnded = false
    var closed = false
    var failStart = false
    var failMetadata = false
    var steps: [Step]
    init(_ steps: [Step] = []) { self.steps = steps }
    func startTrack(_ index: Int) throws { if failStart { throw ProducerFixtureError.injected } }
    func metadata(for index: Int) throws -> TrackMetadata {
        if failMetadata { throw ProducerFixtureError.injected }
        return TrackMetadata(index: index, song: "", game: "", author: "", system: "", lengthMs: 0, introMs: 0, loopMs: 0, playMs: 0, fadeMs: 0)
    }
    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}
    func seek(milliseconds: Int) { absolutePlayedFrames = Int64(milliseconds * sampleRate / 1000) }
    func readFrames(_ count: Int) throws -> (left: [Float], right: [Float]) {
        let step = steps.isEmpty ? .pcm : steps.removeFirst()
        switch step {
        case .empty: return ([], [])
        case .failure: throw ProducerFixtureError.injected
        case .mismatched: return ([0.5], [])
        case .pcm:
            absolutePlayedFrames += Int64(count)
            let pcm = [Float](repeating: 0.5, count: count)
            return (pcm, pcm)
        }
    }
    func close() { closed = true }
}
private func makeSession(_ decoder: ScriptedProducerDecoder) -> PlaybackSession {
    PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.01), makeDecoder: { _, _, _ in decoder })
}
private let fixturePlan = PlaybackPlan(preFadeMilliseconds: 5_000, fadeMilliseconds: 0, isLongPlay: false, usesNativeEnding: false)

@Test func emptyDecoderReadDoesNotAdvanceOrEndAndCanRecover() throws {
    let decoder = ScriptedProducerDecoder([.empty, .pcm])
    let session = makeSession(decoder)
    defer { session.stop() }
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1)
    let empty = session.status()
    #expect(empty.statistics.decodedFrames == 0)
    #expect(empty.diagnostics.bufferedFrames == 0)
    #expect(!empty.reachedEnd)
    try session.seek(to: 0)
    let recovered = session.status()
    #expect(recovered.diagnostics.bufferedFrames > 0)
    #expect(recovered.statistics.audiblePositionFrames == 0)
}

@Test func failedPrimingRetiresDecoderAndRejectsInvalidPCM() throws {
    for step in [ScriptedProducerDecoder.Step.failure, .mismatched] {
        let decoder = ScriptedProducerDecoder([step])
        let session = makeSession(decoder)
        #expect(throws: (any Error).self) { try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1) }
        #expect(decoder.closed)
        #expect(session.status().statistics.decoderFamily == nil)
        #expect(session.status().diagnostics.bufferedFrames == 0)
    }
}

@Test func failedDecoderSetupClosesPreparedDecoder() throws {
    for stage in ["start", "metadata"] {
        let decoder = ScriptedProducerDecoder()
        decoder.failStart = stage == "start"
        decoder.failMetadata = stage == "metadata"
        let session = makeSession(decoder)
        #expect(throws: (any Error).self) { try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1) }
        #expect(decoder.closed, Comment(rawValue: stage))
        #expect(session.status().statistics.decoderFamily == nil)
    }
}
