import Foundation
import Testing
@testable import MetaManCore

@Test("Sony SSHD maps PS-ADPCM headers, loops, and decoder-compatible timing")
func sonySSHDReaderMapsPSXTiming() throws {
    let unlooped = try MetaManCore.read(
        data: makeSonySSHD(bodySize: 32_000, loopStart: UInt32.max, loopEnd: UInt32.max),
        formatHint: "ads",
        displayName: "stage.ads"
    )
    #expect(unlooped.format == "ads")
    #expect(unlooped.fields.title == "stage")
    #expect(unlooped.fields.comment == "Sony SSHD header")
    #expect(unlooped.technicalFacts["codecName"] == "PS-ADPCM")
    #expect(unlooped.technicalFacts["channels"] == "2")
    #expect(unlooped.technicalFacts["sampleRateHz"] == "48000")
    #expect(unlooped.technicalFacts["decodedSampleCount"] == "28000")
    #expect(unlooped.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 583, fadeLengthMs: 0))

    let looped = try MetaManCore.read(
        data: makeSonySSHD(bodySize: 32_000, loopStart: 1_600, loopEnd: UInt32.max),
        formatHint: "ads",
        displayName: "loop.ads"
    )
    #expect(looped.technicalFacts["loopEnabled"] == "true")
    #expect(looped.technicalFacts["loopStartSample"] == "22400")
    #expect(looped.technicalFacts["loopEndSample"] == "28000")
    #expect(looped.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 116, playLengthMs: 10_700, fadeLengthMs: 0))
    #expect(looped.rawMetadataBlocks?["sshdHeader"]?.count == 0x28)
}

@Test("Sony SSHD maps the video DVI IMA codec hijack")
func sonySSHDReaderMapsDVIIMA() throws {
    let document = try MetaManCore.read(
        data: makeSonySSHD(
            codec: 0x01,
            sampleRate: 12_000,
            channels: 1,
            interleave: 0x200,
            loopStart: UInt32.max,
            loopEnd: UInt32.max
        ),
        formatHint: "ads",
        displayName: "video.ads"
    )
    #expect(document.technicalFacts["codecName"] == "DVI IMA")
    #expect(document.technicalFacts["sampleRateHz"] == "48000")
    #expect(document.technicalFacts["interleaveBlockSizeBytes"] == "512")
    #expect(document.technicalFacts["effectiveInterleaveBlockSizeBytes"] == "64")
    #expect(document.technicalFacts["decodedSampleCount"] == "64000")
    #expect(document.timing?.playLengthMs == 1_333)
}

@Test("Sony SSHD supports content routing, ADSC containers, and safe rejection")
func sonySSHDReaderDetectionAndValidation() throws {
    let source = makeSonySSHD(bodySize: 384, codec: 1, loopStart: UInt32.max, loopEnd: UInt32.max)
    #expect(SonySSHDMetadataReader.matches(source))
    #expect(!SonySSHDMetadataReader.matches(Data("SShd but incomplete".utf8)))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("SShd".utf8), formatHint: "ads")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeSonySSHD(codec: 0x99), formatHint: "ads")
    }

    var container = Data("ADSC".utf8)
    appendUInt32LE(1, to: &container)
    container.append(source)
    let wrapped = try MetaManCore.read(data: container, formatHint: "ads", displayName: "wrapped.ads")
    #expect(wrapped.fields.title == "wrapped")
    #expect(wrapped.technicalFacts["headerOffset"] == "8")
    #expect(wrapped.technicalFacts["codecName"] == "PCM16LE")

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-sshd-probe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let knownURL = directory.appendingPathComponent("known.ads")
    let aliasURL = directory.appendingPathComponent("alias.ads")
    try source.write(to: knownURL)
    try Data("OggS".utf8).write(to: aliasURL)
    #expect(MetaManCore.canReadDirectly(fileURL: knownURL, formatHint: "ads"))
    #expect(!MetaManCore.canReadDirectly(fileURL: aliasURL, formatHint: "ads"))
    #expect(try MetaManCore.read(fileURL: knownURL).rawMetadataBlocks?["sshdHeader"]?.count == 0x28)

    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "sony-sshd" })
    #expect(descriptor.fileExtensions == ["ads"])
    #expect(descriptor.methodology.contains("without decoding"))
}

private func makeSonySSHD(
    bodySize: Int = 32_000,
    codec: UInt32 = 0x02,
    sampleRate: Int32 = 48_000,
    channels: Int32 = 2,
    interleave: UInt32 = 0x20,
    loopStart: UInt32 = 0,
    loopEnd: UInt32 = UInt32.max
) -> Data {
    var data = Data(repeating: 0x55, count: 0x28 + bodySize)
    data.replaceSubrange(0..<4, with: Data("SShd".utf8))
    appendUInt32LE(0x18, to: &data, at: 0x04)
    appendUInt32LE(codec, to: &data, at: 0x08)
    appendUInt32LE(UInt32(bitPattern: sampleRate), to: &data, at: 0x0C)
    appendUInt32LE(UInt32(bitPattern: channels), to: &data, at: 0x10)
    appendUInt32LE(interleave, to: &data, at: 0x14)
    appendUInt32LE(loopStart, to: &data, at: 0x18)
    appendUInt32LE(loopEnd, to: &data, at: 0x1C)
    data.replaceSubrange(0x20..<0x24, with: Data("SSbd".utf8))
    appendUInt32LE(UInt32(bodySize), to: &data, at: 0x24)
    return data
}

private func appendUInt32LE(_ value: UInt32, to data: inout Data, at offset: Int? = nil) {
    let bytes = [
        UInt8(value & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8(value >> 24)
    ]
    if let offset {
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    } else {
        data.append(contentsOf: bytes)
    }
}
