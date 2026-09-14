import Foundation
import Testing
@testable import MetaManCore

@Test("Sony MSF PCM and PSX ADPCM preserve their header projection")
func sonyMSFReaderMapsIntegerCodecsAndRetainsHeader() throws {
    let pcm = try MetaManCore.read(
        data: makeSonyMSF(codec: 0, sampleRate: 48_000, payload: Data(repeating: 0x5A, count: 384), streamName: "Embedded title"),
        formatHint: "msf",
        displayName: "fallback.msf"
    )
    #expect(pcm.format == "msf")
    #expect(pcm.fields.title == "Embedded title")
    #expect(pcm.fields.comment == "Sony MSF header")
    #expect(pcm.tags == [MetadataTag(name: "streamName", value: "Embedded title")])
    #expect(pcm.sourceEncoding == "UTF-8")
    #expect(pcm.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 2, fadeLengthMs: 0))
    #expect(pcm.technicalFacts["codecName"] == "PCM16 big-endian")
    #expect(pcm.technicalFacts["channels"] == "2")
    #expect(pcm.technicalFacts["decodedSampleCount"] == "96")
    #expect(pcm.rawMetadataBlocks?["msfHeader"] == Data(pcmSourceHeader(streamName: "Embedded title")))

    let littleEndianPCM = try MetaManCore.read(
        data: makeSonyMSF(codec: 1, sampleRate: 48_000, payload: Data(repeating: 0xA5, count: 384)),
        formatHint: "msf",
        displayName: "fallback.msf"
    )
    #expect(littleEndianPCM.fields.title == "fallback")
    #expect(littleEndianPCM.timing?.playLengthMs == 2)
    #expect(littleEndianPCM.technicalFacts["codecName"] == "PCM16 little-endian")

    let psx = try MetaManCore.read(
        data: makeSonyMSF(codec: 3, sampleRate: 44_100, payload: Data(repeating: 0, count: 64)),
        formatHint: "msf",
        displayName: "psx.msf"
    )
    #expect(psx.timing?.playLengthMs == 1)
    #expect(psx.technicalFacts["codecName"] == "PlayStation ADPCM")
}

@Test("Sony MSF ATRAC3 variants retain encoder delay and invalid-loop cleanup")
func sonyMSFReaderMapsATRAC3Timing() throws {
    for (codec, frameSize) in [(UInt32(4), 0x60), (5, 0x98), (6, 0xC0)] {
        let payload = Data(repeating: 0, count: frameSize * 2 * 2)
        let document = try MetaManCore.read(
            data: makeSonyMSF(codec: codec, sampleRate: -1, payload: payload),
            formatHint: "msf",
            displayName: "atrac.msf"
        )
        #expect(document.timing?.playLengthMs == 20, "codec \(codec)")
        #expect(document.technicalFacts["sampleRateHz"] == "44100")
        #expect(document.technicalFacts["encoderDelaySamples"] == "1162")
    }

    let frameSize = 0x98 * 2
    let looping = try MetaManCore.read(
        data: makeSonyMSF(
            codec: 5,
            sampleRate: 44_100,
            payload: Data(repeating: 0, count: frameSize * 5),
            flags: 0x01,
            loopStart: UInt32(frameSize * 2),
            loopDuration: UInt32(frameSize * 2)
        ),
        formatHint: "msf",
        displayName: "looping.msf"
    )
    #expect(looping.timing?.loopLengthMs == 46)
    #expect(looping.timing?.playLengthMs == 10_112)
    #expect(looping.technicalFacts["loopEnabled"] == "true")
    #expect(looping.technicalFacts["effectiveLoopStartSample"] == "886")

    let ignoredBadLoop = try MetaManCore.read(
        data: makeSonyMSF(
            codec: 5,
            sampleRate: 44_100,
            payload: Data(repeating: 0, count: frameSize * 4),
            flags: 0x01,
            loopStart: UInt32(frameSize * 2),
            loopDuration: UInt32(frameSize * 4)
        ),
        formatHint: "msf",
        displayName: "out-of-range-loop.msf"
    )
    #expect(ignoredBadLoop.timing?.loopLengthMs == 0)
    #expect(ignoredBadLoop.timing?.playLengthMs == 66)
    #expect(ignoredBadLoop.technicalFacts["loopEnabled"] == "false")
    #expect(ignoredBadLoop.technicalFacts["invalidLoopCleared"] == "true")
}

@Test("Sony MSF MPEG CBR and VBR count frame headers without decoding")
func sonyMSFReaderCountsMPEGFrames() throws {
    let cbrPayload = makeMPEGFrame(header: 0xFFFB_9000, size: 417)
        + makeMPEGFrame(header: 0xFFFB_9000, size: 417)
    let cbr = try MetaManCore.read(
        data: makeSonyMSF(codec: 7, sampleRate: 44_100, payload: cbrPayload, flags: 0x40),
        formatHint: "msf",
        displayName: "constant-rate.msf"
    )
    #expect(cbr.timing?.playLengthMs == 52)
    #expect(cbr.technicalFacts["mpegVariableBitRate"] == "false")

    let vbrPayload = makeMPEGFrame(header: 0xFFFB_9000, size: 417)
        + makeMPEGFrame(header: 0xFFFB_B000, size: 626)
    let vbr = try MetaManCore.read(
        data: makeSonyMSF(
            codec: 7,
            sampleRate: 44_100,
            payload: vbrPayload,
            flags: 0x21,
            loopStart: 0,
            loopDuration: UInt32(vbrPayload.count)
        ),
        formatHint: "msf",
        displayName: "variable-rate.msf"
    )
    #expect(vbr.timing?.loopLengthMs == 52)
    #expect(vbr.timing?.playLengthMs == 10_104)
    #expect(vbr.technicalFacts["mpegVariableBitRate"] == "true")
}

