import Foundation
import Testing
import VGMBoyKit
import PlaybackQueueCore
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

@Test func statusSnapshotReadsDoNotPublishEvents() async {
    let transport = PlaybackTransportCoordinator(label: "test.status.nonemitting")
    let recorded = StatusRecorder()
    transport.setStatusHandler { recorded.record($0) }
    _ = transport.statusSync() // Wait for handler installation and earlier events.
    recorded.clear()
    for _ in 0..<8 {
        _ = await transport.status()
        _ = transport.statusSync()
    }
    _ = transport.statusSync() // Drain events queued by any status reads.
    #expect(recorded.snapshot().isEmpty)
}

@Test func staleReplacementCannotStopCurrentPlayback() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.stale.replacement.stop")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let staleRequest = transport.reservePlaybackRequest()
    let currentRequest = transport.reservePlaybackRequest()
    #expect(!transport.stopForPlaybackRequestSync(staleRequest))
    #expect(!(await transport.stopForPlaybackRequest(staleRequest)))
    let stillPlaying = await transport.status()
    #expect(stillPlaying.currentTrackID == url.path && stillPlaying.isPlaying)
    #expect(await transport.stopForPlaybackRequest(currentRequest))
    #expect(!(await transport.status()).trackLoaded)
}

@Test func reversedReservedStartsKeepNewestSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.reversed.starts")
    defer { _ = transport.perform(.init(command: .stop)) }
    let first = transport.reservePlaybackRequest()
    let second = transport.reservePlaybackRequest()
    func start(_ id: String, _ request: Int) -> PlaybackContinuationStart {
        .init(track: .init(id: id, path: url.path), payload: .init(path: url.path), requestID: request)
    }
    try transport.start(start("new", second))
    #expect(throws: CancellationError.self) { try transport.start(start("old", first)) }
    #expect(transport.statusSync().currentTrackID == "new")
    #expect(!transport.stopForPlaybackRequestSync(first))
    #expect(transport.statusSync().currentTrackID == "new")
    let stop = transport.reservePlaybackRequest()
    #expect(transport.stopForPlaybackRequestSync(stop))
    #expect(!transport.statusSync().trackLoaded)
}

@Test func queuedReplacementRequiresItsOriginalNativeGeneration() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.queued-replacement.generation")
    defer { _ = transport.perform(.init(command: .stop)) }
    func start(_ id: String, expected: Int? = nil) throws {
        let request = PlaybackTransportStartRequest(trackID: id, sourcePath: url.path,
                                                    expectedPreviousGeneration: expected)
        let decoded = try JSONDecoder().decode(PlaybackTransportStartRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
        try transport.start(decoded.continuationStart(requestID: transport.reservePlaybackRequest()))
    }
    try start("old")
    let oldGeneration = transport.statusSync().generation
    try start("new")
    let newGeneration = transport.statusSync().generation
    #expect(newGeneration != oldGeneration)
    #expect(throws: CancellationError.self) { try start("stale", expected: oldGeneration) }
    #expect(throws: CancellationError.self) { try start("invalid", expected: 0) }
    let retained = transport.statusSync()
    #expect(retained.currentTrackID == "new")
    #expect(retained.generation == newGeneration)
    #expect(retained.isPlaying)
    try start("accepted", expected: newGeneration)
    #expect(transport.statusSync().currentTrackID == "accepted")
}

@Test func queuedSkipDecisionUsesCurrentSessionAndSharedQueuePolicy() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.queued-skip.decision")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let generation = try #require(loaded.status?.diagnostics.generation)
    let navigation = PlaybackQueueAdjacentRequest(
        state: .init(currentTrackID: "first", selectedTrackID: nil, pendingTrackID: nil),
        playlistIDs: ["first", "second"], direction: .next, wraps: true)
    let request = PlaybackQueuedSkipDecisionRequest(expectedGeneration: generation, navigation: navigation)
    let decoded = try JSONDecoder().decode(PlaybackQueuedSkipDecisionRequest.self, from: JSONEncoder().encode(request))
    #expect(transport.queuedSkipDecisionSync(decoded)?.trackID == "second")
    let explicit = PlaybackQueuedSkipDecisionRequest(expectedGeneration: generation, targetTrackID: "staged")
    #expect(transport.queuedSkipDecisionSync(explicit)?.trackID == "staged")
    let claimed = PlaybackQueuedSkipDecisionRequest(expectedGeneration: generation, requestID: "skip-1", targetTrackID: "staged")
    #expect(transport.queuedSkipDecisionSync(claimed)?.trackID == "staged")
    #expect(transport.queuedSkipDecisionSync(claimed) == nil)
    let distinct = PlaybackQueuedSkipDecisionRequest(expectedGeneration: generation, requestID: "skip-2", targetTrackID: "staged")
    #expect(transport.queuedSkipDecisionSync(distinct)?.trackID == "staged")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.queuedSkipDecisionSync(decoded) == nil)
    #expect(transport.queuedSkipDecisionSync(explicit) == nil)
    #expect(transport.statusSync().trackLoaded)
}

