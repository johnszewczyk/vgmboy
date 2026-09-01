import Darwin
import Foundation
import SQLite3
import Testing
import zlib
@testable import ScanSongKit

@Test func builtInPoliciesPreserveRequiredStructureWork() throws {
    let registry = BuiltInScannerPlugins.registry
    #expect(registry.route(pathExtension: "spc")?.metadataPolicy == .direct)
    #expect(registry.route(pathExtension: ".NSF")?.structurePolicy == .enumerate)
    #expect(registry.route(pathExtension: "gbs")?.structurePolicy == .enumerate)
    #expect(registry.route(pathExtension: "flac")?.metadataPolicy == .direct)
    #expect(registry.route(pathExtension: "txtp")?.structurePolicy == .dependencyEnumerate)
    #expect(registry.route(pathExtension: "sid")?.structurePolicy == .knownSingle)
    #expect(registry.route(pathExtension: "sid")?.metadataPolicy == .direct)
    #expect(registry.route(pathExtension: "sndh")?.pluginID == "psgplay")
    #expect(registry.route(pathExtension: "sndh")?.structurePolicy == .enumerate)
    #expect(registry.route(pathExtension: "sndh")?.metadataPolicy == .direct)
    #expect(registry.route(pathExtension: "mdx")?.pluginID == "mdx")
    #expect(registry.route(pathExtension: "mdx")?.structurePolicy == .knownSingle)
    #expect(registry.route(pathExtension: "pdx") == nil)
    #expect(registry.route(pathExtension: "ape")?.pluginID == "ffmpeg-audio")
    #expect(registry.route(pathExtension: "ape")?.metadataPolicy == .decoder)
    #expect(registry.route(forPath: "/tmp/mod.xpose-end")?.pluginID == "amiga-uade")
    #expect(registry.route(forPath: "/tmp/p4x.earth")?.pluginID == "amiga-uade")
    #expect(registry.route(forPath: "/tmp/music.mod")?.pluginID == "openmpt")
    #expect(registry.route(forPath: "/tmp/stage.p4x") == nil)
    #expect(registry.route(pathExtension: "ogg")?.metadataPolicy == .direct)
    #expect(registry.route(pathExtension: "ogg")?.pluginID == "standard-audio")
    #expect(registry.route(pathExtension: "ogg")?.pluginID != "vgmstream")
    #expect(registry.route(pathExtension: "qsf")?.pluginID == "qsf")
    #expect(registry.route(pathExtension: "miniqsf")?.pluginID == "qsf-mini")
    #expect(registry.route(pathExtension: "miniqsf")?.structurePolicy == .dependencyEnumerate)
    #expect(BuiltInScannerPlugins.archiveExtensions.contains("zst"))
    #expect(BuiltInScannerPlugins.archiveExtensions.contains("lha"))
    #expect(StandaloneArchiveExtractor.isSupportedArchive(URL(fileURLWithPath: "track.vgm.zst")))
    #expect(StandaloneArchiveExtractor.isSupportedArchive(URL(fileURLWithPath: "amiga.lha")))
    #expect(StandaloneArchiveExtractor.isSupportedArchive(URL(fileURLWithPath: "set.tar.zst")))
    #expect(StandaloneArchiveExtractor.isStandaloneSupportFile(URL(fileURLWithPath: "bank.PDX.zst")))
    for sidecar in ["bank.2sflib.zst", "bank.ssflib.zst", "bank.usflib.zst"] {
        #expect(StandaloneArchiveExtractor.isStandaloneSupportFile(URL(fileURLWithPath: sidecar)))
    }
    for documentation in ["album.htm.zst", "album.html.zstd"] {
        #expect(StandaloneArchiveExtractor.isStandaloneSupportFile(URL(fileURLWithPath: documentation)))
    }
    #expect(!StandaloneArchiveExtractor.isStandaloneSupportFile(URL(fileURLWithPath: "track.MDX.zst")))
    #expect(StandaloneArchiveExtractor.standaloneEntryPath(
        for: URL(fileURLWithPath: "track.vgm.zst"),
        registry: registry
    ) == "track.vgm")
    #expect(StandaloneArchiveExtractor.standaloneEntryPath(
        for: URL(fileURLWithPath: "set.tar.zst"),
        registry: registry
    ) == nil)
    #expect(registry.route(pathExtension: "strm")?.pluginID == "vgmstream")
    #expect(registry.route(pathExtension: "ahx")?.pluginID == "vgmstream")
    #expect(registry.route(pathExtension: "xmd")?.pluginID == "vgmstream")
    #expect(registry.route(pathExtension: "hd")?.pluginID == "vgmstream-hd-bank")
    for ext in BuiltInScannerPlugins.gameCubeVGMStreamExtensions {
        #expect(registry.route(pathExtension: ext)?.pluginID == "vgmstream")
    }
    #expect(registry.route(pathExtension: "txth") == nil)
    #expect(registry.route(pathExtension: "sbb") == nil)
    #expect(ScannerFormatPolicy.defaultIgnoredExtensions.contains("sgc"))
    #expect(ScannerFormatPolicy.defaultIgnoredExtensions.contains("minincsf"))
    #expect(ScannerFormatPolicy.defaultIgnoredExtensions.contains("mus"))
}
@Test(
    "Amiga fixture publishes UADE replayer tracks",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_AMIGA_FIXTURE"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_AMIGA_INSPECT"] != nil,
        "Set SCANSONG_AMIGA_FIXTURE and SCANSONG_AMIGA_INSPECT to run the UADE scanner check."
    )
)
func amigaFixtureInspectsThroughUADE() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_AMIGA_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    #expect(inspection.tracks.count > 0)
    #expect(inspection.tracks.allSatisfy { $0.trackCount == inspection.tracks.count })
    #expect(inspection.tracks.map(\.trackIndex) == Array(0..<inspection.tracks.count))
    #expect(inspection.tracks.allSatisfy { $0.metadata?.system == "Commodore Amiga" })
}

