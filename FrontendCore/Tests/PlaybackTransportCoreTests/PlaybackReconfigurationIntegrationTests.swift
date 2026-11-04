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

private func waitForSignal(_ semaphore: DispatchSemaphore, seconds: Int) -> Bool {
    semaphore.wait(timeout: .now() + .seconds(seconds)) == .success
}

private final class FirstPreparationGate: @unchecked Sendable {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    func waitIfFirst() {
        lock.lock(); count += 1; let first = count == 1; lock.unlock()
        if first { entered.signal(); _ = release.wait(timeout: .now() + 20) }
    }
}

private final class TwoPreparationGates: @unchecked Sendable {
    let firstEntered = DispatchSemaphore(value: 0), secondEntered = DispatchSemaphore(value: 0)
    let thirdEntered = DispatchSemaphore(value: 0)
    let firstRelease = DispatchSemaphore(value: 0), secondRelease = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var count = 0
    func wait() -> Int {
        lock.lock(); count += 1; let number = count; lock.unlock()
        if number == 1 { firstEntered.signal(); _ = firstRelease.wait(timeout: .now() + 20) }
        if number == 2 { secondEntered.signal(); _ = secondRelease.wait(timeout: .now() + 20) }
        if number == 3 { thirdEntered.signal() }
        return number
    }
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

@Test func reconfigurationValidationDoesNotMutatePlayingSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    #expect(controller.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    let generation = controller.status().diagnostics.generation
    let invalid: [PlaybackControlPayload] = [
        .init(), .init(playbackMode: .timed, playMilliseconds: 0),
        .init(playbackMode: .longPlay, fadeMilliseconds: -1),
        .init(tempo: .infinity, playbackMode: .fileDefault),
        .init(playbackMode: .longPlay, playMilliseconds: Int(Int32.max), fadeMilliseconds: 1)
    ]
    for payload in invalid {
        #expect(throws: PlaybackControlError.self) { try PlaybackController.validatePlaybackMode(payload) }
    }
    #expect(try PlaybackController.validatePlaybackMode(.init(playbackMode: .timed, playMilliseconds: 1)) == .timed)
    #expect(controller.status().diagnostics.generation == generation)
    #expect(controller.status().isPlaying)
}

@Test func reconfigurationSourcePreservesInMemoryIdentityAndLoop() throws {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let fixture = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let bytes = try Data(contentsOf: fixture)
    let path = "/no-such-directory/reconfiguration-source.spc"
    let loop = PlaybackLoopMetadata(startSample: 1_000, endSample: 20_000, sampleRateHz: 44_100,
                                    repeatCount: 2, source: "fixture")
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let event = controller.loadInMemory(sourceData: bytes, payload: .init(path: path, loop: loop))
    #expect(event.kind != .error)
    let generation = try #require(event.status?.diagnostics.generation)
    let snapshot = try controller.reconfigurationSource(for: .init(tempo: 2, playbackMode: .longPlay))
    #expect(snapshot.payload.path == path)
    #expect(snapshot.payload.tempo == 2)
    #expect(snapshot.payload.loop == loop)
    #expect(snapshot.sourceData == bytes)
    #expect(controller.status().diagnostics.generation == generation)
}

@Test func preparedReconfigurationUsesLatestPausedPosition() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    #expect(controller.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(controller.perform(.init(command: .play)).kind != .error)
    let settings = PlaybackControlPayload(tempo: 1, playbackMode: .longPlay, playMilliseconds: 30_000, fadeMilliseconds: 0)
    #expect(try controller.reconfigurationRequiresReload(settings))
    let source = try controller.reconfigurationSource(for: settings)
    let prepared = try controller.prepareSource(payload: source.payload, sourceData: source.sourceData)
    #expect(controller.perform(.init(command: .pause)).kind != .error)
    #expect(controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: 1_000))).kind != .error)
    let original = controller.status()
    let rejected = controller.reconfigurePrepared(prepared, settings: settings, isCurrent: { false })
    #expect(rejected.kind == .error)
    #expect(controller.status().diagnostics.generation == original.diagnostics.generation)
    let event = controller.reconfigurePrepared(prepared, settings: settings, isCurrent: { true })
    #expect(event.kind != .error, Comment(rawValue: event.message ?? ""))
    let after = controller.status()
    #expect(!after.isPlaying)
    #expect(abs(after.elapsedSeconds - 1) < 0.1)
    #expect(after.diagnostics.generation != original.diagnostics.generation)
    #expect(try !controller.reconfigurationRequiresReload(settings))
}

@Test func reconfigurationPreparationDoesNotBlockPauseOrSeek() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.preparation.pause") { controller, start in
        entered.signal(); _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let request = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 30_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let changing = Task.detached { try transport.reconfigureSync(request) }
    #expect(waitForSignal(entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let pauseAndSeek = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let controlsCompleted = waitForSignal(completed, seconds: 6)
    release.signal()
    _ = try await pauseAndSeek.value
    let changed = try await changing.value
    #expect(controlsCompleted)
    #expect(!changed.isPlaying)
    #expect(abs(changed.elapsedSeconds - 1) < 0.1)
    #expect(changed.currentTrackID == url.path)
}

@Test func archiveReconfigurationPreparationKeepsControlsResponsive() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let wav = directory.appendingPathComponent("source.wav")
    try silentWAV(seconds: 30).write(to: wav)
    let archive = directory.appendingPathComponent("source.zip")
    let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-j", archive.path, wav.path]
    try zip.run(); zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.archive.reconfigure.offqueue") { controller, start in
        entered.signal(); _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load, payload: .init(path: archive.path, archiveEntry: wav.lastPathComponent)))
    #expect(loaded.kind != .error, Comment(rawValue: loaded.message ?? ""))
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let settings = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 30_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let changing = Task.detached { try transport.reconfigureSync(settings) }
    #expect(waitForSignal(entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let control = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(completed, seconds: 6)
    release.signal()
    _ = try await control.value
    let result = try await changing.value
    #expect(responsive)
    #expect(!result.isPlaying && abs(result.elapsedSeconds - 1) < 0.1)
    #expect(result.currentTrackID == archive.path)
}

@Test func newerReconfigurationSupersedesOlderPreparation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.preparation.order") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let older = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 10_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let first = Task.detached { try transport.reconfigureSync(older) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let newer = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let completed = DispatchSemaphore(value: 0)
    let second = Task.detached { defer { completed.signal() }; return try transport.reconfigureSync(newer) }
    let secondFinishedBeforeRelease = waitForSignal(completed, seconds: 6)
    gate.release.signal()
    let accepted = try await second.value
    do { _ = try await first.value; Issue.record("Older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(secondFinishedBeforeRelease)
    #expect(transport.statusSync().generation == accepted.generation)
    let same = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
        fadeMilliseconds: 0, expectedGeneration: accepted.generation, settingsRevision: transport.reserveSettingsRevision()))
    #expect(same.generation == accepted.generation)
}

@Test func invalidNewerSettingsDoNotCancelValidPreparation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.invalid.newer") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    let olderRevision = transport.reserveSettingsRevision()
    let newerRevision = transport.reserveSettingsRevision()
    let pending = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
            expectedGeneration: generation, settingsRevision: olderRevision))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    #expect(throws: (any Error).self) {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: Int(Int32.max),
            fadeMilliseconds: 1, expectedGeneration: generation, settingsRevision: newerRevision))
    }
    gate.release.signal()
    let accepted = try await pending.value
    #expect(accepted.generation != generation)
    let revised = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 10_000,
        expectedGeneration: accepted.generation, settingsRevision: newerRevision))
    #expect(revised.generation != accepted.generation)
}

