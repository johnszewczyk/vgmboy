import Darwin
import Foundation
import SQLite3
import Testing
import zlib
@testable import ScanSongKit

@Test func txtpPreparationRetainsDependenciesWithoutPublishingDuplicateSources() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-txtp-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let bank = root.appendingPathComponent("Bgm", isDirectory: true)
    try FileManager.default.createDirectory(at: bank, withIntermediateDirectories: true)
    let directDependency = bank.appendingPathComponent("direct.adp")
    let flattenedDependency = root.appendingPathComponent("flattened.rsf")
    try Data([0]).write(to: directDependency)
    try Data([0]).write(to: flattenedDependency)
    try Data("Bgm/direct.adp\nBgm/flattened.rsf #I 0 1000\n".utf8)
        .write(to: root.appendingPathComponent("game.txtp"))

    let dependencies = try TXTPDependencyResolver().prepareDependencies(in: root)
    let alias = bank.appendingPathComponent("flattened.rsf")
    #expect(FileManager.default.fileExists(atPath: alias.path))
    #expect(dependencies == Set([
        directDependency.standardizedFileURL.path,
        flattenedDependency.standardizedFileURL.path,
        alias.standardizedFileURL.path
    ]))
}
@Test func ignoredFileTypePolicySkipsOnlyConfiguredExtensions() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-ignore-policy-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(repeating: 0, count: 4).write(to: root.appendingPathComponent("Game.sgc"))
    try Data(repeating: 0, count: 4).write(to: root.appendingPathComponent("Game.strm"))

    let candidates = try await ScanFilesystemDiscovery.discover(
        rootID: 1,
        rootURL: root,
        registry: BuiltInScannerPlugins.registry,
        isArchive: { _ in false },
        ignoredFileExtensions: ScannerFormatPolicy.defaultIgnoredExtensions
    )
    #expect(candidates.map(\.sourceURL.lastPathComponent) == ["Game.strm"])
}

@Test func archiveEnumerationReportsUnknownMembersWithoutSupportFileNoise() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-archive-members-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data([0]).write(to: root.appendingPathComponent("notes.xyz"))
    try Data([0]).write(to: root.appendingPathComponent("music.qsflib"))
    try Data([0]).write(to: root.appendingPathComponent("music.usflib"))
    try Data([0]).write(to: root.appendingPathComponent("music.ssflib"))
    try Data([0]).write(to: root.appendingPathComponent("music.2sflib"))
    try Data([0]).write(to: root.appendingPathComponent("music.sbb"))
    try Data([0]).write(to: root.appendingPathComponent("star.pdx"))
    try Data([0]).write(to: root.appendingPathComponent("ReadMe.TXT"))
    try Data([0]).write(to: root.appendingPathComponent("album.htm"))
    try Data([0]).write(to: root.appendingPathComponent("album.html"))
    try Data([0]).write(to: root.appendingPathComponent("extensionless"))

    let listing = try ArchiveMemberEnumerator().enumerate(
        payloadURL: root,
        registry: BuiltInScannerPlugins.registry,
        ignoredFileExtensions: [],
        dependencyPaths: []
    )

    #expect(listing.members.isEmpty)
    #expect(listing.skipped.map(\.entryPath) == ["notes.xyz"])
    #expect(listing.skipped.first?.reason == .unsupportedFormat)
}

@Test func tarZstandardAcceptsSuccessfulConsumerPipeClosure() {
    #expect(StandaloneArchiveExtractor.isExpectedZstandardPipeClosure(
        exitStatus: SIGPIPE,
        terminationReason: .uncaughtSignal,
        stderr: ""
    ))
    #expect(StandaloneArchiveExtractor.isExpectedZstandardPipeClosure(
        exitStatus: 70,
        terminationReason: .exit,
        stderr: "zstd: error 70: write error: broken pipe"
    ))
    #expect(!StandaloneArchiveExtractor.isExpectedZstandardPipeClosure(
        exitStatus: SIGPIPE,
        terminationReason: .exit,
        stderr: ""
    ))
    #expect(!StandaloneArchiveExtractor.isExpectedZstandardPipeClosure(
        exitStatus: SIGTERM,
        terminationReason: .uncaughtSignal,
        stderr: ""
    ))
}