@Test(
    "APE fixture publishes native FFmpeg duration and tags",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_APE_FIXTURE"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_FFMPEG_INSPECT"] != nil,
        "Set SCANSONG_APE_FIXTURE and SCANSONG_FFMPEG_INSPECT to run the APE scanner check."
    )
)
func apeFixtureInspectsThroughFFmpeg() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_APE_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    let metadata = try #require(inspection.tracks.first?.metadata)
    #expect(inspection.tracks.count == 1)
    #expect(metadata.playLengthMs > 30_000)
    #expect(metadata.song.lowercased().contains("credit"))
    #expect(metadata.game.contains("NeuroDancer") || metadata.game.isEmpty)
}

@Test(
    "MDX fixture publishes one native-duration track",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_MDX_FIXTURE"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_MDX_INSPECT"] != nil,
        "Set SCANSONG_MDX_FIXTURE and SCANSONG_MDX_INSPECT to run the MDX scanner check."
    )
)
func mdxFixtureInspectsThroughVGMBoy() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_MDX_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: fileURL.pathExtension))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect(inspection.tracks.first?.trackIndex == 0)
    #expect(inspection.tracks.first?.trackCount == 1)
    #expect((inspection.tracks.first?.metadata?.playLengthMs ?? 0) > 0)
    #expect(inspection.tracks.first?.metadata?.system == "Sharp X68000")
}

@Test(
    "MDX LZX fixture is decoded before scanner inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_MDX_LZX_FIXTURE"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_MDX_INSPECT"] != nil,
        "Set SCANSONG_MDX_LZX_FIXTURE and SCANSONG_MDX_INSPECT to run the real X68000 LZX check."
    )
)
func mdxLZXFixtureInspectsThroughVGMBoy() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_MDX_LZX_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: fileURL.pathExtension))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    #expect(inspection.tracks.count == 1)
    #expect((inspection.tracks.first?.metadata?.playLengthMs ?? 0) > 0)
    #expect(inspection.tracks.first?.metadata?.system == "Sharp X68000")
}

