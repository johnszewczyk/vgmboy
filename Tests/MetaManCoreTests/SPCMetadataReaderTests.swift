import Foundation
import Testing
@testable import MetaManCore

@Test func spcReaderExposesTextID666FieldsAndExactRawBytes() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCText(&data, at: 0x2E, value: "Text Song")
    writeSPCText(&data, at: 0x4E, value: "Text Game")
    writeSPCText(&data, at: 0x6E, value: "Dumper")
    writeSPCText(&data, at: 0x7E, value: "Comment")
    writeSPCText(&data, at: 0x9E, value: "01/02/2003")
    writeSPCText(&data, at: 0xA9, value: "045")
    writeSPCText(&data, at: 0xAC, value: "00600")
    writeSPCText(&data, at: 0xB1, value: "Text Artist")

    let document = try SPCMetadataReader.read(data: data, displayName: "text.spc")
    #expect(document.fields.title == "Text Song")
    #expect(document.fields.game == "Text Game")
    #expect(document.fields.artist == "Text Artist")
    #expect(document.fields.encodedBy == "Dumper")
    #expect(document.fields.comment == "Comment")
    #expect(document.fields.date == "01/02/2003")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 45_000, fadeLengthMs: 600))
    #expect(document.rawMetadataBlocks?["id666"] == Data(data[0x2E..<0xD2]))
    #expect(document.rawTagBlock == Data(data[0x2E..<0xD2]))
    #expect(document.tags.map(\.name).contains("Dumper"))
    #expect(document.sourceEncoding == "Windows-1252")
}

@Test func spcReaderExposesBinaryID666DateAndHeaderFacts() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCText(&data, at: 0x2E, value: "Binary Song")
    writeSPCText(&data, at: 0x4E, value: "Binary Game")
    writeSPCText(&data, at: 0x6E, value: "Binary Dumper")
    writeSPCText(&data, at: 0xB0, value: "Binary Artist")
    writeSPCUInt32(&data, at: 0x9E, value: 20_240_913)
    data[0xA9] = 30
    data[0xAC] = 0x88
    data[0xAD] = 0x13
    data[0xD0] = 0x81
    data[0xD1] = 2

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.fields.title == "Binary Song")
    #expect(document.fields.artist == "Binary Artist")
    #expect(document.fields.date == "2024-09-13")
    #expect(document.timing?.playLengthMs == 30_000)
    #expect(document.timing?.fadeLengthMs == 5_000)
    #expect(document.technicalFacts["id666Layout"] == "binary")
    #expect(document.technicalFacts["mutedVoices"] == "0x81")
    #expect(document.technicalFacts["emulator"] == "Snes9x")
}

@Test func spcReaderKeepsHyphenatedTextDateAndAllFiveFadeDigits() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCText(&data, at: 0x2E, value: "Text Song")
    writeSPCText(&data, at: 0x4E, value: "Text Game")
    writeSPCText(&data, at: 0x9E, value: "01-11-2003")
    writeSPCText(&data, at: 0xA9, value: "002")
    writeSPCText(&data, at: 0xAC, value: "00048")
    writeSPCText(&data, at: 0xB1, value: "Seisuke Itoh")

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.technicalFacts["id666Layout"] == "text")
    #expect(document.fields.date == "01-11-2003")
    #expect(document.fields.artist == "Seisuke Itoh")
    #expect(document.timing?.playLengthMs == 2_000)
    #expect(document.timing?.fadeLengthMs == 48)
    #expect(document.values(forTag: "Fade (milliseconds)") == ["00048"])
}

@Test func spcReaderUsesTheInfoLengthDefaultWhenTagsHaveNoTiming() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCText(&data, at: 0x2E, value: "Tagged, untimed song")
    writeSPCText(&data, at: 0x4E, value: "Tagged game")
    writeSPCText(&data, at: 0xB0, value: "Binary artist")

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.fields.title == "Tagged, untimed song")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 150_000, fadeLengthMs: 0))
}

