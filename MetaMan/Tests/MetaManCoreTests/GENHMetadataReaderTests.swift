import Foundation
import Testing
@testable import MetaManCore

@Test("GENH legacy zero-size header uses the decoder's 0x800-byte compatibility layout")
func genhLegacyHeaderPreservesTimingAndRawBytes() throws {
    let data = makeGENHFixture(
        headerSize: 0,
        audioOffset: 0x1000,
        channels: 1,
        interleave: 0,
        sampleRate: 32_000,
        loopStart: -1,
        loopEnd: -1,
        codec: 3,
        sampleCount: 32_000,
        dataSize: 1,
        payloadSize: 64_000
    )
    let document = try MetaManCore.read(data: data, formatHint: ".GENH", displayName: "DIGEST.genh")

    #expect(document.format == "genh")
    #expect(document.fields.title == "DIGEST")
    #expect(document.fields.comment == "GENH generic header")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 1_000))
    #expect(document.technicalFacts["codecId"] == "3")
    #expect(document.technicalFacts["codecName"] == "16-bit big-endian PCM")
    #expect(document.technicalFacts["sampleRateHz"] == "32000")
    #expect(document.technicalFacts["sampleCount"] == "32000")
    #expect(document.technicalFacts["declaredHeaderSize"] == "0")
    #expect(document.technicalFacts["headerSize"] == "2048")
    #expect(document.technicalFacts["audioOffset"] == "2048")
    #expect(document.technicalFacts["dataSize"] == "1")
    #expect(document.technicalFacts["payloadBytes"] == "64000")
    #expect(document.rawMetadataBlocks?["genhHeader"]?.count == 0x800)
}

@Test("GENH extended header keeps sample, loop, DSP, and encoder parameters")
func genhExtendedHeaderParsesOptionalMetadataAndLoopTiming() throws {
    let data = makeGENHFixture(
        headerSize: 0x100,
        audioOffset: 0x100,
        channels: 2,
        interleave: 0x8000,
        sampleRate: 44_100,
        loopStart: 22_050,
        loopEnd: 44_100,
        codec: 12,
        sampleCount: 88_200,
        dataSize: 0,
        payloadSize: 0x200,
        codecMode: 2,
        skipSamples: 384,
        coefficientOffset: 0x70,
        secondCoefficientOffset: 0x90,
        coefficientInterleaveType: 1,
        coefficientType: 1,
        splitCoefficientOffset: 0xA0,
        splitSecondCoefficientOffset: 0xC0,
        interleaveLast: 0x20
    )
    let result = try MetaManCore.readResult(data: data, formatHint: "genh", displayName: "MUSIC.genh")
    let document = try #require(result.tracks.first?.document)

    #expect(result.tracks.count == 1)
    #expect(document.fields.title == "MUSIC")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 500, playLengthMs: 11_500))
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["interleaveBytes"] == "32768")
    #expect(document.technicalFacts["codecName"] == "Nintendo DSP ADPCM")
    #expect(document.technicalFacts["sampleCount"] == "88200")
    #expect(document.technicalFacts["playSamples"] == "507150")
    #expect(document.technicalFacts["coefficientOffset"] == "112")
    #expect(document.technicalFacts["coefficientSpacing"] == "32")
    #expect(document.technicalFacts["coefficientInterleaveType"] == "1")
    #expect(document.technicalFacts["coefficientType"] == "1")
    #expect(document.technicalFacts["splitCoefficientOffset"] == "160")
    #expect(document.technicalFacts["splitCoefficientSpacing"] == "32")
    #expect(document.technicalFacts["skipSamples"] == "384")
    #expect(document.technicalFacts["codecMode"] == "2")
    #expect(document.technicalFacts["interleaveLastBytes"] == "32")
    #expect(document.technicalFacts["dataSize"] == "512")
    #expect(document.rawMetadataBlocks?["genhHeader"]?.count == 0x100)
}

