import Foundation
import Testing
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