@Test func spcReaderRecoversTextTimingAndAuthorInBinaryDatedMixedHeader() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCUInt32(&data, at: 0x9E, value: 0x0000_0402)
    writeSPCText(&data, at: 0xA9, value: "69")
    writeSPCText(&data, at: 0xAC, value: "0000")
    writeSPCText(&data, at: 0xB0, value: "0Takashi Horiguchi")

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.technicalFacts["id666Layout"] == "binary")
    #expect(document.technicalFacts["id666PlayTimingLayout"] == "text-fallback")
    #expect(document.technicalFacts["id666FadeTimingLayout"] == "text-fallback")
    #expect(document.fields.artist == "Takashi Horiguchi")
    #expect(document.timing?.playLengthMs == 69_000)
    #expect(document.timing?.fadeLengthMs == 0)
}

@Test func spcReaderCombinesXID6OverridesTimingAndFullTagSet() throws {
    var data = makeSPC(id666Flag: 0x1A)
    writeSPCText(&data, at: 0x2E, value: "Legacy Song")
    writeSPCText(&data, at: 0x4E, value: "Legacy Game")
    let chunk = makeXID6([
        xid6String(0x02, "xID6 Game"),
        xid6String(0x01, "xID6 Song"),
        xid6String(0x03, "xID6 Artist"),
        xid6String(0x04, "xID6 Dumper"),
        xid6Integer(0x05, 20_240_102),
        xid6Data(0x06, 2),
        xid6String(0x07, "xID6 Comment"),
        xid6String(0x10, "Soundtrack Album"),
        xid6Data(0x11, 1),
        xid6Data(0x12, 0x0131),
        xid6String(0x13, "Publisher"),
        xid6Data(0x14, 1998),
        xid6Integer(0x30, 128_000),
        xid6Integer(0x31, 192_000),
        xid6Integer(0x32, 256_000),
        xid6Integer(0x33, 320_000),
        xid6Data(0x34, 0x80),
        xid6Data(0x35, 2),
        xid6Data(0x36, 0x40),
        xid6Bytes(0x55, type: 2, payload: [0xAA, 0xBB])
    ])
    data.append(chunk)

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.fields.title == "xID6 Song")
    #expect(document.fields.game == "xID6 Game")
    #expect(document.fields.artist == "xID6 Artist")
    #expect(document.fields.encodedBy == "xID6 Dumper")
    #expect(document.fields.comment == "xID6 Comment")
    #expect(document.fields.date == "2024-01-02")
    #expect(document.fields.album == "Soundtrack Album")
    #expect(document.fields.copyright == nil)
    #expect(document.values(forTag: "Publisher") == ["Publisher"])
    #expect(document.fields.year == "1998")
    #expect(document.timing == MetadataTiming(introLengthMs: 2_000, loopLengthMs: 3_000, playLengthMs: 12_000, fadeLengthMs: 5_000))
    #expect(document.technicalFacts["xid6ItemCount"] == "20")
    #expect(document.technicalFacts["soundtrackDisc"] == "1")
    #expect(document.technicalFacts["mutedVoices"] == "0x80")
    #expect(document.technicalFacts["mixingLevel"] == "64")
    #expect(document.values(forTag: "Song") == ["Legacy Song", "xID6 Song"])
    #expect(document.rawMetadataBlocks?["id666"] == Data(data[0x2E..<0xD2]))
    #expect(document.rawMetadataBlocks?["xid6"] == chunk)
    #expect(document.rawTagBlock == chunk)
}

@Test func spcReaderPreservesTaglessDefaultsAndMalformedXID6Diagnostics() throws {
    let tagless = try SPCMetadataReader.read(data: makeSPC(id666Flag: 0x27))
    #expect(tagless.fields.title == nil)
    #expect(tagless.timing == MetadataTiming(introLengthMs: -1, loopLengthMs: -1, playLengthMs: 150_000, fadeLengthMs: 0))
    #expect(tagless.rawMetadataBlocks == nil)

    var malformed = makeSPC(id666Flag: 0x1A)
    writeSPCText(&malformed, at: 0x2E, value: "Keep Legacy")
    malformed.append(contentsOf: Data("xid6".utf8))
    malformed.append(contentsOf: [0x20, 0x00, 0x00, 0x00])
    malformed.append(contentsOf: [0x01, 0x01, 0x10, 0x00, 0x41, 0x42])
    let document = try SPCMetadataReader.read(data: malformed)
    #expect(document.fields.title == "Keep Legacy")
    #expect(document.diagnostics.count == 1)
    #expect(document.diagnostics[0].contains("truncated"))
    #expect(document.rawMetadataBlocks?["xid6"] != nil)
}

