import Foundation
import Testing
@testable import MetaManCore

@Test("NSF and GBS headers produce complete ordered MetaMan track documents")
func fixedHeaderGameMusicReadersPreserveIdentityAndNativeFacts() throws {
    let nsf = makeNSF()
    let nsfResult = try MetaManCore.readResult(data: nsf, formatHint: ".NSF", displayName: "game.nsf")
    #expect(nsfResult.tracks.count == 3)
    #expect(nsfResult.tracks.map(\.sourceTrackIndex) == [0, 1, 2])
    let nsfDocument = nsfResult.tracks[0].document
    #expect(nsfDocument.format == "nsf")
    #expect(nsfDocument.fields.game == "NSF Game")
    #expect(nsfDocument.fields.artist == "Composer")
    #expect(nsfDocument.fields.comment == "Copyright")
    #expect(nsfDocument.fields.system == "Nintendo NES")
    #expect(nsfDocument.timing == MetadataTiming(introLengthMs: -1, loopLengthMs: -1, playLengthMs: 150_000, fadeLengthMs: -1))
    #expect(nsfDocument.technicalFacts["loadAddress"] == "0x8000")
    #expect(nsfDocument.technicalFacts["firstTrack"] == "2")
    #expect(nsfDocument.rawMetadataBlocks?["fixed-header"] == Data(nsf.prefix(0x80)))

    let gbs = makeGBS()
    let gbsResult = try MetaManCore.readResult(data: gbs, displayName: "game.gbs")
    #expect(gbsResult.tracks.count == 2)
    #expect(gbsResult.tracks.map(\.sourceTrackIndex) == [0, 1])
    let gbsDocument = gbsResult.tracks[0].document
    #expect(gbsDocument.format == "gbs")
    #expect(gbsDocument.fields.game == "GBS Game")
    #expect(gbsDocument.fields.artist == "Author")
    #expect(gbsDocument.fields.system == "Nintendo Game Boy")
    #expect(gbsDocument.technicalFacts["stackAddress"] == "0xDFFF")
    #expect(gbsDocument.technicalFacts["timerModulo"] == "0xAA")
    #expect(gbsDocument.technicalFacts["timerControl"] == "0x05")
    #expect(gbsDocument.rawMetadataBlocks?["fixed-header"] == Data(gbs.prefix(0x70)))

    do {
        _ = try MetaManCore.read(data: nsf, formatHint: "nsf", displayName: "game.nsf")
        Issue.record("The single-document API must reject track-aware NSF results.")
    } catch let error as MetadataReadError {
        #expect(error == .trackAwareResultRequired("NSF"))
    }
    do {
        _ = try MetaManCore.read(data: gbs, formatHint: "gbs", displayName: "game.gbs")
        Issue.record("The single-document API must reject track-aware GBS results.")
    } catch let error as MetadataReadError {
        #expect(error == .trackAwareResultRequired("GBS"))
    }
}

@Test("NSFE preserves playlist repetitions, source indices, tags, timing, and raw non-audio chunks")
func nsfeReaderPreservesOrderedTrackDocumentsAndSourceFacts() throws {
    let source = makeNSFE()
    let result = try MetaManCore.readResult(data: source, formatHint: "nsfe", displayName: "fixture.nsfe")
    #expect(result.tracks.map(\.sourceTrackIndex) == [2, 0, 2])
    #expect(result.tracks.map { $0.document.fields.title } == ["Third", "First", "Third"])
    #expect(result.tracks.map { $0.document.fields.artist } == ["Third Author", "First Author", "Third Author"])
    #expect(result.tracks.map { $0.document.fields.game } == ["NSFE Game", "NSFE Game", "NSFE Game"])
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [150_000, 1_000, 150_000])
    #expect(result.tracks.map { $0.document.timing?.fadeLengthMs } == [-1, 100, -1])
    #expect(result.tracks[0].document.fields.comment == "Copyright: Copyright\nRipped by: Ripper\nfixture notes")
    #expect(result.tracks[0].document.fields.copyright == "Copyright")
    #expect(result.tracks[0].document.fields.encodedBy == "Ripper")
    #expect(result.tracks[0].document.technicalFacts["dataByteCount"] == "2")
    #expect(result.tracks[0].document.technicalFacts["soundEffectSourceTrackIndices"] == "1")
    #expect(result.tracks[0].document.values(forTag: "track-author") == ["Third Author"])

    let rawChunks = try #require(result.tracks[0].document.rawMetadataBlocks?["non-audio-chunks"])
    #expect(rawChunks.starts(with: Data("NSFE".utf8)))
    #expect(rawChunks.range(of: Data("meta".utf8)) != nil)
    #expect(rawChunks.range(of: Data([0xEA, 0x60])) == nil)
    #expect(rawChunks.count == source.count - 10)

    do {
        _ = try MetaManCore.read(data: source, formatHint: "nsfe", displayName: "fixture.nsfe")
        Issue.record("The single-document API must reject track-aware NSFE results.")
    } catch let error as MetadataReadError {
        #expect(error == .trackAwareResultRequired("NSFE"))
    }
}

