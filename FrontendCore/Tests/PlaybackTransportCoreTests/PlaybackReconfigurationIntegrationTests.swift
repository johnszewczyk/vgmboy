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

@Test func sharedReconfigurationRetainsPausedPositionAndGatesUnsupportedTempo() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.shared.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let original = try #require(loaded.status)
    let updated = try transport.reconfigureSync(.init(
        longPlayEnabled: true, manualPlayMilliseconds: 2_000,
        fadeMilliseconds: 0, tempo: .init(numerator: 2, denominator: 1)
    ))
    #expect(updated.currentTrackID == url.path)
    #expect(updated.generation != original.diagnostics.generation)
    #expect(!updated.isPlaying)
    #expect(updated.elapsedSeconds < 0.05)
    #expect(updated.tempo == 1)
}

@Test func sharedReconfigurationRetiresFailedReload() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.shared.reconfiguration.failure")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    try FileManager.default.removeItem(at: url)
    #expect(throws: (any Error).self) {
        _ = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 1_000))
    }
    let status = transport.statusSync()
    #expect(!status.trackLoaded)
    #expect(status.currentTrackID == nil)
    #expect(!status.isPlaying)
}

@Test(.enabled(if: FileManager.default.isExecutableFile(atPath: "/usr/bin/zip")
    && ["/opt/homebrew/bin/7zz", "/usr/local/bin/7zz", "/usr/bin/7zz"]
        .contains { FileManager.default.isExecutableFile(atPath: $0) },
    "The archive test needs zip and the configured 7zz tool."))
func archiveReconfigurationKeepsActiveSessionWhenPreparationFails() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let fixture = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("music.zip")
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-j", archive.path, fixture.path]
    try zip.run()
    zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)

    let transport = PlaybackTransportCoordinator(label: "test.archive.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: archive.path, archiveEntry: fixture.lastPathComponent
    )))
    #expect(loaded.kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 30_000))
    #expect(configured.isPlaying)
    let generation = configured.generation

    // The active decoder has a prepared member, even after this test-owned
    // archive disappears. Re-preparation must not retire that live session.
    try FileManager.default.removeItem(at: archive)
    #expect(throws: (any Error).self) {
        _ = try transport.reconfigureSync(.init(longPlayEnabled: false))
    }
    let afterFailure = transport.statusSync()
    #expect(afterFailure.generation == generation)
    #expect(afterFailure.currentTrackID == archive.path)
    #expect(afterFailure.trackLoaded)
    #expect(afterFailure.isPlaying)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGM_TXTP_ARCHIVE_FIXTURE_DIR"] != nil,
    "Set VGM_TXTP_ARCHIVE_FIXTURE_DIR to a directory containing ending3.txtp and ending3.rsf."))
func dependencyArchiveReconfigurationKeepsPreparedSetAlive() throws {
    let fixtureDirectory = try #require(ProcessInfo.processInfo.environment["VGM_TXTP_ARCHIVE_FIXTURE_DIR"])
    let fixture = URL(fileURLWithPath: fixtureDirectory, isDirectory: true)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("dependencies.zip")
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.currentDirectoryURL = fixture
    zip.arguments = ["-q", archive.path, "ending3.txtp", "ending3.rsf"]
    try zip.run()
    zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)

    let transport = PlaybackTransportCoordinator(label: "test.dependency.archive.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: archive.path, archiveEntry: "ending3.txtp"
    )))
    #expect(loaded.kind != .error, Comment(rawValue: loaded.message ?? ""))
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 30_000))
    #expect(configured.isPlaying)
    try FileManager.default.removeItem(at: archive)
    #expect(throws: (any Error).self) {
        _ = try transport.reconfigureSync(.init(longPlayEnabled: false))
    }
    let afterFailure = transport.statusSync()
    #expect(afterFailure.generation == configured.generation)
    #expect(afterFailure.trackLoaded && afterFailure.isPlaying)
    #expect(afterFailure.currentTrackID == archive.path)
    let seek = transport.perform(.init(command: .seek, payload: .init(positionMilliseconds: 2_000)))
    #expect(seek.kind != .error, Comment(rawValue: seek.message ?? ""))
    #expect(seek.status?.isPlaying == true)
    #expect((seek.status?.diagnostics.bufferedFrames ?? 0) > 0)
}

@Test func sharedReconfigurationAppliesTempoForNativeTempoFamilies() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    for relative in [
        "VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc",
        "VGMBoy/vendor/zxtune/samples/chiptunes/Multi/vgm/TwinCobra.vgm"
    ] {
        let path = root.appendingPathComponent(relative).path
        let transport = PlaybackTransportCoordinator(label: "test.shared.reconfiguration.tempo")
        let loaded = transport.perform(.init(command: .load, payload: .init(path: path)))
        #expect(loaded.kind != .error, Comment(rawValue: relative))
        let updated = try transport.reconfigureSync(.init(
            longPlayEnabled: false, fadeMilliseconds: 0,
            tempo: .init(numerator: 3, denominator: 2)
        ))
        #expect(updated.tempo == 1.5, Comment(rawValue: relative))
        #expect(!updated.isPlaying, Comment(rawValue: relative))
        #expect(updated.elapsedSeconds < 0.05, Comment(rawValue: relative))
        _ = transport.perform(.init(command: .stop))
    }
}

@Test func nativePlanReconfigurationUsesSharedSessionOperation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.native.plan.reconfiguration")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let before = transport.statusSync()
    try await transport.reconfigureCurrentTrack(
        plan: .init(preFadeSeconds: 2, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true),
        tempo: .init(numerator: 2, denominator: 1)
    )
    let after = transport.statusSync()
    #expect(after.generation != before.generation)
    #expect(after.currentTrackID == before.currentTrackID)
    #expect(!after.isPlaying)
    #expect(after.elapsedSeconds < 0.05)
    #expect(after.tempo == 1)
    _ = transport.perform(.init(command: .stop))
}

@Test func sharedReconfigurationDeliversNaturalEnd() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.shared.reconfiguration.end")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let updated = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 1_000))
    #expect(updated.isPlaying)
    for _ in 0..<60 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [updated.generation])
    _ = transport.perform(.init(command: .stop))
}

@Test func boundedDecoderPlaybackDrainsAfterFade() async throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    for relative in [
        "VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc",
        "VGMBoy/vendor/zxtune/samples/chiptunes/Multi/vgm/TwinCobra.vgm"
    ] {
        let transport = PlaybackTransportCoordinator(label: "test.bounded.decoder.fade")
        let ends = EndRecorder()
        transport.setNaturalEndHandler { ends.record($0.generation) }
        let load = transport.perform(.init(command: .load, payload: .init(
            path: root.appendingPathComponent(relative).path,
            playbackMode: .longPlay, playMilliseconds: 1_000, fadeMilliseconds: 1_000
        )))
        #expect(load.kind != .error, Comment(rawValue: relative))
        let generation = try #require(load.status?.diagnostics.generation)
        #expect(transport.perform(.init(command: .play)).kind != .error, Comment(rawValue: relative))
        for _ in 0..<90 where ends.snapshot().isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(ends.snapshot() == [generation], Comment(rawValue: relative))
        let status = transport.statusSync()
        #expect(status.reachedEnd, Comment(rawValue: relative))
        #expect(status.bufferedFrames == 0, Comment(rawValue: relative))
        _ = transport.perform(.init(command: .stop))
    }
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
