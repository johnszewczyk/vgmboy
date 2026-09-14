import Foundation
import Testing
@testable import MetaManCore

@Test("Konami SVAG exposes native header facts and preserves the catalog timing projection")
func konamiSVAGReaderPreservesHeaderAndTiming() throws {
    let unloopedBytes = makeKonamiSVAG(dataSize: 32_000, loopStartBytes: 1_600)
    let unlooped = try MetaManCore.read(
        data: unloopedBytes,
        formatHint: ".SVAG",
        displayName: "stage.svag"
    )

    #expect(unlooped.format == "svag")
    #expect(unlooped.fields.title == "stage")
    #expect(unlooped.fields.comment == "Konami SVAG header")
    #expect(unlooped.tags.isEmpty)
    #expect(unlooped.rawMetadataBlocks?["svagHeader"] == unloopedBytes)
    #expect(unlooped.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 0,
        playLengthMs: 634,
        fadeLengthMs: 0
    ))
    #expect(unlooped.technicalFacts["layout"] == "interleave")
    #expect(unlooped.technicalFacts["codecName"] == "PS-ADPCM")
    #expect(unlooped.technicalFacts["dataSizeBytes"] == "32000")
    #expect(unlooped.technicalFacts["interleaveBlockSizeBytes"] == "2048")
    #expect(unlooped.technicalFacts["channels"] == "2")
    #expect(unlooped.technicalFacts["sampleRateHz"] == "44100")
    #expect(unlooped.technicalFacts["sampleCount"] == "28000")
    #expect(unlooped.technicalFacts["rawLoopStartBytes"] == "1600")
    #expect(unlooped.technicalFacts["rawLoopStartSample"] == "2800")
    #expect(unlooped.technicalFacts["loopStartSample"] == "0")

    let loopedBytes = makeKonamiSVAG(dataSize: 32_000, loopFlag: true, loopStartBytes: 1_600)
    let looped = try MetaManCore.read(data: loopedBytes, formatHint: "svag", displayName: "loop.svag")
    #expect(looped.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 571,
        playLengthMs: 11_206,
        fadeLengthMs: 0
    ))
    #expect(looped.technicalFacts["loopDeclared"] == "true")
    #expect(looped.technicalFacts["loopEnabled"] == "true")
    #expect(looped.technicalFacts["loopEndSample"] == "28000")
}

@Test("SNK SVAG exposes block-based samples and both loop conventions")
func snkSVAGReaderPreservesHeaderAndTiming() throws {
    let loopedBytes = makeSNKSVAG(
        channels: 2,
        sampleRate: 32_000,
        blockCount: 1_000,
        loopStartBlock: 100,
        loopEndBlock: 900
    )
    let looped = try MetaManCore.read(data: loopedBytes, displayName: "snk-loop.svag")
    #expect(looped.fields.comment == "SNK SVAG header")
    #expect(looped.rawMetadataBlocks?["svagHeader"] == loopedBytes)
    #expect(looped.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 700,
        playLengthMs: 11_487,
        fadeLengthMs: 0
    ))
    #expect(looped.technicalFacts["blockCount"] == "1000")
    #expect(looped.technicalFacts["rawLoopStartBlock"] == "100")
    #expect(looped.technicalFacts["rawLoopEndBlock"] == "900")
    #expect(looped.technicalFacts["rawLoopStartSample"] == "2800")
    #expect(looped.technicalFacts["rawLoopEndSample"] == "25200")

    let unlooped = try MetaManCore.read(
        data: makeSNKSVAG(channels: 2, sampleRate: 32_000, blockCount: 1_000, loopStartBlock: 100),
        formatHint: "svag"
    )
    #expect(unlooped.timing?.loopLengthMs == 0)
    #expect(unlooped.timing?.playLengthMs == 875)
    #expect(unlooped.technicalFacts["loopStartSample"] == "0")
}

@Test("SVAG loop cleanup retains raw bounds and reports malformed ranges")
func svagReaderCleansInvalidLoopsWithoutLosingHeaderFacts() throws {
    let invalidKonami = try MetaManCore.read(
        data: makeKonamiSVAG(dataSize: 32_000, loopFlag: true, loopStartBytes: 20_000),
        formatHint: "svag",
        displayName: "invalid-konami.svag"
    )
    #expect(invalidKonami.timing?.loopLengthMs == 0)
    #expect(invalidKonami.timing?.playLengthMs == 634)
    #expect(invalidKonami.technicalFacts["rawLoopStartBytes"] == "20000")
    #expect(invalidKonami.technicalFacts["loopStartSample"] == "0")
    #expect(invalidKonami.technicalFacts["loopDeclared"] == "true")
    #expect(invalidKonami.technicalFacts["loopEnabled"] == "false")
    #expect(!invalidKonami.diagnostics.isEmpty)

    let invalidSNK = try MetaManCore.read(
        data: makeSNKSVAG(channels: 2, sampleRate: 32_000, blockCount: 1_000,
                          loopStartBlock: 100, loopEndBlock: 1_001),
        formatHint: "svag"
    )
    #expect(invalidSNK.timing?.loopLengthMs == 0)
    #expect(invalidSNK.technicalFacts["rawLoopEndBlock"] == "1001")
    #expect(invalidSNK.technicalFacts["loopEndSample"] == "0")
    #expect(!invalidSNK.diagnostics.isEmpty)
}

