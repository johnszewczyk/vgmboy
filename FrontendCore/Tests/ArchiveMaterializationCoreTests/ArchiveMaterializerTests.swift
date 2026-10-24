import CryptoKit
import Foundation
import Testing
import ArchiveCacheCore
import UACWrapperCore
import VGMBoyFormatCore
@testable import ArchiveMaterializationCore

@Test func boundedProcessRunnerReturnsOutputAndStopsAtTheLimit() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveProcessRunnerBoundedTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let runner = ArchiveProcessRunner(configuration: .init(
        environment: ProcessInfo.processInfo.environment,
        temporaryDirectory: root,
        temporaryFilePrefix: "bounded",
        maxConcurrency: 1,
        listingTimeout: 5,
        extractionTimeout: 5,
        capturedOutputMaximumBytes: 1024
    ))

    let output = try runner.runBounded(
        executable: "/usr/bin/printf",
        arguments: ["hello"],
        maximumOutputBytes: 5,
        operation: .extraction
    )
    #expect(output == Data("hello".utf8))
    #expect(throws: ArchiveProcessRunnerError.outputLimitExceeded(bytes: 6)) {
        try runner.runBounded(
            executable: "/usr/bin/printf",
            arguments: ["123456"],
            maximumOutputBytes: 5,
            operation: .extraction
        )
    }
}

@Test func sharedUACFrameCodecDecodesOneFrameAndChecksItsSeekChecksum() throws {
    guard let zstdPath = ArchiveMaterializerConfiguration.default.zstdCandidates.first(where: {
        FileManager.default.isExecutableFile(atPath: $0)
    }) else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("UACZstandardCLIFrameCodecTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let sourceURL = root.appendingPathComponent("frame.tar-part", isDirectory: false)
    let sourceData = Data("bounded frame bytes".utf8)
    try sourceData.write(to: sourceURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: zstdPath)
    process.arguments = ["-q", "-c", "--", sourceURL.path]
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    try process.run()
    let compressed = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)

    let codec = UACZstandardCLIFrameCodec()
    let checksum = UACSeekableFrameChecksum.value(for: sourceData)
    #expect(try codec.seekableFrameDecoder(compressed, checksum) == sourceData)
    #expect(throws: UACZstandardCLIFrameCodecError.checksumMismatch) {
        try codec.seekableFrameDecoder(compressed, checksum &+ 1)
    }
}

@Test func playbackMaterializerSeeksOnlyFramesCoveringSelectedUACMember() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchivePlaybackSeekableUACTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveURL = try makeSeekableUACFixtureForArchivePlayback(in: root)
    let cacheURL = root.appendingPathComponent("cache", isDirectory: true)
    let keys = ArchiveCachePreferenceKeys(
        modeKey: "ArchivePlaybackSeekableUACTests.\(UUID().uuidString).mode",
        limitKey: "ArchivePlaybackSeekableUACTests.\(UUID().uuidString).limit"
    )
    ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes).save(keys: keys)
    let decodeCounter = ArchivePlaybackFrameDecodeCounter()
    let frameDecoder: UACSeekableFrameDecoder = { compressed, checksum in
        #expect(checksum == nil)
        decodeCounter.increment()
        switch compressed.last {
        case 1: return Data("1234".utf8)
        case 2: return Data("ABCD".utf8)
        case 3: return Data("EFGH".utf8)
        case 4: return Data("9876".utf8)
        default: throw UACContainerError.invalidPayloadMagic
        }
    }
    let materializer = FrontendArchiveCacheMaterializer(
        cacheRootURL: cacheURL,
        preferenceKeys: keys,
        capacityProvider: { _ in Int64.max },
        decompressUACSeekableFrame: frameDecoder
    )

    let selected = try materializer.materialize(
        archiveURL: archiveURL,
        entryPath: "variants/original/track.spc",
        requirement: .selectedEntry
    )
    #expect(try Data(contentsOf: selected) == Data("CDEF".utf8))
    #expect(decodeCounter.value == 2)
}