@Test("GENH data and file APIs reject truncated or structurally invalid headers")
func genhAPIsValidateTheCompleteHeader() throws {
    let valid = makeGENHFixture(
        headerSize: 0x100,
        audioOffset: 0x100,
        channels: 1,
        interleave: 0,
        sampleRate: 22_050,
        loopStart: 0,
        loopEnd: 11_025,
        codec: 0,
        sampleCount: 11_025,
        dataSize: 0,
        payloadSize: 0x100
    )
    #expect(GENHMetadataReader.matches(valid))

    var truncated = valid
    truncated.removeSubrange(0x20..<0x24)
    #expect(!GENHMetadataReader.matches(truncated))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: truncated, formatHint: "genh")
    }

    var invalidChannels = valid
    setGENH32(0, in: &invalidChannels, at: 0x04)
    #expect(!GENHMetadataReader.matches(invalidChannels))

    var unknownCodec = valid
    setGENH32(29, in: &unknownCodec, at: 0x18)
    #expect(!GENHMetadataReader.matches(unknownCodec))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: unknownCodec, formatHint: "genh")
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-genh-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let validURL = directory.appendingPathComponent("track.genh")
    try valid.write(to: validURL)
    #expect(MetaManCore.canReadDirectly(fileURL: validURL, formatHint: "genh"))
    #expect(try MetaManCore.read(fileURL: validURL).fields.title == "track")
}

@Test("GENH is registered as a direct generic-header metadata reader")
func genhFormatIsRegisteredAsDirectMetadata() throws {
    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "genh" })
    #expect(descriptor.fileExtensions == ["genh"])
    #expect(descriptor.methodology.contains("no payload codec"))
}

private func makeGENHFixture(
    headerSize: Int,
    audioOffset: Int,
    channels: Int,
    interleave: UInt32,
    sampleRate: Int,
    loopStart: Int,
    loopEnd: Int,
    codec: UInt32,
    sampleCount: Int,
    dataSize: UInt32,
    payloadSize: Int,
    codecMode: UInt8 = 0,
    skipSamples: Int32 = 0,
    coefficientOffset: UInt32 = 0,
    secondCoefficientOffset: UInt32 = 0,
    coefficientInterleaveType: UInt32 = 0,
    coefficientType: UInt32 = 0,
    splitCoefficientOffset: UInt32 = 0,
    splitSecondCoefficientOffset: UInt32 = 0,
    interleaveLast: UInt32 = 0
) -> Data {
    let effectiveHeaderSize = headerSize == 0 ? 0x800 : headerSize
    let effectiveAudioOffset = headerSize == 0 ? 0x800 : audioOffset
    var data = Data(repeating: 0, count: max(effectiveHeaderSize, effectiveAudioOffset + payloadSize))
    data.replaceSubrange(0..<4, with: Data("GENH".utf8))
    setGENH32(UInt32(channels), in: &data, at: 0x04)
    setGENH32(interleave, in: &data, at: 0x08)
    setGENH32(UInt32(sampleRate), in: &data, at: 0x0C)
    setGENH32(UInt32(bitPattern: Int32(loopStart)), in: &data, at: 0x10)
    setGENH32(UInt32(bitPattern: Int32(loopEnd)), in: &data, at: 0x14)
    setGENH32(codec, in: &data, at: 0x18)
    setGENH32(UInt32(audioOffset), in: &data, at: 0x1C)
    setGENH32(UInt32(headerSize), in: &data, at: 0x20)
    if effectiveHeaderSize >= 0x30 {
        setGENH32(coefficientOffset, in: &data, at: 0x24)
        setGENH32(secondCoefficientOffset, in: &data, at: 0x28)
        setGENH32(coefficientInterleaveType, in: &data, at: 0x2C)
    }
    if effectiveHeaderSize >= 0x34 {
        setGENH32(coefficientType, in: &data, at: 0x30)
    }
    if effectiveHeaderSize >= 0x3C {
        setGENH32(splitCoefficientOffset, in: &data, at: 0x34)
        setGENH32(splitSecondCoefficientOffset, in: &data, at: 0x38)
    }
    if effectiveHeaderSize >= 0x100 {
        setGENH32(UInt32(sampleCount), in: &data, at: 0x40)
        setGENH32(UInt32(bitPattern: skipSamples), in: &data, at: 0x44)
        data[0x48] = 1
        data[0x4B] = codecMode
        setGENH32(dataSize, in: &data, at: 0x50)
        setGENH32(interleaveLast, in: &data, at: 0x54)
    }
    return data
}

private func setGENH32(_ value: UInt32, in data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
