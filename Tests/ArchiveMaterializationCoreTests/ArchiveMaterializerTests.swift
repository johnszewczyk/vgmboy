import Foundation
import Testing
import ArchiveCacheCore
import VGMBoyFormatCore
@testable import ArchiveMaterializationCore

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
        .appendingPathComponent("ArchivePlaybackMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    let cache = root.appendingPathComponent("cache", isDirectory: true)
    let keys = ArchiveCachePreferenceKeys(
        modeKey: "ArchivePlaybackMaterializerTests.\(UUID().uuidString).mode",
        limitKey: "ArchivePlaybackMaterializerTests.\(UUID().uuidString).limit"
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
    let materializer = ArchivePlaybackMaterializer(
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
