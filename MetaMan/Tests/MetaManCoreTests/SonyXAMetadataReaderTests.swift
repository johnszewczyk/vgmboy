import Foundation
import Testing
@testable import MetaManCore

@Test("Sony XA reports source format facts and decoder-compatible timing")
func sonyXAReaderRetainsSectorAndAudioFacts() throws {
    let result = try MetaManCore.readResult(
        data: makeXARaw((0..<3).map { _ in makeXASector() }),
        formatHint: "xa",
        displayName: "Opening Theme.xa"
    )

    #expect(result.tracks.count == 1)
    let document = result.tracks[0].document
    #expect(document.format == "xa")
    #expect(document.fields.title == "Opening Theme")
    #expect(document.fields.comment == "Sony XA header")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 160, fadeLengthMs: 0))
    #expect(document.technicalFacts["container"] == "raw-sector")
    #expect(document.technicalFacts["sectorSizeBytes"] == "2352")
    #expect(document.technicalFacts["audioSectorCount"] == "3")
    #expect(document.technicalFacts["sampleRateHz"] == "37800")
    #expect(document.technicalFacts["sampleCountPerSector"] == "2016")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["bitsPerSample"] == "4")
    #expect(document.technicalFacts["form"] == "2")
}

@Test("Sony XA retains Form 1 and 8-bit stereo timing")
func sonyXAReaderCoversFormAndSampleModes() throws {
    let formOne = try MetaManCore.readResult(
        data: makeXARaw((0..<3).map { _ in makeXASector(submode: 0x44, header: 0x05) }),
        formatHint: "xa",
        displayName: "Form 1.xa"
    )
    #expect(formOne.tracks[0].document.timing?.playLengthMs == 284)
    #expect(formOne.tracks[0].document.technicalFacts["form"] == "1")
    #expect(formOne.tracks[0].document.technicalFacts["sampleRateHz"] == "18900")

    let eightBit = try MetaManCore.readResult(
        data: makeXARaw((0..<3).map { _ in makeXASector(header: 0x11) }),
        formatHint: "xa",
        displayName: "8-bit.xa"
    )
    #expect(eightBit.tracks[0].document.timing?.playLengthMs == 80)
    #expect(eightBit.tracks[0].document.technicalFacts["bitsPerSample"] == "8")
}

@Test("Sony XA preserves interleaved channel and end-of-track ordering")
func sonyXAReaderEnumeratesInterleavedSubtracks() throws {
    let sectors = [
        makeXASector(file: 1, channel: 0),
        makeXASector(file: 1, channel: 1),
        makeXASector(file: 1, channel: 0),
        makeXASector(file: 1, channel: 0, submode: 0xE4),
        makeXASector(file: 1, channel: 0)
    ]
    let result = try MetaManCore.readResult(data: makeXARaw(sectors), formatHint: "xa", displayName: "BGM.XA")

    #expect(result.tracks.count == 3)
    #expect(result.tracks.map { $0.document.fields.title ?? "" } == ["0100", "0101", "0100"])
    #expect(result.tracks.compactMap { $0.document.timing?.playLengthMs } == [160, 53, 53])
    #expect(result.tracks.map { $0.document.technicalFacts["xaConfiguration"] } == ["0100", "0101", "0100"])
}

@Test("Sony XA accepts RIFF/CDXA and decoder-tolerated short sector prefixes")
func sonyXAReaderPreservesContainerAndShortSourceBoundaries() throws {
    let riff = try MetaManCore.readResult(
        data: makeXARIFF(makeXARaw((0..<3).map { _ in makeXASector() })),
        formatHint: "xa",
        displayName: "wrapped.xa"
    )
    #expect(riff.tracks[0].document.technicalFacts["container"] == "RIFF/CDXA")
    #expect(riff.tracks[0].document.timing?.playLengthMs == 160)

    let oneSector = try MetaManCore.readResult(data: makeXARaw([makeXASector()]), formatHint: "xa")
    #expect(oneSector.tracks[0].document.timing?.playLengthMs == 53)

    let truncated = try MetaManCore.readResult(
        data: Data(makeXASector().prefix(100)),
        formatHint: "xa",
        displayName: "partial-sector.xa"
    )
    #expect(truncated.tracks[0].document.timing?.playLengthMs == 53)
}

@Test("Sony XA rejects malformed content and keeps its result track-aware")
func sonyXAReaderRejectsMalformedContentAndSingularRead() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data("XA30".utf8), formatHint: "xa")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(
            data: makeXARaw((0..<3).map { _ in makeXASector(header: 0x03) }),
            formatHint: "xa"
        )
    }
    #expect(throws: MetadataReadError.trackAwareResultRequired("Sony XA")) {
        try MetaManCore.read(data: makeXARaw([makeXASector()]), formatHint: "xa")
    }
}

private func makeXARaw(_ sectors: [Data]) -> Data {
    sectors.reduce(into: Data()) { $0.append($1) }
}

private func makeXARIFF(_ payload: Data) -> Data {
    var wrapped = Data(repeating: 0, count: 0x2C)
    wrapped.replaceSubrange(0..<4, with: Data("RIFF".utf8))
    wrapped.replaceSubrange(0x08..<0x0C, with: Data("CDXA".utf8))
    wrapped.replaceSubrange(0x0C..<0x10, with: Data("fmt ".utf8))
    wrapped.append(payload)
    return wrapped
}

private func makeXASector(
    file: UInt8 = 0,
    channel: UInt8 = 0,
    submode: UInt8 = 0x64,
    header: UInt8 = 0x01
) -> Data {
    var sector = Data(repeating: 0, count: 0x930)
    sector.replaceSubrange(0..<12, with: Data([0x00] + Array(repeating: 0xFF, count: 10) + [0x00]))
    let subheader = Data([file, channel, submode, header])
    sector.replaceSubrange(0x10..<0x14, with: subheader)
    sector.replaceSubrange(0x14..<0x18, with: subheader)
    let frameHeader = Data([
        0x11, 0x22, 0x31, 0x12, 0x11, 0x22, 0x31, 0x12,
        0x11, 0x22, 0x31, 0x12, 0x11, 0x22, 0x31, 0x12
    ])
    for frame in 0..<(0x900 / 0x80) {
        let offset = 0x18 + frame * 0x80
        sector.replaceSubrange(offset..<(offset + frameHeader.count), with: frameHeader)
    }
    return sector
}
