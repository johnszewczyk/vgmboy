import Foundation
import Testing
@testable import VGMBoyKit

private enum ProducerFixtureError: Error { case injected }
private final class ScriptedProducerDecoder: AudioDecoder {
    enum Step { case empty, pcm, partial, end, failure, mismatched }
    let sampleRate = 44_100
    let trackCount = 1
    let systemName = "fixture"
    let appliesFadeInternally = false
    var absolutePlayedFrames: Int64 = 0
    var trackEnded = false
    var closed = false
    var failStart = false
    var failMetadata = false
    var naturalEndFrame: Int64?
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
    func seek(milliseconds: Int) { absolutePlayedFrames = Int64(milliseconds * sampleRate / 1000); trackEnded = false }
    func readFrames(_ count: Int) throws -> (left: [Float], right: [Float]) {
        let step = steps.isEmpty ? .pcm : steps.removeFirst()
        switch step {
        case .empty: return ([], [])
        case .failure: throw ProducerFixtureError.injected
        case .mismatched: return ([0.5], [])
        case .end:
            trackEnded = true
            return ([], [])
        case .partial:
            let partialCount = max(1, count / 2)
            absolutePlayedFrames += Int64(partialCount)
            let pcm = [Float](repeating: 0.25, count: partialCount)
            return (pcm, pcm)
        case .pcm:
            let produced = naturalEndFrame.map { max(0, min(count, Int($0 - absolutePlayedFrames))) } ?? count
            absolutePlayedFrames += Int64(produced)
            if let naturalEndFrame, absolutePlayedFrames >= naturalEndFrame { trackEnded = true }
            let pcm = [Float](repeating: 0, count: produced)
            return (pcm, pcm)
        }
    }
    func close() { closed = true }
}

@Test func authoredLoopRepeatsWhenDecoderEndsAtItsBoundary() async throws {
    let decoder = ScriptedProducerDecoder()
    decoder.naturalEndFrame = 4_410
    let session = PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.1),
                                  makeDecoder: { _, _, _ in decoder })
    let recorder = CompletionRecorder()
    session.setCompletionStatusHandler { recorder.record($0) }
    defer { session.stop() }
    let plan = PlaybackPlan(preFadeMilliseconds: 0, fadeMilliseconds: 0, isLongPlay: false,
                            usesNativeEnding: true, usesDecoderNaturalDuration: true)
    let loop = PlaybackLoopMetadata(startSample: 2_205, endSample: 4_410, sampleRateHz: 44_100, repeatCount: 1)
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: plan, tempo: 1, loop: loop)
    try session.play()
    for _ in 0..<100 where recorder.snapshot.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
    let end = try #require(recorder.snapshot.first)
    #expect(end.statistics.decodedFrames == 6_615)
    #expect(end.diagnostics.bufferedFrames == 0)
}

@Test func decoderEndingBeforeAuthoredLoopBoundaryDoesNotInventARepeat() async throws {
    let decoder = ScriptedProducerDecoder()
    decoder.naturalEndFrame = 4_410
    let session = PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.1),
                                  makeDecoder: { _, _, _ in decoder })
    let recorder = CompletionRecorder()
    session.setCompletionStatusHandler { recorder.record($0) }
    defer { session.stop() }
    let plan = PlaybackPlan(preFadeMilliseconds: 0, fadeMilliseconds: 0, isLongPlay: false,
                            usesNativeEnding: true, usesDecoderNaturalDuration: true)
    let loop = PlaybackLoopMetadata(startSample: 2_205, endSample: 8_820, sampleRateHz: 44_100, repeatCount: 1)
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: plan, tempo: 1, loop: loop)
    try session.play()
    for _ in 0..<100 where recorder.snapshot.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
    let end = try #require(recorder.snapshot.first)
    #expect(end.statistics.decodedFrames == 4_410)
    #expect(end.diagnostics.bufferedFrames == 0)
}

private final class CompletionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var statuses: [PlaybackStatus] = []
    func record(_ status: PlaybackStatus) { lock.lock(); statuses.append(status); lock.unlock() }
    var snapshot: [PlaybackStatus] { lock.lock(); defer { lock.unlock() }; return statuses }
}

