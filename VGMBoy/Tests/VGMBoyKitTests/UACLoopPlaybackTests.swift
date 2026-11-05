import Foundation
import Testing
import VGMBoyArchiveCore
import AVFoundation
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

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"] != nil))
func sotnXAExportRetainsNormalArchiveRoute() throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"])
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let controller = PlaybackController()
    let request = AACExportRequest(sourcePath: path, archiveEntry: "audio/SD-XA_STR1/file00-channel00.xa",
        outputDirectory: folder, filenameStem: "sotn-xa", playMilliseconds: 1_000, fadeMilliseconds: 0)
    let independent = try controller.prepareIndependentSPCAACExport(request)
    #expect(independent == nil)
    let result = try controller.exportAAC(request)
    #expect(result.renderedFrames == 44_100)
    #expect(FileManager.default.fileExists(atPath: result.outputURL.path))
}

// Exercise two native decoder instances on the same extracted member. Each
// worker seeks independently so shared decoder or resampler state changes the
// PCM compared with its sequential reference.
@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"] != nil))
func sotnXADecodersProduceIndependentConcurrentPCM() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"])
    let entry = "audio/SD-XA_STR1/file00-channel00.xa"
    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entry]))
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }
    let source = try materializer.materializeSource(archivePath: path, entry: entry, requirement: requirement)

    @Sendable func render(_ seekMs: Int, ready: DispatchSemaphore? = nil,
                          peer: DispatchSemaphore? = nil) throws -> [Float] {
        let decoder = try VgmstreamDecoder(path: source.url.path)
        try decoder.startTrack(0)
        var samples: [Float] = []
        for chunk in 0..<96 {
            if chunk == 32 {
                ready?.signal()
                if let peer, peer.wait(timeout: .now() + 15) != .success {
                    throw VgmstreamDecoderError.renderFailed("XA decoder peer did not reach the coexistence barrier.")
                }
                decoder.seek(milliseconds: seekMs)
            }
            if chunk == 64 { decoder.seek(milliseconds: seekMs + 2_000) }
            let pcm = try decoder.readFrames(4_096)
            guard pcm.left.count == 4_096, pcm.right.count == 4_096 else {
                throw VgmstreamDecoderError.renderFailed("Unexpected short XA read in coexistence test.")
            }
            samples.append(contentsOf: pcm.left)
            samples.append(contentsOf: pcm.right)
        }
        return samples
    }

    let referenceA = try render(60_000)
    let referenceB = try render(120_000)
    #expect(referenceA.contains { $0 != 0 })
    #expect(referenceB.contains { $0 != 0 })
    let readyA = DispatchSemaphore(value: 0)
    let readyB = DispatchSemaphore(value: 0)
    let first = Task.detached { try render(60_000, ready: readyA, peer: readyB) }
    let second = Task.detached { try render(120_000, ready: readyB, peer: readyA) }
    let actualA = try await first.value
    let actualB = try await second.value
    #expect(actualA.elementsEqual(referenceA))
    #expect(actualB.elementsEqual(referenceB))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_SPC_UAC_FIXTURES"] != nil))
func independentSPCUACExportPreservesAuthoritativeLoop() throws {
    let root = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["VGMBOY_SPC_UAC_FIXTURES"]))
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let controller = PlaybackController()
    for tempo in [1.0, 2.0] {
        var outputs: [Data] = []
        for name in ["loop", "none"] {
            let override = PlaybackLoopMetadata(startSample: 0, endSample: 4_410, sampleRateHz: 44_100, repeatCount: 0)
            let request = AACExportRequest(sourcePath: root.appendingPathComponent("\(name).uac").path,
                archiveEntry: "tone.spc", outputDirectory: folder, filenameStem: "\(name)-\(tempo)",
                playMilliseconds: 1_200, fadeMilliseconds: 0, tempo: tempo, loop: override)
            let reference = try controller.exportAAC(request)
            let candidate = try controller.prepareIndependentSPCAACExport(request)
            let prepared = try #require(candidate)
            let independent = try prepared.export()
            let data = try Data(contentsOf: independent.outputURL)
            let expected = try Data(contentsOf: reference.outputURL)
            #expect(data == expected, Comment(rawValue: "\(name) at \(tempo)x"))
            outputs.append(data)
        }
        #expect(outputs[0] != outputs[1], Comment(rawValue: "\(tempo)x"))
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"] != nil))
func uacAACExportUsesLoopAndSharedFade() throws {
    let directory = try #require(ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"])
    let root = URL(fileURLWithPath: directory)
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: output) }
    let controller = PlaybackController()
    for (name, expected) in [("loop", 48_510), ("none", 44_100), ("endloop", 66_150)] {
        let result = try controller.exportAAC(.init(sourcePath: root.appendingPathComponent("\(name).uac").path,
            archiveEntry: "tone.wav", outputDirectory: output, filenameStem: name,
            playMilliseconds: 2_000, fadeMilliseconds: 0))
        #expect(abs(result.renderedFrames - Int64(expected)) <= 2, Comment(rawValue: name))
    }
    let fade = try controller.exportAAC(.init(sourcePath: root.appendingPathComponent("none.uac").path,
        archiveEntry: "tone.wav", outputDirectory: output, filenameStem: "fade",
        playMilliseconds: 500, fadeMilliseconds: 250))
    #expect(fade.renderedFrames == 33_075)
    let file = try AVAudioFile(forReading: fade.outputURL)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 40_000))
    try file.read(into: buffer)
    let channel = try #require(buffer.floatChannelData?[0])
    let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    #expect(samples.count > 33_000)
    func meanAmplitude(_ range: Range<Int>) -> Double {
        range.reduce(0.0) { $0 + Double(abs(samples[$1])) } / Double(range.count)
    }
    // ADTS decoder priming shifts the audible window; compare well inside the
    // fade rather than assuming exact encoded sample alignment.
    #expect(meanAmplitude(31_000..<32_000) < meanAmplitude(10_000..<11_000) * 0.45)
}