@Test func lowLevelSettingsSupersedePendingReconfigurationOnlyWhenAccepted() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let commands: [(PlaybackControlRequest, Bool)] = [
        (.init(command: .setTempo, payload: .init(tempo: 1)), true),
        (.init(command: .setPlaybackMode, payload: .init(playbackMode: .fileDefault)), true),
        (.init(command: .setTempo, payload: .init(tempo: -1)), false),
        (.init(command: .setPlaybackMode, payload: .init(playbackMode: .timed, playMilliseconds: 0)), false)
    ]
    for (command, accepted) in commands {
        let gate = FirstPreparationGate()
        let transport = PlaybackTransportCoordinator(label: "test.lowlevel.settings.supersession") { controller, start in
            gate.waitIfFirst()
            return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
        }
        defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
        #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
        let generation = transport.statusSync().generation
        let pending = Task.detached {
            try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
                expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision()))
        }
        #expect(waitForSignal(gate.entered, seconds: 5))
        let event = transport.perform(command)
        #expect((event.kind != .error) == accepted)
        #expect(transport.statusSync().generation == generation)
        gate.release.signal()
        do {
            let result = try await pending.value
            #expect(!accepted)
            #expect(result.generation != generation)
        } catch is CancellationError {
            #expect(accepted)
            #expect(transport.statusSync().generation == generation)
        }
    }
}

@Test func replacementSupersedesReconfigurationPreparation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.preparation.replacement") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let settings = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 30_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let changing = Task.detached { try transport.reconfigureSync(settings) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let replacement = PlaybackContinuationStart(track: .init(id: "newer", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest())
    try transport.start(replacement)
    let newGeneration = transport.statusSync().generation
    gate.release.signal()
    do { _ = try await changing.value; Issue.record("Old reconfiguration unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(transport.statusSync().generation == newGeneration)
    #expect(transport.statusSync().currentTrackID == "newer")
    #expect(transport.statusSync().isPlaying)
}

@Test func stopSupersedesReconfigurationPreparation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.preparation.stop") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let settings = PlaybackTransportReconfigurationRequest(longPlayEnabled: true, manualPlayMilliseconds: 30_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision())
    let changing = Task.detached { try transport.reconfigureSync(settings) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let stopID = transport.reservePlaybackRequest()
    #expect(transport.stopForPlaybackRequestSync(stopID))
    gate.release.signal()
    do { _ = try await changing.value; Issue.record("Stopped session was unexpectedly reconfigured") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(!transport.statusSync().trackLoaded)
    #expect(transport.statusSync().currentTrackID == nil)
}

@Test func reconfigurationDuringQueuedReplacementDoesNotLoseReplacement() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.reconfigure.during.queued-start") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    #expect(transport.queuedSkipLifecycle.begin("queued"))
    let replacement = PlaybackContinuationStart(track: .init(id: "replacement", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest(),
        expectedPreviousGeneration: generation, queuedSkipToken: "queued")
    let pending = Task.detached { try transport.start(replacement) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    _ = try? transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 30_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision()))
    gate.release.signal()
    try await pending.value
    #expect(transport.statusSync().currentTrackID == "replacement")
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
    let reconfigured = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
        fadeMilliseconds: 0, expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision()))
    #expect(reconfigured.generation != generation)
    #expect(transport.queuedSkipDecisionSync(decoded)?.trackID == "second")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.queuedSkipDecisionSync(decoded) == nil)
    #expect(transport.queuedSkipDecisionSync(explicit) == nil)
    #expect(transport.queuedSkipDecisionSync(claimed) == nil)
    let replacementGeneration = transport.statusSync().generation
    let replacementClaim = PlaybackQueuedSkipDecisionRequest(expectedGeneration: replacementGeneration,
                                                              requestID: "skip-1", targetTrackID: "replacement")
    #expect(transport.queuedSkipDecisionSync(replacementClaim)?.trackID == "replacement")
    #expect(transport.queuedSkipDecisionSync(replacementClaim) == nil)
    #expect(transport.statusSync().trackLoaded)
}

@Test func queuedSkipStartRequiresCurrentLifecycleToken() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.queued-skip.lifecycle-start")
    defer { _ = transport.perform(.init(command: .stop)) }
    func start(_ id: String, token: String? = nil) throws {
        let request = PlaybackTransportStartRequest(trackID: id, sourcePath: url.path, queuedSkipToken: token)
        let decoded = try JSONDecoder().decode(PlaybackTransportStartRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
        try transport.start(decoded.continuationStart(requestID: transport.reservePlaybackRequest()))
    }
    try start("old")
    #expect(transport.queuedSkipLifecycle.begin("first"))
    #expect(transport.queuedSkipLifecycle.claim("first"))
    #expect(transport.queuedSkipLifecycle.begin("second"))
    #expect(throws: CancellationError.self) { try start("stale", token: "first") }
    #expect(transport.statusSync().currentTrackID == "old")
    #expect(transport.queuedSkipLifecycle.cancel("second"))
    #expect(throws: CancellationError.self) { try start("canceled", token: "second") }
    #expect(transport.statusSync().currentTrackID == "old")
    #expect(transport.queuedSkipLifecycle.begin("third"))
    #expect(transport.queuedSkipLifecycle.claim("third"))
    try start("accepted", token: "third")
    #expect(transport.statusSync().currentTrackID == "accepted")
}

@Test func pauseRemainsResponsiveWhileQueuedSourcePrepares() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.queued-skip.nonblocking") { controller, start in
        if start.track.id == "replacement" {
            entered.signal()
            _ = release.wait(timeout: .now() + 20)
        }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    #expect(transport.queuedSkipLifecycle.begin("queued"))
    let start = PlaybackContinuationStart(track: .init(id: "replacement", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest(),
        expectedPreviousGeneration: generation, queuedSkipToken: "queued")
    let starting = Task.detached { try transport.start(start) }
    #expect(waitForSignal(entered, seconds: 3))
    let paused = DispatchSemaphore(value: 0)
    let pausing = Task.detached {
        defer { paused.signal() }
        return try transport.performSessionControlSync(.pause, expectedGeneration: generation)
    }
    let pauseCompletedBeforePreparation = waitForSignal(paused, seconds: 6)
    #expect(transport.queuedSkipLifecycle.cancel("queued"))
    release.signal()
    let pauseStatus = try await pausing.value
    do { try await starting.value; Issue.record("Canceled queued replacement unexpectedly started") }
    catch is CancellationError {} catch { Issue.record("Unexpected start error: \(error)") }
    #expect(pauseCompletedBeforePreparation)
    #expect(!pauseStatus.isPlaying)
    #expect(transport.statusSync().generation == generation)
    #expect(transport.statusSync().currentTrackID == url.path)
}

