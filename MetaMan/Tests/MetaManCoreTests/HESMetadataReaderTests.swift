import Foundation
import Testing
@testable import MetaManCore

@Test("HES header and extended M3U produce ordered source-aware MetaMan tracks")
func hesReaderPreservesHeaderPlaylistTagsAndTiming() throws {
    var hes = makeHESData()
    writeHESTextField(&hes, at: 0x40, value: "Header Game")
    writeHESTextField(&hes, at: 0x60, value: "Header Composer")
    writeHESTextField(&hes, at: 0x80, value: "1990 Header Copyright")
    let playlist = Data("""
    # Game: Bloody Wolf
    # Artist: Fixture Composer
    # Ripping: Test Set
    DE89003.hes, $0C, Title, 0:20.000, 0:05.000-, 0:02.000
    DE89003.hes, 2, Stage Clear, 0:04.000,, 0:01.000
    """.utf8)

    let result = try MetaManCore.readResult(
        data: hes,
        formatHint: "hes",
        displayName: "DE89003.hes",
        context: MetadataReadContext(companionFiles: [
            MetadataCompanionFile(relativePath: "set/DE89003.M3U", data: playlist)
        ])
    )

    #expect(result.tracks.map(\.sourceTrackIndex) == [12, 1])
    #expect(result.tracks.map { $0.document.fields.title } == ["Title", "Stage Clear"])
    #expect(result.tracks.map { $0.document.fields.game } == ["Bloody Wolf", "Bloody Wolf"])
    #expect(result.tracks.map { $0.document.fields.artist } == ["Fixture Composer", "Fixture Composer"])
    #expect(result.tracks.map { $0.document.fields.system } == ["PC Engine", "PC Engine"])
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [20_000, 4_000])
    #expect(result.tracks[0].document.timing == MetadataTiming(
        introLengthMs: 5_000,
        loopLengthMs: 15_000,
        playLengthMs: 20_000,
        fadeLengthMs: 2_000
    ))
    #expect(result.tracks[1].document.timing == MetadataTiming(
        introLengthMs: -1,
        loopLengthMs: -1,
        playLengthMs: 4_000,
        fadeLengthMs: 1_000
    ))

    let first = result.tracks[0].document
    #expect(first.fields.copyright == "1990 Header Copyright")
    #expect(first.technicalFacts["version"] == "1")
    #expect(first.technicalFacts["firstTrack"] == "3")
    #expect(first.technicalFacts["initAddress"] == "0x1234")
    #expect(first.technicalFacts["banks"] == "0x20 0x21 0x22 0x23 0x24 0x25 0x26 0x27")
    #expect(first.technicalFacts["dataChunkTag"] == "DATA")
    #expect(first.technicalFacts["dataChunkSize"] == "4128")
    #expect(first.technicalFacts["dataAddress"] == "0x00004000")
    #expect(first.values(forTag: "ripping") == ["Test Set"])
    #expect(first.rawMetadataBlocks?["fixed-header"] == hes.prefix(0xD0))
    #expect(first.rawMetadataBlocks?["companion-m3u"] == playlist)

    #expect(MetaManCore.supportedFormats.contains(where: { $0.identifier == "hes" }))
    #expect(throws: MetadataReadError.trackAwareResultRequired("HES")) {
        try MetaManCore.read(data: hes, formatHint: "hes", displayName: "DE89003.hes")
    }
}

@Test("HES without M3U preserves the 256-slot compatibility listing")
func hesReaderPreservesCompatibilitySlotsAndUnknownTiming() throws {
    var hes = makeHESData()
    writeHESTextField(&hes, at: 0x40, value: "Header Game")
    writeHESTextField(&hes, at: 0x60, value: "Header Composer")

    let result = try MetaManCore.readResult(data: hes, formatHint: ".HES", displayName: "game.hes")
    #expect(result.tracks.count == 256)
    #expect(result.tracks.map(\.sourceTrackIndex) == Array(0..<256))
    #expect(result.tracks.allSatisfy { $0.document.fields.game == "Header Game" })
    #expect(result.tracks.allSatisfy { $0.document.fields.artist == "Header Composer" })
    #expect(result.tracks.allSatisfy { $0.document.fields.system == "PC Engine" })
    #expect(result.tracks.allSatisfy {
        $0.document.timing == MetadataTiming(
            introLengthMs: -1,
            loopLengthMs: -1,
            playLengthMs: 150_000,
            fadeLengthMs: -1
        )
    })
    #expect(result.tracks.allSatisfy { $0.document.technicalFacts["hasPlaylist"] == "false" })
}

@Test("HES file reads find only the same-basename M3U companion")
func hesFileURLReadsSiblingPlaylistAutomatically() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-hes-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("game.hes")
    let playlistURL = directory.appendingPathComponent("game.M3U")
    try makeHESData().write(to: fileURL, options: .atomic)
    try Data("# Game: Companion Game\n# Composer: Test Composer\ntrack.hes, $02, Song, 0:03.000\n".utf8)
        .write(to: playlistURL, options: .atomic)

    let result = try MetaManCore.readResult(fileURL: fileURL)
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].sourceTrackIndex == 2)
    #expect(result.tracks[0].document.fields.game == "Companion Game")
    #expect(result.tracks[0].document.fields.title == "Song")
    #expect(result.tracks[0].document.rawMetadataBlocks?["companion-m3u"] != nil)
}

@Test("HES rejects malformed headers, empty playlists, and out-of-range slots")
func hesReaderRejectsMalformedSources() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data(repeating: 0, count: 0xCF), formatHint: "hes", displayName: "short.hes")
    }

    var badSignature = makeHESData()
    badSignature.replaceSubrange(0..<4, with: Data("NOPE".utf8))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: badSignature, formatHint: "hes", displayName: "bad.hes")
    }

    let source = makeHESData()
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(
            data: source,
            formatHint: "hes",
            displayName: "empty.hes",
            context: MetadataReadContext(companionFiles: [
                MetadataCompanionFile(relativePath: "empty.m3u", data: Data("# no tracks\n".utf8))
            ])
        )
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(
            data: source,
            formatHint: "hes",
            displayName: "invalid.hes",
            context: MetadataReadContext(companionFiles: [
                MetadataCompanionFile(relativePath: "invalid.m3u", data: Data("track.hes, $100, Out of range\n".utf8))
            ])
        )
    }
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