@Test func partialAndEmptyReadsRecoverAndPublishOneDrainedEnd() async throws {
    let decoder = ScriptedProducerDecoder([.partial, .empty, .pcm, .end])
    let session = PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.1),
                                  makeDecoder: { _, _, _ in decoder })
    let recorder = CompletionRecorder()
    session.setCompletionStatusHandler { recorder.record($0) }
    defer { session.stop() }
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1)
    let primed = session.status()
    #expect(primed.statistics.decodedFrames > 0)
    #expect(!primed.reachedEnd)
    try session.play()
    for _ in 0..<100 where recorder.snapshot.isEmpty {
        try await Task.sleep(for: .milliseconds(20))
    }
    try await Task.sleep(for: .milliseconds(100))
    let ends = recorder.snapshot
    #expect(ends.count == 1)
    let end = try #require(ends.first)
    #expect(end.reachedEnd)
    #expect(!end.isPlaying)
    #expect(end.diagnostics.bufferedFrames == 0)
    #expect(end.statistics.decodedFrames > primed.statistics.decodedFrames)
    #expect(end.errorMessage == nil)
}

@Test func periodicDecodeFailureStopsOutputAndReportsError() async throws {
    let decoder = ScriptedProducerDecoder([.pcm, .failure])
    let session = makeSession(decoder)
    defer { session.stop() }
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1)
    try session.play()
    for _ in 0..<80 where session.status().errorMessage == nil {
        try await Task.sleep(for: .milliseconds(25))
    }
    let status = session.status()
    #expect(status.errorMessage != nil)
    #expect(!status.isPlaying)
    #expect(!status.reachedEnd)
    #expect(!decoder.closed)
    session.stop()
    #expect(decoder.closed)
}
private func makeSession(_ decoder: ScriptedProducerDecoder) -> PlaybackSession {
    PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.01), makeDecoder: { _, _, _ in decoder })
}
private let fixturePlan = PlaybackPlan(preFadeMilliseconds: 5_000, fadeMilliseconds: 0, isLongPlay: false, usesNativeEnding: false)

@Test func offlineExportRetriesEmptyReadsAndRejectsStallsWithoutPublishingPartialFiles() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let request = AACExportRequest(sourcePath: "/fixture.spc", outputDirectory: folder,
                                   filenameStem: "recovered", playMilliseconds: 100, fadeMilliseconds: 0)
    let recovering = ScriptedProducerDecoder([.empty, .partial, .empty, .pcm])
    let result = try AACExporter.export(request, decoderFactory: { _, _ in recovering })
    #expect(result.renderedFrames == 4_410)
    #expect(recovering.closed)

    for steps in [Array(repeating: ScriptedProducerDecoder.Step.empty, count: 9), [.end]] {
        let stalled = ScriptedProducerDecoder(steps)
        #expect(throws: AACExportError.self) {
            try AACExporter.export(request, decoderFactory: { _, _ in stalled })
        }
        #expect(stalled.closed)
    }
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
    #expect(files == [result.outputURL.lastPathComponent])
}

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

@Test func unrepresentableLoopBoundsFailWithoutTrappingOrLeaking() throws {
    for loop in [
        PlaybackLoopMetadata(startSample: 1, endSample: Int64.max, sampleRateHz: 1),
        PlaybackLoopMetadata(startSample: 1, endSample: Int64.max, sampleRateHz: 44_100),
        PlaybackLoopMetadata(startSample: 1, endSample: Int64.max / 2, sampleRateHz: 44_100)
    ] {
        let decoder = ScriptedProducerDecoder()
        let session = makeSession(decoder)
        #expect(throws: (any Error).self) {
            try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1, loop: loop)
        }
        #expect(decoder.closed)
        #expect(session.status().statistics.decoderFamily == nil)
    }
}

@Test func invalidNativeTrackIndicesFailWithoutOpeningDecodersOrPublishingAAC() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let controller = PlaybackController()
    for index in [-1, Int(Int32.max), Int.max] {
        #expect(throws: (any Error).self) {
            try controller.prepareSource(payload: .init(path: "/virtual.spc", trackIndex: index), sourceData: Data([0]))
        }
        let request = AACExportRequest(sourcePath: "/virtual.spc", trackIndex: index,
            outputDirectory: folder, filenameStem: "invalid", playMilliseconds: 100, fadeMilliseconds: 0)
        #expect(throws: AACExportError.self) {
            try AACExporter.export(request, decoderFactory: { _, _ in
                Issue.record("An invalid index must not open a decoder")
                throw ProducerFixtureError.injected
            })
        }
        #expect(throws: AACExportError.self) { try controller.exportAAC(request) }
        var archiveRequest = request
        archiveRequest.archiveEntry = "track.spc"
        #expect(throws: AACExportError.self) { try controller.exportAAC(archiveRequest) }
    }
    #expect(PlaybackTrackIndex.isRepresentable(Int(Int32.max) - 1))
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
}