@Test func pauseRemainsResponsiveWhileLegacyPlayPrepares() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.legacy-play.nonblocking") { controller, start in
        if start.track.id == "replacement" { entered.signal(); _ = release.wait(timeout: .now() + 20) }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let requestID = transport.reservePlaybackRequest()
    let track = PlaybackTransportTrack(id: "replacement", path: url.path)
    let plan = PlaybackTimingPlan(preFadeSeconds: 30, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true)
    let starting = Task.detached { try await transport.play(track: track, plan: plan, tempo: .defaultValue, requestID: requestID) }
    #expect(waitForSignal(entered, seconds: 3))
    let paused = DispatchSemaphore(value: 0)
    let pausing = Task.detached {
        defer { paused.signal() }
        return try transport.performSessionControlSync(.pause, expectedGeneration: generation)
    }
    let responsive = waitForSignal(paused, seconds: 6)
    transport.invalidatePlaybackRequests()
    release.signal()
    let status = try await pausing.value
    do { try await starting.value; Issue.record("Canceled replacement unexpectedly started") }
    catch is CancellationError {} catch { Issue.record("Unexpected start error: \(error)") }
    #expect(responsive)
    #expect(!status.isPlaying)
    #expect(transport.statusSync().generation == generation)
    #expect(transport.statusSync().currentTrackID == url.path)
}

@Test func legacyPlayStartsThroughSharedContinuation() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.legacy-play.shared-start")
    defer { _ = transport.perform(.init(command: .stop)) }
    let track = PlaybackTransportTrack(id: "legacy", path: url.path)
    let plan = PlaybackTimingPlan(preFadeSeconds: 30, fadeSeconds: 2, usesNativeEnding: false, isLongPlay: true)
    try await transport.play(track: track, plan: plan, tempo: .init(numerator: 2, denominator: 1),
                             requestID: transport.reservePlaybackRequest())
    let status = transport.statusSync()
    #expect(status.currentTrackID == "legacy")
    #expect(status.trackLoaded && status.isPlaying)
    #expect(status.tempo == 1)
}

@Test func newerStartCanCommitWhileOlderSourcePrepares() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.concurrent.preparations") { controller, start in
        if start.track.id == "slow" { entered.signal(); _ = release.wait(timeout: .now() + 10) }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    func start(_ id: String) -> PlaybackContinuationStart {
        .init(track: .init(id: id, path: url.path), payload: .init(path: url.path),
              requestID: transport.reservePlaybackRequest())
    }
    let slow = start("slow")
    let starting = Task.detached { try transport.start(slow) }
    #expect(waitForSignal(entered, seconds: 3))
    let fast = start("newer")
    let finished = DispatchSemaphore(value: 0)
    let newer = Task.detached { defer { finished.signal() }; try transport.start(fast) }
    let newerCommittedBeforeRelease = waitForSignal(finished, seconds: 3)
    release.signal()
    try await newer.value
    do { try await starting.value; Issue.record("Superseded start unexpectedly succeeded") }
    catch is CancellationError {} catch { Issue.record("Unexpected start error: \(error)") }
    #expect(newerCommittedBeforeRelease)
    #expect(transport.statusSync().currentTrackID == "newer")
    #expect(transport.statusSync().isPlaying)
}

@Test func oldSessionEndsWhileReplacementPreparesAndReplacementStillStarts() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let ended = DispatchSemaphore(value: 0), ends = EndRecorder()
    let transport = PlaybackTransportCoordinator(label: "test.end.during.preparation") { controller, start in
        if start.track.id == "replacement" { entered.signal(); _ = release.wait(timeout: .now() + 20) }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    transport.setNaturalEndHandler { status in ends.record(status.generation); ended.signal() }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    let old = PlaybackContinuationStart(track: .init(id: "old", path: url.path),
        payload: .init(path: url.path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0),
        requestID: transport.reservePlaybackRequest())
    try transport.start(old)
    let generation = transport.statusSync().generation
    #expect(transport.queuedSkipLifecycle.begin("replacement"))
    #expect(transport.queuedSkipLifecycle.claim("replacement"))
    let next = PlaybackContinuationStart(track: .init(id: "replacement", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest(),
        expectedPreviousGeneration: generation, queuedSkipToken: "replacement")
    let starting = Task.detached { try transport.start(next) }
    #expect(waitForSignal(entered, seconds: 5))
    let endArrivedBeforeRelease = waitForSignal(ended, seconds: 8)
    release.signal()
    try await starting.value
    #expect(endArrivedBeforeRelease)
    #expect(ends.snapshot() == [generation])
    #expect(transport.statusSync().currentTrackID == "replacement")
    #expect(transport.statusSync().isPlaying)
}

@Test func failedPreparationAfterOldEndPreservesEndedSession() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let ended = DispatchSemaphore(value: 0), ends = EndRecorder()
    let transport = PlaybackTransportCoordinator(label: "test.end.during.failed.preparation") { controller, start in
        if start.track.id == "replacement" {
            entered.signal(); _ = release.wait(timeout: .now() + 20)
            throw PlaybackControlError.invalidPayload("forced preparation failure")
        }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    transport.setNaturalEndHandler { status in ends.record(status.generation); ended.signal() }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    let old = PlaybackContinuationStart(track: .init(id: "old", path: url.path),
        payload: .init(path: url.path, playbackMode: .timed, playMilliseconds: 1_000, fadeMilliseconds: 0),
        requestID: transport.reservePlaybackRequest())
    try transport.start(old)
    let generation = transport.statusSync().generation
    let next = PlaybackContinuationStart(track: .init(id: "replacement", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest(),
        expectedPreviousGeneration: generation)
    let starting = Task.detached { try transport.start(next) }
    #expect(waitForSignal(entered, seconds: 5))
    let endArrivedBeforeRelease = waitForSignal(ended, seconds: 8)
    release.signal()
    do { try await starting.value; Issue.record("Preparation unexpectedly succeeded") }
    catch is PlaybackControlError {} catch { Issue.record("Unexpected error: \(error)") }
    let retained = transport.statusSync()
    #expect(endArrivedBeforeRelease)
    #expect(ends.snapshot() == [generation])
    #expect(retained.currentTrackID == "old" && retained.generation == generation)
    #expect(retained.trackLoaded && !retained.isPlaying)
}

@Test func overlappingPreparationsAreBounded() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 5).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.bounded.preparations") { controller, start in
        entered.signal()
        _ = release.wait(timeout: .now() + 10)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { for _ in 0..<3 { release.signal() }; _ = transport.perform(.init(command: .stop)) }
    func start(_ id: String) -> PlaybackContinuationStart {
        .init(track: .init(id: id, path: url.path), payload: .init(path: url.path),
              requestID: transport.reservePlaybackRequest())
    }
    let firstRequest = start("first")
    let first = Task.detached { try transport.start(firstRequest) }
    #expect(waitForSignal(entered, seconds: 3))
    let secondRequest = start("second")
    let second = Task.detached { try transport.start(secondRequest) }
    #expect(waitForSignal(entered, seconds: 3))
    let thirdRequest = start("third")
    let third = Task.detached { try transport.start(thirdRequest) }
    let enteredBeforeRelease = waitForSignal(entered, seconds: 1)
    release.signal()
    let enteredAfterRelease = waitForSignal(entered, seconds: 3)
    release.signal(); release.signal()
    _ = try? await first.value
    _ = try? await second.value
    try await third.value
    #expect(!enteredBeforeRelease)
    #expect(enteredAfterRelease)
    #expect(transport.statusSync().currentTrackID == "third")
}