@Test(
    "MDX archive fixture materializes its PDX dependency before inspection",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_MDX_ARCHIVE_FIXTURE"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_MDX_ROOT"] != nil
            && ProcessInfo.processInfo.environment["SCANSONG_MDX_INSPECT"] != nil,
        "Set SCANSONG_MDX_ARCHIVE_FIXTURE, SCANSONG_MDX_ROOT, and SCANSONG_MDX_INSPECT to run the archive-backed MDX check."
    )
)
func mdxArchiveFixtureMaterializesDependency() async throws {
    let archiveURL = URL(fileURLWithPath: try #require(
        ProcessInfo.processInfo.environment["SCANSONG_MDX_ARCHIVE_FIXTURE"]
    ))
    let rootURL = URL(fileURLWithPath: try #require(
        ProcessInfo.processInfo.environment["SCANSONG_MDX_ROOT"]
    ))
    let extracted = try await StandaloneArchiveExtractor().extractForScan(
        archiveURL: archiveURL,
        registry: BuiltInScannerPlugins.registry,
        dependencySearchRoot: rootURL
    )
    defer { StandaloneArchiveExtractor().discard(extracted) }

    let member = try #require(extracted.members.first)
    #expect(extracted.members.count == 1)
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: member.route))
    let inspection = try await handler.inspect(fileURL: member.fileURL, route: member.route)
    #expect(inspection.tracks.count == 1)
    #expect((inspection.tracks.first?.metadata?.playLengthMs ?? 0) > 0)
    #expect(inspection.tracks.first?.metadata?.system == "Sharp X68000")
}

@Test func mdxInspectorReportsMissingPDXBeforeInvokingAdapter() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-mdx-missing-pdx-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var mdx = Data("[TITLE] Missing dependency\r\n".utf8)
    mdx.append(0x1A)
    mdx.append(contentsOf: Data("missing.pdx".utf8))
    mdx.append(0)
    let fileURL = root.appendingPathComponent("missing.MDX")
    try mdx.write(to: fileURL)

    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "mdx"))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    do {
        _ = try await handler.inspect(fileURL: fileURL, route: route)
        Issue.record("MDX inspection unexpectedly proceeded without its required PDX dependency")
    } catch let error as ScannerInspectionError {
        #expect(error.errorDescription == "Required MDX dependency is missing: missing.pdx.")
    } catch {
        Issue.record("Unexpected MDX inspection error: \(error.localizedDescription)")
    }
}

@Test func mdxDependencyReaderInfersPDXOnlyForExtensionlessReferences() {
    func mdxData(for dependency: String) -> Data {
        var data = Data("[TITLE] Dependency test\r\n".utf8)
        data.append(contentsOf: [0x1A])
        data.append(contentsOf: Data(dependency.utf8))
        data.append(0)
        return data
    }

    #expect(MDXDependencyReader.dependencyName(in: mdxData(for: "nos")) == "nos.pdx")
    #expect(MDXDependencyReader.dependencyName(in: mdxData(for: "nos.smp")) == "nos.smp")
    #expect(MDXDependencyReader.dependencyName(in: mdxData(for: "thrice.pcm")) == "thrice.pcm")
    #expect(MDXDependencyReader.dependencyName(in: mdxData(for: "konami.mdx")) == "konami.mdx")
}

@Test(
    "SNDH fixture publishes PSGPlay subtunes and timing",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_SNDH_FIXTURE"] != nil,
        "Set SCANSONG_SNDH_FIXTURE to run the Zone Warrior scanner check."
    )
)
func sndhFixtureInspectsThroughPSGPlay() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_SNDH_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: fileURL.pathExtension))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    #expect(!inspection.tracks.isEmpty)
    #expect(inspection.tracks.allSatisfy { $0.trackCount == inspection.tracks.count })
    #expect(inspection.tracks.map(\.trackIndex) == Array(0..<inspection.tracks.count))
    #expect(inspection.tracks.allSatisfy { ($0.metadata?.playLengthMs ?? 0) > 0 })
    #expect(inspection.tracks.first?.metadata?.system == "Atari ST")
}