@Test func sharedMaterializerSeeksOnlyFramesCoveringSelectedUACMember() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveMaterializerSeekableUACTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let archiveURL = try makeSeekableUACFixtureForArchivePlayback(in: root)
    let decodeCounter = ArchivePlaybackFrameDecodeCounter()
    let frameDecoder: UACSeekableFrameDecoder = { compressed, checksum in
        #expect(checksum == nil)
        decodeCounter.increment()
        switch compressed.last {
        case 1: return Data("1234".utf8)
        case 2: return Data("ABCD".utf8)
        case 3: return Data("EFGH".utf8)
        case 4: return Data("9876".utf8)
        default: throw UACContainerError.invalidPayloadMagic
        }
    }
    let materializer = ArchiveMaterializer(
        configuration: .init(
            temporaryDirectoryName: "ArchiveMaterializerSeekableUACTests-\(UUID().uuidString)",
            bsdtarCandidates: [],
            zstdCandidates: []
        ),
        decompressUACSeekableFrame: frameDecoder
    )
    defer { materializer.release() }

    let selected = try materializer.materialize(
        archivePath: archiveURL.path,
        entry: "variants/original/track.spc",
        requirement: .selectedEntry
    )
    #expect(try Data(contentsOf: selected) == Data("CDEF".utf8))
    #expect(decodeCounter.value == 2)
}

@Test func materializationSessionReplacesAndClearsOnlyTemporaryOwnership() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveMaterializationSessionTests-\(UUID().uuidString)", isDirectory: true)
    let first = root.appendingPathComponent("first", isDirectory: true)
    let second = root.appendingPathComponent("second", isDirectory: true)
    try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let session = ArchiveMaterializationSession()
    session.replace(with: first)
    #expect(session.path == first.path)
    session.replace(with: second)

    #expect(session.path == second.path)
    #expect(!FileManager.default.fileExists(atPath: first.path))
    session.clear()
    #expect(session.path == nil)
    #expect(!FileManager.default.fileExists(atPath: second.path))
}

@Test func rejectsMissingSourceBeforeCreatingTemporaryFiles() {
    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: [],
        zstdCandidates: []
    ))

    #expect(throws: ArchiveMaterializationError.missingSource("/private/tmp/no-such-archive")) {
        try materializer.materialize(
            archivePath: "/private/tmp/no-such-archive",
            entry: "track.spc",
            requirement: .selectedEntry
        )
    }
}

@Test func cacheMaterializerPreservesWarmEntryAndAtomicDestination() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    let archiveURL = root.appendingPathComponent("library.zip")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("archive".utf8).write(to: archiveURL)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = testCacheStore(at: root.appendingPathComponent("cache"))
    let lease = ArchivePlaybackLease()
    let materializer = ArchiveCacheMaterializer(cacheStore: store, playbackLease: lease)
    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)
    var extractionCount = 0

    let first = try materializer.materializeEntry(
        archiveURL: archiveURL,
        entryPath: "music/track.spc",
        policy: policy
    ) { outputURL in
        extractionCount += 1
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("payload".utf8).write(to: outputURL)
    }
    let second = try materializer.materializeEntry(
        archiveURL: archiveURL,
        entryPath: "music/track.spc",
        policy: policy
    ) { _ in
        extractionCount += 1
    }

    #expect(first == second)
    #expect(extractionCount == 1)
    #expect(first.lastPathComponent == "track.spc")
    #expect(String(data: try Data(contentsOf: first), encoding: .utf8) == "payload")
    #expect(lease.path == store.archiveCacheURL(for: archiveURL, policy: policy).path)
}

@Test func cacheMaterializerUsesCompletionMarkerForCompleteSets() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    let archiveURL = root.appendingPathComponent("library.zip")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("archive".utf8).write(to: archiveURL)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = testCacheStore(at: root.appendingPathComponent("cache"))
    let materializer = ArchiveCacheMaterializer(cacheStore: store)
    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)
    var extractionCount = 0

    let first = try materializer.materializeCompleteSet(
        archiveURL: archiveURL,
        policy: policy,
        activePlaybackRoot: nil
    ) { destinationURL in
        extractionCount += 1
        try Data("track".utf8).write(to: destinationURL.appendingPathComponent("track.spc"))
    }
    let second = try materializer.materializeCompleteSet(
        archiveURL: archiveURL,
        policy: policy,
        activePlaybackRoot: nil
    ) { _ in
        extractionCount += 1
    }

    #expect(first == second)
    #expect(extractionCount == 1)
    #expect(FileManager.default.fileExists(atPath: first.appendingPathComponent(".complete").path))
    #expect(FileManager.default.fileExists(atPath: first.appendingPathComponent("track.spc").path))
}

