import Foundation
import Testing
@testable import MetaManCore

@Test("Headerless MIB reader mirrors inferred stereo layout and timing")
func mibReaderMapsHeaderlessPSADPCM() throws {
    let document = try MetaManCore.read(
        data: makeMIB(looped: false),
        formatHint: "mib",
        displayName: "stage.mib"
    )

    #expect(document.format == "mib")
    #expect(document.fields.title == "stage")
    #expect(document.fields.comment == "Headerless PS-ADPCM raw header")
    #expect(document.technicalFacts["codecName"] == "PS-ADPCM")
    #expect(document.technicalFacts["sampleRateHz"] == "44100")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["interleaveBlockSizeBytes"] == "16384")
    #expect(document.technicalFacts["decodedSampleCount"] == "35000")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 793, fadeLengthMs: 0))
    #expect(document.rawMetadataBlocks?["mibProbeHeader"]?.count == 0x10)
}

@Test("Headerless MIB reader preserves inferred loop arithmetic")
func mibReaderMapsInferredLoop() throws {
    let document = try MetaManCore.read(
        data: makeMIB(looped: true),
        formatHint: "mib",
        displayName: "loop.mib"
    )

    #expect(document.technicalFacts["loopEnabled"] == "true")
    #expect(document.technicalFacts["rawLoopStartBytes"] == "16400")
    #expect(document.technicalFacts["rawLoopEndBytesExclusive"] == "30016")
    #expect(document.technicalFacts["loopStartSample"] == "0")
    #expect(document.technicalFacts["loopEndSample"] == "23828")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 540, playLengthMs: 11080, fadeLengthMs: 0))
}

@Test("MIB probe rejects invalid PS-ADPCM data and preserves fallback eligibility")
func mibReaderRejectsNonHeaderlessPayload() throws {
    var invalid = Data(repeating: 0, count: 0x40)
    invalid[0] = 0xF0
    #expect(!MIBMetadataReader.matches(invalid))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: invalid, formatHint: "mib")
    }

    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "ps-headerless-mib" })
    #expect(descriptor.fileExtensions == ["mib"])
    #expect(descriptor.methodology.contains("no playback decoder"))
}

private func makeMIB(looped: Bool) -> Data {
    let size = 40_000
    var data = Data(repeating: 0, count: size)
    for offset in stride(from: 16, to: size, by: 16) {
        setFrame(in: &data, at: offset, first: 0x0C, flag: 0x02)
    }
    setFrame(in: &data, at: 16, first: 0x0C, flag: 0x06)
    for offset in stride(from: 2_592, to: 16_384, by: 16) {
        setFrame(in: &data, at: offset, first: 0x37, flag: 0x02, payloadByte: 0x01)
    }
    setFrame(in: &data, at: 16_384, first: 0x00, flag: 0x00)
    setFrame(in: &data, at: 16_400, first: 0x0C, flag: 0x06)
    setFrame(in: &data, at: 18_976, first: 0x07, flag: 0x02, payloadByte: 0x02)
    setFrame(in: &data, at: 32_768, first: 0x07, flag: 0x02, payloadByte: 0x03)
    if looped {
        setFrame(in: &data, at: 16, first: 0x0C, flag: 0x06)
        setFrame(in: &data, at: 16_400, first: 0x0C, flag: 0x06)
        setFrame(in: &data, at: 20_000, first: 0x0C, flag: 0x03)
        setFrame(in: &data, at: 30_000, first: 0x0C, flag: 0x03)
    }
    return data
}

private func setFrame(
    in data: inout Data,
    at offset: Int,
    first: UInt8,
    flag: UInt8,
    payloadByte: UInt8 = 0
) {
    data[offset] = first
    data[offset + 1] = flag
    data[offset + 2] = payloadByte
}