@Test(
    "HES fixture applies its sibling M3U to publish authored music and SFX",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_HES_FIXTURE"] != nil,
        "Set SCANSONG_HES_FIXTURE to run the archive-backed Bloody Wolf HES check."
    )
)
func hesFixtureInspectsCompanionPlaylist() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_HES_FIXTURE"])
    let fileURL = URL(fileURLWithPath: path)
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: fileURL.pathExtension))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)

    #expect(inspection.tracks.count == 17)
    #expect(inspection.tracks[0].metadata?.song == "Title")
    #expect(inspection.tracks[0].metadata?.playLengthMs == 20_000)
    #expect(inspection.tracks[12].metadata?.song == "Stage Clear")
    #expect(inspection.tracks[12].metadata?.playLengthMs == 4_000)
}

@Test(
    "Core Audio inspection publishes FLAC metadata and duration",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_FLAC_FIXTURE"] != nil,
        "Set SCANSONG_FLAC_FIXTURE to run the archive-backed FLAC metadata check."
    )
)
func flacFixturePublishesStandardMetadata() async throws {
    let path = try #require(ProcessInfo.processInfo.environment["SCANSONG_FLAC_FIXTURE"])
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "flac"))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: URL(fileURLWithPath: path), route: route)
    let metadata = try #require(inspection.tracks.first?.metadata)
    #expect(metadata.system == "Standard audio")
    #expect(metadata.song == "Credits")
    #expect(metadata.game == "NeuroDancer - Journey into the Neuronet!")
    #expect(metadata.playLengthMs > 0)
}

@Test(
    "GameCube routes open through the bundled inspector with real timing",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_GAMECUBE_FIXTURES"] != nil,
        "Set SCANSONG_GAMECUBE_FIXTURES to run the archive-backed GameCube scanner checks."
    )
)
func gameCubeFixturesInspectThroughVGMStream() async throws {
    let rootPath = try #require(ProcessInfo.processInfo.environment["SCANSONG_GAMECUBE_FIXTURES"])
    let root = URL(fileURLWithPath: rootPath, isDirectory: true)
    let enumerator = try #require(FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsPackageDescendants]
    ))
    let admitted = BuiltInScannerPlugins.gameCubeVGMStreamExtensions.union(["txtp"])
    let fixtures = enumerator.compactMap { $0 as? URL }.filter {
        admitted.contains($0.pathExtension.lowercased())
    }
    #expect(Set(fixtures.map { $0.pathExtension.lowercased() }) == admitted)

    for fixture in fixtures.sorted(by: { $0.path < $1.path }) {
        let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: fixture.pathExtension))
        let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
        let inspection = try await handler.inspect(fileURL: fixture, route: route)
        #expect(!inspection.tracks.isEmpty, Comment(rawValue: fixture.lastPathComponent))
        #expect(inspection.tracks.allSatisfy {
            ($0.metadata?.playLengthMs ?? 0) > 0
        }, Comment(rawValue: fixture.lastPathComponent))
    }
}

