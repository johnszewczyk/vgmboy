import Foundation
import Testing
@testable import MetaManCore

@Test("Konami XMD v1 reads the Silent Hill 4 header and decoder-compatible loop timing")
func konamiXMDV1ReadsHeaderAndLoopTiming() throws {
    let document = try MetaManCore.read(
        data: makeXMDV1(),
        formatHint: "xmd",
        displayName: "10000.xmd"
    )

    #expect(document.format == "xmd")
    #expect(document.fields.title == "10000")
    #expect(document.fields.comment == "Konami XMD header")
    #expect(document.technicalFacts["headerVersion"] == "v1")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleRateHz"] == "48000")
    #expect(document.technicalFacts["framesPerChannel"] == "10")
    #expect(document.technicalFacts["sampleCountPerChannel"] == "160")
    #expect(document.technicalFacts["loopStartSample"] == "16")
    #expect(document.technicalFacts["vgmstreamDefaultPlaySamples"] == "480304")
    #expect(document.rawMetadataBlocks?["xmdHeader"]?.count == 0x0C)
    #expect(document.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 3,
        playLengthMs: 10_006,
        fadeLengthMs: 0
    ))
}

@Test("Konami XMD v2 retains unknown header bytes and derives per-channel frame timing")
func konamiXMDV2ReadsHeaderAndLoopTiming() throws {
    let data = makeXMDV2()
    let document = try MetaManCore.read(
        data: data,
        formatHint: "xmd",
        displayName: "track.xmd"
    )
    let result = try MetaManCore.readResult(
        data: data,
        formatHint: "xmd",
        displayName: "track.xmd"
    )

    #expect(document.technicalFacts["headerVersion"] == "v2")
    #expect(document.technicalFacts["framesPerChannel"] == "4")
    #expect(document.technicalFacts["sampleCountPerChannel"] == "128")
    #expect(document.rawMetadataBlocks?["xmdHeader"] == Data(data.prefix(0x11)))
    #expect(document.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 4,
        playLengthMs: 10_010,
        fadeLengthMs: 0
    ))
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].document == document)
}

@Test("Konami XMD file reads inspect only the bounded header and content routing rejects aliases")
func konamiXMDFileReadsUseBoundedHeader() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-xmd-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("large.xmd")
    let payloadSize = 8 * 1024 * 1024
    let data = makeXMDV1(dataSize: UInt32(payloadSize), loopFlag: 0)
    try data.write(to: fileURL)

    #expect(MetaManCore.canReadDirectly(fileURL: fileURL, formatHint: "xmd"))
    let document = try MetaManCore.read(fileURL: fileURL)
    #expect(document.technicalFacts["dataBytes"] == String(payloadSize))
    #expect(document.rawMetadataBlocks?["xmdHeader"]?.count == 0x0C)

    let aliasURL = directory.appendingPathComponent("alias.xmd")
    try Data("not XMD".utf8).write(to: aliasURL)
    #expect(!MetaManCore.canReadDirectly(fileURL: aliasURL, formatHint: "xmd"))
}

@Test("Konami XMD rejects unsafe sizes, channel counts, and loop positions")
func konamiXMDRejectsMalformedHeaders() {
    var truncated = makeXMDV1()
    truncated.removeLast()
    let malformed = [
        Data("xmd".utf8),
        makeXMDV1(channels: 3),
        truncated,
        makeXMDV1(loopStart: 1_000)
    ]
    for data in malformed {
        #expect(throws: MetadataReadError.self) {
            try MetaManCore.read(data: data, formatHint: "xmd", displayName: "bad.xmd")
        }
    }
}

private func makeXMDV1(
    channels: UInt8 = 2,
    sampleRate: UInt16 = 48_000,
    dataSize: UInt32 = 260,
    loopFlag: UInt8 = 1,
    loopStart: UInt32 = 26
) -> Data {
    var data = Data(repeating: 0, count: 0x0C + Int(dataSize))
    data[0] = channels
    setXMD16(sampleRate, in: &data, at: 0x01)
    setXMD32(dataSize, in: &data, at: 0x03)
    data[0x07] = loopFlag
    setXMD32(loopStart, in: &data, at: 0x08)
    return data
}

private func makeXMDV2() -> Data {
    let dataSize: UInt32 = 168
    var data = Data(repeating: 0, count: 0x11 + Int(dataSize))
    data.replaceSubrange(0..<3, with: Data("xmd".utf8))
    data[0x03] = 2
    setXMD16(22_050, in: &data, at: 0x04)
    setXMD32(dataSize, in: &data, at: 0x06)
    data[0x0A] = 1
    setXMD32(42, in: &data, at: 0x0B)
    data[0x0F] = 0xA5
    data[0x10] = 0x5A
    return data
}

private func setXMD16(_ value: UInt16, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func setXMD32(_ value: UInt32, in data: inout Data, at offset: Int) {
    for index in 0..<4 {
        data[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8))
    }
}
