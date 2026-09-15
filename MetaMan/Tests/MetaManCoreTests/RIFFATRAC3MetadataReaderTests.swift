import Foundation
import Testing
@testable import MetaManCore

@Test("ATRAC3 RIFF exposes exact source chunks, facts, loops, and legacy timing")
func riffATRAC3ReaderPreservesSourceAndSMPLTiming() throws {
    let source = makeAT3Wave(
        sampleCount: 200_000,
        sampleSkip: 1_000,
        loopStart: 10_000,
        loopEnd: 109_999
    )
    let document = try MetaManCore.read(data: source, formatHint: "at3", displayName: "Loop Theme.at3")

    #expect(document.format == "at3")
    #expect(document.fields.title == "Loop Theme")
    #expect(document.fields.comment == "RIFF WAVE header (smpl looping)")
    #expect(document.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 2_267,
        playLengthMs: 14_739,
        fadeLengthMs: 0
    ))
    #expect(document.technicalFacts["codecTag"] == "624")
    #expect(document.technicalFacts["codecName"] == "ATRAC3")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleRateHz"] == "44100")
    #expect(document.technicalFacts["factSampleCount"] == "200000")
    #expect(document.technicalFacts["encoderSkipSamples"] == "1000")
    #expect(document.technicalFacts["rawSMPLLoopStartSample"] == "10000")
    #expect(document.technicalFacts["rawSMPLLoopEndSample"] == "109999")
    #expect(document.technicalFacts["effectiveLoopStartSample"] == "9000")
    #expect(document.technicalFacts["effectiveLoopEndSampleExclusive"] == "109000")
    #expect(document.rawMetadataBlocks?["riffHeader"] == Data(source.prefix(12)))
    #expect(document.rawMetadataBlocks?["riffChunk.fmt #0"] == riffChunk("fmt ", payload: makeAT3Format()))
    #expect(document.rawMetadataBlocks?["riffChunk.fact#0"] != nil)
    #expect(document.rawMetadataBlocks?["riffChunk.smpl#0"] != nil)
    #expect(document.rawMetadataBlocks?["riffChunk.data#0"] == nil)
    #expect(document.tags.isEmpty)

    let unlooped = try MetaManCore.read(
        data: makeAT3Wave(sampleCount: 44_100),
        formatHint: "at3",
        displayName: "Opening.at3"
    )
    #expect(unlooped.fields.comment == "RIFF WAVE header")
    #expect(unlooped.timing?.loopLengthMs == 0)
    #expect(unlooped.timing?.playLengthMs == 1_000)
}

@Test("ATRAC3+ extensible GUID and fact encoder skip are retained")
func riffATRAC3PlusReaderExposesExtensibleFacts() throws {
    let document = try MetaManCore.read(
        data: makeAT3Wave(sampleCount: 88_200, sampleSkip: 2_000, extensible: true),
        formatHint: "at3",
        displayName: "Plus.at3"
    )

    #expect(document.fields.title == "Plus")
    #expect(document.technicalFacts["codecTag"] == "65534")
    #expect(document.technicalFacts["codecName"] == "ATRAC3+")
    #expect(document.technicalFacts["formatExtensionBytes"] == "22")
    #expect(document.technicalFacts["validBitsPerSample"] == "16")
    #expect(document.technicalFacts["channelMask"] == "3")
    #expect(document.technicalFacts["subFormatGUID"] == "bfaa23e958cb7144a119fffa01e4ce62")
    #expect(document.technicalFacts["encoderSkipSamples"] == "2000")
    #expect(document.timing?.playLengthMs == 2_000)
}

