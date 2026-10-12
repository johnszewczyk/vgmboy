import Foundation

/// The kind of bounded archive operation being run.
public enum ArchiveProcessOperation: Sendable, Equatable {
    case listing
    case extraction
}

/// Errors produced by the shared archive-process boundary.
public enum ArchiveProcessRunnerError: Error, Equatable, Sendable {
    case timedOut(executable: String, seconds: Int)
    case failed(executable: String, status: Int32, message: String)
    case outputLimitExceeded(bytes: Int64)
}

/// Shared process mechanics for archive listing and materialization.
///
/// This type owns only bounded process execution: concurrency, cancellation,
/// timeout observation, temporary stdout capture, and process failure. Archive
/// formats, executable discovery, arguments, dependency policy, and cache
/// policy remain owned by the archive/materialization layers above this
/// runner.
public final class ArchiveProcessRunner: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var environment: [String: String]
        public var temporaryDirectory: URL
        public var temporaryFilePrefix: String
        public var maxConcurrency: Int
        public var listingTimeout: TimeInterval
        public var extractionTimeout: TimeInterval
        public var capturedOutputMaximumBytes: Int64

        public init(
            environment: [String: String],
            temporaryDirectory: URL = FileManager.default.temporaryDirectory,
            temporaryFilePrefix: String = "FrontendCore-process",
            maxConcurrency: Int,
            listingTimeout: TimeInterval,
            extractionTimeout: TimeInterval,
            capturedOutputMaximumBytes: Int64
        ) {
            self.environment = environment
            self.temporaryDirectory = temporaryDirectory
            self.temporaryFilePrefix = temporaryFilePrefix
            self.maxConcurrency = max(1, maxConcurrency)
            self.listingTimeout = listingTimeout
            self.extractionTimeout = extractionTimeout
            self.capturedOutputMaximumBytes = capturedOutputMaximumBytes
        }
    }

    private let configuration: Configuration
    private let processGate: DispatchSemaphore

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.processGate = DispatchSemaphore(value: configuration.maxConcurrency)
    }

    /// Acquires one bounded archive-process slot, observing task cancellation.
    /// Call `releasePermit()` exactly once after successful acquisition.
    public func acquirePermit() throws {
        while processGate.wait(timeout: .now() + .milliseconds(100)) != .success {
            if Task.isCancelled { throw CancellationError() }
        }
    }

    public func releasePermit() {
        processGate.signal()
    }

    /// Runs a process and captures stdout in a temporary file before reading it.
    public func run(
        executable: String,
        arguments: [String],
        operation: ArchiveProcessOperation
    ) throws -> Data {
        try acquirePermit()
        defer { releasePermit() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = configuration.environment

        let outputURL = try processOutputURL()
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }
        let stderr = Pipe()
        process.standardOutput = outputHandle
        process.standardError = stderr

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        try process.run()
        defer { process.terminationHandler = nil }

        let errorReadHandle = stderr.fileHandleForReading
        try stderr.fileHandleForWriting.close()
        let errorCollector = ArchiveProcessOutputCollector()
        let readers = DispatchGroup()
        readers.enter()
        Thread.detachNewThread {
            let data = errorReadHandle.readDataToEndOfFile()
            try? errorReadHandle.close()
            errorCollector.set(data)
            readers.leave()
        }

        do {
            try waitForProcess(
                process,
                completion: completion,
                executable: executable,
                timeout: operation == .extraction ? configuration.extractionTimeout : configuration.listingTimeout
            )
        } catch {
            readers.wait()
            throw error
        }
        readers.wait()
        try outputHandle.close()

        guard process.terminationStatus == 0 else {
            throw ArchiveProcessRunnerError.failed(
                executable: URL(fileURLWithPath: executable).lastPathComponent,
                status: process.terminationStatus,
                message: processErrorText(errorCollector.value, status: process.terminationStatus)
            )
        }

        let outputBytes = Int64((try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        guard outputBytes <= configuration.capturedOutputMaximumBytes else {
            throw ArchiveProcessRunnerError.outputLimitExceeded(bytes: outputBytes)
        }
        return try Data(contentsOf: outputURL, options: .mappedIfSafe)
    }

    /// Runs a process while enforcing a hard stdout limit during execution.
    /// Unlike `run`, excess output is drained and the child is stopped as soon
    /// as the bound is crossed, so a malformed compressed frame cannot fill
    /// the temporary volume before its size is checked.
    public func runBounded(
        executable: String,
        arguments: [String],
        maximumOutputBytes: Int64,
        operation: ArchiveProcessOperation
    ) throws -> Data {
        guard maximumOutputBytes > 0 else {
            throw ArchiveProcessRunnerError.outputLimitExceeded(bytes: 0)
        }
        try acquirePermit()
        defer { releasePermit() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = configuration.environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            try? stdout.fileHandleForWriting.close()
            try? stderr.fileHandleForWriting.close()
            throw error
        }

        // The child inherited these descriptors when launched; close the
        // parent's copies so the readers observe EOF when the child exits.
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()

        let stdoutCollector = ArchiveProcessBoundedDataCollector(maximumBytes: maximumOutputBytes)
        let stderrCollector = ArchiveProcessBoundedDataCollector(
            maximumBytes: min(configuration.capturedOutputMaximumBytes, 128 * 1024)
        )
        let readers = DispatchGroup()
        readers.enter()
        Thread.detachNewThread {
            defer { readers.leave() }
            Self.collect(
                from: stdout.fileHandleForReading,
                into: stdoutCollector,
                terminate: { if process.isRunning { process.terminate() } }
            )
        }
        readers.enter()
        Thread.detachNewThread {
            defer { readers.leave() }
            Self.collect(from: stderr.fileHandleForReading, into: stderrCollector)
        }

        do {
            try waitForProcess(
                process,
                completion: completion,
                executable: executable,
                timeout: operation == .extraction ? configuration.extractionTimeout : configuration.listingTimeout
            )
        } catch {
            readers.wait()
            process.terminationHandler = nil
            throw error
        }
        readers.wait()
        process.terminationHandler = nil

        if let readFailure = stdoutCollector.readFailure {
            throw ArchiveProcessRunnerError.failed(
                executable: URL(fileURLWithPath: executable).lastPathComponent,
                status: process.terminationStatus,
                message: readFailure
            )
        }
        if stdoutCollector.exceededLimit {
            throw ArchiveProcessRunnerError.outputLimitExceeded(bytes: stdoutCollector.receivedBytes)
        }
        guard process.terminationStatus == 0 else {
            throw ArchiveProcessRunnerError.failed(
                executable: URL(fileURLWithPath: executable).lastPathComponent,
                status: process.terminationStatus,
                message: processErrorText(stderrCollector.value, status: process.terminationStatus)
            )
        }
        return stdoutCollector.value
    }

    /// Runs a process with stdout directed to a caller-owned output file.
    public func runWritingOutput(
        executable: String,
        arguments: [String],
        outputURL: URL,
        operation: ArchiveProcessOperation = .extraction
    ) throws {
        try acquirePermit()
        defer { releasePermit() }

        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer { try? outputHandle.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = configuration.environment
        process.standardOutput = outputHandle

        let stderr = Pipe()
        process.standardError = stderr
        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }
        try process.run()
        defer { process.terminationHandler = nil }

        let errorReadHandle = stderr.fileHandleForReading
        try stderr.fileHandleForWriting.close()
        let errorCollector = ArchiveProcessOutputCollector()
        let readers = DispatchGroup()
        readers.enter()
        Thread.detachNewThread {
            let data = errorReadHandle.readDataToEndOfFile()
            try? errorReadHandle.close()
            errorCollector.set(data)
            readers.leave()
        }

        do {
            try waitForProcess(
                process,
                completion: completion,
                executable: executable,
                timeout: operation == .extraction ? configuration.extractionTimeout : configuration.listingTimeout
            )
        } catch {
            readers.wait()
            throw error
        }
        readers.wait()
        try outputHandle.close()

        guard process.terminationStatus == 0 else {
            throw ArchiveProcessRunnerError.failed(
                executable: URL(fileURLWithPath: executable).lastPathComponent,
                status: process.terminationStatus,
                message: processErrorText(errorCollector.value, status: process.terminationStatus)
            )
        }
    }

    /// Waits for a process while preserving cancellation and timeout behavior
    /// for archive pipelines that own more than one connected Process.
    public func waitForProcess(
        _ process: Process,
        completion: DispatchSemaphore,
        executable: String,
        timeout: TimeInterval
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while completion.wait(timeout: .now() + .milliseconds(100)) != .success {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            if Date() >= deadline {
                process.terminate()
                process.waitUntilExit()
                throw ArchiveProcessRunnerError.timedOut(
                    executable: URL(fileURLWithPath: executable).lastPathComponent,
                    seconds: Int(timeout)
                )
            }
        }
    }

    private func processOutputURL() throws -> URL {
        try FileManager.default.createDirectory(
            at: configuration.temporaryDirectory,
            withIntermediateDirectories: true
        )
        return configuration.temporaryDirectory.appendingPathComponent(
            "\(configuration.temporaryFilePrefix)-\(UUID().uuidString)",
            isDirectory: false
        )
    }

    private static func collect(
        from handle: FileHandle,
        into collector: ArchiveProcessBoundedDataCollector,
        terminate: (() -> Void)? = nil
    ) {
        defer { try? handle.close() }
        do {
            while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                if !collector.append(chunk) { terminate?() }
            }
        } catch {
            collector.setReadFailure(error.localizedDescription)
            terminate?()
        }
    }

    private func processErrorText(_ data: Data, status: Int32) -> String {
        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "exit code \(status)" : text
    }
}

private final class ArchiveProcessBoundedDataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int64
    private var data = Data()
    private var received = Int64(0)
    private var didExceedLimit = false
    private var failure: String?

    init(maximumBytes: Int64) {
        self.maximumBytes = max(0, maximumBytes)
    }

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    var receivedBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return received
    }

    var exceededLimit: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExceedLimit
    }

    var readFailure: String? {
        lock.lock()
        defer { lock.unlock() }
        return failure
    }

    @discardableResult
    func append(_ chunk: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let (nextReceived, overflow) = received.addingReportingOverflow(Int64(chunk.count))
        received = overflow ? Int64.max : nextReceived
        let remaining = max(0, maximumBytes - Int64(data.count))
        if Int64(chunk.count) > remaining {
            didExceedLimit = true
            if remaining > 0 { data.append(chunk.prefix(Int(remaining))) }
            return false
        }
        if !didExceedLimit { data.append(chunk) }
        return !didExceedLimit
    }

    func setReadFailure(_ message: String) {
        lock.lock()
        failure = message
        lock.unlock()
    }
}

/// Thread-safe stderr collection for connected archive-process pipelines.
public final class ArchiveProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    public init() {}

    public var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }

    public func set(_ data: Data) {
        lock.lock()
        self.data = data
        lock.unlock()
    }
}
