import Foundation
import Testing
import VGMBoyCAudioUnit
@testable import VGMBoyKit

/// Eight one-second SN76489 tones make source position visible without
/// depending on the waveform phase of a commercial recording.
private func timelineVGM() -> Data {
    var data = Data(repeating: 0, count: 64)
    func put32(_ value: UInt32, at offset: Int) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.replaceSubrange(offset..<(offset + 4), with: $0) }
    }
    data.replaceSubrange(0..<4, with: Array("Vgm ".utf8))
    put32(0x150, at: 8)
    put32(3_579_545, at: 12)
    put32(44_100 * 8, at: 0x18)
    put32(12, at: 0x34)
    for period in [40, 80, 160, 320, 500, 700, 900, 100] {
        data.append(contentsOf: [0x50, UInt8(0x80 | (period & 15)), 0x50,
            UInt8((period >> 4) & 63), 0x50, 0x90, 0x61, 0x44, 0xac])
    }
    data.append(0x66)
    put32(UInt32(data.count - 4), at: 4)
    return data
}

private func risingCrossings(_ samples: [Float]) -> Int {
    zip(samples, samples.dropFirst()).reduce(0) { $0 + ($1.0 <= 0 && $1.1 > 0 ? 1 : 0) }
}

@Test func offlineTempoReloadRampsRealDecoderPCMThroughSilence() throws {
    let synthetic = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: synthetic) }
    try timelineVGM().write(to: synthetic)
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let spc = root.appendingPathComponent("vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let families: [(String, () throws -> any AudioDecoder)] = [
        ("libvgm", { try VGMDecoder(path: synthetic.path) }),
        ("libgme", { try GMEDecoder(path: spc.path) })
    ]
    let rampFrames = 441
    for (name, make) in families {
        let oldDecoder = try make()
        try oldDecoder.startTrack(0)
        var last: (left: [Float], right: [Float]) = ([], [])
        for _ in 0..<20 { last = try oldDecoder.readFrames(4_096) }
        let newDecoder = try make()
        try newDecoder.startTrack(0)
        newDecoder.setTempo(2)
        newDecoder.seek(milliseconds: Int((20.0 * 4_096 / 44_100 / 2 * 1_000).rounded()))
        let next = try newDecoder.readFrames(rampFrames)
        #expect(last.left.count >= rampFrames && next.left.count >= rampFrames, Comment(rawValue: name))

        var config = VGMBoyAudioUnitConfig(sample_rate: 44_100, channel_count: 2, callback_frames: 512, ring_buffer_frames: 2_048)
        var handle: OpaquePointer?
        #expect(vgmboy_audio_unit_create(&handle, &config) == 0)
        let output = try #require(handle)
        defer { vgmboy_audio_unit_destroy(output) }
        func interleave(_ left: ArraySlice<Float>, _ right: ArraySlice<Float>) -> [Int16] {
            zip(left, right).flatMap { l, r in
                [Int16(max(-32768, min(32767, (l * 32767).rounded()))),
                 Int16(max(-32768, min(32767, (r * 32767).rounded())))]
            }
        }
        var oldPCM = interleave(last.left.suffix(rampFrames), last.right.suffix(rampFrames))
        #expect(vgmboy_audio_unit_enqueue_pcm(output, &oldPCM, rampFrames) == rampFrames)
        vgmboy_audio_unit_set_transport_active(output, 1)
        vgmboy_audio_unit_set_transport_gain(output, 1)
        vgmboy_audio_unit_ramp_transport_gain(output, 0, UInt32(rampFrames))
        var fadedOut = [Int16](repeating: 0, count: rampFrames * 2)
        #expect(vgmboy_audio_unit_render_offline(output, &fadedOut, rampFrames) == rampFrames)
        #expect(fadedOut.suffix(2).allSatisfy { $0 == 0 }, Comment(rawValue: name))
        #expect(fadedOut.contains { $0 != 0 }, Comment(rawValue: name))

        vgmboy_audio_unit_clear(output)
        var newPCM = interleave(next.left.prefix(rampFrames), next.right.prefix(rampFrames))
        #expect(vgmboy_audio_unit_enqueue_pcm(output, &newPCM, rampFrames) == rampFrames)
        vgmboy_audio_unit_ramp_transport_gain(output, 1, UInt32(rampFrames))
        var fadedIn = [Int16](repeating: 0, count: rampFrames * 2)
        #expect(vgmboy_audio_unit_render_offline(output, &fadedIn, rampFrames) == rampFrames)
        #expect(fadedIn.prefix(2).allSatisfy { abs(Int($0)) <= 75 }, Comment(rawValue: name))
        #expect(fadedIn.contains { $0 != 0 }, Comment(rawValue: name))
    }
}

