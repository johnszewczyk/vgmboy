import Darwin
import Foundation
import SQLite3
import Testing
import zlib
@testable import ScanSongKit

@Test func dryRunReportsTypedRoutesWithoutWritingADataStore() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-probe-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("SNES-SPC700 Sound File Data".utf8).write(to: root.appendingPathComponent("Track.spc"))
    try Data("notes".utf8).write(to: root.appendingPathComponent("notes.txt"))

    let result = try DryRunProbe().run(paths: [root.path], recursive: true, strict: true)
    #expect(result.hasErrors)
    #expect(result.events.contains { $0.route?.pluginID == "gme" })
    #expect(result.events.contains { $0.diagnostic?.code == "source.unrecognized" })
    #expect(result.events.last?.discovered == 2)

    try Data("SGC".utf8).write(to: root.appendingPathComponent("ignored.sgc"))
    let ignored = try DryRunProbe().run(paths: [root.appendingPathComponent("ignored.sgc").path], recursive: false, strict: true)
    #expect(!ignored.hasErrors)
    #expect(ignored.events.contains { $0.diagnostic?.code == "source.ignored" })
}
@Test func dryRunStopsBeforeWorkWhenCancellationIsRequested() throws {
    #expect(throws: CancellationError.self) {
        try DryRunProbe().run(
            paths: [FileManager.default.temporaryDirectory.path],
            recursive: true,
            strict: false,
            isCancelled: { true }
        )
    }
}

@Test func everyEventCarriesTheProcessContractVersion() throws {
    let event = ScannerEvent(kind: .sessionStarted, sequence: 0)
    let data = try JSONEncoder().encode(event)
    let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(json["contract"] as? String == ScanSongContract.name)
    #expect(json["version"] as? Int == ScanSongContract.version)
}

@Test func inspectorProcessRunnerRejectsExcessiveOutput() async throws {
    await #expect(throws: ScannerInspectionError.self) {
        _ = try await InspectorProcessRunner.run(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["123456789"],
            standardOutputLimit: 4
        )
    }
}

@Test func inspectorProcessRunnerTerminatesTimedOutTools() async throws {
    let clock = ContinuousClock()
    let started = clock.now
    await #expect(throws: ScannerInspectionError.self) {
        _ = try await InspectorProcessRunner.run(
            executable: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["5"],
            timeout: .milliseconds(20)
        )
    }
    #expect(started.duration(to: clock.now) < .seconds(2))
}

