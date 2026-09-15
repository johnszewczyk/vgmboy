import Foundation
import Testing
@testable import MetaManCore

@Test("ADX reads CRI versions, header facts, loop timing, and retained header bytes")
func adxReaderPreservesCRIHeaderContract() throws {
    for version in [UInt16(0x0300), 0x0400, 0x0408, 0x0409] {
        let source = makeCRIADX(version: version)
        let document = try MetaManCore.read(
            data: source,
            formatHint: "ADX",
            displayName: "Battle Theme.adx"
        )

        #expect(document.format == "adx")
        #expect(document.fields.title == "Battle Theme")
        #expect(document.fields.comment == (version == 0x0300 ? "CRI ADX header (type 03)" : "CRI ADX header (type 04)"))
        #expect(document.timing == MetadataTiming(
            introLengthMs: 0,
            loopLengthMs: 2_000,
            playLengthMs: 15_000,
            fadeLengthMs: 0
        ))
        #expect(document.technicalFacts["sampleRateHz"] == "44100")
        #expect(document.technicalFacts["sampleCount"] == "441000")
        #expect(document.technicalFacts["channels"] == "2")
        #expect(document.technicalFacts["encodingType"] == "3")
        #expect(document.technicalFacts["frameSizeBytes"] == "18")
        #expect(document.technicalFacts["sampleBitDepth"] == "4")
        #expect(document.technicalFacts["highpassFrequencyHz"] == "500")
        #expect(document.technicalFacts["loopEnabled"] == "true")
        #expect(document.technicalFacts["loopStartSample"] == "44100")
        #expect(document.technicalFacts["loopEndSample"] == "132300")
        #expect(document.technicalFacts["dataOffset"] == "128")
        #expect(document.rawMetadataBlocks?["adxHeader"] == Data(source.prefix(128)))
        #expect(document.tags.isEmpty)
    }

    let type05Source = makeCRIADX(
        version: 0x0500,
        loopFlag: 0,
        sampleRate: 32_000,
        sampleCount: 64_000
    )
    let type05 = try MetaManCore.read(data: type05Source, formatHint: "adx", displayName: "No Loop.adx")
    #expect(type05.fields.comment == "CRI ADX header (type 05)")
    #expect(type05.timing?.loopLengthMs == 0)
    #expect(type05.timing?.playLengthMs == 2_000)
    #expect(type05.technicalFacts["loopEnabled"] == "false")
}

@Test("Monster Games ADX exposes native channel and loop facts")
func adxReaderSupportsMonsterGamesHeader() throws {
    let source = makeMonsterADX()
    let document = try MetaManCore.read(data: source, displayName: "Boss.adx")

    #expect(document.format == "adx")
    #expect(document.fields.title == "Boss")
    #expect(document.fields.comment == "Monster Games .ADX header")
    #expect(document.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 2_000,
        playLengthMs: 15_000,
        fadeLengthMs: 0
    ))
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleRateHz"] == "32000")
    #expect(document.technicalFacts["sampleCount"] == "128000")
    #expect(document.technicalFacts["channelDataOffsets"] == "128,128")
    #expect(document.rawMetadataBlocks?["adxHeader"] == Data(source.prefix(0x80)))
}

@Test("ADX signatures autodetect, aliases do not, and malformed ADX is rejected")
func adxReaderDetectionAndMalformedInputs() throws {
    let cri = makeCRIADX(version: 0x0400)
    #expect(ADXMetadataReader.matches(cri))
    #expect(try MetaManCore.read(data: cri).format == "adx")
    #expect(!ADXMetadataReader.matches(Data("OggS".utf8)))

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("not ADX".utf8), formatHint: "adx")
    }

    var unsupportedVersion = cri
    putUInt16BE(&unsupportedVersion, at: 0x12, value: 0x0600)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: unsupportedVersion, formatHint: "adx")
    }

    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "adx" })
    #expect(descriptor.fileExtensions == ["adx"])
    #expect(descriptor.methodology.contains("non-ADX aliases"))
}

private func makeCRIADX(
    version: UInt16,
    loopFlag: Int32 = 1,
    sampleRate: Int32 = 44_100,
    sampleCount: Int32 = 441_000
) -> Data {
    let dataOffset = 0x80
    var data = Data(repeating: 0, count: dataOffset + 0x20)
    putUInt16BE(&data, at: 0, value: 0x8000)
    putUInt16BE(&data, at: 0x02, value: UInt16(dataOffset - 4))
    data[0x04] = 0x03
    data[0x05] = 0x12
    data[0x06] = 4
    data[0x07] = 2
    putUInt32BE(&data, at: 0x08, value: UInt32(bitPattern: sampleRate))
    putUInt32BE(&data, at: 0x0C, value: UInt32(bitPattern: sampleCount))
    putUInt16BE(&data, at: 0x10, value: 500)
    putUInt16BE(&data, at: 0x12, value: version)

    let headerVersion = [UInt16(0x0408), 0x0409].contains(version) ? 0x0400 : version
    if headerVersion == 0x0300 {
        putUInt32BE(&data, at: 0x18, value: UInt32(bitPattern: loopFlag))
        putUInt32BE(&data, at: 0x1C, value: 44_100)
        putUInt32BE(&data, at: 0x24, value: 132_300)
    } else if headerVersion == 0x0400 {
        putUInt32BE(&data, at: 0x24, value: UInt32(bitPattern: loopFlag))
        putUInt32BE(&data, at: 0x28, value: 44_100)
        putUInt32BE(&data, at: 0x30, value: 132_300)
    }
    data.replaceSubrange((dataOffset - 6)..<dataOffset, with: Data("(c)CRI".utf8))
    return data
}

private func makeMonsterADX() -> Data {
    var data = Data(repeating: 0, count: 0x100)
    putUInt32BE(&data, at: 0x00, value: 0x0200_0000)
    putUInt32LE(&data, at: 0x00, value: 2)
    putUInt16LE(&data, at: 0x6E, value: 1)
    putUInt32LE(&data, at: 0x70, value: 32_000)
    putUInt32LE(&data, at: 0x74, value: 128_000)
    putUInt32LE(&data, at: 0x78, value: 32_000)
    putUInt32LE(&data, at: 0x7C, value: 96_000)
    putUInt32LE(&data, at: 0x34, value: 0x80)
    putUInt32LE(&data, at: 0x68, value: 0x80)
    return data
}

private func putUInt16BE(_ data: inout Data, at offset: Int, value: UInt16) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 1] = UInt8(truncatingIfNeeded: value)
}

private func putUInt16LE(_ data: inout Data, at offset: Int, value: UInt16) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func putUInt32BE(_ data: inout Data, at offset: Int, value: UInt32) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 24)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 3] = UInt8(truncatingIfNeeded: value)
}

private func putUInt32LE(_ data: inout Data, at offset: Int, value: UInt32) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