@Test func invalidFadeDurationsLeavePlaybackIntact() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.invalid.fade.duration")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    for duration in [Double.nan, Double.infinity, -Double.infinity, Double.greatestFiniteMagnitude] {
        #expect(await transport.beginFadedSkip(duration: duration) == nil)
    }
    let oversized = transport.perform(.init(command: .rampOutputGain,
                                            payload: .init(outputGain: 0, rampMilliseconds: Int.max)))
    #expect(oversized.kind == .error)
    let status = transport.statusSync()
    #expect(status.generation == generation && status.isPlaying)
    #expect(await transport.beginFadedSkip(duration: 0.01) == generation)
    #expect(await transport.beginFadedSkip(duration: -Double.greatestFiniteMagnitude) == generation)
}

@Test func staleGainRampCannotAffectReplacementSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.stale.gain.ramp")
    defer { _ = transport.perform(.init(command: .stop)) }
    let first = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let oldGeneration = try #require(first.status?.diagnostics.generation)
    let replacement = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let currentGeneration = try #require(replacement.status?.diagnostics.generation)
    #expect(oldGeneration != currentGeneration)
    #expect(throws: CancellationError.self) {
        try transport.restoreQueuedSkipGainSync(.init(expectedGeneration: oldGeneration, rampMilliseconds: 10))
    }
    let restored = try transport.restoreQueuedSkipGainSync(.init(expectedGeneration: currentGeneration, rampMilliseconds: 10))
    #expect(restored.generation == currentGeneration)
    #expect(throws: CancellationError.self) {
        try transport.rampOutputGainSync(.init(outputGain: 0, rampMilliseconds: 10,
                                               expectedGeneration: oldGeneration))
    }
    #expect(transport.statusSync().generation == currentGeneration)
    let accepted = try transport.rampOutputGainSync(.init(outputGain: 1, rampMilliseconds: 10,
                                                          expectedGeneration: currentGeneration))
    #expect(accepted.generation == currentGeneration)
    _ = try transport.rampOutputGainSync(.init(outputGain: 1, rampMilliseconds: 10))
}

@Test func orderedGainRampsRejectLateFadeAfterRestore() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.ordered.gain.ramps")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let generation = try #require(loaded.status?.diagnostics.generation)
    let oldFade = transport.reserveRampRevision(), restore = transport.reserveRampRevision()
    _ = try transport.restoreQueuedSkipGainSync(.init(expectedGeneration: generation, rampMilliseconds: 10,
                                                     rampRevision: restore))
    #expect(throws: CancellationError.self) {
        try transport.rampOutputGainSync(.init(outputGain: 0, rampMilliseconds: 5000,
                                               expectedGeneration: generation, rampRevision: oldFade))
    }
    #expect(throws: CancellationError.self) {
        try transport.rampOutputGainSync(.init(outputGain: 0, rampMilliseconds: 10, rampRevision: restore + 1))
    }
    let next = transport.reserveRampRevision()
    _ = try transport.rampOutputGainSync(.init(outputGain: 0, rampMilliseconds: 10,
                                               expectedGeneration: generation, rampRevision: next))
    _ = try transport.rampOutputGainSync(.init(outputGain: 1, rampMilliseconds: 10))
}

@Test func staleSessionControlsCannotChangeReplacement() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.stale.session.controls")
    defer { _ = transport.perform(.init(command: .stop)) }
    let old = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let oldGeneration = try #require(old.status?.diagnostics.generation)
    let new = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let generation = try #require(new.status?.diagnostics.generation)
    _ = try transport.performSessionControlSync(.play, expectedGeneration: generation)
    for command in [PlaybackControlCommand.pause, .play, .seek] {
        #expect(throws: CancellationError.self) {
            try transport.performSessionControlSync(command, payload: .init(positionMilliseconds: 2000),
                                                    expectedGeneration: oldGeneration)
        }
    }
    #expect(transport.statusSync().generation == generation && transport.statusSync().isPlaying)
    let paused = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
    #expect(!paused.isPlaying)
    let sought = try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1000),
                                                         expectedGeneration: generation)
    #expect(sought.elapsedSeconds >= 0.9)
    #expect(try transport.performSessionControlSync(.play).isPlaying)
}

