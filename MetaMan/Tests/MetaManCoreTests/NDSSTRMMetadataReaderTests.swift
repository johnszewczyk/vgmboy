import Foundation
import Testing
@testable import MetaManCore

@Test("NDS STRM reader preserves header facts and decoder-compatible loop timing")
func ndsSTRMReaderPreservesHeaderAndLoopTiming() throws {
    let data = makeNDSSTRM(codec: 2, loopFlag: 1, sampleRate: 32_000, loopStart: 24_000, sampleCount: 96_000)

    let document = try MetaManCore.read(data: data, formatHint: "strm", displayName: "Stage 1.strm")

    #expect(document.format == "nds-strm")
    #expect(document.fields.title == "Stage 1")
    #expect(document.fields.comment == "Nintendo STRM header")
    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 2_250)
    #expect(document.timing?.playLengthMs == 15_250)
    #expect(document.timing?.fadeLengthMs == 0)
    #expect(document.technicalFacts["codecName"] == "Nintendo DS IMA ADPCM")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleCount"] == "96000")
    #expect(document.technicalFacts["loopDeclared"] == "true")
    #expect(document.technicalFacts["dataOffset"] == "104")
    #expect(document.rawMetadataBlocks?["strmHeader"]?.count == 0x60)
    #expect(document.rawMetadataBlocks?["dataChunkHeader"]?.count == 8)
}

@Test("NDS STRM accepts both legacy marker byte sequences and all supported codecs")
func ndsSTRMReaderAcceptsKnownHeaderVariants() throws {
    for codec in UInt8(0)...UInt8(2) {
        for marker in [UInt32(0xFFFE0001), UInt32(0xFEFF0001)] {
            let data = makeNDSSTRM(codec: codec, loopFlag: 0, marker: marker)
            let document = try MetaManCore.read(data: data, formatHint: "strm", displayName: "stream.strm")
            #expect(document.technicalFacts["codec"] == String(codec))
            #expect(document.technicalFacts["byteOrderMarker"] == String(format: "0x%08X", marker))
            #expect(document.timing?.loopLengthMs == 0)
            #expect(document.timing?.playLengthMs == 3_000)
        }
    }
}

@Test("NDS STRM reader rejects unsafe offsets and invalid loop ranges")
func ndsSTRMReaderRejectsInvalidStructure() {
    var outOfBounds = makeNDSSTRM(codec: 0, loopFlag: 0)
    ndsSTRMSetUInt32LE(UInt32.max, in: &outOfBounds, at: 0x28)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: outOfBounds, formatHint: "strm", displayName: "broken.strm")
    }

    let invalidLoop = makeNDSSTRM(codec: 1, loopFlag: 1, loopStart: 96_001, sampleCount: 96_000)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: invalidLoop, formatHint: "strm", displayName: "broken.strm")
    }
}

private func makeNDSSTRM(
    codec: UInt8,
    loopFlag: UInt8,
    marker: UInt32 = 0xFFFE0001,
    sampleRate: UInt16 = 32_000,
    loopStart: UInt32 = 24_000,
    sampleCount: UInt32 = 96_000
) -> Data {
    let payloadOffset = 0x68
    var data = Data(repeating: 0, count: payloadOffset + 64)
    data.replaceSubrange(0..<4, with: Data("STRM".utf8))
    ndsSTRMSetUInt32BE(marker, in: &data, at: 0x04)
    ndsSTRMSetUInt32LE(UInt32(data.count), in: &data, at: 0x08)
    ndsSTRMSetUInt16LE(0x10, in: &data, at: 0x0C)
    ndsSTRMSetUInt16LE(1, in: &data, at: 0x0E)
    data.replaceSubrange(0x10..<0x14, with: Data("HEAD".utf8))
    ndsSTRMSetUInt32LE(0x50, in: &data, at: 0x14)
    data[0x18] = codec
    data[0x19] = loopFlag
    data[0x1A] = 2
    ndsSTRMSetUInt16LE(sampleRate, in: &data, at: 0x1C)
    ndsSTRMSetUInt32LE(loopStart, in: &data, at: 0x20)
    ndsSTRMSetUInt32LE(sampleCount, in: &data, at: 0x24)
    ndsSTRMSetUInt32LE(UInt32(payloadOffset), in: &data, at: 0x28)
    ndsSTRMSetUInt32LE(0x2000, in: &data, at: 0x30)
    ndsSTRMSetUInt32LE(0x2000, in: &data, at: 0x38)
    data.replaceSubrange(0x60..<0x64, with: Data("DATA".utf8))
    ndsSTRMSetUInt32LE(64, in: &data, at: 0x64)
    return data
}

private func ndsSTRMSetUInt16LE(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func ndsSTRMSetUInt32LE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for byteIndex in 0..<4 {
        data[offset + byteIndex] = UInt8(truncatingIfNeeded: value >> (byteIndex * 8))
    }
}

private func ndsSTRMSetUInt32BE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for byteIndex in 0..<4 {
        data[offset + byteIndex] = UInt8(truncatingIfNeeded: value >> ((3 - byteIndex) * 8))
    }
}