@Test(arguments: [false, true])
func supersededStartDoesNotWaitForBusyPreparationSlots(cancelByToken: Bool) async throws {
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let waitingStarted = DispatchSemaphore(value: 0), waitingFinished = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.cancel.waiting.preparation") { controller, start in
        entered.signal()
        _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); release.signal() }
    func request(_ id: String) -> PlaybackContinuationStart {
        .init(track: .init(id: id, path: "/missing.wav"), payload: .init(path: "/missing.wav"),
              requestID: transport.reservePlaybackRequest())
    }
    let firstRequest = request("first")
    let first = Task.detached { try transport.start(firstRequest) }
    #expect(waitForSignal(entered, seconds: 5))
    let secondRequest = request("second")
    let second = Task.detached { try transport.start(secondRequest) }
    #expect(waitForSignal(entered, seconds: 5))
    #expect(transport.queuedSkipLifecycle.begin("waiting-token"))
    let waitingRequest = PlaybackContinuationStart(track: .init(id: "waiting", path: "/missing.wav"),
        payload: .init(path: "/missing.wav"), requestID: transport.reservePlaybackRequest(),
        queuedSkipToken: "waiting-token")
    let waiting = Task.detached {
        waitingStarted.signal()
        defer { waitingFinished.signal() }
        try transport.start(waitingRequest)
    }
    #expect(waitForSignal(waitingStarted, seconds: 5))
    #expect(!waitForSignal(entered, seconds: 1))
    if cancelByToken {
        #expect(transport.queuedSkipLifecycle.cancel("waiting-token"))
    } else {
        transport.invalidatePlaybackRequests()
    }
    let canceledBeforeRelease = waitForSignal(waitingFinished, seconds: 5)
    release.signal(); release.signal()
    do { try await waiting.value; Issue.record("Superseded waiter unexpectedly started") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    _ = try? await first.value
    _ = try? await second.value
    #expect(canceledBeforeRelease)
}

@Test func preparedSourceCanOnlyBeCommittedOnce() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let prepared = try controller.prepareSource(payload: .init(path: url.path))
    let accepted = controller.loadPreparedIfCurrent(prepared) { true }
    #expect(accepted.kind != .error)
    let generation = try #require(accepted.status?.diagnostics.generation)
    let repeated = controller.loadPreparedIfCurrent(prepared) { true }
    #expect(repeated.kind == .error)
    #expect(controller.status().diagnostics.generation == generation)
}

@Test func lowLevelStopCancelsReconfigurationWaitingForPreparationSlot() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 5).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let started = DispatchSemaphore(value: 0), finished = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.stop.waiting.settings") { controller, start in
        entered.signal()
        _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    func request(_ id: String) -> PlaybackContinuationStart {
        .init(track: .init(id: id, path: url.path), payload: .init(path: url.path),
              requestID: transport.reservePlaybackRequest())
    }
    let firstRequest = request("first")
    let first = Task.detached { try transport.start(firstRequest) }
    #expect(waitForSignal(entered, seconds: 5))
    let secondRequest = request("second")
    let second = Task.detached { try transport.start(secondRequest) }
    #expect(waitForSignal(entered, seconds: 5))
    let pending = Task.detached {
        started.signal()
        defer { finished.signal() }
        return try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 3_000))
    }
    #expect(waitForSignal(started, seconds: 5))
    #expect(!waitForSignal(finished, seconds: 1))
    #expect(transport.perform(.init(command: .stop)).kind != .error)
    let canceledBeforeRelease = waitForSignal(finished, seconds: 3)
    transport.invalidatePlaybackRequests()
    release.signal(); release.signal()
    do { _ = try await pending.value; Issue.record("Stopped reconfiguration unexpectedly succeeded") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    _ = try? await first.value
    _ = try? await second.value
    #expect(canceledBeforeRelease)
}

@Test(arguments: [false, true])
func explicitStopCancelsStartBeingPrepared(asyncStop: Bool) async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 5).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.stop.pending.start") { controller, start in
        entered.signal()
        _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let request = PlaybackContinuationStart(track: .init(id: "pending", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest())
    let pending = Task.detached { try transport.start(request) }
    #expect(waitForSignal(entered, seconds: 5))
    if asyncStop {
        await transport.stop()
    } else {
        let stopped = transport.perform(.init(requestID: "stop", command: .stop))
        #expect(stopped.kind == .response && stopped.requestID == "stop")
    }
    release.signal()
    do { try await pending.value; Issue.record("Stopped pending start unexpectedly played") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(!transport.statusSync().trackLoaded)
}

@Test func invalidVersionStopDoesNotCancelPendingStart() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 5).write(to: url)
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.invalid.stop.pending.start") { controller, start in
        entered.signal()
        _ = release.wait(timeout: .now() + 20)
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { release.signal(); _ = transport.perform(.init(command: .stop)) }
    let request = PlaybackContinuationStart(track: .init(id: "pending", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest())
    let pending = Task.detached { try transport.start(request) }
    #expect(waitForSignal(entered, seconds: 5))
    var stop = PlaybackControlRequest(requestID: "invalid-stop", command: .stop)
    stop.version = PlaybackControlProtocol.version + 1
    let event = transport.perform(stop)
    #expect(event.kind == .error && event.requestID == "invalid-stop")
    release.signal()
    try await pending.value
    #expect(transport.statusSync().currentTrackID == "pending")
}

@Test(arguments: [false, true])
func newerPlaybackRequestSupersedesQueuedExplicitStop(asyncStop: Bool) async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 5).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.queued.stop.newer.start")
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    transport.setStatusHandler { _ in gate.waitIfFirst() }
    let oldRequest = transport.reservePlaybackRequest()
    let triggering = Task.detached { transport.perform(.init(command: .pause)) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let stopping = Task.detached { () -> PlaybackControlEvent? in
        if asyncStop { await transport.stop(); return nil }
        return transport.perform(.init(requestID: "queued-stop", command: .stop))
    }
    for _ in 0..<500 where transport.isCurrentPlaybackRequest(oldRequest) {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    #expect(!transport.isCurrentPlaybackRequest(oldRequest))
    let newRequest = transport.reservePlaybackRequest()
    gate.release.signal()
    _ = await triggering.value
    let result = await stopping.value
    if !asyncStop { #expect(result?.kind == .error && result?.requestID == "queued-stop") }
    #expect(transport.statusSync().currentTrackID == url.path)
    let start = PlaybackContinuationStart(track: .init(id: "newer", path: url.path),
        payload: .init(path: url.path), requestID: newRequest)
    try transport.start(start)
    #expect(transport.statusSync().currentTrackID == "newer")
}

@Test func supersededPreparationFailureReportsCancellation() async throws {
    let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
    let transport = PlaybackTransportCoordinator(label: "test.superseded.preparation.failure") { _, _ in
        entered.signal()
        _ = release.wait(timeout: .now() + 10)
        throw PlaybackControlError.invalidPayload("preparation failed")
    }
    defer { release.signal() }
    let start = PlaybackContinuationStart(track: .init(id: "old", path: "/missing.wav"),
        payload: .init(path: "/missing.wav"), requestID: transport.reservePlaybackRequest())
    let pending = Task.detached { try transport.start(start) }
    #expect(waitForSignal(entered, seconds: 3))
    transport.invalidatePlaybackRequests()
    release.signal()
    do { try await pending.value; Issue.record("Superseded preparation unexpectedly succeeded") }
    catch is CancellationError {} catch { Issue.record("Expected cancellation, got: \(error)") }
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
    let generation = transport.statusSync().generation
    try FileManager.default.removeItem(at: url)
    #expect(throws: (any Error).self) {
        _ = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 1_000))
    }
    #expect(transport.statusSync().trackLoaded)
    #expect(transport.statusSync().generation == generation)
    // A readable invalid source gets past preparation but fails when the
    // decoder is reopened, after the original session has been retired.
    try Data("not a WAV".utf8).write(to: url)
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

    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let sourceLoad = controller.perform(.init(command: .load, payload: .init(
        path: archive.path, archiveEntry: fixture.lastPathComponent
    )))
    #expect(sourceLoad.kind != .error)
    let snapshot = try controller.reconfigurationSource(for: .init(tempo: 2, playbackMode: .fileDefault))
    #expect(snapshot.payload.path == archive.path)
    #expect(snapshot.payload.archiveEntry == fixture.lastPathComponent)
    #expect(snapshot.payload.tempo == 2)
    #expect(snapshot.sourceData == nil)
    _ = controller.perform(.init(command: .stop))

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

