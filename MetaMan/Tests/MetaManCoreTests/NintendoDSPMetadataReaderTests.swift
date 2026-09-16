import Foundation
import Testing
@testable import MetaManCore

@Test("Standard Nintendo DSP reads its native header and scanner timing without decoding")
func standardNintendoDSPReaderPreservesHeaderAndTiming() throws {
    let document = try MetaManCore.read(
        data: makeStandardDSP(loopFlag: 1),
        formatHint: "dsp",
        displayName: "Stage Theme.dsp"
    )

    #expect(document.format == "ngc-dsp-standard")
    #expect(document.fields.title == "Stage Theme")
    #expect(document.fields.comment == "Nintendo DSP header")
    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 393)
    #expect(document.timing?.playLengthMs == 10_831)
    #expect(document.technicalFacts["channels"] == "1")
    #expect(document.technicalFacts["sampleCount"] == "96000")
    #expect(document.technicalFacts["loopStartSample"] == "1400")
    #expect(document.technicalFacts["loopEndSample"] == "14001")
    #expect(document.rawMetadataBlocks?["dspHeader"]?.count == 0x60)
}

@Test("Retro Studios RS03 reads its channel/interleave header and byte-addressed loop")
func rs03ReaderPreservesHeaderAndTiming() throws {
    let document = try MetaManCore.read(
        data: makeRS03(loopFlag: 1),
        formatHint: "dsp",
        displayName: "Echoes Theme.dsp"
    )

    #expect(document.format == "rs03")
    #expect(document.fields.title == "Echoes Theme")
    #expect(document.fields.comment == "Retro Studios RS03 header")
    #expect(document.timing?.loopLengthMs == 437)
    #expect(document.timing?.playLengthMs == 10_962)
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["loopStartSample"] == "2800")
    #expect(document.technicalFacts["loopEndSample"] == "16800")
    #expect(document.technicalFacts["interleaveBytes"] == String(0x8F00))
    #expect(document.rawMetadataBlocks?["rs03Header"]?.count == 0x60)
}

@Test("THP DSP audio follows versioned component headers and retains raw layout blocks")
func thpDSPAudioReaderParsesBigAndLittleEndianHeaders() throws {
    for bigEndian in [true, false] {
        let document = try MetaManCore.read(
            data: makeTHP(bigEndian: bigEndian),
            formatHint: "dsp",
            displayName: "Mission Briefing.dsp"
        )

        #expect(document.format == "ngc-thp-audio")
        #expect(document.fields.title == "Mission Briefing")
        #expect(document.fields.comment == "Nintendo THP header")
        #expect(document.timing?.loopLengthMs == 0)
        #expect(document.timing?.playLengthMs == 2_000)
        #expect(document.technicalFacts["byteOrder"] == (bigEndian ? "big" : "little"))
        #expect(document.technicalFacts["audioHeaderOffset"] == "96")
        #expect(document.technicalFacts["channels"] == "2")
        #expect(document.rawMetadataBlocks?["thpComponentTypes"]?.count == 0x14)
        #expect(document.rawMetadataBlocks?["thpComponentHeaders"]?.count == 0x0C)
        #expect(document.rawMetadataBlocks?["thpAudioHeader"]?.count == 0x10)
    }
}

@Test("DSP signature matching rejects unknown aliases and malformed headers")
func dspSignatureMatchingRejectsUnknownAndMalformedSources() throws {
    let aliasURL = try writeDSPFixture(Data("not a DSP".utf8), name: "alias.dsp")
    defer { try? FileManager.default.removeItem(at: aliasURL.deletingLastPathComponent()) }
    #expect(!MetaManCore.canReadDirectly(
        fileURL: aliasURL,
        formatHint: "dsp"
    ))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("not a DSP".utf8), formatHint: "dsp", displayName: "alias.dsp")
    }

    var malformed = makeStandardDSP(loopFlag: 0)
    setDSPUInt16BE(1, in: &malformed, at: 0x0E)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: malformed, formatHint: "dsp", displayName: "broken.dsp")
    }
}