@Test func newerSeekWinsWhenWorkersArriveOutOfOrder() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 4).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.reordered.seeks")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let generation = try #require(loaded.status?.diagnostics.generation)
    let first = transport.reserveSeekRevision(), second = transport.reserveSeekRevision()
    let newer = try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 2000),
                                                         expectedGeneration: generation, seekRevision: second)
    #expect(abs(newer.elapsedSeconds - 2) < 0.05)
    #expect(throws: CancellationError.self) {
        try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1000),
                                                expectedGeneration: generation, seekRevision: first)
    }
    #expect(abs(transport.statusSync().elapsedSeconds - 2) < 0.05)
    let third = transport.reserveSeekRevision()
    let next = try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 3000),
                                                       expectedGeneration: generation, seekRevision: third)
    #expect(abs(next.elapsedSeconds - 3) < 0.05)
}

@Test func oversizedTimingPlansAreRejectedBeforeReplacingPlayback() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.oversized.plan")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let original = transport.statusSync()
    let plans = [
        PlaybackTimingPlan(preFadeSeconds: .max, fadeSeconds: .max, usesNativeEnding: false, isLongPlay: true),
        PlaybackTimingPlan(preFadeSeconds: 1, fadeSeconds: .max, usesNativeEnding: false, isLongPlay: true),
        PlaybackTimingPlan(preFadeSeconds: 1, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true,
                           unknownDurationSeconds: .max)
    ]
    #expect(plans[0].totalSeconds == Int.max)
    for plan in plans {
        await #expect(throws: PlaybackControlError.self) {
            try await transport.reconfigureCurrentTrack(plan: plan, tempo: .defaultValue)
        }
        let request = transport.reservePlaybackRequest()
        await #expect(throws: PlaybackControlError.self) {
            try await transport.play(track: .init(id: "replacement", path: url.path), plan: plan,
                                     tempo: .defaultValue, requestID: request)
        }
        let status = transport.statusSync()
        #expect(status.currentTrackID == original.currentTrackID && status.generation == original.generation)
    }
    #expect(throws: PlaybackControlError.self) {
        try transport.exportAAC(sourcePath: url.path, trackIndex: 0, plan: plans[0],
                                outputDirectory: url.deletingLastPathComponent(), filenameStem: "invalid")
    }
    #expect(throws: AACExportError.self) {
        try transport.exportAAC(.init(sourcePath: url.path, trackIndex: 0,
            outputDirectory: url.deletingLastPathComponent(), filenameStem: "invalid",
            playMilliseconds: .max, fadeMilliseconds: .max))
    }
    #expect(throws: AACExportError.self) {
        try transport.exportAAC(.init(sourcePath: url.path, trackIndex: 0,
            outputDirectory: url.deletingLastPathComponent(), filenameStem: "invalid",
            playMilliseconds: Int(Int32.max), fadeMilliseconds: 1))
    }
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

@Test func staleReconfigurationCannotModifyAReplacementSession() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let first = directory.appendingPathComponent("first.wav"), second = directory.appendingPathComponent("second.wav")
    try silentWAV(seconds: 2).write(to: first)
    try silentWAV(seconds: 2).write(to: second)
    let transport = PlaybackTransportCoordinator(label: "test.stale.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    let old = transport.perform(.init(command: .load, payload: .init(path: first.path)))
    let oldGeneration = try #require(old.status?.diagnostics.generation)
    #expect(transport.perform(.init(command: .load, payload: .init(path: second.path))).kind != .error)
    let before = transport.statusSync()
    #expect(throws: CancellationError.self) {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 5_000,
                                            expectedGeneration: oldGeneration))
    }
    let after = transport.statusSync()
    #expect(after.currentTrackID == second.path)
    #expect(after.generation == before.generation)
    #expect(after.bufferedFrames == before.bufferedFrames)
    let accepted = try transport.reconfigureSync(.init(
        longPlayEnabled: true, manualPlayMilliseconds: 5_000, expectedGeneration: before.generation
    ))
    #expect(accepted.currentTrackID == second.path)
    #expect(accepted.generation != before.generation)
}

