import Foundation
import Testing
@testable import VGMBoyFormatDataCore

@Test func nsfAndGBSReadersHarvestCompleteFileHeadersWithoutPlayback() throws {
    var nsf = Data(repeating: 0, count: 0x80)
    nsf.replaceSubrange(0..<5, with: Data([0x4E, 0x45, 0x53, 0x4D, 0x1A]))
    nsf[0x05] = 1
    nsf[0x06] = 3
    nsf[0x07] = 2
    writeLittleEndian(&nsf, at: 0x08, value: 0x8000)
    writeLittleEndian(&nsf, at: 0x0A, value: 0x8003)
    writeLittleEndian(&nsf, at: 0x0C, value: 0x8006)
    writeText(&nsf, at: 0x0E, value: "NSF Game")
    writeText(&nsf, at: 0x2E, value: "Composer")
    writeText(&nsf, at: 0x4E, value: "Copyright")
    let nsfFacts = try #require(try GameMusicFormatDataReader.read(
        data: nsf,
        pathExtension: "nsf",
        displayName: "game.nsf"
    ))
    #expect(nsfFacts.format == .nsf)
    #expect(nsfFacts.trackCount == 3)
    #expect(nsfFacts.firstTrack == 2)
    #expect(nsfFacts.loadAddress == 0x8000)
    #expect(nsfFacts.metadata.game == "NSF Game")
    #expect(nsfFacts.metadata.author == "Composer")
    #expect(nsfFacts.metadata.comment == "Copyright")
    #expect(nsfFacts.metadata.introLengthMs == -1)
    #expect(nsfFacts.metadata.loopLengthMs == -1)
    #expect(nsfFacts.metadata.playLengthMs == 150_000)
    #expect(nsfFacts.metadata.fadeLengthMs == -1)

    var gbs = Data(repeating: 0, count: 0x70)
    gbs.replaceSubrange(0..<3, with: Data("GBS".utf8))
    gbs[0x03] = 1
    gbs[0x04] = 2
    gbs[0x05] = 1
    writeLittleEndian(&gbs, at: 0x06, value: 0x4000)
    writeLittleEndian(&gbs, at: 0x08, value: 0x4100)
    writeLittleEndian(&gbs, at: 0x0A, value: 0x4200)
    writeLittleEndian(&gbs, at: 0x0C, value: 0xDFFF)
    gbs[0x0E] = 0xAA
    gbs[0x0F] = 0x05
    writeText(&gbs, at: 0x10, value: "GBS Game")
    writeText(&gbs, at: 0x30, value: "Author")
    let gbsFacts = try #require(try GameMusicFormatDataReader.read(
        data: gbs,
        pathExtension: "gbs",
        displayName: "game.gbs"
    ))
    #expect(gbsFacts.format == .gbs)
    #expect(gbsFacts.trackCount == 2)
    #expect(gbsFacts.stackAddress == 0xDFFF)
    #expect(gbsFacts.timerModulo == 0xAA)
    #expect(gbsFacts.timerControl == 0x05)
    #expect(gbsFacts.metadata.game == "GBS Game")
    #expect(gbsFacts.metadata.author == "Author")
}

@Test func nsfeReaderHarvestsChunkMetadataAndPlaylistOrderWithoutPlayback() throws {
    var data = Data("NSFE".utf8)
    var info = [UInt8](repeating: 0, count: 10)
    info[0] = 0x00
    info[1] = 0x80
    info[2] = 0x03
    info[3] = 0x80
    info[4] = 0x06
    info[5] = 0x80
    info[6] = 0x01
    info[7] = 0x02
    info[8] = 0x03
    info[9] = 0x00
    appendNSFEChunk(&data, identifier: "INFO", payload: info)
    appendNSFEChunk(&data, identifier: "auth", payload: Array("NSFE Game\0Artist\0Copyright\0Ripper\0".utf8))
    appendNSFEChunk(&data, identifier: "tlbl", payload: Array("First\0Second\0Third\0".utf8))
    appendNSFEChunk(&data, identifier: "taut", payload: Array("First Author\0\0Third Author\0".utf8))
    appendNSFEChunk(&data, identifier: "time", payload: littleEndianBytes(1_000) + littleEndianBytes(UInt32(bitPattern: Int32(-1))) + littleEndianBytes(0))
    appendNSFEChunk(&data, identifier: "fade", payload: littleEndianBytes(100) + littleEndianBytes(200) + littleEndianBytes(UInt32(bitPattern: Int32(-1))))
    appendNSFEChunk(&data, identifier: "plst", payload: [2, 0, 2])
    appendNSFEChunk(&data, identifier: "text", payload: Array("fixture notes\0".utf8))
    appendNSFEChunk(&data, identifier: "meta", payload: [1, 2, 3])
    appendNSFEChunk(&data, identifier: "DATA", payload: [0xEA, 0x60])
    appendNSFEChunk(&data, identifier: "NEND", payload: [])

    let facts = try NSFEFormatDataReader.read(data: data, displayName: "fixture.nsfe")
    #expect(facts.trackCount == 3)
    #expect(facts.firstTrack == 0)
    #expect(facts.dataByteCount == 2)
    #expect(facts.gameTitle == "NSFE Game")
    #expect(facts.artist == "Artist")
    #expect(facts.copyright == "Copyright")
    #expect(facts.ripper == "Ripper")
    #expect(facts.notes == "fixture notes")
    #expect(facts.optionalChunks == [NSFEOptionalChunk(identifier: "meta", data: Data([1, 2, 3]))])
    #expect(facts.orderedTracks.map(\.sourceTrackIndex) == [2, 0, 2])
    #expect(facts.orderedTracks.map(\.title) == ["Third", "First", "Third"])
    #expect(facts.orderedTracks.map(\.author) == ["Third Author", "First Author", "Third Author"])
    #expect(facts.tracks[1].metadata.author == "Artist")
    #expect(facts.orderedTracks.map(\.timeMs) == [0, 1_000, 0])
    #expect(facts.orderedTracks.map(\.fadeMs) == [-1, 100, -1])
    #expect(facts.orderedTracks.map { $0.metadata.playLengthMs } == [150_000, 1_000, 150_000])
    #expect(facts.orderedTracks.map { $0.metadata.fadeLengthMs } == [-1, 100, -1])
    #expect(facts.orderedTracks.allSatisfy { $0.metadata.system == "Nintendo NES" })
    #expect(facts.orderedTracks[0].metadata.comment == "Copyright: Copyright\nRipped by: Ripper\nfixture notes")
}