private final class TimelineEndRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: PlaybackStatus?
    func record(_ status: PlaybackStatus) { lock.lock(); value = status; lock.unlock() }
    func snapshot() -> PlaybackStatus? { lock.lock(); defer { lock.unlock() }; return value }
}

@Test func authoredLoopBoundsScaleWithNativeTempo() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: url) }
    try timelineVGM().write(to: url)
    let loop = PlaybackLoopMetadata(startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100, repeatCount: 2)
    let controller = PlaybackController()
    let end = TimelineEndRecorder()
    let token = controller.subscribe { event in
        if event.kind == .ended, let status = event.status { end.record(status) }
    }
    defer {
        controller.unsubscribe(token)
        _ = controller.perform(.init(command: .stop))
    }
    let loaded = controller.perform(.init(command: .load, payload: .init(
        path: url.path, tempo: 2, playbackMode: .fileDefault, fadeMilliseconds: 0, loop: loop
    )))
    #expect(loaded.kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    for _ in 0..<140 where end.snapshot() == nil {
        try await Task.sleep(for: .milliseconds(50))
    }
    let finished = try #require(end.snapshot())
    #expect(finished.diagnostics.bufferedFrames == 0)
    // Eight source seconds plus two half-second repeats, played at 2×.
    #expect((4.4...4.6).contains(finished.elapsedSeconds))
}

@Test func controllerTempoChangesPreserveLogicalSourcePosition() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: url) }
    try timelineVGM().write(to: url)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let loaded = controller.perform(.init(command: .load, payload: .init(
        path: url.path, tempo: 1, playbackMode: .fileDefault, fadeMilliseconds: 0
    )))
    #expect(loaded.kind != .error)
    #expect(controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: 1_800))).kind != .error)
    let fast = controller.perform(.init(command: .setPlaybackMode, payload: .init(
        tempo: 2, playbackMode: .fileDefault, fadeMilliseconds: 0
    )))
    let fastStatus = try #require(fast.status)
    #expect(fast.kind != .error)
    #expect(abs(fastStatus.elapsedSeconds - 0.9) < 0.03)
    #expect(fastStatus.statistics.tempo == 2)
    #expect(fastStatus.diagnostics.generation != loaded.status?.diagnostics.generation)

    let slow = controller.perform(.init(command: .setTempo, payload: .init(tempo: 0.5)))
    let slowStatus = try #require(slow.status)
    #expect(slow.kind != .error)
    #expect(abs(slowStatus.elapsedSeconds - 3.6) < 0.04)
    #expect(slowStatus.statistics.tempo == 0.5)
    #expect(slowStatus.diagnostics.generation != fastStatus.diagnostics.generation)
    let normal = controller.perform(.init(command: .setTempo, payload: .init(tempo: 1)))
    #expect(normal.kind != .error)
    #expect(abs((normal.status?.elapsedSeconds ?? 0) - 1.8) < 0.04)
}

