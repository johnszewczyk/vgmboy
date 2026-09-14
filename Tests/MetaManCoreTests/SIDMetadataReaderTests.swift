import Foundation
import Testing
@testable import MetaManCore

@Test func sidReaderUsesPSIDIdentityOffsetsAndDoesNotTreatFlagsAsDuration() throws {
    var data = Data(repeating: 0, count: 0x82)
    data.replaceSubrange(0..<4, with: Data("PSID".utf8))
    writeSIDUInt16(&data, at: 0x04, value: 2)
    writeSIDUInt16(&data, at: 0x06, value: 0x7C)
    writeSIDUInt16(&data, at: 0x08, value: 0x0800)
    writeSIDUInt16(&data, at: 0x0E, value: 3)
    writeSIDUInt16(&data, at: 0x10, value: 1)
    writeSIDUInt32(&data, at: 0x12, value: 0x0000_0001)
    writeSIDText(&data, at: 0x16, width: 32, value: "Correct Title")
    writeSIDText(&data, at: 0x36, width: 32, value: "Correct Author")
    writeSIDText(&data, at: 0x56, width: 32, value: "Released 1988")
    // v2 starts its extension with flags, not PAL/NTSC durations.
    writeSIDUInt16(&data, at: 0x76, value: 30)

    let document = try SIDMetadataReader.read(data: data, displayName: "fixture.sid")

    #expect(document.format == "sid")
    #expect(document.fields.title == "Correct Title")
    #expect(document.fields.game == "Correct Title")
    #expect(document.fields.artist == "Correct Author")
    #expect(document.fields.copyright == "Released 1988")
    #expect(document.fields.comment == "Released 1988")
    #expect(document.fields.date == nil)
    #expect(document.fields.system == "Commodore 64")
    #expect(document.tags == [
        MetadataTag(name: "Title", value: "Correct Title"),
        MetadataTag(name: "Author", value: "Correct Author"),
        MetadataTag(name: "Released", value: "Released 1988")
    ])
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 0, fadeLengthMs: 0))
    #expect(document.technicalFacts["magicID"] == "PSID")
    #expect(document.technicalFacts["version"] == "2")
    #expect(document.technicalFacts["songCount"] == "3")
    #expect(document.technicalFacts["startSong"] == "1")
    #expect(document.technicalFacts["durationSource"] == "none")
    #expect(document.rawMetadataBlocks?["sidHeader"] == Data(data.prefix(0x7C)))
}

@Test func sidReaderHandlesRSIDAndUsesFilenameWhenTitleIsAbsent() throws {
    var data = Data(repeating: 0, count: 0x76)
    data.replaceSubrange(0..<4, with: Data("RSID".utf8))
    writeSIDUInt16(&data, at: 0x04, value: 1)
    writeSIDText(&data, at: 0x36, width: 32, value: "Composer")
    writeSIDText(&data, at: 0x56, width: 32, value: "1986")

    let document = try SIDMetadataReader.read(data: data, displayName: "Fallback Tune.sid")

    #expect(document.fields.title == "Fallback Tune")
    #expect(document.fields.game == nil)
    #expect(document.fields.artist == "Composer")
    #expect(document.fields.copyright == "1986")
    #expect(document.technicalFacts["magicID"] == "RSID")
    #expect(document.technicalFacts["titleSource"] == "filename")
    #expect(document.rawMetadataBlocks?["sidHeader"] == Data(data.prefix(0x76)))
    #expect(document.timing?.playLengthMs == 0)
}

@Test func sidReaderRejectsInvalidAndTruncatedFiles() {
    #expect(throws: MetadataReadError.self) {
        try SIDMetadataReader.read(data: Data(repeating: 0, count: 0x80), displayName: "invalid.sid")
    }
    #expect(throws: MetadataReadError.self) {
        try SIDMetadataReader.read(data: Data("PSID".utf8), displayName: "truncated.sid")
    }
    var truncatedV1 = Data(repeating: 0, count: 0x75)
    truncatedV1.replaceSubrange(0..<4, with: Data("PSID".utf8))
    writeSIDUInt16(&truncatedV1, at: 0x04, value: 1)
    #expect(throws: MetadataReadError.self) {
        try SIDMetadataReader.read(data: truncatedV1, displayName: "truncated-v1.sid")
    }
    var truncatedV2 = Data(repeating: 0, count: 0x7B)
    truncatedV2.replaceSubrange(0..<4, with: Data("RSID".utf8))
    writeSIDUInt16(&truncatedV2, at: 0x04, value: 2)
    #expect(throws: MetadataReadError.self) {
        try SIDMetadataReader.read(data: truncatedV2, displayName: "truncated-v2.sid")
    }
}

private func writeSIDText(_ data: inout Data, at offset: Int, width: Int, value: String) {
    let bytes = Data(value.utf8.prefix(width))
    data.replaceSubrange(offset..<(offset + width), with: Data(bytes + Data(repeating: 0, count: width - bytes.count)))
}

private func writeSIDUInt16(_ data: inout Data, at offset: Int, value: UInt16) {
    data[offset] = UInt8(value >> 8)
    data[offset + 1] = UInt8(truncatingIfNeeded: value)
}

private func writeSIDUInt32(_ data: inout Data, at offset: Int, value: UInt32) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 24)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 3] = UInt8(truncatingIfNeeded: value)
}