@Test func settingsRevisionsOrderReloadsWithinOneTrack() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.settings.order")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let initial = try #require(loaded.status?.diagnostics.generation)
    let firstRevision = transport.reserveSettingsRevision()
    let secondRevision = transport.reserveSettingsRevision()
    #expect(secondRevision > firstRevision)
    let first = try transport.reconfigureSync(.init(
        longPlayEnabled: true, manualPlayMilliseconds: 1_000, expectedGeneration: initial, settingsRevision: firstRevision
    ))
    let second = try transport.reconfigureSync(.init(
        longPlayEnabled: true, manualPlayMilliseconds: 2_000, expectedGeneration: initial, settingsRevision: secondRevision
    ))
    #expect(second.generation != first.generation)
    #expect(throws: CancellationError.self) {
        try transport.reconfigureSync(.init(
            longPlayEnabled: true, manualPlayMilliseconds: 3_000, expectedGeneration: initial, settingsRevision: firstRevision
        ))
    }
    #expect(transport.statusSync().generation == second.generation)
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let replacement = transport.statusSync()
    let thirdRevision = transport.reserveSettingsRevision()
    #expect(thirdRevision > secondRevision)
    #expect(throws: CancellationError.self) {
        try transport.reconfigureSync(.init(
            longPlayEnabled: true, manualPlayMilliseconds: 4_000, expectedGeneration: initial, settingsRevision: thirdRevision
        ))
    }
    #expect(transport.statusSync().generation == replacement.generation)
}

@Test func asyncSeekRejectsUnrepresentablePositionsWithoutChangingPlayback() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.seek.bounds")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let before = await transport.status()
    for position in [Double.nan, Double.infinity, -Double.infinity, Double.greatestFiniteMagnitude,
                     Double(Int32.max) / 1_000 + 1] {
        await #expect(throws: (any Error).self) { try await transport.seek(to: position) }
    }
    let after = await transport.status()
    #expect(after.currentTrackID == before.currentTrackID)
    #expect(after.generation == before.generation)
    #expect(after.bufferedFrames == before.bufferedFrames)
    try await transport.seek(to: -1)
    #expect((await transport.status()).elapsedSeconds == 0)
}

@Test func unchangedReconfigurationKeepsSessionAndBufferedPCM() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.unchanged.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: url.path, tempo: 1, playbackMode: .fileDefault,
        fadeMilliseconds: 0, unknownDurationMilliseconds: 150_000
    )))
    let before = try #require(loaded.status)
    let unchanged = try transport.reconfigureSync(.init(
        longPlayEnabled: false, fadeMilliseconds: 0, unknownDurationMilliseconds: 150_000
    ))
    #expect(unchanged.generation == before.diagnostics.generation)
    #expect(unchanged.bufferedFrames == before.diagnostics.bufferedFrames)
    #expect(unchanged.elapsedSeconds == before.elapsedSeconds)
    let changed = try transport.reconfigureSync(.init(
        longPlayEnabled: false, fadeMilliseconds: 1_000, unknownDurationMilliseconds: 150_000
    ))
    #expect(changed.generation != unchanged.generation)
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

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGM_TEST_SLOW_ARCHIVE"] == "1",
    "Run with a deliberately slow VGMBOY_7Z_BINARY to verify the preparation boundary."))
func reconfigurationCapturesPositionAfterArchivePreparation() async throws {
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

    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    #expect(controller.perform(.init(command: .load, payload: .init(
        path: archive.path, archiveEntry: fixture.lastPathComponent,
        playbackMode: .fileDefault, fadeMilliseconds: 0
    ))).kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    let before = controller.status()
    let operation = Task.detached {
        controller.perform(.init(command: .setPlaybackMode, payload: .init(
            playbackMode: .fileDefault, fadeMilliseconds: 1_000
        )))
    }
    try await Task.sleep(for: .milliseconds(200))
    let during = controller.status()
    #expect(during.isPlaying)
    #expect(during.elapsedSeconds > before.elapsedSeconds + 0.08)
    let result = await operation.value
    let after = try #require(result.status)
    #expect(result.kind != .error)
    #expect(after.isPlaying)
    #expect(after.elapsedSeconds >= during.elapsedSeconds - 0.03)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGM_TEST_SLOW_START_MARKER"] != nil,
    "Run with a signaling, deliberately slow VGMBOY_7Z_BINARY."))