@Test func tempoChangesPreservePositionAcrossAuthoredRepeats() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: url) }
    try timelineVGM().write(to: url)
    let loop = PlaybackLoopMetadata(startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100, repeatCount: 2)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    #expect(controller.perform(.init(command: .load, payload: .init(
        path: url.path, tempo: 1, playbackMode: .fileDefault, fadeMilliseconds: 0, loop: loop
    ))).kind != .error)
    #expect(controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: 1_750))).kind != .error)
    let fast = controller.perform(.init(command: .setTempo, payload: .init(tempo: 2)))
    #expect(fast.kind != .error)
    #expect(abs((fast.status?.elapsedSeconds ?? 0) - 0.875) < 0.04)
    let slow = controller.perform(.init(command: .setTempo, payload: .init(tempo: 0.5)))
    #expect(slow.kind != .error)
    #expect(abs((slow.status?.elapsedSeconds ?? 0) - 3.5) < 0.05)
}

@Test func nativeTempoSeekUsesCurrentSpeedPlaybackTime() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: url) }
    try timelineVGM().write(to: url)
    let families: [(String, () throws -> any AudioDecoder)] = [
        ("libvgm", { try VGMDecoder(path: url.path) }),
        ("libgme", { try GMEDecoder(path: url.path) })
    ]
    for (name, make) in families {
        let continuous = try make()
        try continuous.startTrack(0)
        for _ in 0..<20 { _ = try continuous.readFrames(4_096) }
        continuous.setTempo(2)
        let reference = risingCrossings(try continuous.readFrames(2_048).left)

        let matching = try make()
        try matching.startTrack(0)
        matching.setTempo(2)
        matching.seek(milliseconds: Int((20.0 * 4_096 / 44_100 / 2 * 1_000).rounded()))
        let matchingTone = risingCrossings(try matching.readFrames(2_048).left)

        let unconverted = try make()
        try unconverted.startTrack(0)
        unconverted.setTempo(2)
        unconverted.seek(milliseconds: Int((20.0 * 4_096 / 44_100 * 1_000).rounded()))
        let wrongTone = risingCrossings(try unconverted.readFrames(2_048).left)
        print("TIMELINE \(name) continuous=\(reference) converted=\(matchingTone) unconverted=\(wrongTone)")
        #expect(reference > 10, Comment(rawValue: name))
        #expect(abs(reference - matchingTone) <= 3, Comment(rawValue: name))
        #expect(abs(reference - wrongTone) > 10, Comment(rawValue: name))
    }
}

@Test func nativeTempoSeekMapsMultipleSpeedSegments() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".vgm")
    defer { try? FileManager.default.removeItem(at: url) }
    try timelineVGM().write(to: url)
    let families: [(String, () throws -> any AudioDecoder)] = [
        ("libvgm", { try VGMDecoder(path: url.path) }),
        ("libgme", { try GMEDecoder(path: url.path) })
    ]
    let firstOutput = 20.0 * 4_096 / 44_100
    let secondOutput = 5.0 * 4_096 / 44_100
    let sourcePosition = firstOutput + secondOutput * 2
    for (name, make) in families {
        let continuous = try make()
        try continuous.startTrack(0)
        for _ in 0..<20 { _ = try continuous.readFrames(4_096) }
        continuous.setTempo(2)
        for _ in 0..<5 { _ = try continuous.readFrames(4_096) }
        continuous.setTempo(0.5)
        let reference = risingCrossings(try continuous.readFrames(2_048).left)

        let matching = try make()
        try matching.startTrack(0)
        matching.setTempo(0.5)
        matching.seek(milliseconds: Int((sourcePosition / 0.5 * 1_000).rounded()))
        let matchingTone = risingCrossings(try matching.readFrames(2_048).left)

        let unconverted = try make()
        try unconverted.startTrack(0)
        unconverted.setTempo(0.5)
        unconverted.seek(milliseconds: Int(((firstOutput + secondOutput) * 1_000).rounded()))
        let wrongTone = risingCrossings(try unconverted.readFrames(2_048).left)
        print("MULTI-TIMELINE \(name) continuous=\(reference) converted=\(matchingTone) unconverted=\(wrongTone)")
        #expect(reference > 10, Comment(rawValue: name))
        #expect(abs(reference - matchingTone) <= 3, Comment(rawValue: name))
        #expect(abs(reference - wrongTone) > 10, Comment(rawValue: name))
    }
}