@Test func standaloneZstandardExtractionProducesOneImplicitPlayableMember() async throws {
    let zstandardPath = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let zstandardPath else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-standalone-zst-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let source = root.appendingPathComponent("track.vgm")
    let archive = root.appendingPathComponent("track.vgm.zst")
    try Data("standalone-vgm-payload".utf8).write(to: source)

    let compressor = Process()
    compressor.executableURL = URL(fileURLWithPath: zstandardPath)
    compressor.arguments = ["-q", "-f", source.path, "-o", archive.path]
    try compressor.run()
    compressor.waitUntilExit()
    #expect(compressor.terminationStatus == 0)

    let extracted = try await StandaloneArchiveExtractor().extractForScan(archiveURL: archive)
    defer { StandaloneArchiveExtractor().discard(extracted) }
    #expect(extracted.members.map(\.entryPath) == ["track.vgm"])
    #expect(String(data: try Data(contentsOf: extracted.members[0].fileURL), encoding: .utf8) == "standalone-vgm-payload")
}

@Test func standaloneMDXZstandardMaterializesItsCompressedPDXSibling() async throws {
    let zstandardPath = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let zstandardPath else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-standalone-mdx-pdx-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var mdx = Data("[TITLE] Test MDX\r\n".utf8)
    mdx.append(contentsOf: [0x1A])
    mdx.append(contentsOf: Data("foo.pdx".utf8))
    mdx.append(0)
    mdx.append(contentsOf: [0, 0, 0, 0])
    let pdx = Data(repeating: 0x5A, count: 1_024)
    let rawMDX = root.appendingPathComponent("song.MDX")
    let rawPDX = root.appendingPathComponent("FOO.PDX")
    try mdx.write(to: rawMDX)
    try pdx.write(to: rawPDX)

    func compress(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zstandardPath)
        process.arguments = ["-q", "-f", source.path, "-o", destination.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    let mdxArchive = root.appendingPathComponent("song.MDX.zst")
    let pdxArchive = root.appendingPathComponent("FOO.PDX.zst")
    try compress(rawMDX, to: mdxArchive)
    try compress(rawPDX, to: pdxArchive)
    try FileManager.default.removeItem(at: rawMDX)
    try FileManager.default.removeItem(at: rawPDX)

    let report = try await ScanFilesystemDiscovery.discoverReport(
        rootID: 1,
        rootURL: root,
        registry: BuiltInScannerPlugins.registry,
        isArchive: StandaloneArchiveExtractor.isSupportedArchive
    )
    #expect(report.candidates.map(\.sourceURL.lastPathComponent) == ["song.MDX.zst"])

    let extracted = try await StandaloneArchiveExtractor().extractForScan(
        archiveURL: mdxArchive,
        registry: BuiltInScannerPlugins.registry
    )
    defer { StandaloneArchiveExtractor().discard(extracted) }
    #expect(extracted.members.map(\.entryPath) == ["song.MDX"])
    let materializedPDX = extracted.scratchURL
        .appendingPathComponent("payload", isDirectory: true)
        .appendingPathComponent("foo.pdx")
    #expect(try Data(contentsOf: materializedPDX) == pdx)
}

@Test func standaloneMDXResolvesRootScopedShiftJISPDXDependency() async throws {
    let zstandardPath = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let zstandardPath else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-mdx-root-pdx-\(UUID().uuidString)", isDirectory: true)
    let bankDirectory = root.appendingPathComponent("PDX Banks", isDirectory: true)
    try FileManager.default.createDirectory(at: bankDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let dependencyName = "音楽.pdx"
    var mdx = Data("[TITLE] Shift-JIS MDX\r\n".utf8)
    mdx.append(contentsOf: [0x1A])
    mdx.append(contentsOf: try #require(dependencyName.data(using: .shiftJIS)))
    mdx.append(0)
    mdx.append(contentsOf: [0, 0, 0, 0])
    let pdx = Data(repeating: 0x3C, count: 1_024)
    let rawMDX = root.appendingPathComponent("song.MDX")
    let rawPDX = bankDirectory.appendingPathComponent(dependencyName.uppercased())
    try mdx.write(to: rawMDX)
    try pdx.write(to: rawPDX)

    func compress(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zstandardPath)
        process.arguments = ["-q", "-f", source.path, "-o", destination.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    let mdxArchive = root.appendingPathComponent("song.MDX.zst")
    let pdxArchive = bankDirectory.appendingPathComponent("\(dependencyName.uppercased()).zst")
    try compress(rawMDX, to: mdxArchive)
    try compress(rawPDX, to: pdxArchive)
    try FileManager.default.removeItem(at: rawMDX)
    try FileManager.default.removeItem(at: rawPDX)

    let extracted = try await StandaloneArchiveExtractor().extractForScan(
        archiveURL: mdxArchive,
        registry: BuiltInScannerPlugins.registry,
        dependencySearchRoot: root
    )
    defer { StandaloneArchiveExtractor().discard(extracted) }
    let materializedPDX = extracted.scratchURL
        .appendingPathComponent("payload", isDirectory: true)
        .appendingPathComponent(dependencyName)
    #expect(try Data(contentsOf: materializedPDX) == pdx)
}

@Test func standaloneMDXNormalizesLegacyLeadingBackslashDependency() async throws {
    let zstandardPath = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let zstandardPath else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-mdx-legacy-pdx-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var mdx = Data("[TITLE] Legacy dependency\r\n".utf8)
    mdx.append(contentsOf: [0x1A])
    mdx.append(contentsOf: Data("\\bos".utf8))
    mdx.append(0)
    mdx.append(contentsOf: [0, 0, 0, 0])
    let pdx = Data(repeating: 0x4B, count: 1_024)
    let rawMDX = root.appendingPathComponent("song.MDX")
    let rawPDX = root.appendingPathComponent("BOS.PDX")
    try mdx.write(to: rawMDX)
    try pdx.write(to: rawPDX)

    func compress(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zstandardPath)
        process.arguments = ["-q", "-f", source.path, "-o", destination.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    let mdxArchive = root.appendingPathComponent("song.MDX.zst")
    let pdxArchive = root.appendingPathComponent("BOS.PDX.zst")
    try compress(rawMDX, to: mdxArchive)
    try compress(rawPDX, to: pdxArchive)
    try FileManager.default.removeItem(at: rawMDX)
    try FileManager.default.removeItem(at: rawPDX)

    let extracted = try await StandaloneArchiveExtractor().extractForScan(
        archiveURL: mdxArchive,
        registry: BuiltInScannerPlugins.registry
    )
    defer { StandaloneArchiveExtractor().discard(extracted) }
    #expect(extracted.members.map(\.entryPath) == ["song.MDX"])
    let materializedPDX = extracted.scratchURL
        .appendingPathComponent("payload", isDirectory: true)
        .appendingPathComponent("bos.pdx")
    #expect(try Data(contentsOf: materializedPDX) == pdx)
}

@Test func standaloneMDXResolvesExplicitAlternateDependencyFromScanRoot() async throws {
    let zstandardPath = ["/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd"]
        .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    guard let zstandardPath else { return }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-mdx-root-smp-\(UUID().uuidString)", isDirectory: true)
    let bankDirectory = root.appendingPathComponent("Alternate Banks", isDirectory: true)
    try FileManager.default.createDirectory(at: bankDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var mdx = Data("[TITLE] Alternate dependency\r\n".utf8)
    mdx.append(contentsOf: [0x1A])
    mdx.append(contentsOf: Data("nos.smp".utf8))
    mdx.append(0)
    mdx.append(contentsOf: [0, 0, 0, 0])
    let smp = Data(repeating: 0x46, count: 1_024)
    let rawMDX = root.appendingPathComponent("song.MDX")
    let rawSMP = bankDirectory.appendingPathComponent("NOS.SMP")
    try mdx.write(to: rawMDX)
    try smp.write(to: rawSMP)

    func compress(_ source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zstandardPath)
        process.arguments = ["-q", "-f", source.path, "-o", destination.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
    let mdxArchive = root.appendingPathComponent("song.MDX.zst")
    let smpArchive = bankDirectory.appendingPathComponent("NOS.SMP.zst")
    try compress(rawMDX, to: mdxArchive)
    try compress(rawSMP, to: smpArchive)
    try FileManager.default.removeItem(at: rawMDX)
    try FileManager.default.removeItem(at: rawSMP)

    let extracted = try await StandaloneArchiveExtractor().extractForScan(
        archiveURL: mdxArchive,
        registry: BuiltInScannerPlugins.registry,
        dependencySearchRoot: root
    )
    defer { StandaloneArchiveExtractor().discard(extracted) }
    #expect(extracted.members.map(\.entryPath) == ["song.MDX"])
    #expect(extracted.skippedMembers.isEmpty)
    let materializedSMP = extracted.scratchURL
        .appendingPathComponent("payload", isDirectory: true)
        .appendingPathComponent("nos.smp")
    #expect(try Data(contentsOf: materializedSMP) == smp)
}

@Test(
    "JoshW Resident Evil 2 tar.zst scans all PSF members and reports progress",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_RE2_ARCHIVE"] != nil,
        "Set SCANSONG_RE2_ARCHIVE to run the JoshW Resident Evil 2 archive check."
    )
)
func joshWResidentEvil2ArchiveScansThroughTarZstandard() async throws {
    let archivePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_RE2_ARCHIVE"])
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-re2-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let archiveURL = root.appendingPathComponent("Resident Evil 2.tar.zst")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: archivePath), to: archiveURL)

    let progress = ProgressCapture()
    let databaseURL = root.appendingPathComponent("Library.sqlite")
    let result = try await CatalogScanner(
        databaseURL: databaseURL,
        inspectionPermits: 4,
        archivePipelineLimit: 1
    ).scan(rootURL: root, mode: .newScan) { progress.append($0) }

    #expect(result.discoveredSourceCount == 1)
    #expect(result.trackCount == 75)
    #expect(result.failures.isEmpty)
    #expect(result.skipped.isEmpty)

    let updates = progress.values()
    #expect(updates.contains { $0.phase == .archiveListing })
    #expect(updates.contains { $0.phase == .materialization })
    #expect(updates.contains { $0.phase == .persistence && $0.processed == 1 && $0.discovered == 1 })
    #expect(updates.last?.processed == 1)
    #expect(updates.last?.discovered == 1)

    var database: OpaquePointer?
    #expect(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    let row = try querySingleRow(
        database: try #require(database),
        sql: "SELECT m.play_length_ms, m.fade_length_ms FROM tracks t INNER JOIN track_metadata m ON m.track_id=t.id WHERE t.archive_entry='11 Secure Place.psf';"
    )
    sqlite3_close(database)
    #expect(row == ["43000", "10000"])
}

@Test(
    "JoshW Dungeons and Dragons QSF archive scans all miniQSF members",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_QSF_ARCHIVE"] != nil,
        "Set SCANSONG_QSF_ARCHIVE to run the archive-backed QSF scanner check."
    )
)
func joshWQSFArchiveScansAllMiniQSFMembers() async throws {
    let archivePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_QSF_ARCHIVE"])
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-qsf-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let archiveURL = root.appendingPathComponent("Dungeons & Dragons QSF.tar.zst")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: archivePath), to: archiveURL)

    let result = try await CatalogScanner(
        databaseURL: root.appendingPathComponent("Library.sqlite"),
        inspectionPermits: 4,
        archivePipelineLimit: 1
    ).scan(rootURL: root, mode: .newScan)

    #expect(result.discoveredSourceCount == 1)
    #expect(result.trackCount == 39)
    #expect(result.failures.isEmpty)
    #expect(result.skipped.isEmpty)
}

@Test(
    "JoshW Resident Evil 2 GameCube archive resolves underscore TXTH aliases",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_RE2_GAMECUBE_ARCHIVE"] != nil,
        "Set SCANSONG_RE2_GAMECUBE_ARCHIVE to run the archive-backed GameCube LDAT check."
    )
)
func joshWResidentEvil2GameCubeArchiveResolvesTXTHAliases() async throws {
    let archivePath = try #require(ProcessInfo.processInfo.environment["SCANSONG_RE2_GAMECUBE_ARCHIVE"])
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-re2-gc-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let archiveURL = root.appendingPathComponent("Resident Evil 2 GameCube.7z")
    try FileManager.default.copyItem(at: URL(fileURLWithPath: archivePath), to: archiveURL)

    let result = try await CatalogScanner(
        databaseURL: root.appendingPathComponent("Library.sqlite"),
        inspectionPermits: 4,
        archivePipelineLimit: 1
    ).scan(rootURL: root, mode: .newScan)

    #expect(result.discoveredSourceCount == 1)
    #expect(result.failures.isEmpty)
    #expect(result.trackCount >= 131)
}