@Test("SVAG supports content routing, preserves Konami padding, and rejects invalid headers")
func svagReaderDetectionAndValidation() throws {
    let konami = makeKonamiSVAG(dataSize: 32_000, paddingMarker: "Svag")
    let desiPadding = makeKonamiSVAG(dataSize: 32_000, paddingMarker: "Desi")
    #expect(SVAGMetadataReader.matches(konami))
    #expect(!SVAGMetadataReader.matches(Data("OTHER".utf8)))
    #expect(try MetaManCore.read(data: desiPadding).technicalFacts["paddingMarkerName"] == "Desi")

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeKonamiSVAG(dataSize: 32_000, paddingMarker: "NOPE"), formatHint: "svag")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("Svag".utf8), formatHint: "svag")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeKonamiSVAG(dataSize: 32_000, channels: 0), formatHint: "svag")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeSNKSVAG(channels: 2, sampleRate: 32_000, blockCount: .max), formatHint: "svag")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("OTHER".utf8), formatHint: "svag")
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-svag-probe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let recognizedURL = directory.appendingPathComponent("known.svag")
    let aliasURL = directory.appendingPathComponent("alias.svag")
    try konami.write(to: recognizedURL)
    try Data("OggS".utf8).write(to: aliasURL)
    #expect(MetaManCore.canReadDirectly(fileURL: recognizedURL, formatHint: "svag"))
    #expect(!MetaManCore.canReadDirectly(fileURL: aliasURL, formatHint: "svag"))
    #expect(try MetaManCore.read(fileURL: recognizedURL).rawMetadataBlocks?["svagHeader"] == konami)

    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "svag" })
    #expect(descriptor.fileExtensions == ["svag"])
    #expect(descriptor.methodology.contains("does not decode audio"))
}

private func makeKonamiSVAG(
    dataSize: UInt32,
    sampleRate: UInt32 = 44_100,
    channels: UInt16 = 2,
    interleave: UInt32 = 0x800,
    loopFlag: Bool = false,
    loopStartBytes: UInt32 = 0,
    paddingMarker: String = ""
) -> Data {
    var data = Data(repeating: 0, count: 0x800)
    data.replaceSubrange(0..<4, with: Data("Svag".utf8))
    setSVAGUInt32(dataSize, in: &data, at: 0x04)
    setSVAGUInt32(sampleRate, in: &data, at: 0x08)
    setSVAGUInt16(channels, in: &data, at: 0x0C)
    setSVAGUInt32(interleave, in: &data, at: 0x10)
    setSVAGUInt32(loopFlag ? 1 : 0, in: &data, at: 0x14)
    setSVAGUInt32(loopStartBytes, in: &data, at: 0x18)
    if !paddingMarker.isEmpty {
        data.replaceSubrange(0x400..<0x404, with: Data(paddingMarker.utf8))
    }
    return data
}

private func makeSNKSVAG(
    channels: UInt32,
    sampleRate: UInt32,
    blockCount: UInt32,
    loopStartBlock: UInt32 = 0,
    loopEndBlock: UInt32 = 0
) -> Data {
    var data = Data(repeating: 0, count: 0x20)
    data.replaceSubrange(0..<4, with: Data("VAGm".utf8))
    setSVAGUInt32(sampleRate, in: &data, at: 0x08)
    setSVAGUInt32(channels, in: &data, at: 0x0C)
    setSVAGUInt32(blockCount, in: &data, at: 0x10)
    setSVAGUInt32(loopStartBlock, in: &data, at: 0x18)
    setSVAGUInt32(loopEndBlock, in: &data, at: 0x1C)
    return data
}

private func setSVAGUInt16(_ value: UInt16, in data: inout Data, at offset: Int) {
    data.replaceSubrange(offset..<(offset + 2), with: [UInt8(value & 0xFF), UInt8(value >> 8)])
}

private func setSVAGUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
    data.replaceSubrange(
        offset..<(offset + 4),
        with: [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8(value >> 24)
        ]
    )
}
