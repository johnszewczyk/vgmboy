import Foundation
import Testing
@testable import VGMBoyFormatDataCore

@Test func ayFormatReaderExtractsRelativeMetadataAndAuthoredLengthsWithoutPlayback() throws {
    let data = makeAYData(
        author: "  Composer  ",
        comment: " Copyright 1987 ",
        tracks: [("Opening", 125), ("Loop", 0)]
    )
    let facts = try AYFormatDataReader.read(data: data, displayName: "fixture.ay")

    #expect(facts.version == 1)
    #expect(facts.playerID == 3)
    #expect(facts.firstTrack == 1)
    #expect(facts.trackCount == 2)
    #expect(facts.author == "Composer")
    #expect(facts.comment == "Copyright 1987")
    #expect(facts.tracks.map(\.sourceTrackIndex) == [0, 1])
    #expect(facts.tracks.map(\.title) == ["Opening", "Loop"])
    #expect(facts.tracks.map(\.lengthFrames) == [125, 0])
    #expect(facts.tracks[0].metadata == FormatMetadata(
        game: "",
        song: "Opening",
        system: "ZX Spectrum",
        author: "Composer",
        comment: "Copyright 1987",
        introLengthMs: -1,
        loopLengthMs: -1,
        playLengthMs: 2_500,
        fadeLengthMs: -1
    ))
    #expect(facts.tracks[1].metadata.playLengthMs == 150_000)
}

@Test func ayFormatReaderUsesHeaderTrackCountAndRejectsOnlyInvalidTopLevelData() throws {
    let data = makeAYData(author: "<?> ", comment: "", tracks: [("?", 0)])
    let facts = try AYFormatDataReader.read(data: data, displayName: "defaults.ay")
    #expect(facts.trackCount == 1)
    #expect(facts.author.isEmpty)
    #expect(facts.comment.isEmpty)
    #expect(facts.tracks[0].title.isEmpty)
    #expect(facts.tracks[0].metadata.playLengthMs == 150_000)

    var truncatedTable = Data(repeating: 0, count: 0x14)
    truncatedTable.replaceSubrange(0..<8, with: Data("ZXAYEMUL".utf8))
    truncatedTable[16] = 1
    writeAYRelativePointer(&truncatedTable, at: 18, target: 0x14)
    #expect(throws: FormatDataError.self) {
        try AYFormatDataReader.read(data: truncatedTable, displayName: "truncated.ay")
    }
    #expect(throws: FormatDataError.self) {
        try AYFormatDataReader.read(data: Data(repeating: 0, count: 0x20), displayName: "invalid.ay")
    }
}

@Test func spcFormatReaderPreservesBinaryID666Facts() throws {
    var data = Data(repeating: 0, count: 0x10200)
    data.replaceSubrange(0..<27, with: Data("SNES-SPC700 Sound File Data".utf8))
    data[0x23] = 0x1A
    writeText(&data, at: 0x2E, value: "Song")
    writeText(&data, at: 0x4E, value: "Game")
    writeText(&data, at: 0xB0, value: "Artist")
    data[0xA9] = 30
    data[0xAC] = 0x88
    data[0xAD] = 0x13

    let metadata = try SPCFormatDataReader.read(data: data, displayName: "song.spc")
    #expect(metadata.song == "Song")
    #expect(metadata.game == "Game")
    #expect(metadata.author == "Artist")
    #expect(metadata.playLengthMs == 30_000)
    #expect(metadata.fadeLengthMs == 5_000)
}

@Test func spcFormatReaderUsesInfoOnlyDefaultsWhenBothTagFormatsAreAbsent() throws {
    var data = Data(repeating: 0, count: 0x10200)
    data.replaceSubrange(0..<27, with: Data("SNES-SPC700 Sound File Data".utf8))

    let metadata = try SPCFormatDataReader.read(data: data, displayName: "untagged.spc")
    #expect(metadata == FormatMetadata(
        game: "",
        song: "",
        system: "Super Nintendo",
        author: "",
        comment: "",
        introLengthMs: -1,
        loopLengthMs: -1,
        playLengthMs: 150_000,
        fadeLengthMs: 0
    ))
}

@Test func psfFormatReaderHarvestsTagsAndTiming() throws {
    var data = Data([0x50, 0x53, 0x46, 0x41])
    data.append(Data(repeating: 0, count: 12))
    data.append(Data("[TAG]\ntitle=Song\ngame=Game\nartist=Artist\nlength=1:23.500\nfade=4.250\n".utf8))

    let result = try #require(PSFFormatDataReader.readResult(
        data: data,
        pathExtension: "psf",
        displayName: "song.psf"
    ))
    #expect(result.tags["title"] == "Song")
    #expect(result.metadata.game == "Game")
    #expect(result.metadata.author == "Artist")
    #expect(result.metadata.playLengthMs == 83_500)
    #expect(result.metadata.fadeLengthMs == 4_250)
}

@Test func sidFormatReaderHarvestsHeaderFacts() throws {
    var data = Data(repeating: 0, count: 0x7A)
    data.replaceSubrange(0..<4, with: Data("PSID".utf8))
    data[0x05] = 2
    writeText(&data, at: 0x16, value: "Willow")
    writeText(&data, at: 0x2E, value: "Tester")
    data[0x77] = 30

    let metadata = try #require(try SIDFormatDataReader.read(data: data, displayName: "Willow.sid"))
    #expect(metadata.game == "Willow")
    #expect(metadata.song == "Willow")
    #expect(metadata.author == "Tester")
    #expect(metadata.playLengthMs == 30_000)
}

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

