import Foundation
import Testing
@testable import ArchiveMaterializationCore

private func runner() -> ArchiveProcessRunner {
    ArchiveProcessRunner(configuration: .init(
        environment: ProcessInfo.processInfo.environment,
        temporaryDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ArchiveProcessRunnerTests", isDirectory: true),
        temporaryFilePrefix: "test-process",
        maxConcurrency: 1,
        listingTimeout: 2,
        extractionTimeout: 2,
        capturedOutputMaximumBytes: 64
    ))
}

@Test func capturesBoundedProcessOutput() throws {
    let output = try runner().run(
        executable: "/usr/bin/printf",
        arguments: ["hello"],
        operation: .listing
    )
    #expect(output == Data("hello".utf8))
}

@Test func writesProcessOutputToCallerFile() throws {
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveProcessRunner-(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    try runner().runWritingOutput(
        executable: "/usr/bin/printf",
        arguments: ["materialized"],
        outputURL: outputURL
    )
    #expect(try Data(contentsOf: outputURL) == Data("materialized".utf8))
}

@Test func reportsNonZeroExitAsProcessFailure() {
    #expect(throws: ArchiveProcessRunnerError.failed(
        executable: "sh",
        status: 7,
        message: "exit code 7"
    )) {
        try runner().run(
            executable: "/bin/sh",
            arguments: ["-c", "exit 7"],
            operation: .listing
        )
    }
}

@Test func rejectsCapturedOutputAboveConfiguredLimit() {
    #expect(throws: ArchiveProcessRunnerError.outputLimitExceeded(bytes: 65)) {
        try runner().run(
        executable: "/usr/bin/printf",
            arguments: [String(repeating: "x", count: 65)],
            operation: .listing
        )
    }
}

@Test func enforcesOperationTimeout() {
    let timeoutRunner = ArchiveProcessRunner(configuration: .init(
        environment: ProcessInfo.processInfo.environment,
        maxConcurrency: 1,
        listingTimeout: 0.05,
        extractionTimeout: 0.05,
        capturedOutputMaximumBytes: 64
    ))
    #expect(throws: ArchiveProcessRunnerError.timedOut(executable: "sh", seconds: 0)) {
        try timeoutRunner.run(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 1"],
            operation: .listing
        )
    }
}

@Test func cancellationWhileWaitingForPermitIsObserved() async throws {
    let constrainedRunner = ArchiveProcessRunner(configuration: .init(
        environment: ProcessInfo.processInfo.environment,
        maxConcurrency: 1,
        listingTimeout: 2,
        extractionTimeout: 2,
        capturedOutputMaximumBytes: 64
    ))
    try constrainedRunner.acquirePermit()
    defer { constrainedRunner.releasePermit() }

    let task = Task {
        try constrainedRunner.run(
            executable: "/usr/bin/printf",
            arguments: ["should-not-run"],
            operation: .listing
        )
    }
    task.cancel()

    do {
        _ = try await task.value
        #expect(Bool(false), "Cancelled archive work unexpectedly ran.")
    } catch is CancellationError {
        #expect(Bool(true))
    }
}
