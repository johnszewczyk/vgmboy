import Foundation
import Testing
import VGMBoyArchiveCore
@testable import VGMBoyKit

private final class UACLoopEndRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var ended: PlaybackStatus?
    func record(_ status: PlaybackStatus) { lock.lock(); ended = status; lock.unlock() }
    var snapshot: PlaybackStatus? { lock.lock(); defer { lock.unlock() }; return ended }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"] != nil))
func sotnUACMemberPreservesAuthoredLoop() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"])
    let entry = "audio/SD-XA_STR1/file00-channel00.xa"
    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entry]))
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }
    let prepared = try materializer.materializeSource(archivePath: path, entry: entry, requirement: requirement)
    #expect(prepared.isUAC)
    let loop = try #require(prepared.authoredLoop)
    #expect(loop.startSamples == 2_153_088)
    #expect(loop.endSamples == 5_310_144)
    #expect(loop.sampleRateHz == 37_800)
    #expect(loop.repeatCount == nil)
    #expect(loop.source == "sotn.dra.xa_music_config")
    let decoder = try VgmstreamDecoder(path: prepared.url.path)
    try decoder.startTrack(0)
    let metadata = try decoder.metadata(for: 0)
    decoder.seek(milliseconds: max(0, metadata.naturalPlayMs - 100))
    var sawShortRead = false
    for _ in 0..<32 {
        let pcm = try decoder.readFrames(4_096)
        if pcm.left.count < 4_096 { sawShortRead = true }
        if decoder.trackEnded { break }
    }
    #expect(decoder.trackEnded)
    #expect(sawShortRead)
    decoder.seek(milliseconds: Int(Double(loop.startSamples) * 1_000 / Double(loop.sampleRateHz)))
    let replayed = try decoder.readFrames(4_096)
    #expect(!decoder.trackEnded)
    #expect(!replayed.left.isEmpty)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    #expect(controller.perform(.init(command: .setOutputVolume, payload: .init(outputVolume: 0))).kind != .error)
    let loaded = controller.perform(.init(command: .load, payload: .init(path: path, archiveEntry: entry)))
    #expect(loaded.kind != .error, Comment(rawValue: loaded.message ?? ""))
    let seekMs = Int(Double(loop.endSamples) * 1_000 / Double(loop.sampleRateHz)) - 250
    #expect(controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: seekMs))).kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    try await Task.sleep(for: .milliseconds(800))
    let status = controller.status()
    #expect(status.isPlaying)
    #expect(status.errorMessage == nil)
    #expect(status.elapsedSeconds > Double(seekMs) / 1_000)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"] != nil))
func uacMemberLoopControlsPlayback() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"])
    for (name, expected) in [("loop", 1.1), ("none", 1.0), ("endloop", 1.5)] {
        try await verifyUACPlayback(path: URL(fileURLWithPath: directory).appendingPathComponent("\(name).uac").path,
                                    expectedSeconds: expected)
    }
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let root = URL(fileURLWithPath: directory)
    let old = root.appendingPathComponent("none.uac").path
    let invalid = root.appendingPathComponent("invalid.uac").path
    #expect(controller.perform(.init(command: .load, payload: .init(path: old, archiveEntry: "tone.wav"))).kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    let generation = controller.status().diagnostics.generation
    let rejected = controller.perform(.init(command: .load, payload: .init(path: invalid, archiveEntry: "tone.wav")))
    #expect(rejected.kind == .error)
    #expect(controller.status().diagnostics.generation == generation)
    #expect(controller.status().isPlaying)
}

private func verifyUACPlayback(path: String, expectedSeconds: Double) async throws {
    let controller = PlaybackController()
    let end = UACLoopEndRecorder()
    let token = controller.subscribe { event in
        if event.kind == .ended, let status = event.status { end.record(status) }
    }
    defer { controller.unsubscribe(token); _ = controller.perform(.init(command: .stop)) }
    let loaded = controller.perform(.init(command: .load, payload: .init(
        path: path, archiveEntry: "tone.wav", playbackMode: .fileDefault,
        // This conflicting caller override must not replace the UAC manifest.
        loop: PlaybackLoopMetadata(startSample: 0, endSample: 2_205, sampleRateHz: 44_100, repeatCount: 2)
    )))
    #expect(loaded.kind != .error, Comment(rawValue: loaded.message ?? ""))
    #expect(controller.perform(.init(command: .play)).kind != .error)
    for _ in 0..<100 where end.snapshot == nil { try await Task.sleep(for: .milliseconds(30)) }
    let status = try #require(end.snapshot)
    #expect(status.diagnostics.bufferedFrames == 0)
    // The loop package adds two 50 ms repeats; the package without metadata
    // plays its one-second member without borrowing the caller's override.
    #expect(abs(status.elapsedSeconds - expectedSeconds) < 0.02)
}