@Test func generatedTXTPArchiveRetainsSiblingAcrossReconfigurationFailure() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let wav = directory.appendingPathComponent("tone.wav")
    let txtp = directory.appendingPathComponent("track.txtp")
    let archive = directory.appendingPathComponent("dependencies.zip")
    try silentWAV(seconds: 5).write(to: wav)
    try "tone.wav\n".write(to: txtp, atomically: true, encoding: .utf8)
    let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.currentDirectoryURL = directory
    zip.arguments = ["-q", archive.path, wav.lastPathComponent, txtp.lastPathComponent]
    try zip.run(); zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)
    try FileManager.default.removeItem(at: wav)
    try FileManager.default.removeItem(at: txtp)
    let transport = PlaybackTransportCoordinator(label: "test.generated.txtp.archive")
    defer { _ = transport.perform(.init(command: .stop)) }
    let loaded = transport.perform(.init(command: .load,
        payload: .init(path: archive.path, archiveEntry: txtp.lastPathComponent)))
    #expect(loaded.kind != .error, Comment(rawValue: loaded.message ?? ""))
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let configured = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 5_000))
    try FileManager.default.removeItem(at: archive)
    #expect(throws: (any Error).self) {
        try transport.reconfigureSync(.init(longPlayEnabled: false))
    }
    let after = transport.statusSync()
    #expect(after.generation == configured.generation && after.isPlaying && after.trackLoaded)
    let sought = transport.perform(.init(command: .seek, payload: .init(positionMilliseconds: 2_000)))
    #expect(sought.kind != .error, Comment(rawValue: sought.message ?? ""))
    #expect(sought.status?.isPlaying == true)
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

@Test func lowLevelModeBeforeLoadRetainsTimingAndRequestIdentity() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.mode.before.load")
    defer { _ = transport.perform(.init(command: .stop)) }
    let payload = PlaybackControlPayload(playbackMode: .longPlay, playMilliseconds: 2_000, fadeMilliseconds: 0)
    let beforeLoad = transport.perform(.init(requestID: "mode-before-load", command: .setPlaybackMode, payload: payload))
    #expect(beforeLoad.kind == .response && beforeLoad.requestID == "mode-before-load")
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    let repeated = transport.perform(.init(requestID: "same-mode", command: .setPlaybackMode, payload: payload))
    #expect(repeated.kind == .response && repeated.requestID == "same-mode")
    #expect(repeated.status?.diagnostics.generation == generation)
    let changed = transport.perform(.init(requestID: "changed-mode", command: .setPlaybackMode,
        payload: .init(playbackMode: .longPlay, playMilliseconds: 1_000, fadeMilliseconds: 0)))
    #expect(changed.kind == .response && changed.requestID == "changed-mode")
    #expect(changed.status?.diagnostics.generation != generation)
}

@Test(arguments: [false, true])
func lowLevelSettingsPreparationKeepsControlsResponsive(tempoOnly: Bool) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.settings.offqueue") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let request: PlaybackControlRequest = tempoOnly
        ? .init(requestID: "tempo", command: .setTempo, payload: .init(tempo: 2))
        : .init(requestID: "mode", command: .setPlaybackMode,
                payload: .init(playbackMode: .longPlay, playMilliseconds: 20_000, fadeMilliseconds: 0))
    let changing = Task.detached { transport.perform(request) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let control = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(completed, seconds: 6)
    gate.release.signal()
    _ = try await control.value
    let result = await changing.value
    #expect(responsive)
    #expect(result.kind == .response && result.requestID == request.requestID)
    #expect(result.status?.diagnostics.generation != generation)
    #expect(result.status?.isPlaying == false)
    #expect(abs((result.status?.elapsedSeconds ?? -1) - (tempoOnly ? 0.5 : 1)) < 0.1)
}

@Test func lowLevelModePreparationFailureRetainsActiveArchiveSession() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let wav = directory.appendingPathComponent("source.wav")
    let archive = directory.appendingPathComponent("source.zip")
    try silentWAV(seconds: 5).write(to: wav)
    let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-j", archive.path, wav.path]
    try zip.run(); zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.settings.archive.failure")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load,
        payload: .init(path: archive.path, archiveEntry: wav.lastPathComponent))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let before = transport.statusSync()
    try FileManager.default.removeItem(at: archive)
    let error = transport.perform(.init(requestID: "missing-archive", command: .setPlaybackMode,
        payload: .init(playbackMode: .longPlay, playMilliseconds: 3_000, fadeMilliseconds: 0)))
    #expect(error.kind == .error && error.requestID == "missing-archive")
    let after = transport.statusSync()
    #expect(after.generation == before.generation && after.currentTrackID == before.currentTrackID)
    #expect(after.isPlaying)
}

@Test func failedOverlappingLowLevelModeLeavesOlderPreparationEligible() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let wav = directory.appendingPathComponent("source.wav")
    let archive = directory.appendingPathComponent("source.zip")
    let heldArchive = directory.appendingPathComponent("held.zip")
    try silentWAV(seconds: 5).write(to: wav)
    let zip = Process(); zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.arguments = ["-q", "-j", archive.path, wav.path]
    try zip.run(); zip.waitUntilExit()
    #expect(zip.terminationStatus == 0)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.failure") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load,
        payload: .init(path: archive.path, archiveEntry: wav.lastPathComponent))).kind != .error)
    let generation = transport.statusSync().generation
    let old = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 3_000))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    try FileManager.default.moveItem(at: archive, to: heldArchive)
    let rejected = transport.perform(.init(requestID: "missing-overlap", command: .setPlaybackMode,
        payload: .init(playbackMode: .longPlay, playMilliseconds: 2_000, fadeMilliseconds: 0)))
    #expect(rejected.kind == .error && rejected.requestID == "missing-overlap")
    try FileManager.default.moveItem(at: heldArchive, to: archive)
    gate.release.signal()
    let accepted = try await old.value
    #expect(accepted.generation != generation && accepted.currentTrackID == archive.path)
}

