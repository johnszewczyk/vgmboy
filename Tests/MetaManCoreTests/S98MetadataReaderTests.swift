import Foundation
import Testing
@testable import MetaManCore

@Test("S98 v3 retains DATE, YEAR, duplicate tags, and unknown tags")
func s98RetainsCompleteTagBlockAndNormalizesDate() throws {
    let tagText = "[S98]\u{FEFF}TITLE=Opening\nGAME=Example\nDATE=2001-02-03\nYEAR=2001\nDATE=2001-02-04\nX-PRODUCER=Studio=One\n"
    let data = makeS98(tags: Data(tagText.utf8) + [0])

    let document = try MetaManCore.read(data: data)

    #expect(document.format == "s98")
    #expect(document.fields.title == "Opening")
    #expect(document.fields.game == "Example")
    #expect(document.fields.date == "2001-02-03")
    #expect(document.fields.year == "2001")
    #expect(document.values(forTag: "date") == ["2001-02-03", "2001-02-04"])
    #expect(document.value(forTag: "x-producer") == "Studio=One")
    #expect(document.sourceEncoding == "UTF-8")
    #expect(document.rawTagBlock == Data(tagText.utf8))
    #expect(document.diagnostics.isEmpty)
}

@Test("S98 v3 legacy tags decode Shift_JIS without a UTF-8 marker")
func s98LegacyTagEncodingIsDecoded() throws {
    let japanese = try #require("TITLE=曲名".data(using: .shiftJIS))
    let tagBlock = Data("[S98]".utf8) + japanese + [0]
    let document = try MetaManCore.read(data: makeS98(tags: tagBlock))

    #expect(document.fields.title == "曲名")
    #expect(document.sourceEncoding == "Shift_JIS")
    #expect(document.rawTagBlock == Data(tagBlock.dropLast()))
}

@Test("S98 v1 legacy title and v2 device table are read without a decoder")
func s98LegacyHeadersAreSupported() throws {
    let legacyTitle = try #require("曲".data(using: .shiftJIS))
    let v1 = try MetaManCore.read(data: makeS98(version: 1, commands: [0xFF, 0xFD], tags: Data(legacyTitle) + [0]))
    #expect(v1.fields.title == "曲")
    #expect(v1.timing?.playLengthMs == 10)

    let v2 = try MetaManCore.read(data: makeS98(version: 2, commands: [0xFF, 0xFD], tags: Data(), v2Terminator: true))
    #expect(v2.technicalFacts["deviceCount"] == "0")
    #expect(v2.timing?.playLengthMs == 10)
}

@Test("S98 timing measures the pre-loop intro separately from the loop body")
func s98LoopTimingUsesFileLoopOffset() throws {
    let document = try MetaManCore.read(data: makeS98(
        numerator: 100,
        denominator: 1_000,
        commands: [0xFF, 0xFF, 0xFF, 0xFF, 0xFD],
        loopCommandIndex: 2
    ))

    #expect(document.timing?.introLengthMs == 200)
    #expect(document.timing?.loopLengthMs == 200)
    #expect(document.timing?.playLengthMs == 400)
    #expect(document.technicalFacts["loopStartTicks"] == "2")
}

@Test("S98 loop pointers after the end command are diagnosed and ignored")
func s98StaleLoopPointerIsIgnored() throws {
    let document = try MetaManCore.read(data: makeS98(
        numerator: 10,
        denominator: 1_000,
        commands: [0xFF, 0xFD, 0xFF],
        loopCommandIndex: 2
    ))

    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 0)
    #expect(document.timing?.playLengthMs == 10)
    #expect(document.technicalFacts["loopOffsetRecognized"] == "false")
    #expect(document.diagnostics.contains { $0.contains("loop offset does not identify") })
}

@Test("S98 zero-duration loop pointers are omitted with a diagnostic")
func s98ZeroDurationLoopIsOmitted() throws {
    let document = try MetaManCore.read(data: makeS98(
        numerator: 10,
        denominator: 1_000,
        commands: [0xFF, 0xFD],
        loopCommandIndex: 1
    ))

    #expect(document.timing?.playLengthMs == 10)
    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 0)
    #expect(document.diagnostics.contains { $0.contains("zero duration") })
}

@Test("S98 malformed waits fail, while an incomplete final write remains diagnosable")
func s98MalformedInputsFailSafely() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("S98X".utf8))
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeS98(commands: [0xFE, 0x80]))
    }
    let partialWrite = try MetaManCore.read(data: makeS98(commands: [0x01]))
    #expect(partialWrite.timing?.playLengthMs == 0)
    #expect(partialWrite.diagnostics.contains { $0.contains("truncated register-write") })
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data(), formatHint: "gym")
    }
}

@Test("AY and the registered single-track formats are direct readers")
func supportedFormatsAreRegisteredAsDirectFormatDataParsers() {
    let formats = MetaManCore.supportedFormats
    #expect(formats.map(\.identifier) == ["ay", "s98", "vgm", "psf-family", "spc", "sid", "ape", "adx", "aus", "at3", "msf", "svag"])
    #expect(formats[0].fileExtensions == ["ay"])
    #expect(formats[0].methodology.contains("no playback decoder"))
    #expect(formats[1].fileExtensions == ["s98"])
    #expect(formats[1].methodology.contains("no playback decoder"))
    #expect(formats[3].fileExtensions.contains("mini2sf"))
    #expect(formats[4].fileExtensions == ["spc"])
    #expect(formats[4].methodology.contains("does not start the playback emulator"))
    #expect(formats[5].fileExtensions == ["sid"])
    #expect(formats[5].methodology.contains("does not instantiate the SID playback core"))
    #expect(formats[6].fileExtensions == ["ape"])
    #expect(formats[6].methodology.contains("without an audio decoder"))
    #expect(formats[7].fileExtensions == ["adx"])
    #expect(formats[7].methodology.contains("Direct CRI/Monster ADX"))
    #expect(formats[8].fileExtensions == ["aus"])
    #expect(formats[8].methodology.contains("Direct Atomic Planet"))
    #expect(formats[9].fileExtensions == ["at3"])
    #expect(formats[9].methodology.contains("RIFF/WAVE ATRAC3"))
    #expect(formats[10].fileExtensions == ["msf"])
    #expect(formats[10].methodology.contains("Direct Sony MSF"))
    #expect(formats[11].fileExtensions == ["svag"])
    #expect(formats[11].methodology.contains("Konami/SNK SVAG"))
}

private func makeS98(
    version: UInt8 = 3,
    numerator: UInt32 = 0,
    denominator: UInt32 = 0,
    commands: [UInt8] = [0xFD],
    loopCommandIndex: Int? = nil,
    tags: Data = Data(),
    v2Terminator: Bool = false
) -> Data {
    let headerSize = version == 2 && v2Terminator ? 0x30 : 0x20
    var data = Data(repeating: 0, count: headerSize)
    data[0] = 0x53
    data[1] = 0x39
    data[2] = 0x38
    data[3] = 0x30 + version
    writeLE32(numerator, into: &data, at: 0x04)
    writeLE32(denominator, into: &data, at: 0x08)
    writeLE32(UInt32(headerSize), into: &data, at: 0x14)
    if version == 3 { writeLE32(0, into: &data, at: 0x1C) }
    if let loopCommandIndex { writeLE32(UInt32(headerSize + loopCommandIndex), into: &data, at: 0x18) }
    data.append(contentsOf: commands)
    if !tags.isEmpty {
        writeLE32(UInt32(data.count), into: &data, at: 0x10)
        data.append(tags)
    }
    return data
}

private func writeLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