@Test("RIFF wsmp loop points retain their exclusive end and timing projection")
func riffATRAC3ReaderPreservesWSMPLoopProjection() throws {
    let document = try MetaManCore.read(
        data: makeAT3Wave(
            sampleCount: 200_000,
            sampleSkip: 1_000,
            wsmpLoopStart: 10_000,
            wsmpLoopLength: 90_000
        ),
        formatHint: "at3",
        displayName: "WSMP Theme.at3"
    )

    #expect(document.fields.comment == "RIFF WAVE header (wsmp looping)")
    #expect(document.technicalFacts["loopSource"] == "wsmp")
    #expect(document.technicalFacts["rawWSMPLoopStartSample"] == "10000")
    #expect(document.technicalFacts["rawWSMPLoopEndSample"] == "100000")
    #expect(document.technicalFacts["effectiveLoopEndSampleExclusive"] == "100000")
    #expect(document.timing?.loopLengthMs == 2_040)
    #expect(document.timing?.playLengthMs == 14_308)
}

@Test("RIFF LIST INFO preserves ordered duplicate and unknown metadata")
func riffATRAC3ReaderParsesInfoTagsAndRetainsTheSourceBlock() throws {
    let infoItems: [(String, Data)] = [
        ("INAM", Data("Tagged Theme".utf8)),
        ("IPRD", Data("Example Game".utf8)),
        ("IART", Data("Composer".utf8)),
        ("ICMT", Data("Authored note".utf8)),
        ("ICRD", Data("2001-02-03".utf8)),
        ("IGNR", Data("Game".utf8)),
        ("ICOP", Data("Studio".utf8)),
        ("ISFT", Data("Encoder".utf8)),
        ("X-??", Data("Unknown key".utf8)),
        ("INAM", Data("Second title".utf8))
    ]
    let infoPayload = makeInfoPayload(infoItems)
    let source = makeAT3Wave(sampleCount: 44_100, infoPayload: infoPayload)
    let document = try MetaManCore.read(data: source, formatHint: "at3", displayName: "Filename.at3")

    #expect(document.fields.title == "Tagged Theme")
    #expect(document.fields.game == "Example Game")
    #expect(document.fields.album == "Example Game")
    #expect(document.fields.artist == "Composer")
    #expect(document.fields.comment == "Authored note")
    #expect(document.fields.date == "2001-02-03")
    #expect(document.fields.genre == "Game")
    #expect(document.fields.copyright == "Studio")
    #expect(document.fields.encodedBy == "Encoder")
    #expect(document.values(forTag: "inam") == ["Tagged Theme", "Second title"])
    #expect(document.value(forTag: "x-??") == "Unknown key")
    #expect(document.sourceEncoding == "UTF-8")
    #expect(document.rawTagBlock == infoPayload)
    #expect(document.rawMetadataBlocks?["riffChunk.LIST#0"] == riffChunk("LIST", payload: infoPayload))
    #expect(document.technicalFacts["infoTagCount"] == "10")
    #expect(document.diagnostics.isEmpty)

    let windows1252 = try MetaManCore.read(
        data: makeAT3Wave(sampleCount: 44_100, infoPayload: makeInfoPayload([("INAM", Data([0x43, 0x61, 0x66, 0xE9]))])),
        formatHint: "at3",
        displayName: "Encoding.at3"
    )
    #expect(windows1252.fields.title == "Café")
    #expect(windows1252.sourceEncoding == "Windows-1252")
}

@Test("ATRAC3 recognition is content-aware and malformed RIFF input is rejected")
func riffATRAC3RecognitionPreservesAliases() throws {
    let valid = makeAT3Wave(sampleCount: 44_100)
    let invalidCodec = makeAT3Wave(sampleCount: 44_100, codec: 1)
    #expect(RIFFATRAC3MetadataReader.matches(valid))
    #expect(!RIFFATRAC3MetadataReader.matches(invalidCodec))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("RIFFWAVE".utf8), formatHint: "at3")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: invalidCodec, formatHint: "at3")
    }

    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-at3-probe-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let supportedURL = directory.appendingPathComponent("music.at3")
    try valid.write(to: supportedURL)
    let aliasURL = directory.appendingPathComponent("other.at3")
    try invalidCodec.write(to: aliasURL)
    #expect(MetaManCore.canReadDirectly(fileURL: supportedURL, formatHint: "at3"))
    #expect(!MetaManCore.canReadDirectly(fileURL: aliasURL, formatHint: "at3"))
    let autoDetected = try MetaManCore.read(data: valid)
    #expect(autoDetected.format == "at3")
}