@Test(arguments: [false, true])
func overlappingLowLevelPreparationKeepsControlsResponsiveAndOrdersCommit(failNewer: Bool) async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.two.phase") { controller, start in
        let number = gate.wait()
        if number == 2 && failNewer { throw CocoaError(.fileReadNoSuchFile) }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let olderFinished = DispatchSemaphore(value: 0)
    let older = Task.detached {
        defer { olderFinished.signal() }
        return try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000))
    }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let newer = Task.detached {
        transport.perform(.init(requestID: "new-mode", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let controlsFinished = DispatchSemaphore(value: 0)
    let controls = Task.detached {
        defer { controlsFinished.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(controlsFinished, seconds: 5)
    gate.firstRelease.signal()
    let committedTooEarly = waitForSignal(olderFinished, seconds: 1)
    gate.secondRelease.signal()
    _ = try await controls.value
    let newerResult = await newer.value
    #expect(responsive && !committedTooEarly)
    #expect(newerResult.requestID == "new-mode")
    if failNewer {
        #expect(newerResult.kind == .error)
        let accepted = try await older.value
        #expect(!accepted.isPlaying && abs(accepted.elapsedSeconds - 1) < 0.1)
        #expect(accepted.generation != generation)
    } else {
        #expect(newerResult.kind == .response)
        do { _ = try await older.value; Issue.record("Superseded older settings unexpectedly committed") }
        catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
        let accepted = transport.statusSync()
        #expect(!accepted.isPlaying && abs(accepted.elapsedSeconds - 1) < 0.1)
        #expect(accepted.generation != generation)
    }
}

@Test func stopCancelsOverlappingLowLevelPreparationsAndWaiter() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.stop") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let newer = Task.detached {
        transport.perform(.init(requestID: "candidate", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let waiterStarted = DispatchSemaphore(value: 0), waiterFinished = DispatchSemaphore(value: 0)
    let waiter = Task.detached {
        waiterStarted.signal(); defer { waiterFinished.signal() }
        return transport.perform(.init(requestID: "waiter", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 4_000)))
    }
    #expect(waitForSignal(waiterStarted, seconds: 5))
    #expect(!waitForSignal(waiterFinished, seconds: 1))
    #expect(transport.perform(.init(command: .stop)).kind == .response)
    let waiterCanceled = waitForSignal(waiterFinished, seconds: 5)
    gate.firstRelease.signal(); gate.secondRelease.signal()
    let pendingEvent = await newer.value
    let waiterEvent = await waiter.value
    #expect(waiterCanceled && pendingEvent.kind == .error && waiterEvent.kind == .error)
    do { _ = try await older.value; Issue.record("Stopped older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(!transport.statusSync().trackLoaded)
}

@Test func retirementRejectsWaitingLowLevelSettingsWithoutNewRequestID() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.retirement") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let requestID = transport.reservePlaybackRequest()
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let candidate = Task.detached {
        transport.perform(.init(requestID: "candidate", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let waiterStarted = DispatchSemaphore(value: 0), waiterFinished = DispatchSemaphore(value: 0)
    let waiter = Task.detached {
        waiterStarted.signal(); defer { waiterFinished.signal() }
        return transport.perform(.init(requestID: "waiter", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 4_000)))
    }
    #expect(waitForSignal(waiterStarted, seconds: 5))
    #expect(!waitForSignal(waiterFinished, seconds: 1))
    #expect(transport.stopForPlaybackRequestSync(requestID))
    #expect(waitForSignal(waiterFinished, seconds: 5))
    gate.firstRelease.signal(); gate.secondRelease.signal()
    #expect((await waiter.value).kind == .error)
    #expect((await candidate.value).kind == .error)
    do { _ = try await older.value; Issue.record("Retired older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(!transport.statusSync().trackLoaded)
}

@Test func overlappingLowLevelTempoPreservesItsActiveTimingContract() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.tempo.overlap") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let candidate = Task.detached {
        transport.perform(.init(requestID: "tempo", command: .setTempo, payload: .init(tempo: 2)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    gate.secondRelease.signal()
    let result = await candidate.value
    #expect(result.kind == .response && result.requestID == "tempo" && result.status?.statistics.tempo == 2)
    gate.firstRelease.signal()
    do { _ = try await older.value; Issue.record("Older timing unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    let generation = transport.statusSync().generation
    let same = transport.perform(.init(command: .setPlaybackMode, payload: .init(playbackMode: .fileDefault)))
    #expect(same.kind == .response && same.status?.diagnostics.generation == generation)
}

@Test func failedCandidateCommitRetiresSessionAndDoesNotReviveOlderSettings() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.commit.failure") { controller, start in
        let number = gate.wait()
        let prepared = try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
        if number == 2 { try FileManager.default.removeItem(at: url) }
        return prepared
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let newer = Task.detached {
        transport.perform(.init(requestID: "candidate", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    gate.secondRelease.signal()
    let result = await newer.value
    #expect(result.kind == .error && result.requestID == "candidate")
    gate.firstRelease.signal()
    do { _ = try await older.value; Issue.record("Older settings unexpectedly revived after failed commit") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(!transport.statusSync().trackLoaded)
}

@Test func newerTypedSettingsSupersedeBothOverlappingPreparations() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.newer.settings") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let candidate = Task.detached {
        transport.perform(.init(requestID: "candidate", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let latest = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 4_000,
            expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision()))
    }
    gate.firstRelease.signal()
    #expect(waitForSignal(gate.thirdEntered, seconds: 5))
    gate.secondRelease.signal()
    let accepted = try await latest.value
    let candidateEvent = await candidate.value
    #expect(candidateEvent.kind == .error && candidateEvent.requestID == "candidate")
    do { _ = try await older.value; Issue.record("Older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(transport.statusSync().generation == accepted.generation)
}

@Test func replacementStartSupersedesBothOverlappingPreparations() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.replacement") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let candidate = Task.detached {
        transport.perform(.init(requestID: "candidate", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let replacement = PlaybackContinuationStart(track: .init(id: "replacement", path: url.path),
        payload: .init(path: url.path), requestID: transport.reservePlaybackRequest())
    let start = Task.detached { try transport.start(replacement) }
    gate.firstRelease.signal()
    #expect(waitForSignal(gate.thirdEntered, seconds: 5))
    gate.secondRelease.signal()
    try await start.value
    let event = await candidate.value
    #expect(event.kind == .error && event.requestID == "candidate")
    do { _ = try await older.value; Issue.record("Older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(transport.statusSync().currentTrackID == "replacement")
}

@Test func consecutiveLowLevelCandidatesCommitInOrder() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 10).write(to: url)
    let gate = TwoPreparationGates()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.overlap.consecutive") { controller, start in
        _ = gate.wait()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.firstRelease.signal(); gate.secondRelease.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let older = Task.detached { try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 8_000)) }
    #expect(waitForSignal(gate.firstEntered, seconds: 5))
    let second = Task.detached {
        transport.perform(.init(requestID: "second", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 6_000)))
    }
    #expect(waitForSignal(gate.secondEntered, seconds: 5))
    let thirdStarted = DispatchSemaphore(value: 0), thirdFinished = DispatchSemaphore(value: 0)
    let third = Task.detached {
        thirdStarted.signal(); defer { thirdFinished.signal() }
        return transport.perform(.init(requestID: "third", command: .setPlaybackMode,
            payload: .init(playbackMode: .longPlay, playMilliseconds: 4_000)))
    }
    #expect(waitForSignal(thirdStarted, seconds: 5))
    #expect(!waitForSignal(thirdFinished, seconds: 1))
    gate.secondRelease.signal()
    #expect((await second.value).kind == .response)
    #expect(waitForSignal(gate.thirdEntered, seconds: 5))
    gate.firstRelease.signal()
    let result = await third.value
    #expect(result.kind == .response && result.requestID == "third")
    do { _ = try await older.value; Issue.record("Older settings unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    let finalGeneration = transport.statusSync().generation
    let same = transport.perform(.init(command: .setPlaybackMode,
        payload: .init(playbackMode: .longPlay, playMilliseconds: 4_000)))
    #expect(same.status?.diagnostics.generation == finalGeneration)
}

@Test func lowLevelTempoPreparationIsSupersededByStop() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.tempo.stop") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    let changing = Task.detached {
        transport.perform(.init(requestID: "stale-tempo", command: .setTempo, payload: .init(tempo: 2)))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    #expect(transport.perform(.init(command: .stop)).kind == .response)
    gate.release.signal()
    let result = await changing.value
    #expect(result.kind == .error && result.requestID == "stale-tempo")
    #expect(!transport.statusSync().trackLoaded)
}

@Test func lowLevelSettingsRejectUnsupportedVersionWithoutChangingSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.settings.version")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    for command in [PlaybackControlCommand.setTempo, .setPlaybackMode] {
        var request = PlaybackControlRequest(requestID: "invalid-version", command: command,
            payload: .init(tempo: 2, playbackMode: .longPlay, playMilliseconds: 1_000))
        request.version = PlaybackControlProtocol.version + 1
        let response = transport.perform(request)
        #expect(response.kind == .error && response.requestID == "invalid-version")
        #expect(response.status?.diagnostics.generation == generation)
        #expect(response.message?.contains("Unsupported control API version") == true)
    }
    let invalidTempo = transport.perform(.init(requestID: "invalid-tempo", command: .setPlaybackMode,
        payload: .init(tempo: .infinity, playbackMode: .fileDefault)))
    #expect(invalidTempo.kind == .error && invalidTempo.requestID == "invalid-tempo")
    #expect(transport.statusSync().generation == generation)
}

@Test func lowLevelSettingsValidationFailurePublishesCurrentStatus() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.settings.error.status")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let recorder = StatusRecorder()
    transport.setStatusHandler { recorder.record($0) }
    let before = transport.statusSync()
    recorder.clear()
    let event = transport.perform(.init(requestID: "bad-tempo", command: .setTempo, payload: .init(tempo: -1)))
    #expect(event.kind == .error && event.requestID == "bad-tempo")
    _ = transport.statusSync()
    #expect(recorder.snapshot().contains { $0.generation == before.generation && $0.trackLoaded })
}

@Test func lowLevelPreparationFailurePublishesCurrentStatus() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.lowlevel.preparation.error.status") { _, _ in
        throw CocoaError(.fileReadNoSuchFile)
    }
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let recorder = StatusRecorder()
    transport.setStatusHandler { recorder.record($0) }
    let before = transport.statusSync()
    recorder.clear()
    let event = transport.perform(.init(requestID: "bad-source", command: .setPlaybackMode,
        payload: .init(playbackMode: .longPlay, playMilliseconds: 2_000)))
    #expect(event.kind == .error && event.requestID == "bad-source")
    _ = transport.statusSync()
    #expect(recorder.snapshot().contains { $0.generation == before.generation && $0.trackLoaded })
}

@Test func typedTempoPreparationPreservesTimingAndKeepsControlsResponsive() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.typed.tempo.offqueue") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .setPlaybackMode, payload: .init(
        playbackMode: .longPlay, playMilliseconds: 20_000, fadeMilliseconds: 0,
        unknownDurationMilliseconds: 150_000))).kind != .error)
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let changing = Task.detached {
        try transport.setTempoSync(.init(tempo: .init(numerator: 2, denominator: 1)))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let control = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(completed, seconds: 6)
    gate.release.signal()
    _ = try await control.value
    let result = try await changing.value
    #expect(responsive)
    #expect(!result.isPlaying && abs(result.elapsedSeconds - 0.5) < 0.1)
    #expect(result.tempo == 2 && result.generation != generation)
    let sameSettings = try transport.reconfigureSync(.init(longPlayEnabled: true,
        manualPlayMilliseconds: 20_000, fadeMilliseconds: 0,
        tempo: .init(numerator: 2, denominator: 1)))
    #expect(sameSettings.generation == result.generation)
}

@Test func typedTempoNoOpPreservesBufferedUnsupportedPlayback() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.typed.tempo.unsupported")
    defer { _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let before = transport.statusSync()
    let after = try transport.setTempoSync(.init(tempo: .init(numerator: 2, denominator: 1)))
    #expect(after.generation == before.generation && after.tempo == 1)
}

@Test func tempoUpdateCarriesPendingTimingAcrossSupersession() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    for asyncTempo in [false, true] {
        let gate = FirstPreparationGate()
        let transport = PlaybackTransportCoordinator(label: "test.tempo.pending.timing") { controller, start in
            gate.waitIfFirst()
            return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
        }
        defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
        #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
        let generation = transport.statusSync().generation
        let old = Task.detached {
            try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
                fadeMilliseconds: 0, expectedGeneration: generation,
                settingsRevision: transport.reserveSettingsRevision()))
        }
        #expect(waitForSignal(gate.entered, seconds: 5))
        if asyncTempo {
            try await transport.setTempo(.init(numerator: 2, denominator: 1))
        } else {
            _ = try transport.setTempoSync(.init(tempo: .init(numerator: 2, denominator: 1)))
        }
        gate.release.signal()
        do { _ = try await old.value; Issue.record("Older request unexpectedly committed") }
        catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
        let merged = transport.statusSync()
        #expect(merged.tempo == 2 && merged.generation != generation)
        let same = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
            fadeMilliseconds: 0, tempo: .init(numerator: 2, denominator: 1)))
        #expect(same.generation == merged.generation)
    }
}

