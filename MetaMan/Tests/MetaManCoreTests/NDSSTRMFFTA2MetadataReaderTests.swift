import Foundation
import Testing
@testable import MetaManCore

@Test("Final Fantasy Tactics A2 RIFF/IMA header supplies loop and scanner timing without decoding")
func ndsSTRMFFTA2ReadsHeaderTiming() throws {
    let data = makeNDSFFTA2STRM(sampleRate: 8_000, sampleCount: 8_000, loopStart: 800, loopEnd: 4_800)
    let document = try MetaManCore.read(data: data, formatHint: "strm", displayName: "103 Green Wind.strm")

    #expect(document.format == "nds-strm-ffta2")
    #expect(document.fields.title == "103 Green Wind")
    #expect(document.fields.comment == "Square Enix RIFF IMA header")
    #expect(document.timing?.introLengthMs == 0)
    #expect(document.timing?.loopLengthMs == 500)
    #expect(document.timing?.playLengthMs == 11_100)
    #expect(document.timing?.fadeLengthMs == 0)
    #expect(document.technicalFacts["codec"] == "IMA ADPCM")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleCount"] == "8000")
    #expect(document.technicalFacts["loopDeclared"] == "true")
    #expect(document.technicalFacts["interleaveBlockSize"] == "128")
    #expect(document.rawMetadataBlocks?["ffta2Header"]?.count == 0x2C)
}

@Test("Final Fantasy Tactics A2 RIFF/IMA file probe is bounded and size-aware")
func ndsSTRMFFTA2FileProbeValidatesDeclaredSize() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-nds-ffta2-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("track.strm")
    try makeNDSFFTA2STRM(sampleRate: 32_728, sampleCount: 1_000, loopStart: 0, loopEnd: 0).write(to: sourceURL)
    #expect(MetaManCore.canReadDirectly(fileURL: sourceURL, formatHint: "strm"))
    #expect(try MetaManCore.read(fileURL: sourceURL).format == "nds-strm-ffta2")

    var malformed = makeNDSFFTA2STRM(sampleRate: 32_728, sampleCount: 1_000, loopStart: 0, loopEnd: 0)
    malformed[4] &+= 1
    try malformed.write(to: sourceURL)
    #expect(!MetaManCore.canReadDirectly(fileURL: sourceURL, formatHint: "strm"))
}

@Test("Final Fantasy Tactics A2 rejects malformed loop bounds")
func ndsSTRMFFTA2RejectsInvalidLoopBounds() {
    let invalid = makeNDSFFTA2STRM(sampleRate: 32_728, sampleCount: 1_000, loopStart: 800, loopEnd: 700)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: invalid, formatHint: "strm", displayName: "broken.strm")
    }
}

private func makeNDSFFTA2STRM(
    sampleRate: UInt32,
    sampleCount: UInt32,
    loopStart: UInt32,
    loopEnd: UInt32
) -> Data {
    let riffSize = sampleCount + 0x2C
    var data = Data(repeating: 0, count: Int(riffSize))
    data.replaceSubrange(0..<4, with: Data("RIFF".utf8))
    ndsFFTA2SetUInt32LE(riffSize, in: &data, at: 0x04)
    data.replaceSubrange(0x08..<0x0C, with: Data("IMA ".utf8))
    ndsFFTA2SetUInt32LE(sampleRate, in: &data, at: 0x0C)
    ndsFFTA2SetUInt32LE(loopStart, in: &data, at: 0x20)
    ndsFFTA2SetUInt32LE(2, in: &data, at: 0x24)
    ndsFFTA2SetUInt32LE(loopEnd, in: &data, at: 0x28)
    return data
}

private func ndsFFTA2SetUInt32LE(_ value: UInt32, in data: inout Data, at offset: Int) {
    for byteIndex in 0..<4 {
        data[offset + byteIndex] = UInt8(truncatingIfNeeded: value >> (byteIndex * 8))
    }
}