func supersededArchiveStartNeverBeginsPlayback() async throws {
    let marker = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["VGM_TEST_SLOW_START_MARKER"]))
    try? FileManager.default.removeItem(at: marker)
    defer { try? FileManager.default.removeItem(at: marker) }
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

    for route in ["typed", "async", "replacement", "preserve", "async-preserve", "end-during-preparation"] {
        try? FileManager.default.removeItem(at: marker)
        let transport = PlaybackTransportCoordinator(label: "test.superseded.archive.\(route)")
        defer { _ = transport.perform(.init(command: .stop)) }
        let ends = EndRecorder()
        transport.setNaturalEndHandler { ends.record($0.generation) }
        var previousGeneration: Int?
        if route.contains("preserve") || route == "end-during-preparation" {
            let path = "/no-such-directory/previous.spc"
            let payload = route == "end-during-preparation"
                ? PlaybackControlPayload(path: path, playbackMode: .timed, playMilliseconds: 300, fadeMilliseconds: 0)
                : PlaybackControlPayload(path: path)
            let initial = PlaybackContinuationStart(
                track: .init(id: "previous", path: path, sourceData: try Data(contentsOf: fixture)),
                payload: payload, requestID: transport.reservePlaybackRequest()
            )
            try transport.start(initial)
            previousGeneration = transport.statusSync().generation
        }
        let requestID = transport.reservePlaybackRequest()
        let request = PlaybackTransportStartRequest(
            trackID: "old", sourcePath: archive.path, archivePath: archive.path,
            archiveEntry: fixture.lastPathComponent, fadeMilliseconds: 0
        )
        let start = try request.continuationStart(requestID: requestID)
        let track = PlaybackTransportTrack(id: "old", path: archive.path, archiveEntry: fixture.lastPathComponent)
        let plan = PlaybackTimingPlan(preFadeSeconds: 30, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true)
        let pending = Task.detached {
            if !route.hasPrefix("async") { try transport.start(start) }
            else { try await transport.play(track: track, plan: plan, tempo: .defaultValue, requestID: requestID) }
        }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: marker.path) {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(FileManager.default.fileExists(atPath: marker.path), Comment(rawValue: route))
        let replacement: Task<Void, any Error>?
        if route == "replacement" {
            let newID = transport.reservePlaybackRequest()
            let newPath = "/no-such-directory/new-fixture.spc"
            let newStart = PlaybackContinuationStart(
                track: .init(id: "new", path: newPath, sourceData: try Data(contentsOf: fixture)),
                payload: .init(path: newPath), requestID: newID
            )
            replacement = Task.detached { try transport.start(newStart) }
        } else {
            transport.invalidatePlaybackRequests()
            replacement = nil
        }
        await #expect(throws: CancellationError.self) { try await pending.value }
        if let replacement { try await replacement.value }
        if route == "end-during-preparation" {
            for _ in 0..<80 where ends.snapshot().isEmpty {
                try await Task.sleep(for: .milliseconds(25))
            }
        }
        let status = transport.statusSync()
        if route == "replacement" {
            #expect(status.isPlaying && status.trackLoaded)
            #expect(status.currentTrackID == "new")
        } else if route.contains("preserve") {
            #expect(status.isPlaying && status.trackLoaded)
            #expect(status.currentTrackID == "previous")
            #expect(status.generation == previousGeneration)
        } else if route == "end-during-preparation" {
            #expect(!status.isPlaying && status.trackLoaded)
            #expect(status.currentTrackID == "previous")
            #expect(status.generation == previousGeneration)
            #expect(ends.snapshot() == [previousGeneration].compactMap { $0 })
        } else {
            #expect(!status.isPlaying, Comment(rawValue: route))
            #expect(!status.trackLoaded, Comment(rawValue: route))
            #expect(status.currentTrackID == nil, Comment(rawValue: route))
        }
    }
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

@Test func effectiveTempoMatchesNativeLimitsAndPreview() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    for relative in [
        "VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc",
        "VGMBoy/vendor/zxtune/samples/chiptunes/Multi/vgm/TwinCobra.vgm"
    ] {
        let path = root.appendingPathComponent(relative).path
        let transport = PlaybackTransportCoordinator(label: "test.effective.tempo")
        let loaded = transport.perform(.init(command: .load, payload: .init(path: path, tempo: 8)))
        #expect(loaded.kind != .error, Comment(rawValue: relative))
        #expect(loaded.status?.statistics.tempo == 4, Comment(rawValue: relative))
        let preview = try PlaybackTimingPreviewRequest(
            sourcePath: path, playMilliseconds: 90_000, fadeMilliseconds: 0,
            tempo: .init(numerator: 8, denominator: 1)
        ).preview()
        #expect(preview.preFadeSeconds == 22, Comment(rawValue: relative))
        if path.hasSuffix(".vgm") {
            let changed = transport.perform(.init(command: .setTempo, payload: .init(tempo: 1.0 / 32)))
            #expect(changed.kind != .error)
            #expect(changed.status?.statistics.tempo == 0.05)
            let slowPreview = try PlaybackTimingPreviewRequest(
                sourcePath: path, playMilliseconds: 90_000, fadeMilliseconds: 0,
                tempo: .init(numerator: 1, denominator: 32)
            ).preview()
            #expect(slowPreview.preFadeSeconds == 1_800)
        }
        _ = transport.perform(.init(command: .stop))
    }
}