@Test func vgmstreamRejectsUnrepresentableTrackIndices() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("vendor/play/js/psfplayer_browser/public/silence.wav")
    for index in [-1, Int(Int32.max), Int.max] {
        #expect(throws: (any Error).self) { try VgmstreamDecoder(path: source.path, trackIndex: index) }
    }
    let decoder = try VgmstreamDecoder(path: source.path)
    for index in [-1, Int(Int32.max), Int.max] {
        #expect(throws: (any Error).self) { try decoder.startTrack(index) }
        #expect(throws: (any Error).self) { try decoder.metadata(for: index) }
    }
}

@Test func gmeRejectsUnrepresentableAndUnavailableTrackIndices() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let decoder = try GMEDecoder(path: source.path)
    for index in [-1, decoder.trackCount, Int(Int32.max) + 1, Int.max] {
        #expect(throws: (any Error).self) { try decoder.startTrack(index) }
        #expect(throws: (any Error).self) { try decoder.metadata(for: index) }
    }
    try decoder.startTrack(0)
}

@Test func standardAudioProbeRespectsNintendoDSOverrides() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let swav = directory.appendingPathComponent("sample.wav")
    try Data("SWAV".utf8).write(to: swav)
    try DecoderFactory.validateStandardAudioSource(path: swav.path, sourceData: nil, sampleRate: 44_100)
    let raw = directory.appendingPathComponent("sample_01.wav")
    try Data(repeating: 0, count: 65_536).write(to: raw)
    try DecoderFactory.validateStandardAudioSource(path: raw.path, sourceData: nil, sampleRate: 44_100)
    let invalid = directory.appendingPathComponent("invalid.wav")
    try Data("not a WAV".utf8).write(to: invalid)
    #expect(throws: (any Error).self) {
        try DecoderFactory.validateStandardAudioSource(path: invalid.path, sourceData: nil, sampleRate: 44_100)
    }
}

@Test func singleTrackPreflightPreservesVariableTrackRoutes() throws {
    // SPC and SAP use decoder-discovered subtune counts, even in memory.
    try DecoderFactory.validateTrackIndex(1, path: "/virtual.spc", sourceData: Data([0]))
    try DecoderFactory.validateTrackIndex(1, path: "/virtual.sap", sourceData: Data([0]))
    // A SWAV payload can override ordinary WAV extension routing, so its
    // count must remain the responsibility of the vgmstream decoder.
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    try Data("SWAV".utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    try DecoderFactory.validateTrackIndex(1, path: url.path, sourceData: nil)
    try Data("RIFF".utf8).write(to: url)
    #expect(throws: (any Error).self) {
        try DecoderFactory.validateTrackIndex(1, path: url.path, sourceData: nil)
    }
}

@Test func preparedLoopBoundsUseEffectiveDecoderTempo() throws {
    let controller = PlaybackController()
    let end = Int64(Int32.max) * 44_100 / 1_000 * 3 / 2
    let loop = PlaybackLoopMetadata(startSample: 1, endSample: end, sampleRateHz: 44_100)
    let path = "/virtual.spc"
    // SPC at 2x brings the loop inside the decoder timeline; 1x does not.
    _ = try controller.prepareSource(payload: .init(path: path, tempo: 2, loop: loop), sourceData: Data([0]))
    #expect(throws: (any Error).self) {
        try controller.prepareSource(payload: .init(path: path, tempo: 1, loop: loop), sourceData: Data([0]))
    }
    // WAV does not support tempo; a requested 2x remains effectively 1x.
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    try FileManager.default.copyItem(at: root.appendingPathComponent("vendor/play/js/psfplayer_browser/public/silence.wav"), to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    #expect(throws: (any Error).self) {
        try controller.prepareSource(payload: .init(path: url.path, tempo: 2, loop: loop))
    }
}

@Test func invalidSeekDoesNotAlterTheLoadedSession() throws {
    let decoder = ScriptedProducerDecoder()
    let session = makeSession(decoder)
    defer { session.stop() }
    _ = try session.load(path: "/fixture.spc", trackIndex: 0, plan: fixturePlan, tempo: 1)
    let before = session.status()
    for seconds in [Double.infinity, Double.nan, -1, Double(Int32.max) / 1_000 + 1] {
        #expect(throws: (any Error).self) { try session.seek(to: seconds) }
    }
    let after = session.status()
    #expect(after.diagnostics.generation == before.diagnostics.generation)
    #expect(after.diagnostics.bufferedFrames == before.diagnostics.bufferedFrames)
    #expect(!decoder.closed)
}