@Test("GBS extended M3U companions add authored track titles and timing")
func gbsReaderProjectsNEZPlugPlaylistMetadata() throws {
    let m3u = """
    # @TITLE Fixture Album
    # @ARTIST Test Publisher
    # @COMPOSER Test Composer
    # @DATE 2000-01-02

    fixture.gbs::GBS,0,Opening\\, theme,0:42,0:20,0:05,3
    other.gbs::GBS,1,Unrelated,1:00,,10
    """
    let context = MetadataReadContext(companionFiles: [
        MetadataCompanionFile(relativePath: "01 Opening.m3u", data: Data(m3u.utf8))
    ])
    let result = try MetaManCore.readResult(
        data: makeGBS(),
        formatHint: "gbs",
        displayName: "fixture.gbs",
        context: context
    )

    #expect(result.tracks.count == 2)
    let first = result.tracks[0].document
    #expect(first.fields.title == "Opening, theme")
    #expect(first.fields.game == "Fixture Album")
    #expect(first.fields.artist == "Test Publisher")
    #expect(first.fields.date == "2000-01-02")
    #expect(first.timing == MetadataTiming(introLengthMs: -1, loopLengthMs: 20_000, playLengthMs: 42_000, fadeLengthMs: 5_000))
    #expect(first.technicalFacts["m3uLoopCount"] == "3")
    #expect(first.technicalFacts["m3uSourcePath"] == "01 Opening.m3u")
    #expect(first.rawMetadataBlocks?["companion-m3u"] == Data(m3u.utf8))
    #expect(first.tags.contains(MetadataTag(name: "COMPOSER", value: "Test Composer")))
    #expect(result.tracks[1].document.fields.title == nil)
    #expect(result.tracks[1].document.fields.game == "Fixture Album")
    #expect(result.tracks[1].document.fields.artist == "Test Publisher")
}

@Test("GBS file-URL reads discover sibling NEZPlug playlists")
func gbsFileURLReadDiscoversSiblingPlaylists() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-gbs-m3u-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let gbsURL = root.appendingPathComponent("fixture.gbs")
    let source = makeGBS()
    try source.write(to: gbsURL)
    try "fixture.gbs::GBS,0,File URL Track,1:23,,5\n"
        .write(to: root.appendingPathComponent("01 File URL Track.m3u"), atomically: true, encoding: .utf8)

    let result = try MetaManCore.readResult(fileURL: gbsURL)
    #expect(result.tracks[0].document.fields.title == "File URL Track")
    #expect(result.tracks[0].document.timing?.playLengthMs == 83_000)
    #expect(result.tracks[0].document.technicalFacts["m3uSourcePath"] == "01 File URL Track.m3u")
    #expect(try Data(contentsOf: gbsURL) == source)
}

@Test("NSF, GBS, and NSFE reject malformed headers and chunk boundaries")
func gameMusicReadersRejectMalformedSources() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data("bad".utf8), formatHint: "nsf", displayName: "bad.nsf")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data("GBS".utf8), displayName: "short.gbs")
    }

    var truncated = Data("NSFE".utf8)
    truncated.append(contentsOf: [0, 0, 0, 0, 0x49, 0x4E, 0x46, 0x4F])
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: truncated, displayName: "truncated.nsfe")
    }

    var unsupported = Data("NSFE".utf8)
    appendNSFEChunk(&unsupported, "INFO", Data([0, 0, 0, 0, 0, 0, 0, 0, 1]))
    appendNSFEChunk(&unsupported, "DATA", Data())
    appendNSFEChunk(&unsupported, "WXYZ", Data())
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: unsupported, displayName: "unsupported.nsfe")
    }
}