@Test func typedStartAndReconfigurationResolveRequestedTempoInSharedCore() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let spc = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let wav = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: wav) }
    try silentWAV(seconds: 3).write(to: wav)
    for (url, effective) in [(spc, 4.0), (wav, 1.0)] {
        let transport = PlaybackTransportCoordinator(label: "test.typed.requested.tempo")
        defer { _ = transport.perform(.init(command: .stop)) }
        let requested = PlaybackTempo(numerator: 8, denominator: 1)
        let preview = try PlaybackTimingPreviewRequest(
            sourcePath: url.path, manualPlayMilliseconds: 80_000, fadeMilliseconds: 0,
            tempo: requested, longPlayEnabled: true
        ).preview()
        let start = PlaybackTransportStartRequest(
            trackID: "tempo", sourcePath: url.path,
            playMilliseconds: preview.preFadeMilliseconds, fadeMilliseconds: 0,
            tempo: requested, longPlayEnabled: true
        )
        try transport.start(start.continuationStart(requestID: transport.reservePlaybackRequest()))
        #expect(transport.statusSync().tempo == effective, Comment(rawValue: url.path))
        #expect(preview.preFadeMilliseconds == Int(80_000 / effective), Comment(rawValue: url.path))
        let updated = try transport.reconfigureSync(.init(
            longPlayEnabled: true, manualPlayMilliseconds: preview.preFadeMilliseconds,
            fadeMilliseconds: 0, tempo: requested
        ))
        #expect(updated.tempo == effective, Comment(rawValue: url.path))
        #expect(updated.currentTrackID == "tempo")
    }
}

@Test func inMemorySourcesSurviveSharedReconfigurationWithoutAFilePath() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    for (relative, ext, effective) in [
        ("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc", "spc", 2.0),
        ("VGMBoy/vendor/zxtune/samples/chiptunes/CO12294/sap/intro.sap", "sap", 1.0)
    ] {
        let data = try Data(contentsOf: root.appendingPathComponent(relative))
        let path = "/no-such-directory/shared-memory-fixture.\(ext)"
        #expect(!FileManager.default.fileExists(atPath: path))
        let transport = PlaybackTransportCoordinator(label: "test.in-memory.reconfiguration")
        defer { _ = transport.perform(.init(command: .stop)) }
        let start = PlaybackContinuationStart(
            track: .init(id: "memory-\(ext)", path: path, sourceData: data),
            payload: .init(path: path, tempo: 1, playbackMode: .longPlay, playMilliseconds: 20_000, fadeMilliseconds: 0),
            requestID: transport.reservePlaybackRequest()
        )
        try transport.start(start)
        #expect(transport.perform(.init(command: .pause)).kind != .error)
        let before = transport.statusSync()
        #expect(before.currentTrackID == "memory-\(ext)")
        #expect(before.trackLoaded)
        let after = try transport.reconfigureSync(.init(
            longPlayEnabled: true, manualPlayMilliseconds: 10_000,
            fadeMilliseconds: 0, tempo: .init(numerator: 2, denominator: 1)
        ))
        #expect(after.currentTrackID == "memory-\(ext)")
        #expect(after.trackLoaded)
        #expect(!after.isPlaying)
        #expect(after.tempo == effective)
        #expect(after.generation != before.generation)
    }
}

@Test func unsupportedDirectTempoDoesNotDiscardPausedPCM() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.unsupported.tempo")
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let before = try #require(loaded.status)
    let changed = transport.perform(.init(command: .setTempo, payload: .init(tempo: 2)))
    let after = try #require(changed.status)
    #expect(after.statistics.tempo == 1)
    #expect(after.elapsedSeconds == before.elapsedSeconds)
    #expect(after.diagnostics.bufferedFrames == before.diagnostics.bufferedFrames)
    _ = transport.perform(.init(command: .stop))
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