@Test func sapReaderExtractsInfoOnlyMetadataAndRetainsNativeTimeHints() throws {
    let facts = try SAPFormatDataReader.read(
        data: makeSAPData("""
        AUTHOR "Composer"
        NAME "Sample Game"
        DATE "1992"
        SONGS 3
        TYPE C
        MUSIC 8000
        PLAYER 9000
        FASTPLAY 156
        STEREO
        TIME 01:20.125 LOOP
        TIME 0:45.5
        TIME invalid
        """),
        displayName: "sample.sap"
    )

    #expect(facts.playerType == 0x43)
    #expect(facts.trackCount == 3)
    #expect(facts.initAddress == nil)
    #expect(facts.playerAddress == 0x9000)
    #expect(facts.musicAddress == 0x8000)
    #expect(facts.fastPlayScanlines == 156)
    #expect(facts.isStereo)
    #expect(facts.game == "Sample Game")
    #expect(facts.author == "Composer")
    #expect(facts.copyright == "1992")
    #expect(facts.tracks.map { $0.metadata.game } == Array(repeating: "Sample Game", count: 3))
    #expect(facts.tracks.map { $0.metadata.system } == Array(repeating: "Atari XL", count: 3))
    #expect(facts.tracks.map { $0.metadata.author } == Array(repeating: "Composer", count: 3))
    #expect(facts.tracks.allSatisfy { $0.metadata.song.isEmpty && $0.metadata.comment.isEmpty })
    #expect(facts.tracks.allSatisfy {
        $0.metadata.loopLengthMs == -1 && $0.metadata.fadeLengthMs == -1
    })
    #expect(facts.tracks[0].timeHint == SAPTimeHint(milliseconds: 80_125, loops: true))
    #expect(facts.tracks[0].metadata.introLengthMs == 80_125)
    #expect(facts.tracks[0].metadata.playLengthMs == 150_000)
    #expect(facts.tracks[1].timeHint == SAPTimeHint(milliseconds: 45_500, loops: false))
    #expect(facts.tracks[1].metadata.introLengthMs == -1)
    #expect(facts.tracks[1].metadata.playLengthMs == 45_500)
    #expect(facts.tracks[2].timeHint == nil)
    #expect(facts.tracks[2].metadata.introLengthMs == -1)
    #expect(facts.tracks[2].metadata.playLengthMs == 150_000)
}

@Test func sapReaderUsesLibGMEDefaultTrackCountAndCleansUnknownIdentity() throws {
    let facts = try SAPFormatDataReader.read(
        data: makeSAPData("""
        TYPE B
        NAME "?"
        AUTHOR "<?>"
        """),
        displayName: "single.sap"
    )
    #expect(facts.trackCount == 1)
    #expect(facts.game.isEmpty)
    #expect(facts.author.isEmpty)
    #expect(facts.tracks.count == 1)
    #expect(facts.tracks[0].timeHint == nil)
}

@Test func sapReaderRejectsMalformedHeadersAndCounts() throws {
    for malformed in [
        Data(repeating: 0, count: 20),
        Data("SAP\r\nTYPE D\r\n\u{FFFD}\u{FFFD}".utf8),
        makeSAPData("TYPE B\r\nSONGS 0"),
        makeSAPData("TYPE B\r\nSONGS 65537"),
        makeSAPData("TYPE B\r\nINIT XYZ")
    ] {
        #expect(throws: FormatDataError.self) {
            try SAPFormatDataReader.read(data: malformed, displayName: "invalid.sap")
        }
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

private func makeSAPData(_ header: String) -> Data {
    var data = Data("SAP\r\n".utf8)
    let normalized = header
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\n", with: "\r\n")
    data.append(Data(normalized.utf8))
    if !normalized.hasSuffix("\r\n") { data.append(Data("\r\n".utf8)) }
    data.append(contentsOf: [0xFF, 0xFF, 0, 0, 0, 0, 0])
    return data
}

private func makeAYData(author: String, comment: String, tracks: [(String, UInt16)]) -> Data {
    precondition((1...256).contains(tracks.count))
    var data = Data(repeating: 0, count: 0x14)
    data.replaceSubrange(0..<8, with: Data("ZXAYEMUL".utf8))
    data[8] = 1
    data[9] = 3
    data[16] = UInt8(tracks.count - 1)
    data[17] = 1

    let authorOffset = appendAYCString(author, to: &data)
    writeAYRelativePointer(&data, at: 12, target: authorOffset)
    let commentOffset = appendAYCString(comment, to: &data)
    writeAYRelativePointer(&data, at: 14, target: commentOffset)
    let titleOffsets = tracks.map { appendAYCString($0.0, to: &data) }

    let tableOffset = data.count
    data.append(contentsOf: repeatElement(0, count: tracks.count * 4))
    writeAYRelativePointer(&data, at: 18, target: tableOffset)
    for (index, track) in tracks.enumerated() {
        let rowOffset = tableOffset + index * 4
        writeAYRelativePointer(&data, at: rowOffset, target: titleOffsets[index])
        let infoOffset = data.count
        data.append(contentsOf: [0, 0, 0, 0, UInt8(track.1 >> 8), UInt8(track.1 & 0xFF)])
        writeAYRelativePointer(&data, at: rowOffset + 2, target: infoOffset)
    }
    return data
}

private func appendAYCString(_ value: String, to data: inout Data) -> Int {
    let offset = data.count
    data.append(contentsOf: value.utf8)
    data.append(0)
    return offset
}

private func writeAYRelativePointer(_ data: inout Data, at offset: Int, target: Int) {
    let relative = Int16(target - offset)
    let encoded = UInt16(bitPattern: relative)
    data[offset] = UInt8(encoded >> 8)
    data[offset + 1] = UInt8(encoded & 0xFF)
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
