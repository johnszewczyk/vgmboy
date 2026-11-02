import Foundation
import Testing
@testable import VGMBoyKit

@Test func aresClosedPCMBeforeProcessExitReportsError() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = directory.appendingPathComponent("closed-pipe-helper")
    try "#!/bin/sh\nexec 1>&-\nexec /bin/sleep 30\n".write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    let decoder = try AresSNESDecoder(path: directory.appendingPathComponent("test.snesstate").path, helperURL: helper)
    defer { decoder.close() }
    #expect(throws: AresSNESDecoderError.self) { try decoder.readFrames(1) }
    #expect(!decoder.trackEnded)
}

@Test func aresUnexpectedExitIsNotReportedAsNaturalEnd() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = directory.appendingPathComponent("failed-helper")
    try "#!/bin/sh\nexit 7\n".write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    let session = PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.01),
        makeDecoder: { path, _, sampleRate in try AresSNESDecoder(path: path, sampleRate: sampleRate, helperURL: helper) })
    defer { session.stop() }
    #expect(throws: AresSNESDecoderError.self) {
        try session.load(path: directory.appendingPathComponent("test.snesstate").path, trackIndex: 0,
            plan: .init(preFadeMilliseconds: 5_000, fadeMilliseconds: 0, isLongPlay: false, usesNativeEnding: false), tempo: 1)
    }
    #expect(!session.status().reachedEnd)
}

@Test func aresExitAfterPCMReportsFailureDuringRefill() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let helper = directory.appendingPathComponent("short-helper")
    try "#!/bin/sh\n/bin/dd if=/dev/zero bs=1764 count=4 2>/dev/null\nexit 7\n".write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
    let session = PlaybackSession(output: AudioOutput(sampleRate: 44_100, capacitySeconds: 0.01),
        makeDecoder: { path, _, sampleRate in try AresSNESDecoder(path: path, sampleRate: sampleRate, helperURL: helper) })
    defer { session.stop() }
    _ = try session.load(path: directory.appendingPathComponent("test.snesstate").path, trackIndex: 0,
        plan: .init(preFadeMilliseconds: 5_000, fadeMilliseconds: 0, isLongPlay: false, usesNativeEnding: false), tempo: 1)
    try session.play()
    for _ in 0..<80 where session.status().errorMessage == nil {
        try await Task.sleep(for: .milliseconds(25))
    }
    let status = session.status()
    #expect(status.errorMessage != nil)
    #expect(!status.isPlaying)
    #expect(!status.reachedEnd)
}