@Test func failedMergedTempoDoesNotReviveOlderTiming() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.tempo.pending.failure") { controller, start in
        gate.waitIfFirst()
        if start.payload.tempo == 2 { throw CocoaError(.fileReadNoSuchFile) }
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    let generation = transport.statusSync().generation
    let old = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000, fadeMilliseconds: 0))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    do {
        _ = try transport.setTempoSync(.init(tempo: .init(numerator: 2, denominator: 1)))
        Issue.record("Injected preparation failure unexpectedly succeeded")
    } catch {}
    let unchanged = try transport.setTempoSync(.init(tempo: .defaultValue))
    #expect(unchanged.generation == generation && unchanged.tempo == 1)
    gate.release.signal()
    do { _ = try await old.value; Issue.record("Superseded request unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(transport.statusSync().generation == generation)
}

@Test func tempoDoesNotInheritTimingFromSupersededPlaybackRequest() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.tempo.pending.request") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    let old = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000, fadeMilliseconds: 0))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    _ = transport.reservePlaybackRequest()
    let tempo = try transport.setTempoSync(.init(tempo: .init(numerator: 2, denominator: 1)))
    gate.release.signal()
    do { _ = try await old.value; Issue.record("Superseded request unexpectedly committed") }
    catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    let timing = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000,
        fadeMilliseconds: 0, tempo: .init(numerator: 2, denominator: 1)))
    #expect(timing.generation != tempo.generation)
}

@Test func asyncTempoPreparationKeepsControlsResponsive() async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let source = root.appendingPathComponent("VGMBoy/vendor/zxtune/samples/chiptunes/SPC700/spc/f-zero - big blue.spc")
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.async.tempo.offqueue") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: source.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let changing = Task.detached { try await transport.setTempo(.init(numerator: 2, denominator: 1)) }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let control = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(completed, seconds: 6)
    gate.release.signal()
    _ = try await control.value
    try await changing.value
    let after = transport.statusSync()
    #expect(responsive)
    #expect(!after.isPlaying && abs(after.elapsedSeconds - 0.5) < 0.1)
    #expect(after.tempo == 2 && after.generation != generation)
}