@Test func nsfeReaderRejectsMalformedMandatoryStructure() throws {
    var truncated = Data("NSFE".utf8)
    truncated.append(contentsOf: [0, 0, 0, 0, 0x49, 0x4E, 0x46, 0x4F])
    #expect(throws: FormatDataError.self) {
        try NSFEFormatDataReader.read(data: truncated, displayName: "truncated.nsfe")
    }

    var unsupported = Data("NSFE".utf8)
    appendNSFEChunk(&unsupported, identifier: "INFO", payload: [0, 0, 0, 0, 0, 0, 0, 0, 1])
    appendNSFEChunk(&unsupported, identifier: "DATA", payload: [])
    appendNSFEChunk(&unsupported, identifier: "WXYZ", payload: [])
    #expect(throws: FormatDataError.self) {
        try NSFEFormatDataReader.read(data: unsupported, displayName: "unsupported.nsfe")
    }
}

@Test func hesReaderUsesHeaderTagsAndExtendedM3UWithoutPlayback() throws {
    var hes = makeHESData()
    writeHESTextField(&hes, at: 0x40, value: "Header Game")
    writeHESTextField(&hes, at: 0x60, value: "Header Composer")
    writeHESTextField(&hes, at: 0x80, value: "1990 Header Copyright")

    let playlist = """
    # Game: Bloody Wolf
    # Artist: Fixture Composer
    # Ripping: Test Set
    DE89003.hes, $0C, Title, 0:20.000, 0:05.000-, 0:02.000
    DE89003.hes, 2, Stage Clear, 0:04.000,, 0:01.000
    """
    let facts = try HESFormatDataReader.read(
        data: hes,
        playlistData: Data(playlist.utf8),
        displayName: "DE89003.hes"
    )

    #expect(facts.version == 1)
    #expect(facts.firstTrack == 3)
    #expect(facts.initAddress == 0x1234)
    #expect(facts.banks == Array(0x20..<0x28))
    #expect(facts.dataChunkTag == "DATA")
    #expect(facts.dataChunkSize == 0x1020)
    #expect(facts.dataAddress == 0x4000)
    #expect(facts.hasPlaylist)
    #expect(facts.trackCount == 2)
    #expect(facts.tracks.map(\.sourceTrackIndex) == [12, 1])
    #expect(facts.tracks.map { $0.metadata.game } == ["Bloody Wolf", "Bloody Wolf"])
    #expect(facts.tracks.map { $0.metadata.author } == ["Fixture Composer", "Fixture Composer"])
    #expect(facts.tracks.map { $0.metadata.song } == ["Title", "Stage Clear"])
    #expect(facts.tracks.map { $0.metadata.system } == ["PC Engine", "PC Engine"])
    #expect(facts.tracks.map { $0.metadata.playLengthMs } == [20_000, 4_000])
    #expect(facts.tracks[0].metadata.introLengthMs == 5_000)
    #expect(facts.tracks[0].metadata.loopLengthMs == 15_000)
    #expect(facts.tracks[0].metadata.fadeLengthMs == 2_000)
    #expect(facts.tracks[1].metadata.introLengthMs == -1)
    #expect(facts.tracks[1].metadata.loopLengthMs == -1)
    #expect(facts.tracks[1].metadata.fadeLengthMs == 1_000)
}