@Test func spcReaderRecoversCoherentID666ValuesWithAnAbsentHeaderFlag() throws {
    var data = makeSPC(id666Flag: 0x1B)
    writeSPCText(&data, at: 0x2E, value: "Recovered Song")
    writeSPCText(&data, at: 0x4E, value: "Recovered Game")
    writeSPCText(&data, at: 0x6E, value: "Recovered Dumper")
    writeSPCText(&data, at: 0xA9, value: "045")
    writeSPCText(&data, at: 0xAC, value: "00600")
    writeSPCText(&data, at: 0xB1, value: "Recovered Artist")

    let document = try SPCMetadataReader.read(data: data)
    #expect(document.fields.title == "Recovered Song")
    #expect(document.fields.game == "Recovered Game")
    #expect(document.fields.artist == "Recovered Artist")
    #expect(document.timing == MetadataTiming(introLengthMs: -1, loopLengthMs: -1, playLengthMs: 45_000, fadeLengthMs: 600))
    #expect(document.technicalFacts["id666Flagged"] == "false")
    #expect(document.technicalFacts["recoveredID666WithoutFlag"] == "true")
    #expect(document.diagnostics.contains { $0.contains("coherent fixed-slot metadata") })
}

@Test func spcReaderRejectsTruncatedAndInvalidHeaders() {
    #expect(throws: MetadataReadError.self) {
        try SPCMetadataReader.read(data: Data(repeating: 0, count: 128))
    }
    #expect(throws: MetadataReadError.self) {
        try SPCMetadataReader.read(data: makeSPC(id666Flag: 0x27).prefix(0x100))
    }
}

@Test func metadataDocumentDecodesOlderJSONWithoutRawMetadataBlocks() throws {
    let json = #"{"format":"spc","fields":{"title":null,"game":null,"system":"Super Nintendo","artist":null,"album":null,"date":null,"year":null,"genre":null,"comment":null,"copyright":null,"encodedBy":null},"tags":[],"rawTagBlock":null,"sourceEncoding":null,"timing":null,"technicalFacts":{},"diagnostics":[]}"#
    let document = try JSONDecoder().decode(MetadataDocument.self, from: Data(json.utf8))
    #expect(document.rawMetadataBlocks == nil)
}

private func makeSPC(id666Flag: UInt8) -> Data {
    var data = Data(repeating: 0, count: 0x10200)
    data.replaceSubrange(0..<27, with: Data("SNES-SPC700 Sound File Data".utf8))
    data[0x23] = id666Flag
    return data
}

private func writeSPCText(_ data: inout Data, at offset: Int, value: String) {
    let bytes = Array(value.utf8)
    data.replaceSubrange(offset..<(offset + bytes.count), with: Data(bytes))
}

private func writeSPCUInt32(_ data: inout Data, at offset: Int, value: UInt32) {
    for index in 0..<4 { data[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8)) }
}

private func makeXID6(_ items: [[UInt8]]) -> Data {
    let payload = items.flatMap { $0 }
    var chunk = Data("xid6".utf8)
    chunk.append(contentsOf: littleEndian(UInt32(payload.count)))
    chunk.append(contentsOf: payload)
    return chunk
}

private func xid6String(_ id: UInt8, _ value: String) -> [UInt8] {
    xid6Bytes(id, type: 1, payload: Array(value.utf8) + [0])
}

private func xid6Integer(_ id: UInt8, _ value: UInt32) -> [UInt8] {
    xid6Bytes(id, type: 4, payload: littleEndian(value))
}

private func xid6Data(_ id: UInt8, _ value: UInt16) -> [UInt8] {
    [id, 0, UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8)]
}

private func xid6Bytes(_ id: UInt8, type: UInt8, payload: [UInt8]) -> [UInt8] {
    var item = [id, type, UInt8(truncatingIfNeeded: payload.count), UInt8(truncatingIfNeeded: payload.count >> 8)]
    item.append(contentsOf: payload)
    item.append(contentsOf: repeatElement(0, count: (4 - payload.count % 4) % 4))
    return item
}

private func littleEndian(_ value: UInt32) -> [UInt8] {
    (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
}