@Test func directTempoReloadPublishesEndForNewGeneration() async throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let path = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc").path
    let transport = PlaybackTransportCoordinator(label: "test.direct.tempo.end")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0
    )))
    let oldGeneration = try #require(loaded.status?.diagnostics.generation)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let changed = transport.perform(.init(command: .setTempo, payload: .init(tempo: 2)))
    let newGeneration = try #require(changed.status?.diagnostics.generation)
    #expect(changed.kind != .error)
    #expect(newGeneration != oldGeneration)
    try await transport.setTempo(.init(numerator: 3, denominator: 2))
    let asyncGeneration = transport.statusSync().generation
    #expect(asyncGeneration != newGeneration)
    for _ in 0..<80 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [asyncGeneration])
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

@Test func subsecondTimedWindowAndFadeRemainBounded() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.subsecond.timing")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .timed, playMilliseconds: 500, fadeMilliseconds: 250
    )))
    let generation = try #require(loaded.status?.diagnostics.generation)
    #expect(loaded.kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    for _ in 0..<40 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [generation])
    let status = transport.statusSync()
    #expect(status.reachedEnd)
    #expect(status.bufferedFrames == 0)
    #expect((0.70...0.80).contains(status.elapsedSeconds))
    _ = transport.perform(.init(command: .stop))
}

@Test func oversizedTimingIsRejectedWithoutRetiringCurrentTrack() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.oversized.timing")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: url.path)))
    let generation = try #require(loaded.status?.diagnostics.generation)
    let rejected = transport.perform(.init(command: .setPlaybackMode, payload: .init(
        playbackMode: .timed, playMilliseconds: Int(Int32.max), fadeMilliseconds: 1
    )))
    #expect(rejected.kind == .error)
    #expect(transport.statusSync().generation == generation)
    #expect(transport.statusSync().trackLoaded)
    #expect(transport.statusSync().currentTrackID == url.path)
}

@Test func explicitLoopMetadataSurvivesSharedReconfiguration() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let loop = PlaybackLoopMetadata(
        startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100,
        repeatCount: 2, source: "uac-manifest"
    )
    let transport = PlaybackTransportCoordinator(label: "test.shared.authoritative.loop")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let request = PlaybackTransportStartRequest(
        trackID: "loop-track", sourcePath: url.path, fadeMilliseconds: 0, loop: loop
    )
    try transport.start(request.continuationStart(requestID: transport.reservePlaybackRequest()))
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: false, fadeMilliseconds: 1_000))
    for _ in 0..<100 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [configured.generation])
    let status = transport.statusSync()
    // A two-second source plus two 0.5-second loop repeats lasts about three
    // seconds. The metadata must survive the controller's session reload.
    #expect(status.reachedEnd)
    #expect(status.bufferedFrames == 0)
    #expect((2.9...3.1).contains(status.elapsedSeconds))
    _ = transport.perform(.init(command: .stop))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"] != nil))
func uacManifestLoopSurvivesPausedSeekAndSharedReconfiguration() async throws {
    let directory = try #require(ProcessInfo.processInfo.environment["VGMBOY_UAC_LOOP_FIXTURES"])
    let path = URL(fileURLWithPath: directory).appendingPathComponent("loop.uac").path
    let transport = PlaybackTransportCoordinator(label: "test.uac.paused.loop.reconfiguration")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    defer { _ = transport.perform(.init(command: .stop)) }
    let request = PlaybackTransportStartRequest(trackID: "uac-loop", sourcePath: path,
        archivePath: path, archiveEntry: "tone.wav", fadeMilliseconds: 0)
    try transport.start(request.continuationStart(requestID: transport.reservePlaybackRequest()))
    let initial = transport.statusSync()
    #expect(initial.isPlaying)
    let paused = try transport.performSessionControlSync(.pause, expectedGeneration: initial.generation)
    #expect(!paused.isPlaying)
    let sought = try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 700),
                                                         expectedGeneration: initial.generation)
    #expect(abs(sought.elapsedSeconds - 0.7) < 0.05)
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: false, fadeMilliseconds: 200,
        expectedGeneration: initial.generation, settingsRevision: transport.reserveSettingsRevision()))
    #expect(configured.currentTrackID == "uac-loop")
    #expect(configured.generation != initial.generation)
    #expect(!configured.isPlaying)
    #expect(abs(configured.elapsedSeconds - 0.7) < 0.05)
    _ = try transport.performSessionControlSync(.play, expectedGeneration: configured.generation)
    for _ in 0..<100 where ends.snapshot().isEmpty { try await Task.sleep(for: .milliseconds(20)) }
    #expect(ends.snapshot() == [configured.generation])
    let finished = transport.statusSync()
    #expect(finished.reachedEnd)
    #expect(finished.bufferedFrames == 0)
    // One-second source plus the two 50 ms manifest repeats.
    #expect((1.08...1.12).contains(finished.elapsedSeconds))
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"] != nil))
func sotnLoopSurvivesPausedSharedReconfiguration() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"])
    let entry = "audio/SD-XA_STR1/file00-channel00.xa"
    let transport = PlaybackTransportCoordinator(label: "test.sotn.paused.loop.reconfiguration")
    defer { _ = transport.perform(.init(command: .stop)) }
    _ = try transport.configureAudio(.init(outputVolume: 0, equalizerEnabled: false,
                                          equalizerBandGains: Array(repeating: 0, count: 10), monoEnabled: false))
    let request = PlaybackTransportStartRequest(trackID: "sotn-xa", sourcePath: path,
        archivePath: path, archiveEntry: entry, fadeMilliseconds: 0)
    try transport.start(request.continuationStart(requestID: transport.reservePlaybackRequest()))
    let initial = transport.statusSync()
    _ = try transport.performSessionControlSync(.pause, expectedGeneration: initial.generation)
    _ = try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 140_100),
                                                expectedGeneration: initial.generation)
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: false, fadeMilliseconds: 200,
        expectedGeneration: initial.generation, settingsRevision: transport.reserveSettingsRevision()))
    #expect(configured.currentTrackID == "sotn-xa")
    #expect(!configured.isPlaying)
    #expect(abs(configured.elapsedSeconds - 140.1) < 0.1)
    _ = try transport.performSessionControlSync(.play, expectedGeneration: configured.generation)
    try await Task.sleep(for: .milliseconds(1_000))
    let status = transport.statusSync()
    #expect(status.currentTrackID == "sotn-xa")
    #expect(status.generation == configured.generation)
    #expect(status.isPlaying)
    #expect(status.elapsedSeconds > 140.5)
    #expect(status.errorMessage == nil)
}