@Test func sidHeaderReaderPublishesCommodore64Metadata() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-sid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    var header = Data(repeating: 0, count: 0x7C)
    header.replaceSubrange(0..<4, with: Data("PSID".utf8))
    header[0x04] = 0; header[0x05] = 2            // version 2
    header[0x06] = 0; header[0x07] = 0x7C          // data offset
    header[0x08] = 0x08; header[0x09] = 0x00       // load address
    header[0x0E] = 0; header[0x0F] = 1             // number of songs
    header[0x10] = 0; header[0x11] = 1             // start song
    let name = Data("Willow".utf8); header.replaceSubrange(0x16..<(0x16 + name.count), with: name)
    let author = Data("Tester".utf8); header.replaceSubrange(0x2E..<(0x2E + author.count), with: author)
    header[0x76] = 0; header[0x77] = 30            // PAL play length 30s
    header[0x78] = 0; header[0x79] = 0

    let fileURL = root.appendingPathComponent("Willow.sid")
    try header.write(to: fileURL)

    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "sid"))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    let metadata = try #require(inspection.tracks.first?.metadata)
    #expect(inspection.tracks.count == 1)
    #expect(metadata.system == "Commodore 64")
    #expect(metadata.song == "Willow")
    #expect(metadata.author == "Tester")
    #expect(metadata.playLengthMs == 30_000)
}

@Test func psfStyleReaderHarvestsQSFTagsAndTimingWithoutOpeningTheEngine() throws {
    var data = Data([0x50, 0x53, 0x46, 0x41])
    data.append(Data(repeating: 0, count: 12))
    data.append(Data("[TAG]\ntitle=Cyberbot\ngame=Cyberbots\nartist=Capcom\nlength=1:23.500\nfade=4.250\n".utf8))

    let fileURL = try writeSPCTestFile(data, name: "cyberbot.qsf")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let result = try #require(try PSFTagReader.readResult(fileURL: fileURL))

    #expect(result.tags["title"] == "Cyberbot")
    #expect(result.metadata.game == "Cyberbots")
    #expect(result.metadata.author == "Capcom")
    #expect(result.metadata.playLengthMs == 83_500)
    #expect(result.metadata.fadeLengthMs == 4_250)
}

@Test func gameMusicHeaderReaderHarvestsNSFAndGBSTextWithoutEmulation() throws {
    var nsf = Data(repeating: 0, count: 128)
    nsf.replaceSubrange(0..<5, with: Data([0x4E, 0x45, 0x53, 0x4D, 0x1A]))
    nsf[0x06] = 3
    writeBytes(&nsf, at: 0x0E, value: "Famicom Quest")
    writeBytes(&nsf, at: 0x2E, value: "Composer")
    writeBytes(&nsf, at: 0x4E, value: "1989")
    let nsfURL = try writeSPCTestFile(nsf, name: "quest.nsf")
    defer { try? FileManager.default.removeItem(at: nsfURL) }

    let nsfResult = try #require(try GameMusicMetadataReader.read(fileURL: nsfURL))
    #expect(nsfResult.trackCount == 3)
    #expect(nsfResult.metadata.game == "Famicom Quest")
    #expect(nsfResult.metadata.author == "Composer")
    #expect(nsfResult.metadata.comment == "1989")

    var gbs = Data(repeating: 0, count: 0x70)
    gbs.replaceSubrange(0..<3, with: Data("GBS".utf8))
    gbs[0x04] = 5
    writeBytes(&gbs, at: 0x10, value: "Pocket Quest")
    writeBytes(&gbs, at: 0x30, value: "Composer")
    let gbsURL = try writeSPCTestFile(gbs, name: "quest.gbs")
    defer { try? FileManager.default.removeItem(at: gbsURL) }

    let gbsResult = try #require(try GameMusicMetadataReader.read(fileURL: gbsURL))
    #expect(gbsResult.trackCount == 5)
    #expect(gbsResult.metadata.game == "Pocket Quest")
    #expect(gbsResult.metadata.system == "Nintendo Game Boy")
}

