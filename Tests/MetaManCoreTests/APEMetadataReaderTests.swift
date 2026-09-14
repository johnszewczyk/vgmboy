import Foundation
import Testing
@testable import MetaManCore

@Test("APE reads complete native tags, leading ID3, header timing, and source blocks")
func apeReaderRetainsTagsAndProjectsCommonFields() throws {
    let id3 = makeID3v24Prefix([
        ("TIT2", "ID3 title"),
        ("TALB", "ID3 album"),
        ("TPE1", "ID3 artist")
    ])
    let ape = makeAPEFixture(tags: [
        ("Title", "Earlier duplicate"),
        ("Title", "  Direct title  "),
        ("Album", "Game album"),
        ("Artist", "Composer"),
        ("Comment", "Authored comment"),
        ("Year", "1997"),
        ("Genre", "Chiptune"),
        ("X-Producer", "Studio=One")
    ])
    let source = id3 + ape.data

    #expect(APEMetadataReader.matches(source))
    let document = try MetaManCore.read(data: source, formatHint: "APE", displayName: "fixture.ape")

    #expect(document.format == "ape")
    #expect(document.fields.title == "Direct title")
    #expect(document.fields.game == "Game album")
    #expect(document.fields.album == "Game album")
    #expect(document.fields.artist == "Composer")
    #expect(document.fields.comment == "Authored comment")
    #expect(document.fields.date == "1997")
    #expect(document.fields.year == "1997")
    #expect(document.fields.genre == "Chiptune")
    #expect(document.values(forTag: "title") == ["ID3 title", "Earlier duplicate", "  Direct title  "])
    #expect(document.value(forTag: "x-producer") == "Studio=One")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 1_000, fadeLengthMs: 0))
    #expect(document.technicalFacts["sampleRateHz"] == "44100")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["durationSource"] == "APE frame sample counts")
    #expect(document.rawMetadataBlocks?["id3v2"] == id3)
    #expect(document.rawMetadataBlocks?["apev2"] == ape.tagBlock)
    #expect(document.rawTagBlock == ape.tagBlock)
    #expect(document.diagnostics.isEmpty)
}

@Test("APE supports legacy headers and filename title fallback")
func apeReaderSupportsLegacyHeaderAndFilenameFallback() throws {
    let document = try MetaManCore.read(data: makeLegacyAPEFixture(), formatHint: "ape", displayName: "legacy-track.ape")

    #expect(document.fields.title == "legacy-track")
    #expect(document.fields.game == nil)
    #expect(document.fields.artist == nil)
    #expect(document.timing?.playLengthMs == 1_000)
    #expect(document.technicalFacts["apeVersion"] == "3970")
}

@Test("APE rejects truncated headers and incomplete seek tables")
func apeReaderRejectsMalformedContainers() {
    let valid = makeAPEFixture(tags: []).data
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data(valid.prefix(18)), formatHint: "ape", displayName: "truncated-header.ape")
    }

    var brokenSeekTable = valid
    brokenSeekTable.replaceSubrange(64..<68, with: littleEndian(UInt32(2)))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: brokenSeekTable, formatHint: "ape", displayName: "bad-seek-table.ape")
    }
}

@Test("APE can be identified by signature without a filename hint")
func apeReaderSupportsSignatureDetection() throws {
    let fixture = makeAPEFixture(tags: [])
    let document = try MetaManCore.read(data: fixture.data, displayName: "fixture.ape")
    #expect(document.format == "ape")
    #expect(document.fields.title == "fixture")
    #expect(!APEMetadataReader.matches(Data("not APE".utf8)))
}

private struct APEFixture {
    let data: Data
    let tagBlock: Data
}