@Test func cacheMaterializerNormalizesExtractedDirectoryPermissions() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheMaterializerPermissions-(UUID().uuidString)", isDirectory: true)
    let archiveURL = root.appendingPathComponent("library.tar")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("archive".utf8).write(to: archiveURL)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = testCacheStore(at: root.appendingPathComponent("cache"))
    let materializer = ArchiveCacheMaterializer(cacheStore: store)
    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)
    let completeSet = try materializer.materializeCompleteSet(
        archiveURL: archiveURL,
        policy: policy,
        activePlaybackRoot: nil
    ) { destinationURL in
        let nested = destinationURL.appendingPathComponent("UNKNOWN", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("track".utf8).write(to: nested.appendingPathComponent("track.psf"))
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: nested.path)
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: completeSet.appendingPathComponent("UNKNOWN").path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o755)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o644],
        ofItemAtPath: completeSet.appendingPathComponent("UNKNOWN").path
    )
    let warmHit = try materializer.materializeCompleteSet(
        archiveURL: archiveURL,
        policy: policy,
        activePlaybackRoot: nil,
        isValid: { root in
            FileManager.default.fileExists(atPath: root.appendingPathComponent("UNKNOWN/track.psf").path)
        }
    ) { _ in
        Issue.record("A valid complete-set warm hit should not be re-extracted.")
    }
    let repairedAttributes = try FileManager.default.attributesOfItem(atPath: warmHit.appendingPathComponent("UNKNOWN").path)
    #expect((repairedAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o755)
    try FileManager.default.removeItem(at: completeSet)
    #expect(!FileManager.default.fileExists(atPath: completeSet.path))
}

@Test func playbackMaterializerReturnsPlayableMemberForSelectedAndCompleteRequirements() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("FrontendArchiveCacheMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    let cache = root.appendingPathComponent("cache", isDirectory: true)
    let keys = ArchiveCachePreferenceKeys(
        modeKey: "FrontendArchiveCacheMaterializerTests.\(UUID().uuidString).mode",
        limitKey: "FrontendArchiveCacheMaterializerTests.\(UUID().uuidString).limit"
    )
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("selected".utf8).write(to: source.appendingPathComponent("track.spc"))
    try Data("complete".utf8).write(to: source.appendingPathComponent("set.usf"))
    defer { try? FileManager.default.removeItem(at: root) }

    let creator = Process()
    creator.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    creator.arguments = ["-cf", archive.path, "-C", source.path, "."]
    try creator.run()
    creator.waitUntilExit()
    #expect(creator.terminationStatus == 0)

    ArchiveCachePolicy(
        mode: .disabled,
        maximumBytes: ArchiveCachePolicy.defaultLimitBytes
    ).save(keys: keys)
    let materializer = FrontendArchiveCacheMaterializer(
        cacheRootURL: cache,
        preferenceKeys: keys,
        capacityProvider: { _ in Int64.max }
    )

    let selected = try materializer.materialize(
        archiveURL: archive,
        entryPath: "track.spc",
        requirement: .selectedEntry
    )
    #expect(selected.lastPathComponent == "track.spc")
    #expect(try Data(contentsOf: selected) == Data("selected".utf8))

    let complete = try materializer.materialize(
        archiveURL: archive,
        entryPath: "set.usf",
        requirement: .completeSet
    )
    #expect(complete.lastPathComponent == "set.usf")
    #expect(try Data(contentsOf: complete) == Data("complete".utf8))
    materializer.release()
}