@Test func vgmAndVGZReadersHarvestNativeGD3AndTiming() async throws {
    var data = Data(repeating: 0, count: 0x40)
    data.replaceSubrange(0..<4, with: Data("Vgm ".utf8))
    writeLittleEndian(&data, at: 0x18, value: 44_100)
    writeLittleEndian(&data, at: 0x1C, value: 1)
    writeLittleEndian(&data, at: 0x20, value: 22_050)
    let gd3Strings = ["Song", "", "Game", "", "System", "", "Artist", "", "", "", "Comment"]
    var gd3Payload: [UInt8] = []
    for string in gd3Strings {
        for unit in string.utf16 {
            gd3Payload.append(UInt8(unit & 0xFF))
            gd3Payload.append(UInt8(unit >> 8))
        }
        gd3Payload.append(contentsOf: [0, 0])
    }
    var gd3 = Data("Gd3 ".utf8)
    gd3.append(contentsOf: [0x00, 0x01, 0x00, 0x00])
    gd3.append(contentsOf: littleEndianBytes(UInt32(gd3Payload.count)))
    gd3.append(contentsOf: gd3Payload)
    let gd3Offset = data.count - 0x14
    writeLittleEndian(&data, at: 0x14, value: UInt32(gd3Offset))
    data.append(gd3)

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-vgm-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let vgmURL = root.appendingPathComponent("Song.vgm")
    let vgzURL = root.appendingPathComponent("Song.vgz")
    try data.write(to: vgmURL)
    try writeGZip(data, to: vgzURL)

    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "vgm"))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    for fixture in [vgmURL, vgzURL] {
        let inspection = try await handler.inspect(
            fileURL: fixture,
            route: route
        )
        let metadata = try #require(inspection.tracks.first?.metadata)
        #expect(metadata.song == "Song")
        #expect(metadata.game == "Game")
        #expect(metadata.author == "Artist")
        #expect(metadata.playLengthMs == 1_000)
        #expect(metadata.loopLengthMs == 500)
    }
}

@Test func spcReaderParsesBinaryID666LengthAndFade() throws {
    var data = makeSPCFile(id666Flag: 0x1A)
    writeBytes(&data, at: 0x2E, value: "Binary Song")
    writeBytes(&data, at: 0x4E, value: "Binary Game")
    writeBytes(&data, at: 0x6E, value: "Binary Dumper")
    writeBytes(&data, at: 0xB0, value: "Binary Artist")

    // Binary ID666: seconds at 0xA9 as LE16 and fade milliseconds at 0xAC as LE24.
    data[0xA9] = 30
    data[0xAA] = 0
    data[0xAB] = 0
    data[0xAC] = 0x88
    data[0xAD] = 0x13
    data[0xAE] = 0
    data[0xAF] = 0

    let fileURL = try writeSPCTestFile(data, name: "binary.spc")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let metadata = try #require(try SPCMetadataReader.read(fileURL: fileURL))

    #expect(metadata.song == "Binary Song")
    #expect(metadata.game == "Binary Game")
    #expect(metadata.dumper == "Binary Dumper")
    #expect(metadata.author == "Binary Artist")
    #expect(metadata.playLengthMs == 30_000)
    #expect(metadata.fadeLengthMs == 5_000)
}

@Test func spcReaderParsesTextID666LengthAndFade() throws {
    var data = makeSPCFile(id666Flag: 0x1A)
    writeBytes(&data, at: 0x2E, value: "Text Song")
    writeBytes(&data, at: 0x6E, value: "Text Dumper")
    writeBytes(&data, at: 0x9E, value: "01/02/2003")
    writeBytes(&data, at: 0xA9, value: "045")
    writeBytes(&data, at: 0xAC, value: "00600")
    writeBytes(&data, at: 0xB1, value: "Text Artist")

    let fileURL = try writeSPCTestFile(data, name: "text.spc")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let metadata = try #require(try SPCMetadataReader.read(fileURL: fileURL))

    #expect(metadata.song == "Text Song")
    #expect(metadata.dumper == "Text Dumper")
    #expect(metadata.author == "Text Artist")
    #expect(metadata.playLengthMs == 45_000)
    #expect(metadata.fadeLengthMs == 600)
}

