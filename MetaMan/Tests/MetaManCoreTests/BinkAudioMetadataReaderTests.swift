import Foundation
import Testing
@testable import MetaManCore

@Test("Bink audio walks frame offsets and packet sample counts without decoding")
func binkAudioReaderMapsContainerTiming() throws {
    let data = makeBinkAudio(frameSampleBytes: [9_600, 9_600])
    #expect(BinkAudioMetadataReader.matches(data))

    let result = try MetaManCore.readResult(data: data, formatHint: "bika", displayName: "fixture.bika")
    let track = try #require(result.tracks.first)
    #expect(result.tracks.count == 1)
    #expect(track.sourceTrackIndex == 1)
    #expect(track.document.format == "bika")
    #expect(track.document.fields.title == "fixture")
    #expect(track.document.fields.comment == "RAD Game Tools Bink header")
    #expect(track.document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 200, fadeLengthMs: 0))
    #expect(track.document.technicalFacts["signature"] == "BIK")
    #expect(track.document.technicalFacts["revision"] == "i")
    #expect(track.document.technicalFacts["videoFlags"] == "0x10000000")
    #expect(track.document.technicalFacts["largestFrameSizeBytes"] == "32")
    #expect(track.document.technicalFacts["streamID"] == "0x1234")
    #expect(track.document.technicalFacts["audioFlags"] == "0x2000")
    #expect(track.document.technicalFacts["channels"] == "2")
    #expect(track.document.technicalFacts["sampleRateHz"] == "24000")
    #expect(track.document.technicalFacts["decodedSampleCount"] == "4800")
    #expect(track.document.technicalFacts["streamSizeBytes"] == "32")
    #expect(track.document.rawMetadataBlocks?["binkHeader"]?.count == 0x44)
}

@Test("Bink audio rejects truncated tables and invalid declared sizes")
func binkAudioReaderRejectsMalformedContainers() {
    #expect(!BinkAudioMetadataReader.matches(Data("BIKi".utf8)))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("BIKi".utf8), formatHint: "bika")
    }

    var malformed = makeBinkAudio(frameSampleBytes: [9_600])
    malformed[4] = 0
    malformed[5] = 0
    malformed[6] = 0
    malformed[7] = 0
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: malformed, formatHint: "bika")
    }
}

private func makeBinkAudio(frameSampleBytes: [UInt32]) -> Data {
    let frameCount = frameSampleBytes.count
    let headerEnd = 0x2C + 4 + 4 + 4 + frameCount * 4 + 4
    let packetSize = 12
    var data = Data(repeating: 0, count: headerEnd + frameCount * (packetSize + 4))
    data.replaceSubrange(0..<4, with: Data("BIKi".utf8))
    writeLE32(UInt32(data.count - 8), into: &data, at: 0x04)
    writeLE32(UInt32(frameCount), into: &data, at: 0x08)
    writeLE32(UInt32(frameCount * (packetSize + 4)), into: &data, at: 0x0C)
    writeLE32(UInt32(frameCount), into: &data, at: 0x10)
    writeLE32(1, into: &data, at: 0x14)
    writeLE32(1, into: &data, at: 0x18)
    writeLE32(30, into: &data, at: 0x1C)
    writeLE32(1, into: &data, at: 0x20)
    writeLE32(0x1000_0000, into: &data, at: 0x24)
    writeLE32(1, into: &data, at: 0x28)

    let firstFrame = headerEnd
    var cursor = 0x2C + 4 + 4 + 4
    for index in frameSampleBytes.indices {
        writeLE32(UInt32(firstFrame + index * (packetSize + 4)), into: &data, at: cursor)
        cursor += 4
    }
    writeLE32(UInt32(data.count), into: &data, at: cursor)

    cursor = firstFrame
    for sampleBytes in frameSampleBytes {
        writeLE32(UInt32(packetSize), into: &data, at: cursor)
        writeLE32(sampleBytes, into: &data, at: cursor + 4)
        cursor += packetSize + 4
    }
    // BIK revision i starts its stream tables at 0x2c; newer revisions may
    // insert one color-flags word before these fields.
    writeLE32(16, into: &data, at: 0x2C)
    writeLE32(24_000 | (0x2000 << 16), into: &data, at: 0x30)
    writeLE32(0x1234, into: &data, at: 0x34)
    return data
}

private func writeLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