@Test func cacheMaterializerRemovesInterruptedCompleteSetStaging() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    let archiveURL = root.appendingPathComponent("library.zip")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("archive".utf8).write(to: archiveURL)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = testCacheStore(at: root.appendingPathComponent("cache"))
    let materializer = ArchiveCacheMaterializer(cacheStore: store)
    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)

    #expect(throws: CancellationError.self) {
        try materializer.materializeCompleteSet(
            archiveURL: archiveURL,
            policy: policy,
            activePlaybackRoot: nil
        ) { stagingURL in
            try Data("partial".utf8).write(to: stagingURL.appendingPathComponent("track.spc"))
            throw CancellationError()
        }
    }

    let disposableRoot = store.lifecycle.disposableRootURL
    let remaining = (try? FileManager.default.contentsOfDirectory(
        at: disposableRoot,
        includingPropertiesForKeys: nil
    )) ?? []
    #expect(remaining.filter { $0.lastPathComponent.hasPrefix(".set-") }.isEmpty)
}

private final class ArchivePlaybackFrameDecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private func makeSeekableUACFixtureForArchivePlayback(in directory: URL) throws -> URL {
    let digest = String(repeating: "a", count: 64)
    let manifest = UACManifest(
        packageID: "fixture-game",
        payload: UACPayload(
            format: "tar+zstd-seekable",
            compressionProfile: "uac-zstd-seekable-level-3-frame-4194304-v1",
            encoderVersion: "FrontendCore fixture",
            blake3: digest
        ),
        game: UACGame(id: "fixture-game", title: "Fixture Game", console: "Nintendo SNES"),
        variants: [UACVariant(id: "original", label: "Original", kind: "retail")],
        members: [UACMember(
            path: "variants/original/track.spc",
            originalName: "track.spc",
            variantID: "original",
            role: "playable",
            format: "spc",
            byteSize: 4,
            tarDataOffset: 6,
            blake3: digest
        )]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let manifestData = try encoder.encode(manifest)

    var payload = Data([
        0x28, 0xB5, 0x2F, 0xFD, 1,
        0x28, 0xB5, 0x2F, 0xFD, 2,
        0x28, 0xB5, 0x2F, 0xFD, 3,
        0x28, 0xB5, 0x2F, 0xFD, 4,
    ])
    var seekTable = Data()
    for _ in 0..<4 {
        appendLittleEndian(UInt32(5), to: &seekTable)
        appendLittleEndian(UInt32(4), to: &seekTable)
    }
    appendLittleEndian(UInt32(4), to: &seekTable)
    seekTable.append(0)
    appendLittleEndian(UACZstandardSeekTable.seekableFooterMagic, to: &seekTable)
    appendLittleEndian(UACZstandardSeekTable.skippableFrameMagic, to: &payload)
    appendLittleEndian(UInt32(seekTable.count), to: &payload)
    payload.append(seekTable)

    var metadataFrame = UACContainerReader.metadataMagic
    appendLittleEndian(UInt16(1), to: &metadataFrame)
    appendLittleEndian(UInt16(0), to: &metadataFrame)
    metadataFrame.append(contentsOf: SHA256.hash(data: manifestData))
    metadataFrame.append(manifestData)

    var container = Data()
    appendLittleEndian(UACContainerReader.uacSkippableMagic, to: &container)
    appendLittleEndian(UInt32(metadataFrame.count), to: &container)
    container.append(metadataFrame)
    container.append(payload)

    let archiveURL = directory.appendingPathComponent("seekable-fixture.uac", isDirectory: false)
    try container.write(to: archiveURL, options: .atomic)
    return archiveURL
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

private func testCacheStore(at root: URL) -> ArchiveCacheStore {
    ArchiveCacheStore(cacheRootURL: root, capacityProvider: { _ in Int64.max })
}

@Test func rejectsEmptyEntry() {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("archive-placeholder")
    FileManager.default.createFile(atPath: source.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: source) }

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: [],
        zstdCandidates: []
    ))
    #expect(throws: ArchiveMaterializationError.invalidEntry) {
        try materializer.materialize(
            archivePath: source.path,
            entry: "",
            requirement: .selectedEntry
        )
    }
}