@Test("Sony MSF content probe distinguishes the TamaSoft alias")
func sonyMSFReaderUsesContentAwareAdmission() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-msf-probe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    for (name, signature, expected) in [
        ("sony.msf", "MSF0", true),
        ("konami.msf", "MSFC", true),
        ("tamasoft.msf", "MSF ", false),
        ("unknown.msf", "OTHER", false)
    ] {
        let url = directory.appendingPathComponent(name)
        try Data(Array(signature.utf8) + [UInt8](repeating: 0, count: 0x3C)).write(to: url)
        #expect(MetaManCore.canReadDirectly(fileURL: url, formatHint: "msf") == expected, Comment(rawValue: name))
    }

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(
            data: makeSonyMSF(codec: 2, sampleRate: 48_000, payload: Data(repeating: 0, count: 32)),
            formatHint: "msf",
            displayName: "unsupported.msf"
        )
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("MSF ".utf8), formatHint: "msf")
    }
}

@Test("Sony MSF honors remainder-sized payloads and retains malformed source names")
func sonyMSFReaderValidatesHeaderBoundsAndPreservesRawBytes() throws {
    var remainderSized = makeSonyMSF(
        codec: 0,
        sampleRate: 48_000,
        payload: Data(repeating: 0x5A, count: 384)
    )
    setMSFUInt32(UInt32.max, in: &remainderSized, at: 0x0C)
    let remainderDocument = try MetaManCore.read(
        data: remainderSized,
        formatHint: "msf",
        displayName: "sentinel.msf"
    )
    #expect(remainderDocument.technicalFacts["dataSizeUsesRemainder"] == "true")
    #expect(remainderDocument.technicalFacts["dataSizeBytes"] == "384")

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("MSF0".utf8), formatHint: "msf")
    }

    var tooManyChannels = makeSonyMSF(codec: 0, sampleRate: 48_000, payload: Data(repeating: 0, count: 384))
    setMSFUInt32(33, in: &tooManyChannels, at: 0x08)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: tooManyChannels, formatHint: "msf")
    }

    var outOfBounds = makeSonyMSF(codec: 0, sampleRate: 48_000, payload: Data(repeating: 0, count: 384))
    setMSFUInt32(0xFFFF, in: &outOfBounds, at: 0x0C)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: outOfBounds, formatHint: "msf")
    }

    var invalidName = makeSonyMSF(codec: 0, sampleRate: 48_000, payload: Data(repeating: 0, count: 384))
    invalidName[0x18] = 0xFF
    invalidName[0x19] = 0
    let invalidNameDocument = try MetaManCore.read(
        data: invalidName,
        formatHint: "msf",
        displayName: "filename-fallback.msf"
    )
    #expect(invalidNameDocument.fields.title == "filename-fallback")
    #expect(!invalidNameDocument.diagnostics.isEmpty)
    #expect(invalidNameDocument.rawMetadataBlocks?["msfHeader"] == Data(invalidName.prefix(0x40)))
}

private func makeSonyMSF(
    codec: UInt32,
    channels: UInt32 = 2,
    sampleRate: Int32,
    payload: Data,
    flags: UInt32 = 0x40,
    loopStart: UInt32 = 0,
    loopDuration: UInt32 = 0,
    streamName: String? = nil
) -> Data {
    var data = Data(repeating: 0, count: 0x40)
    data.replaceSubrange(0..<4, with: Data("MSF0".utf8))
    setMSFUInt32(codec, in: &data, at: 0x04)
    setMSFUInt32(channels, in: &data, at: 0x08)
    setMSFUInt32(UInt32(payload.count), in: &data, at: 0x0C)
    setMSFUInt32(UInt32(bitPattern: sampleRate), in: &data, at: 0x10)
    setMSFUInt32(flags, in: &data, at: 0x14)
    if flags != UInt32.max && flags & 0x03 != 0 {
        setMSFUInt32(loopStart, in: &data, at: 0x18)
        setMSFUInt32(loopDuration, in: &data, at: 0x1C)
    }
    if let streamName {
        let name = Data(streamName.utf8)
        data.replaceSubrange(0x18..<(0x18 + min(name.count, 0x27)), with: name.prefix(0x27))
        setMSFUInt32(0, in: &data, at: 0x28)
    }
    data.append(payload)
    return data
}

private func pcmSourceHeader(streamName: String) -> [UInt8] {
    Array(makeSonyMSF(
        codec: 0,
        sampleRate: 48_000,
        payload: Data(repeating: 0x5A, count: 384),
        streamName: streamName
    ).prefix(0x40))
}

private func makeMPEGFrame(header: UInt32, size: Int) -> Data {
    var frame = Data(repeating: 0, count: size)
    setMSFUInt32(header, in: &frame, at: 0)
    return frame
}

private func setMSFUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
    data.replaceSubrange(
        offset..<(offset + 4),
        with: [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    )
}