private func makeAT3Wave(
    sampleCount: UInt32,
    sampleSkip: UInt32 = 0,
    loopStart: UInt32? = nil,
    loopEnd: UInt32? = nil,
    wsmpLoopStart: UInt32? = nil,
    wsmpLoopLength: UInt32? = nil,
    extensible: Bool = false,
    codec: UInt16 = 0x0270,
    infoPayload: Data? = nil
) -> Data {
    let format = makeAT3Format(extensible: extensible, codec: codec)
    var fact = Data()
    appendUInt32LE(sampleCount, to: &fact)
    appendUInt32LE(sampleSkip, to: &fact)
    var chunks = riffChunk("fmt ", payload: format)
    if let infoPayload { chunks.append(riffChunk("LIST", payload: infoPayload)) }
    chunks.append(riffChunk("fact", payload: fact))

    if let loopStart, let loopEnd {
        var smpl = Data(repeating: 0, count: 0x3C)
        writeUInt32LE(1, into: &smpl, at: 0x1C)
        writeUInt32LE(loopStart, into: &smpl, at: 0x2C)
        writeUInt32LE(loopEnd, into: &smpl, at: 0x30)
        chunks.append(riffChunk("smpl", payload: smpl))
    }
    if let wsmpLoopStart, let wsmpLoopLength {
        var wsmp = Data(repeating: 0, count: 0x24)
        writeUInt32LE(0x14, into: &wsmp, at: 0x00)
        writeUInt32LE(1, into: &wsmp, at: 0x10)
        writeUInt32LE(0x10, into: &wsmp, at: 0x14)
        writeUInt32LE(wsmpLoopStart, into: &wsmp, at: 0x1C)
        writeUInt32LE(wsmpLoopLength, into: &wsmp, at: 0x20)
        chunks.append(riffChunk("wsmp", payload: wsmp))
    }
    chunks.append(riffChunk("data", payload: Data([0, 0, 0, 0])))

    var body = Data("WAVE".utf8)
    body.append(chunks)
    var result = Data("RIFF".utf8)
    appendUInt32LE(UInt32(body.count), to: &result)
    result.append(body)
    return result
}

private func makeAT3Format(extensible: Bool = false, codec: UInt16 = 0x0270) -> Data {
    var format = Data()
    appendUInt16LE(extensible ? 0xFFFE : codec, to: &format)
    appendUInt16LE(2, to: &format)
    appendUInt32LE(44_100, to: &format)
    appendUInt32LE(24_000, to: &format)
    appendUInt16LE(0x0460, to: &format)
    appendUInt16LE(34, to: &format)
    if extensible {
        appendUInt16LE(0x16, to: &format)
        appendUInt16LE(16, to: &format)
        appendUInt32LE(3, to: &format)
        format.append(contentsOf: [
            0xBF, 0xAA, 0x23, 0xE9, 0x58, 0xCB, 0x71, 0x44,
            0xA1, 0x19, 0xFF, 0xFA, 0x01, 0xE4, 0xCE, 0x62
        ])
    } else {
        appendUInt16LE(0, to: &format)
    }
    return format
}

private func makeInfoPayload(_ items: [(String, Data)]) -> Data {
    var payload = Data("INFO".utf8)
    for (name, bytes) in items {
        payload.append(riffChunk(name, payload: bytes + Data([0])))
    }
    return payload
}

private func riffChunk(_ identifier: String, payload: Data) -> Data {
    var result = Data(identifier.utf8)
    appendUInt32LE(UInt32(payload.count), to: &result)
    result.append(payload)
    if payload.count % 2 == 1 { result.append(0) }
    return result
}

private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
    data.append(UInt8(truncatingIfNeeded: value >> 16))
    data.append(UInt8(truncatingIfNeeded: value >> 24))
}

private func writeUInt32LE(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
