import Foundation
import Testing
@testable import MetaManCore

@Test("Atomic Planet AUS preserves timing, native facts, and the complete header")
func atomicPlanetAUSReaderRetainsHeaderAndProjectsTiming() throws {
    let unloopedBytes = makeAUS(
        codec: 0,
        channels: 2,
        sampleRate: 48_000,
        samples: 48_000,
        loopStart: 12_000,
        loopEnd: 36_000
    )
    let unlooped = try MetaManCore.read(data: unloopedBytes, formatHint: "aus", displayName: "01_stage.aus")

    #expect(unlooped.format == "aus")
    #expect(unlooped.fields.title == "01_stage")
    #expect(unlooped.fields.comment == "Atomic Planet AUS header")
    #expect(unlooped.tags.isEmpty)
    #expect(unlooped.rawMetadataBlocks?["ausHeader"] == unloopedBytes)
    #expect(unlooped.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 0,
        playLengthMs: 1_000,
        fadeLengthMs: 0
    ))
    #expect(unlooped.technicalFacts["codec"] == "0")
    #expect(unlooped.technicalFacts["codecName"] == "PS-ADPCM")
    #expect(unlooped.technicalFacts["sampleCount"] == "48000")
    #expect(unlooped.technicalFacts["sampleRateHz"] == "48000")
    #expect(unlooped.technicalFacts["channels"] == "2")
    #expect(unlooped.technicalFacts["rawLoopStartSample"] == "12000")
    #expect(unlooped.technicalFacts["rawLoopEndSample"] == "36000")
    #expect(unlooped.technicalFacts["loopEnabled"] == "false")

    let xboxIMABytes = makeAUS(
        codec: 2,
        channels: 1,
        sampleRate: 44_100,
        samples: 44_100,
        loopStart: 11_025,
        loopEnd: 33_075,
        loopMarker: true
    )
    let xboxIMA = try MetaManCore.read(data: xboxIMABytes, formatHint: ".AUS", displayName: "looped.aus")
    #expect(xboxIMA.technicalFacts["codecName"] == "Xbox IMA ADPCM")
    #expect(xboxIMA.technicalFacts["loopEnabled"] == "true")
    #expect(xboxIMA.technicalFacts["loopStartSample"] == "11025")
    #expect(xboxIMA.technicalFacts["loopEndSample"] == "33075")
    #expect(xboxIMA.rawMetadataBlocks?["ausHeader"] == xboxIMABytes)
    #expect(xboxIMA.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 500,
        playLengthMs: 11_250,
        fadeLengthMs: 0
    ))

    let unknownCodec = try MetaManCore.read(
        data: makeAUS(codec: 0xFFFF, channels: 2, sampleRate: 32_000, samples: 32_000),
        formatHint: "aus"
    )
    #expect(unknownCodec.technicalFacts["codec"] == "65535")
    #expect(unknownCodec.technicalFacts["codecName"] == "PS-ADPCM")
    #expect(unknownCodec.fields.title == nil)
}

@Test("Atomic Planet AUS preserves legacy loop flags and vgmstream invalid-loop cleanup")
func atomicPlanetAUSReaderHandlesLoopVariants() throws {
    let legacyLoop = try MetaManCore.read(
        data: makeAUS(
            codec: 1,
            channels: 2,
            sampleRate: 32_000,
            samples: 32_000,
            loopStart: 8_000,
            loopEnd: 24_000,
            legacyLoopFlag: true
        ),
        formatHint: "aus",
        displayName: "legacy-loop.aus"
    )
    #expect(legacyLoop.technicalFacts["legacyLoopFlag"] == "1")
    #expect(legacyLoop.technicalFacts["loopMarker"] == "0")
    #expect(legacyLoop.timing?.loopLengthMs == 500)
    #expect(legacyLoop.timing?.playLengthMs == 11_250)

    let invalidLoop = try MetaManCore.read(
        data: makeAUS(
            codec: 0,
            channels: 2,
            sampleRate: 48_000,
            samples: 10_000,
            loopStart: 5_000,
            loopEnd: 20_000,
            loopMarker: true
        ),
        formatHint: "aus",
        displayName: "invalid-loop.aus"
    )
    #expect(invalidLoop.technicalFacts["loopEnabled"] == "true")
    #expect(invalidLoop.technicalFacts["rawLoopStartSample"] == "5000")
    #expect(invalidLoop.technicalFacts["rawLoopEndSample"] == "20000")
    #expect(invalidLoop.technicalFacts["loopStartSample"] == "0")
    #expect(invalidLoop.technicalFacts["loopEndSample"] == "0")
    #expect(invalidLoop.timing?.loopLengthMs == 0)
    #expect(invalidLoop.timing?.playLengthMs == 208)
}

@Test("Atomic Planet AUS rejects malformed headers and never claims aliases")
func atomicPlanetAUSReaderRejectsInvalidData() throws {
    #expect(AtomicPlanetAUSMetadataReader.matches(Data("AUS ".utf8)))
    #expect(!AtomicPlanetAUSMetadataReader.matches(Data("OTHER".utf8)))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("AUS ".utf8), formatHint: "aus")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("OTHER".utf8), formatHint: "aus")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(
            data: makeAUS(codec: 0, channels: 0, sampleRate: 48_000, samples: 10_000),
            formatHint: "aus"
        )
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(
            data: makeAUS(codec: 0, channels: 2, sampleRate: 48_000, samples: -1),
            formatHint: "aus"
        )
    }
    let valid = try MetaManCore.read(data: makeAUS(codec: 0, channels: 2, sampleRate: 48_000, samples: 1))
    #expect(valid.format == "aus")
}

private func makeAUS(
    codec: UInt16,
    channels: UInt16,
    sampleRate: Int32,
    samples: Int32,
    loopStart: Int32 = 0,
    loopEnd: Int32 = 0,
    legacyLoopFlag: Bool = false,
    loopMarker: Bool = false
) -> Data {
    var data = Data(repeating: 0, count: 0x20)
    data.replaceSubrange(0..<4, with: Data("AUS ".utf8))
    setAUSUInt16(codec, in: &data, at: 0x06)
    setAUSInt32(samples, in: &data, at: 0x08)
    setAUSUInt16(channels, in: &data, at: 0x0C)
    setAUSUInt16(legacyLoopFlag ? 1 : 0, in: &data, at: 0x0E)
    setAUSInt32(sampleRate, in: &data, at: 0x10)
    setAUSInt32(loopStart, in: &data, at: 0x14)
    setAUSInt32(loopEnd, in: &data, at: 0x18)
    setAUSUInt32(loopMarker ? 1 : 0, in: &data, at: 0x1C)
    return data
}

private func setAUSUInt16(_ value: UInt16, in data: inout Data, at offset: Int) {
    data.replaceSubrange(offset..<(offset + 2), with: [UInt8(value & 0xFF), UInt8(value >> 8)])
}

private func setAUSInt32(_ value: Int32, in data: inout Data, at offset: Int) {
    setAUSUInt32(UInt32(bitPattern: value), in: &data, at: offset)
}

private func setAUSUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
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