@Test func hesReaderPreservesTheNoPlaylistCompatibilityAddressSpace() throws {
    var hes = makeHESData()
    writeHESTextField(&hes, at: 0x40, value: "Header Game")
    writeHESTextField(&hes, at: 0x60, value: "Header Composer")

    let facts = try HESFormatDataReader.read(data: hes, displayName: "game.hes")
    #expect(!facts.hasPlaylist)
    #expect(facts.trackCount == 256)
    #expect(facts.tracks.map(\.sourceTrackIndex) == Array(0..<256))
    #expect(facts.tracks.allSatisfy { $0.metadata.game == "Header Game" })
    #expect(facts.tracks.allSatisfy { $0.metadata.author == "Header Composer" })
    #expect(facts.tracks.allSatisfy { $0.metadata.system == "PC Engine" })
    #expect(facts.tracks.allSatisfy { $0.metadata.song.isEmpty })
    #expect(facts.tracks.allSatisfy { $0.metadata.playLengthMs == 150_000 })
    #expect(facts.tracks.allSatisfy { $0.metadata.introLengthMs == -1 })
    #expect(facts.tracks.allSatisfy { $0.metadata.loopLengthMs == -1 })
    #expect(facts.tracks.allSatisfy { $0.metadata.fadeLengthMs == -1 })
}

@Test func hesReaderRejectsShortHeadersBadSignaturesAndEmptyPlaylists() throws {
    #expect(throws: FormatDataError.self) {
        try HESFormatDataReader.read(data: Data(repeating: 0, count: 0xCF), displayName: "short.hes")
    }

    var badSignature = makeHESData()
    badSignature.replaceSubrange(0..<4, with: Data("NOPE".utf8))
    #expect(throws: FormatDataError.self) {
        try HESFormatDataReader.read(data: badSignature, displayName: "bad.hes")
    }

    #expect(throws: FormatDataError.self) {
        try HESFormatDataReader.read(
            data: makeHESData(),
            playlistData: Data("# empty playlist\n".utf8),
            displayName: "empty-playlist.hes"
        )
    }
}

@Test(
    "NSFE fixture directory parses without playback",
    .enabled(
        if: ProcessInfo.processInfo.environment["VGMBOY_NSFE_FIXTURE_DIR"] != nil,
        "Set VGMBOY_NSFE_FIXTURE_DIR to run the corpus-backed NSFE reader check."
    )
)
func nsfeFixtureDirectoryParsesWithoutPlayback() throws {
    let directoryPath = try #require(ProcessInfo.processInfo.environment["VGMBOY_NSFE_FIXTURE_DIR"])
    let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
    let files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension.lowercased() == "nsfe" }
    #expect(!files.isEmpty)
    for file in files {
        let facts = try NSFEFormatDataReader.read(
            data: Data(contentsOf: file),
            displayName: file.lastPathComponent
        )
        #expect(facts.trackCount > 0)
        #expect(facts.tracks.count == facts.trackCount)
        #expect(facts.orderedTracks.count > 0)
    }
}

private func writeText(_ data: inout Data, at offset: Int, value: String) {
    let bytes = Array(value.utf8)
    data.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
}

private func makeHESData() -> Data {
    var data = Data(repeating: 0, count: 0xD0)
    data.replaceSubrange(0..<4, with: Data("HESM".utf8))
    data[4] = 1
    data[5] = 3
    data[6] = 0x34
    data[7] = 0x12
    for index in 0..<8 { data[8 + index] = UInt8(0x20 + index) }
    data.replaceSubrange(16..<20, with: Data("DATA".utf8))
    writeLittleEndian(&data, at: 20, value: 0x1020)
    writeLittleEndian(&data, at: 24, value: 0x4000)
    return data
}

private func writeHESTextField(_ data: inout Data, at offset: Int, value: String) {
    let bytes = Array(value.utf8)
    data.replaceSubrange(offset..<(offset + 0x30), with: Data(repeating: 0, count: 0x30))
    data.replaceSubrange(offset..<(offset + bytes.count), with: Data(bytes))
}

private func writeLittleEndian(_ data: inout Data, at offset: Int, value: UInt32) {
    data[offset] = UInt8(value & 0xFF)
    data[offset + 1] = UInt8((value >> 8) & 0xFF)
    data[offset + 2] = UInt8((value >> 16) & 0xFF)
    data[offset + 3] = UInt8((value >> 24) & 0xFF)
}

private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8((value >> 24) & 0xFF)]
}

private func appendNSFEChunk(_ data: inout Data, identifier: String, payload: [UInt8]) {
    data.append(contentsOf: littleEndianBytes(UInt32(payload.count)))
    data.append(contentsOf: identifier.utf8)
    data.append(contentsOf: payload)
}