private func makeAPEFixture(tags: [(String, String)]) -> APEFixture {
    var data = Data("MAC ".utf8)
    data.append(contentsOf: littleEndian(UInt16(3_990)))
    data.append(contentsOf: littleEndian(UInt16(0)))
    data.append(contentsOf: littleEndian(UInt32(52)))
    data.append(contentsOf: littleEndian(UInt32(24)))
    data.append(contentsOf: littleEndian(UInt32(4)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: littleEndian(UInt32(4)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: repeatElement(0, count: 16))
    data.append(contentsOf: littleEndian(UInt16(2_000)))
    data.append(contentsOf: littleEndian(UInt16(0)))
    data.append(contentsOf: littleEndian(UInt32(294_912)))
    data.append(contentsOf: littleEndian(UInt32(44_100)))
    data.append(contentsOf: littleEndian(UInt32(1)))
    data.append(contentsOf: littleEndian(UInt16(16)))
    data.append(contentsOf: littleEndian(UInt16(2)))
    data.append(contentsOf: littleEndian(UInt32(44_100)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: [0, 0, 0, 0])

    var fields = Data()
    for (key, value) in tags {
        let valueBytes = Array(value.utf8)
        fields.append(contentsOf: littleEndian(UInt32(valueBytes.count)))
        fields.append(contentsOf: littleEndian(UInt32(0)))
        fields.append(contentsOf: key.utf8)
        fields.append(0)
        fields.append(contentsOf: valueBytes)
    }
    let tagSize = UInt32(fields.count + 32)
    var tagBlock = Data()
    tagBlock.append(Data("APETAGEX".utf8))
    tagBlock.append(contentsOf: littleEndian(UInt32(2_000)))
    tagBlock.append(contentsOf: littleEndian(tagSize))
    tagBlock.append(contentsOf: littleEndian(UInt32(tags.count)))
    tagBlock.append(contentsOf: littleEndian(UInt32(0xA000_0000)))
    tagBlock.append(contentsOf: repeatElement(0, count: 8))
    tagBlock.append(fields)
    tagBlock.append(Data("APETAGEX".utf8))
    tagBlock.append(contentsOf: littleEndian(UInt32(2_000)))
    tagBlock.append(contentsOf: littleEndian(tagSize))
    tagBlock.append(contentsOf: littleEndian(UInt32(tags.count)))
    tagBlock.append(contentsOf: littleEndian(UInt32(0x8000_0000)))
    tagBlock.append(contentsOf: repeatElement(0, count: 8))
    data.append(tagBlock)
    return APEFixture(data: data, tagBlock: tagBlock)
}

private func makeLegacyAPEFixture() -> Data {
    var data = Data("MAC ".utf8)
    data.append(contentsOf: littleEndian(UInt16(3_970)))
    data.append(contentsOf: littleEndian(UInt16(4_000)))
    data.append(contentsOf: littleEndian(UInt16(0)))
    data.append(contentsOf: littleEndian(UInt16(2)))
    data.append(contentsOf: littleEndian(UInt32(44_100)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: littleEndian(UInt32(1)))
    data.append(contentsOf: littleEndian(UInt32(44_100)))
    data.append(contentsOf: littleEndian(UInt32(0)))
    data.append(contentsOf: [0, 0, 0, 0])
    return data
}

private func makeID3v24Prefix(_ frames: [(String, String)]) -> Data {
    var body = Data()
    for (identifier, value) in frames {
        let payload = [UInt8(3)] + Array(value.utf8)
        body.append(Data(identifier.utf8))
        body.append(contentsOf: synchsafe(payload.count))
        body.append(contentsOf: [0, 0])
        body.append(contentsOf: payload)
    }
    var tag = Data("ID3".utf8)
    tag.append(contentsOf: [4, 0, 0])
    tag.append(contentsOf: synchsafe(body.count))
    tag.append(body)
    return tag
}

private func littleEndian(_ value: UInt16) -> [UInt8] {
    [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
}

private func littleEndian(_ value: UInt32) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ]
}

private func synchsafe(_ value: Int) -> [UInt8] {
    [
        UInt8((value >> 21) & 0x7F),
        UInt8((value >> 14) & 0x7F),
        UInt8((value >> 7) & 0x7F),
        UInt8(value & 0x7F)
    ]
}