@Test(
    "NSFE fixture directory parses without playback",
    .enabled(
        if: ProcessInfo.processInfo.environment["METAMAN_NSFE_FIXTURE_DIR"] != nil,
        "Set METAMAN_NSFE_FIXTURE_DIR to run the corpus-backed NSFE reader check."
    )
)
func nsfeFixtureDirectoryParsesWithoutPlayback() throws {
    let directoryPath = try #require(ProcessInfo.processInfo.environment["METAMAN_NSFE_FIXTURE_DIR"])
    let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "nsfe" }
    #expect(!files.isEmpty)
    for file in files {
        let result = try MetaManCore.readResult(fileURL: file)
        #expect(!result.tracks.isEmpty)
        #expect(result.tracks.allSatisfy { $0.document.format == "nsfe" })
    }
}

private func makeNSF() -> Data {
    var data = Data(repeating: 0, count: 0x80)
    data.replaceSubrange(0..<5, with: Data([0x4E, 0x45, 0x53, 0x4D, 0x1A]))
    data[0x05] = 1
    data[0x06] = 3
    data[0x07] = 2
    writeLE16(&data, 0x08, 0x8000)
    writeLE16(&data, 0x0A, 0x8003)
    writeLE16(&data, 0x0C, 0x8006)
    writeText(&data, 0x0E, "NSF Game")
    writeText(&data, 0x2E, "Composer")
    writeText(&data, 0x4E, "Copyright")
    return data
}

private func makeGBS() -> Data {
    var data = Data(repeating: 0, count: 0x70)
    data.replaceSubrange(0..<3, with: Data("GBS".utf8))
    data[0x03] = 1
    data[0x04] = 2
    data[0x05] = 1
    writeLE16(&data, 0x06, 0x4000)
    writeLE16(&data, 0x08, 0x4100)
    writeLE16(&data, 0x0A, 0x4200)
    writeLE16(&data, 0x0C, 0xDFFF)
    data[0x0E] = 0xAA
    data[0x0F] = 0x05
    writeText(&data, 0x10, "GBS Game")
    writeText(&data, 0x30, "Author")
    return data
}

private func makeNSFE() -> Data {
    var data = Data("NSFE".utf8)
    appendNSFEChunk(&data, "INFO", Data([0x00, 0x80, 0x03, 0x80, 0x06, 0x80, 0x01, 0x02, 0x03, 0x00]))
    appendNSFEChunk(&data, "auth", Data("NSFE Game\0Artist\0Copyright\0Ripper\0".utf8))
    appendNSFEChunk(&data, "tlbl", Data("First\0Second\0Third\0".utf8))
    appendNSFEChunk(&data, "taut", Data("First Author\0\0Third Author\0".utf8))
    appendNSFEChunk(&data, "time", le32(1_000) + le32(UInt32(bitPattern: Int32(-1))) + le32(0))
    appendNSFEChunk(&data, "fade", le32(100) + le32(200) + le32(UInt32(bitPattern: Int32(-1))))
    appendNSFEChunk(&data, "plst", Data([2, 0, 2]))
    appendNSFEChunk(&data, "psfx", Data([1]))
    appendNSFEChunk(&data, "text", Data("fixture notes\0".utf8))
    appendNSFEChunk(&data, "meta", Data([1, 2, 3]))
    appendNSFEChunk(&data, "DATA", Data([0xEA, 0x60]))
    appendNSFEChunk(&data, "NEND", Data())
    return data
}

private func appendNSFEChunk(_ data: inout Data, _ identifier: String, _ payload: Data) {
    data.append(le32(UInt32(payload.count)))
    data.append(contentsOf: identifier.utf8)
    data.append(payload)
}

private func writeLE16(_ data: inout Data, _ offset: Int, _ value: UInt16) {
    data[offset] = UInt8(value & 0xFF)
    data[offset + 1] = UInt8(value >> 8)
}

private func writeText(_ data: inout Data, _ offset: Int, _ value: String) {
    data.replaceSubrange(offset..<(offset + value.utf8.count), with: value.utf8)
}

private func le32(_ value: UInt32) -> Data {
    Data((0..<4).map { UInt8((value >> ($0 * 8)) & 0xFF) })
}