@Test func scanLogFormatsDiagnosticsWithoutExpandingArchiveInventories() {
    let fingerprint = ScanFingerprint(fileSize: 1, modifiedAt: .distantPast)
    let archivePath = "/library/NeuroDancer.zip"
    let archiveFailure = ScanFailure(
        identity: ScanItemIdentity(rootID: 1, path: archivePath, archiveEntry: "music/bad.spc"),
        fingerprint: fingerprint,
        route: nil,
        stage: .metadata,
        message: "decoder failed"
    )
    let skippedArchiveMembers = [
        ScanSkippedFile(
            identity: ScanItemIdentity(rootID: 1, path: archivePath, archiveEntry: "music/one.sgc"),
            extensionName: "sgc",
            reason: .explicitlyIgnored
        ),
        ScanSkippedFile(
            identity: ScanItemIdentity(rootID: 1, path: archivePath, archiveEntry: "music/two.sgc"),
            extensionName: "sgc",
            reason: .explicitlyIgnored
        )
    ]
    let lines = ScanLogFormatter.lines(
        status: "complete",
        summary: "4 discovered, 2 tracks, 1 reused, 1 skipped",
        rootPath: "/library",
        failures: [archiveFailure],
        skipped: skippedArchiveMembers + [
            ScanSkippedFile(
                identity: ScanItemIdentity(rootID: 1, path: "/library/notes.xyz", archiveEntry: nil),
                extensionName: "xyz",
                reason: .unsupportedFormat
            )
        ]
    )

    #expect(lines[0] == "status | detail | path")
    #expect(lines[1] == "complete | 4 discovered, 2 tracks, 1 reused, 1 skipped | .")
    #expect(lines.contains("archive-error | metadata: decoder failed | NeuroDancer.zip#music/bad.spc"))
    #expect(lines.contains("unrecognized | unsupported format (.xyz) | notes.xyz"))
    #expect(!lines.contains(where: { $0.contains("explicit ignore") || $0.contains("music/one.sgc") || $0.contains("music/two.sgc") }))
    #expect(ScanLogFormatter.reportableSkipped(skippedArchiveMembers).isEmpty)

    let ignoredLooseFiles = [
        ScanSkippedFile(
            identity: ScanItemIdentity(rootID: 1, path: "/library/playlist.m3u", archiveEntry: nil),
            extensionName: "m3u",
            reason: .explicitlyIgnored
        ),
        ScanSkippedFile(
            identity: ScanItemIdentity(rootID: 1, path: "/library/cover.png", archiveEntry: nil),
            extensionName: "png",
            reason: .explicitlyIgnored
        )
    ]
    let ignoredLines = ScanLogFormatter.lines(
        status: "complete",
        summary: "1 discovered, 1 track, 0 skipped",
        rootPath: "/library",
        failures: [],
        skipped: ignoredLooseFiles
    )
    #expect(ignoredLines == [
        "status | detail | path",
        "complete | 1 discovered, 1 track, 0 skipped | ."
    ])

    let scratchFailure = ScanFailure(
        identity: ScanItemIdentity(rootID: 1, path: "/library/Silent Hill HD Collection.tar.zst", archiveEntry: "sh3_bgm_02.hd"),
        fingerprint: fingerprint,
        route: nil,
        stage: .metadata,
        message: "failed opening /private/var/folders/example/T/ScanSong-ScanScratch/CB56DFBC-58F8-4BDC-87C0-9F0E79FFBA63/payload/sh3_bgm_02.hd"
    )
    #expect(scratchFailure.message == "failed opening sh3_bgm_02.hd")
    let scratchLines = ScanLogFormatter.lines(
        status: "complete",
        summary: "1 discovered, 0 tracks, 0 reused, 1 failed",
        rootPath: "/library",
        failures: [scratchFailure],
        skipped: []
    )
    #expect(scratchLines.contains("archive-error | metadata: failed opening | Silent Hill HD Collection.tar.zst#sh3_bgm_02.hd"))
    #expect(!scratchLines.contains(where: { $0.contains("ScanSong-ScanScratch") || $0.contains("/private/var") }))

    let duplicateMemberFailure = ScanFailure(
        identity: ScanItemIdentity(rootID: 1, path: "/library/Hard Corps.tar.zst", archiveEntry: "Stage01_Active.txtp"),
        fingerprint: fingerprint,
        route: nil,
        stage: .metadata,
        message: "vgmstream returned invalid metadata for Stage01_Active.txtp"
    )
    let duplicateLines = ScanLogFormatter.lines(
        status: "complete",
        summary: "1 discovered, 0 tracks, 0 reused, 1 failed",
        rootPath: "/library",
        failures: [duplicateMemberFailure],
        skipped: []
    )
    #expect(duplicateLines.contains("archive-error | metadata: vgmstream returned invalid metadata | Hard Corps.tar.zst#Stage01_Active.txtp"))
}

@Test func sharedLifecycleAndAccumulatorUseOneCrossHostVocabulary() async throws {
    #expect(ScanLifecyclePhase.infer(from: "Discovering files") == .discovery)
    #expect(ScanLifecyclePhase.infer(from: "Publishing scan") == .publication)

    let identity = ScanItemIdentity(rootID: 1, path: "/library/game.spc", archiveEntry: nil)
    let fingerprint = ScanFingerprint(fileSize: 1, modifiedAt: .distantPast)
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "spc"))
    let candidate = ScanCandidate(
        identity: identity,
        fingerprint: fingerprint,
        sourceURL: URL(fileURLWithPath: identity.path),
        route: route
    )
    let accumulator = ScanResultAccumulator(discovered: 2)
    try await accumulator.accept(.success(candidate, ScanInspection(
        route: route,
        tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: nil)]
    )))
    try await accumulator.accept(.failure(ScanFailure(
        identity: identity,
        fingerprint: fingerprint,
        route: route,
        stage: .metadata,
        message: "decoder failed"
    )))
    let summary = await accumulator.summary
    #expect(summary.discovered == 2)
    #expect(summary.successful == 1)
    #expect(summary.failed == 1)
}

@Test func sharedSchedulerReleasesItsPermitAfterPluginFailure() async throws {
    let scheduler = ScanResourceScheduler(permits: 1)
    await #expect(throws: SchedulerTestError.self) {
        try await scheduler.withPermit { throw SchedulerTestError.expected } as Void
    }
    #expect(try await scheduler.withPermit { 42 } == 42)
}

@Test func sharedSchedulerRemovesCancelledWaitersBeforePluginWorkStarts() async throws {
    let scheduler = ScanResourceScheduler(permits: 1)
    let first = Task {
        try await scheduler.withPermit {
            try await Task.sleep(for: .milliseconds(100))
            return 1
        }
    }
    try await Task.sleep(for: .milliseconds(10))
    let queued = Task { try await scheduler.withPermit { 2 } }
    try await Task.sleep(for: .milliseconds(10))
    queued.cancel()
    guard case .failure(let error) = await queued.result else {
        Issue.record("Cancelled scanner waiter unexpectedly ran")
        return
    }
    #expect(error is CancellationError)
    #expect(try await first.value == 1)
    #expect(try await scheduler.withPermit { 3 } == 3)
}