@Test func spcReaderAggregatesXID6SegmentsAndSkipsUnknownItems() throws {
    var data = makeSPCFile(id666Flag: 0x27)
    data.append(contentsOf: makeXID6Chunk(items: [
        makeXID6Item(id: 0x02, type: 1, payload: Array("xID6 Game".utf8)),
        makeXID6Item(id: 0x01, type: 1, payload: Array("xID6 Song".utf8)),
        makeXID6Item(id: 0x03, type: 1, payload: Array("xID6 Artist".utf8)),
        makeXID6Item(id: 0x04, type: 1, payload: Array("xID6 Dumper".utf8)),
        makeXID6Item(id: 0x55, type: 2, payload: [0xAA, 0xBB]),
        makeXID6Item(id: 0x30, type: 4, payload: littleEndianBytes(128_000)), // 2 seconds
        makeXID6Item(id: 0x31, type: 4, payload: littleEndianBytes(192_000)), // 3 seconds
        makeXID6Item(id: 0x32, type: 4, payload: littleEndianBytes(256_000)), // 4 seconds
        makeXID6Item(id: 0x33, type: 4, payload: littleEndianBytes(320_000)), // 5 seconds
        makeXID6Item(id: 0x35, type: 0, payload: [2, 0])
    ]))

    let fileURL = try writeSPCTestFile(data, name: "xid6.spc")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let metadata = try #require(try SPCMetadataReader.read(fileURL: fileURL))

    #expect(metadata.song == "xID6 Song")
    #expect(metadata.game == "xID6 Game")
    #expect(metadata.author == "xID6 Artist")
    #expect(metadata.dumper == "xID6 Dumper")
    #expect(metadata.introLengthMs == 2_000)
    #expect(metadata.loopLengthMs == 3_000)
    #expect(metadata.playLengthMs == 12_000) // intro + loop * 2 + end
    #expect(metadata.fadeLengthMs == 5_000)
}

@Test(
    "Archive-backed SPC fixtures publish native lengths",
    .enabled(
        if: ProcessInfo.processInfo.environment["SCANSONG_SPC_FIXTURES"] != nil,
        "Set SCANSONG_SPC_FIXTURES to run the archive-backed SPC metadata check."
    )
)
func spcFixturesPublishNativeLengths() async throws {
    let rootPath = try #require(ProcessInfo.processInfo.environment["SCANSONG_SPC_FIXTURES"])
    let route = try #require(BuiltInScannerPlugins.registry.route(pathExtension: "spc"))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let expectedLengths: [String: Int] = ["ar-01.spc": 62_000, "ar-02.spc": 83_000, "ar-12.spc": 6_000]

    for (name, expectedLength) in expectedLengths {
        let fixture = URL(fileURLWithPath: rootPath).appendingPathComponent(name)
        let inspection = try await handler.inspect(fileURL: fixture, route: route)
        let metadata = try #require(inspection.tracks.first?.metadata)
        #expect(metadata.playLengthMs == expectedLength, Comment(rawValue: name))
    }
}

@Test func catalogScannerPersistsTheNativeSPCPlayLength() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScanSong-spc-catalog-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let root = directory.appendingPathComponent("Library", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    var data = makeSPCFile(id666Flag: 0x1A)
    writeBytes(&data, at: 0x2E, value: "Stored SPC")
    writeBytes(&data, at: 0x6E, value: "Stored Dumper")
    data[0xA9] = 62
    data[0xAA] = 0
    data[0xAB] = 0
    try data.write(to: root.appendingPathComponent("Stored.spc"))

    let databaseURL = directory.appendingPathComponent("Library.sqlite")
    let result = try await CatalogScanner(databaseURL: databaseURL).scan(rootURL: root, mode: .newScan)
    #expect(result.trackCount == 1)
    #expect(result.failures.isEmpty)

    var database: OpaquePointer?
    #expect(sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    let row = try querySingleRow(
        database: try #require(database),
        sql: "SELECT play_length_ms, fade_length_ms, dumper FROM track_metadata LIMIT 1;"
    )
    sqlite3_close(database)
    #expect(row == ["62000", "0", "Stored Dumper"])
}