@Test func asyncTempoIgnoresMissingAndUnsupportedTracks() async throws {
    let transport = PlaybackTransportCoordinator(label: "test.async.tempo.unsupported")
    defer { _ = transport.perform(.init(command: .stop)) }
    try await transport.setTempo(.init(numerator: 2, denominator: 1))
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 3).write(to: url)
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let before = transport.statusSync()
    try await transport.setTempo(.init(numerator: 2, denominator: 1))
    let after = transport.statusSync()
    #expect(after.generation == before.generation && after.tempo == 1)
}

@Test func ignoredAsyncTempoDoesNotCancelPendingSettings() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.async.tempo.ignored.pending") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    let pending = Task.detached {
        try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 20_000))
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    try await transport.setTempo(.init(numerator: 2, denominator: 1))
    gate.release.signal()
    let after = try await pending.value
    #expect(after.generation != generation)
}

@Test func nativePlanPreparationKeepsControlsResponsiveAndUsesLatestPosition() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.native.plan.offqueue") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let generation = transport.statusSync().generation
    let changing = Task.detached {
        try await transport.reconfigureCurrentTrack(
            plan: .init(preFadeSeconds: 20, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true),
            tempo: .defaultValue)
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let completed = DispatchSemaphore(value: 0)
    let control = Task.detached {
        defer { completed.signal() }
        _ = try transport.performSessionControlSync(.pause, expectedGeneration: generation)
        return try transport.performSessionControlSync(.seek, payload: .init(positionMilliseconds: 1_000),
                                                       expectedGeneration: generation)
    }
    let responsive = waitForSignal(completed, seconds: 6)
    gate.release.signal()
    _ = try await control.value
    try await changing.value
    let result = transport.statusSync()
    #expect(responsive)
    #expect(!result.isPlaying && abs(result.elapsedSeconds - 1) < 0.1)
    #expect(result.generation != generation)
}

@Test func nativePlanPreparationIsSupersededByBridgeSettings() async throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 30).write(to: url)
    let gate = FirstPreparationGate()
    let transport = PlaybackTransportCoordinator(label: "test.native.plan.superseded") { controller, start in
        gate.waitIfFirst()
        return try controller.prepareSource(payload: start.payload, sourceData: start.track.sourceData)
    }
    defer { gate.release.signal(); _ = transport.perform(.init(command: .stop)) }
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    let generation = transport.statusSync().generation
    let old = Task.detached {
        try await transport.reconfigureCurrentTrack(
            plan: .init(preFadeSeconds: 20, fadeSeconds: 0, usesNativeEnding: false, isLongPlay: true),
            tempo: .defaultValue)
    }
    #expect(waitForSignal(gate.entered, seconds: 5))
    let newer = try transport.reconfigureSync(.init(longPlayEnabled: true, manualPlayMilliseconds: 10_000,
        expectedGeneration: generation, settingsRevision: transport.reserveSettingsRevision()))
    gate.release.signal()
    do {
        try await old.value
        Issue.record("Superseded native reconfiguration unexpectedly succeeded")
    } catch is CancellationError {} catch { Issue.record("Unexpected error: \(error)") }
    #expect(transport.statusSync().generation == newer.generation)
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
func sotnReconfigurationSourcePreservesAuthoredLoop() throws {
    let path = try #require(ProcessInfo.processInfo.environment["VGMBOY_SOTN_XA_UAC"])
    let entry = "audio/SD-XA_STR1/file00-channel00.xa"
    let controller = PlaybackController()
    defer { _ = controller.perform(.init(command: .stop)) }
    let event = controller.perform(.init(command: .load, payload: .init(path: path, archiveEntry: entry)))
    #expect(event.kind != .error, Comment(rawValue: event.message ?? ""))
    let snapshot = try controller.reconfigurationSource(for: .init(playbackMode: .fileDefault))
    #expect(snapshot.payload.path == path)
    #expect(snapshot.payload.archiveEntry == entry)
    let loop = try #require(snapshot.payload.loop)
    #expect(loop.startSample == 2_153_088)
    #expect(loop.endSample == 5_310_144)
    #expect(loop.sampleRateHz == 37_800)
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

@Test func unrepresentableLoopReplacementPreservesPlayingSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.invalid.loop.replacement")
    defer { _ = transport.perform(.init(command: .stop)) }
    _ = try transport.configureAudio(.init(outputVolume: 0, equalizerEnabled: false,
        equalizerBandGains: Array(repeating: 0, count: 10), monoEnabled: false))
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let before = transport.statusSync()
    let loop = PlaybackLoopMetadata(startSample: 1, endSample: Int64.max, sampleRateHz: 44_100)
    let start = PlaybackContinuationStart(
        track: .init(id: "bad-loop", path: url.path, loop: loop),
        payload: .init(path: url.path, loop: loop), requestID: transport.reservePlaybackRequest()
    )
    #expect(throws: (any Error).self) { try transport.start(start) }
    let after = transport.statusSync()
    #expect(after.trackLoaded && after.isPlaying)
    #expect(after.currentTrackID == before.currentTrackID)
    #expect(after.generation == before.generation)
}

@Test func unsupportedInMemoryReplacementPreservesPlayingSession() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
    defer { try? FileManager.default.removeItem(at: url) }
    try silentWAV(seconds: 2).write(to: url)
    let transport = PlaybackTransportCoordinator(label: "test.unsupported.memory.replacement")
    defer { _ = transport.perform(.init(command: .stop)) }
    _ = try transport.configureAudio(.init(outputVolume: 0, equalizerEnabled: false,
        equalizerBandGains: Array(repeating: 0, count: 10), monoEnabled: false))
    #expect(transport.perform(.init(command: .load, payload: .init(path: url.path))).kind != .error)
    #expect(transport.perform(.init(command: .play)).kind != .error)
    let before = transport.statusSync()
    let start = PlaybackContinuationStart(
        track: .init(id: "unsupported-memory", path: "/virtual.wav", sourceData: Data([0])),
        payload: .init(path: "/virtual.wav"), requestID: transport.reservePlaybackRequest()
    )
    #expect(throws: (any Error).self) { try transport.start(start) }
    let after = transport.statusSync()
    #expect(after.trackLoaded && after.isPlaying)
    #expect(after.currentTrackID == before.currentTrackID)
    #expect(after.generation == before.generation)
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

    // Missing standalone files also fail before the old decoder is released.
    let missingWAV = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".wav")
    let missingError = transport.perform(.init(command: .load, payload: .init(path: missingWAV.path)))
    #expect(missingError.kind == .error)
    #expect(transport.statusSync().currentTrackID == url.path)
    #expect(transport.statusSync().generation == firstGeneration)
    let missingStart = PlaybackContinuationStart(
        track: PlaybackTransportTrack(id: "missing", path: missingWAV.path),
        payload: .init(path: missingWAV.path), requestID: transport.reservePlaybackRequest()
    )
    #expect(throws: (any Error).self) { try transport.start(missingStart) }
    #expect(transport.statusSync().currentTrackID == url.path)
    #expect(transport.statusSync().generation == firstGeneration)

    // A readable but invalid WAV reaches session.load and retires the old
    // decoder before the replacement fails to open.
    let invalidWAV = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".wav")
    try Data("not a WAV".utf8).write(to: invalidWAV)
    defer { try? FileManager.default.removeItem(at: invalidWAV) }
    let openError = transport.perform(.init(command: .load, payload: .init(path: invalidWAV.path)))
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
        track: PlaybackTransportTrack(id: "invalid", path: invalidWAV.path),
        payload: .init(path: invalidWAV.path),
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
