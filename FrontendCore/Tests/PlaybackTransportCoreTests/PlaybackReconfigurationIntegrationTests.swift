import Foundation
import Testing
import VGMBoyKit
@testable import PlaybackTransportCore

private final class EndRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var generations: [Int] = []

    func record(_ generation: Int) {
        lock.lock()
        generations.append(generation)
        lock.unlock()
    }

    func snapshot() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return generations
    }
}

private final class StatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [PlaybackTransportStatus] = []
    func record(_ status: PlaybackTransportStatus) { lock.lock(); values.append(status); lock.unlock() }
    func clear() { lock.lock(); values.removeAll(); lock.unlock() }
    func snapshot() -> [PlaybackTransportStatus] { lock.lock(); defer { lock.unlock() }; return values }
}

@Test func failedReplacementRetiresOnlyAfterSessionReplacementBegins() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.failed.replacement")
    defer { _ = transport.perform(.init(command: .stop)) }
    let first = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    #expect(first.kind != .error)
    let firstGeneration = try #require(first.status?.diagnostics.generation)

    // Preparation fails before the current decoder is released.
    let missingArchive = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".zip")
    let preparationError = transport.perform(.init(command: .load, payload: .init(
        path: missingArchive.path, archiveEntry: "track.spc"
    )))
    #expect(preparationError.kind == .error)
    #expect(transport.statusSync().currentTrackID == url.path)
    #expect(transport.statusSync().generation == firstGeneration)

    // This admitted extension reaches session.load, which retires the old
    // decoder before failing to open the missing replacement.
    let missingWAV = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".wav")
    let openError = transport.perform(.init(command: .load, payload: .init(path: missingWAV.path)))
    #expect(openError.kind == .error)
    let stopped = transport.statusSync()
    #expect(stopped.currentTrackID == nil)
    #expect(!stopped.trackLoaded)
    #expect(!stopped.isPlaying)
    #expect(stopped.generation != firstGeneration)

    let retry = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    #expect(retry.kind != .error)
    #expect(transport.statusSync().currentTrackID == url.path)

    // The typed start route must apply the same failure boundary.
    let start = PlaybackContinuationStart(
        track: PlaybackTransportTrack(id: "missing", path: missingWAV.path),
        payload: .init(path: missingWAV.path),
        requestID: transport.reservePlaybackRequest()
    )
    #expect(throws: (any Error).self) { try transport.start(start) }
    #expect(!transport.statusSync().trackLoaded)
    #expect(transport.statusSync().currentTrackID == nil)
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
}

@MainActor
@Test func delayedOldStatusCannotDescribeReplacementTrack() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = directory.appendingPathComponent("first.wav")
    let second = directory.appendingPathComponent("second.wav")
    try silentWAV(seconds: 2).write(to: first)
    try silentWAV(seconds: 2).write(to: second)
    let transport = PlaybackTransportCoordinator(label: "test.delayed.status")
    let statuses = StatusRecorder()
    transport.setStatusHandler { statuses.record($0) }
    let original = transport.perform(.init(command: .load, payload: .init(path: first.path)))
    let oldGeneration = try #require(original.status?.diagnostics.generation)
    let replacement = transport.perform(.init(command: .load, payload: .init(path: second.path)))
    let newGeneration = try #require(replacement.status?.diagnostics.generation)
    statuses.clear()
    // The main queue could not deliver session status callbacks while the
    // two synchronous loads ran, so the old callbacks arrive after replacement.
    try await Task.sleep(for: .milliseconds(300))
    let observed = statuses.snapshot()
    #expect(!observed.isEmpty)
    #expect(!observed.contains { $0.generation == oldGeneration })
    #expect(observed.allSatisfy { $0.generation == newGeneration && $0.currentTrackID == second.path })
    _ = transport.perform(.init(command: .stop))
}

@Test func reconfigurationPublishesEndForReloadedGeneration() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)

    let transport = PlaybackTransportCoordinator(label: "test.reconfiguration.end")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0
    )))
    #expect(loaded.kind != .error)
    let originalGeneration = try #require(loaded.status?.diagnostics.generation)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let changed = transport.perform(.init(command: .setPlaybackMode, payload: .init(
        playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0
    )))
    #expect(changed.kind != .error)
    let newGeneration = try #require(changed.status?.diagnostics.generation)
    #expect(newGeneration != originalGeneration)

    for _ in 0..<60 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [newGeneration])
    _ = transport.perform(.init(command: .stop))
}

@MainActor
@Test func delayedCompletionRetainsOriginalSessionGeneration() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)

    let controller = PlaybackController()
    let ends = EndRecorder()
    let subscription = controller.subscribe { event in
        if event.kind == .ended, let generation = event.status?.diagnostics.generation {
            ends.record(generation)
        }
    }
    defer {
        controller.unsubscribe(subscription)
        _ = controller.perform(.init(command: .stop))
    }
    let original = controller.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0
    )))
    let originalGeneration = try #require(original.status?.diagnostics.generation)
    #expect(controller.perform(.init(command: .play)).kind != .error)

    // Keep the main queue occupied until the old completion is queued, then
    // replace the decoder before its callback can run on that queue.
    let replaced = waitForDrainAndReplace(controller, path: url.path)
    #expect(replaced.kind != .error)
    let replacementGeneration = try #require(replaced.status?.diagnostics.generation)
    #expect(replacementGeneration != originalGeneration)
    for _ in 0..<40 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(25))
    }
    #expect(ends.snapshot() == [originalGeneration])
}

private func waitForDrainAndReplace(_ controller: PlaybackController, path: String) -> PlaybackControlEvent {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
        let status = controller.status()
        if status.reachedEnd && status.diagnostics.bufferedFrames == 0 && !status.isPlaying {
            break
        }
        Thread.sleep(forTimeInterval: 0.01)
    }
    return controller.perform(.init(command: .load, payload: .init(
        path: path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0
    )))
}

private func silentWAV(seconds: Int) -> Data {
    let sampleRate: UInt32 = 44_100
    let bytes = sampleRate * 4 * UInt32(seconds)
    var result = Data()
    func text(_ value: String) { result.append(contentsOf: value.utf8) }
    func integer<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { result.append(contentsOf: $0) }
    }
    text("RIFF"); integer(bytes + 36); text("WAVEfmt ")
    integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(2)); integer(sampleRate)
    integer(sampleRate * 4); integer(UInt16(4)); integer(UInt16(16))
    text("data"); integer(bytes); result.append(Data(count: Int(bytes)))
    return result
}