@Test func seekingInsideRepeatedLoopPreservesLogicalTimeline() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let loop = PlaybackLoopMetadata(
        startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100,
        repeatCount: 2, source: "uac-manifest"
    )
    let transport = PlaybackTransportCoordinator(label: "test.seek.repeated.loop")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .fileDefault, fadeMilliseconds: 0, loop: loop
    )))
    let generation = try #require(loaded.status?.diagnostics.generation)
    let seek = transport.perform(.init(command: .seek, payload: .init(positionMilliseconds: 1_750)))
    #expect(seek.kind != .error)
    #expect(abs((seek.status?.elapsedSeconds ?? 0) - 1.75) < 0.05)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    for _ in 0..<100 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [generation])
    let status = transport.statusSync()
    #expect(status.reachedEnd)
    #expect((2.9...3.1).contains(status.elapsedSeconds))
    _ = transport.perform(.init(command: .stop))
}

@Test func seekingBeforeLoopRestoresItsRepeatCount() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let loop = PlaybackLoopMetadata(
        startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100, repeatCount: 2
    )
    let transport = PlaybackTransportCoordinator(label: "test.seek.before.loop")
    let ends = EndRecorder()
    transport.setNaturalEndHandler { ends.record($0.generation) }
    let loaded = transport.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .fileDefault, fadeMilliseconds: 0, loop: loop
    )))
    let generation = try #require(loaded.status?.diagnostics.generation)
    #expect(transport.perform(.init(command: .seek, payload: .init(positionMilliseconds: 200))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    for _ in 0..<100 where ends.snapshot().isEmpty {
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(ends.snapshot() == [generation])
    #expect((2.9...3.1).contains(transport.statusSync().elapsedSeconds))
    _ = transport.perform(.init(command: .stop))
}

@Test func unboundedLoopSeekMapsLogicalPosition() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let loop = PlaybackLoopMetadata(startSample: 11_025, endSample: 33_075, sampleRateHz: 44_100)
    let transport = PlaybackTransportCoordinator(label: "test.seek.unbounded.loop")
    #expect(transport.perform(.init(command: .load, payload: .init(
        path: url.path, playbackMode: .fileDefault, fadeMilliseconds: 0, loop: loop
    ))).kind != .error)
    let seek = transport.perform(.init(command: .seek, payload: .init(positionMilliseconds: 5_250)))
    #expect(seek.kind != .error)
    #expect(abs((seek.status?.elapsedSeconds ?? 0) - 5.25) < 0.05)
    #expect(seek.status?.reachedEnd == false)
    #expect((seek.status?.diagnostics.bufferedFrames ?? 0) > 0)
    _ = transport.perform(.init(command: .stop))
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
        playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 1_000
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