@Test("DSP format registry lists each independently recognized layout")
func dspFormatsAreRegisteredSeparately() {
    let formats = MetaManCore.supportedFormats.filter { ["ngc-dsp-standard", "rs03", "ngc-thp-audio"].contains($0.identifier) }
    #expect(formats.map(\.identifier) == ["ngc-dsp-standard", "rs03", "ngc-thp-audio"])
    #expect(formats.allSatisfy { $0.fileExtensions == ["dsp"] })
}

private func makeStandardDSP(loopFlag: UInt16) -> Data {
    var data = Data(repeating: 0, count: 0x60 + 64)
    setDSPUInt32BE(96_000, in: &data, at: 0x00)
    setDSPUInt32BE(192_000, in: &data, at: 0x04)
    setDSPUInt32BE(32_000, in: &data, at: 0x08)
    setDSPUInt16BE(loopFlag, in: &data, at: 0x0C)
    setDSPUInt16BE(0, in: &data, at: 0x0E)
    setDSPUInt32BE(1_600, in: &data, at: 0x10)
    setDSPUInt32BE(16_000, in: &data, at: 0x14)
    setDSPUInt32BE(2, in: &data, at: 0x18)
    setDSPUInt16BE(1, in: &data, at: 0x1C)
    setDSPUInt16BE(0, in: &data, at: 0x3C)
    setDSPUInt16BE(0, in: &data, at: 0x3E)
    data[0x60] = 0
    return data
}

private func makeRS03(loopFlag: UInt16) -> Data {
    var data = Data(repeating: 0, count: 0x60 + 0x200)
    data.replaceSubrange(0..<4, with: Data([0x52, 0x53, 0x00, 0x03]))
    setDSPUInt32BE(2, in: &data, at: 0x04)
    setDSPUInt32BE(96_000, in: &data, at: 0x08)
    setDSPUInt32BE(32_000, in: &data, at: 0x0C)
    setDSPUInt16BE(loopFlag, in: &data, at: 0x14)
    setDSPUInt32BE(1_600, in: &data, at: 0x18)
    setDSPUInt32BE(9_600, in: &data, at: 0x1C)
    return data
}

private func makeTHP(bigEndian: Bool) -> Data {
    var data = Data(repeating: 0, count: 0xA0)
    data.replaceSubrange(0..<4, with: Data([0x54, 0x48, 0x50, 0x00]))
    setTHPUInt32(0x00011000, in: &data, at: 0x04, bigEndian: bigEndian)
    setTHPUInt32(0x1000, in: &data, at: 0x08, bigEndian: bigEndian)
    setTHPUInt32(0x800, in: &data, at: 0x0C, bigEndian: bigEndian)
    setTHPUInt32(1, in: &data, at: 0x14, bigEndian: bigEndian)
    setTHPUInt32(0x20, in: &data, at: 0x18, bigEndian: bigEndian)
    setTHPUInt32(0x20, in: &data, at: 0x1C, bigEndian: bigEndian)
    setTHPUInt32(0x40, in: &data, at: 0x20, bigEndian: bigEndian)
    setTHPUInt32(0x80, in: &data, at: 0x28, bigEndian: bigEndian)
    setTHPUInt32(2, in: &data, at: 0x40, bigEndian: bigEndian)
    data[0x44] = 0x00 // Video component, with its version-1.1 information header.
    data[0x45] = 0x01 // Audio component.
    setTHPUInt32(2, in: &data, at: 0x60, bigEndian: bigEndian)
    setTHPUInt32(32_000, in: &data, at: 0x64, bigEndian: bigEndian)
    setTHPUInt32(64_000, in: &data, at: 0x68, bigEndian: bigEndian)
    return data
}

private func setDSPUInt16BE(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 1] = UInt8(truncatingIfNeeded: value)
}

private func setDSPUInt32BE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for index in 0..<4 {
        data[offset + index] = UInt8(truncatingIfNeeded: value >> ((3 - index) * 8))
    }
}

private func setTHPUInt32(_ value: UInt32, in data: inout Data, at offset: Int, bigEndian: Bool) {
    for index in 0..<4 {
        let shift = (bigEndian ? 3 - index : index) * 8
        data[offset + index] = UInt8(truncatingIfNeeded: value >> shift)
    }
}

private func writeDSPFixture(_ data: Data, name: String) throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-dsp-probe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent(name)
    try data.write(to: file)
    return file
}