@Test func materializesPSFDependencyBesideSelectedTrack() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveMaterializerPSF-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let psf = Data("PSF\u{1}\n[TAG]\n_lib=re2.psflib\n[/TAG]\n".utf8)
    let library = Data("shared-library".utf8)
    try psf.write(to: source.appendingPathComponent("06 Prologue.psf"))
    try library.write(to: source.appendingPathComponent("re2.psflib"))

    let tar = Process()
    tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    tar.arguments = ["-cf", archive.path, "-C", source.path, "."]
    try tar.run()
    tar.waitUntilExit()
    #expect(tar.terminationStatus == 0)

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: ["/usr/bin/bsdtar"],
        zstdCandidates: []
    ))
    let selected = try materializer.materialize(
        archivePath: archive.path,
        entry: "06 Prologue.psf",
        requirement: .selectedEntry
    )
    let dependency = selected.deletingLastPathComponent().appendingPathComponent("re2.psflib")
    #expect(FileManager.default.fileExists(atPath: selected.path))
    #expect(FileManager.default.fileExists(atPath: dependency.path))
    #expect(try Data(contentsOf: dependency) == library)
    materializer.release()
}

@Test func materializesSevenZipEntryThroughSharedToolRouting() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveMaterializer7z-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.7z")
    let selectedData = Data("shared-routing-entry".utf8)
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try selectedData.write(to: source.appendingPathComponent("track.spc"))
    defer { try? FileManager.default.removeItem(at: root) }

    let sevenZip = "/opt/homebrew/bin/7zz"
    #expect(FileManager.default.isExecutableFile(atPath: sevenZip))
    let creator = Process()
    creator.executableURL = URL(fileURLWithPath: sevenZip)
    creator.arguments = ["a", archive.path, "track.spc"]
    creator.currentDirectoryURL = source
    try creator.run()
    creator.waitUntilExit()
    #expect(creator.terminationStatus == 0)

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: [],
        zstdCandidates: [],
        sevenZipCandidates: [sevenZip],
        unarCandidates: []
    ))
    let selected = try materializer.materialize(
        archivePath: archive.path,
        entry: "track.spc",
        requirement: .selectedEntry
    )
    #expect(try Data(contentsOf: selected) == selectedData)
    materializer.release()
}

@Test func materializesCompleteSetAndLazyUSFAliasesThroughSharedCore() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveMaterializerUSF-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("usf".utf8).write(to: source.appendingPathComponent("track.usf"))
    try Data("library".utf8).write(to: source.appendingPathComponent("library.usflib"))
    defer { try? FileManager.default.removeItem(at: root) }

    let tar = Process()
    tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    tar.arguments = ["-cf", archive.path, "-C", source.path, "."]
    try tar.run()
    tar.waitUntilExit()
    #expect(tar.terminationStatus == 0)

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: ["/usr/bin/bsdtar"],
        zstdCandidates: []
    ))
    let selected = try materializer.materialize(
        archivePath: archive.path,
        entry: "track.usf",
        requirement: .completeSetWithLazyUSFAliases
    )
    let alias = selected.deletingLastPathComponent().appendingPathComponent("library")
    #expect(FileManager.default.fileExists(atPath: alias.path))
    #expect(try Data(contentsOf: alias) == Data("library".utf8))
    materializer.release()
}

@Test func materializesCompleteSetAndTXTPAliasesThroughSharedCore() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveMaterializerTXTP-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try Data("audio/track.adx # generated path\n".utf8).write(to: source.appendingPathComponent("mix.txtp"))
    try Data("stream".utf8).write(to: source.appendingPathComponent("track.adx"))
    defer { try? FileManager.default.removeItem(at: root) }

    let tar = Process()
    tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    tar.arguments = ["-cf", archive.path, "-C", source.path, "."]
    try tar.run()
    tar.waitUntilExit()
    #expect(tar.terminationStatus == 0)

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: ["/usr/bin/bsdtar"],
        zstdCandidates: []
    ))
    let selected = try materializer.materialize(
        archivePath: archive.path,
        entry: "mix.txtp",
        requirement: .completeSet
    )
    let alias = selected.deletingLastPathComponent()
        .appendingPathComponent("audio", isDirectory: true)
        .appendingPathComponent("track.adx")
    #expect(FileManager.default.fileExists(atPath: alias.path))
    #expect(try Data(contentsOf: alias) == Data("stream".utf8))
    materializer.release()
}
