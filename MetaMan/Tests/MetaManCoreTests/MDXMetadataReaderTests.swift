import Foundation
import Testing
@testable import MetaManCore

private func makeMDXFixture(streams: [[UInt8]]) -> Data {
    var data = Data("MetaMan timing fixture".utf8)
    data.append(contentsOf: [0x0D, 0x0A, 0x1A, 0x00])
    let headerOffset = data.count
    let offsetTableLength = 2 + streams.count * 2
    let voiceDataRelativeOffset = offsetTableLength
    var sequenceCursor = headerOffset + offsetTableLength + 27
    var sequenceOffsets: [Int] = []
    for stream in streams {
        sequenceOffsets.append(sequenceCursor - headerOffset)
        sequenceCursor += stream.count
    }

    func appendBigEndian(_ value: Int, to data: inout Data) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    appendBigEndian(voiceDataRelativeOffset, to: &data)
    for offset in sequenceOffsets { appendBigEndian(offset, to: &data) }
    data.append(contentsOf: [UInt8](repeating: 0, count: 27))
    for stream in streams { data.append(contentsOf: stream) }
    return data
}

private func mdxTracks(first: [UInt8]) -> [[UInt8]] {
    [first] + Array(repeating: [0xF1, 0x00, 0x00], count: 8)
}

@Test("MDX metadata reads the bounded Shift-JIS title and PDX reference without a decoder")
func mdxReadsHeaderMetadataAndKeepsItsRawBytes() throws {
    let title = Data("X68000 Opening Theme".utf8)
    let bank = Data("samples/NOS.PDX".utf8)
    var data = title
    data.append(contentsOf: [0x0D, 0x0A, 0x1A])
    data.append(bank)
    data.append(0)
    data.append(contentsOf: [0x00, 0x04, 0x00, 0x00])
    data.append(Data(repeating: 0xA5, count: 2_000))

    let document = try MetaManCore.read(data: data, formatHint: ".MDX", displayName: "opening.mdx")
    #expect(document.format == "mdx")
    #expect(document.fields.title == "X68000 Opening Theme")
    #expect(document.fields.system == "Sharp X68000")
    #expect(document.values(forTag: "title") == ["X68000 Opening Theme"])
    #expect(document.values(forTag: "pdx") == ["samples/NOS.PDX"])
    #expect(document.sourceEncoding == "Shift-JIS")
    #expect(document.technicalFacts["mdx.requiresPDX"] == "true")
    #expect(document.technicalFacts["mdx.pdxName"] == "samples/NOS.PDX")
    #expect(document.technicalFacts["mdx.sequenceTiming"] == "unavailable")
    #expect(document.rawMetadataBlocks?["mdxTextHeader"] == Data(data[..<(title.count + 3 + bank.count + 1)]))

    let result = try MetaManCore.readResult(data: data, formatHint: "mdx", displayName: "opening.mdx")
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].document == document)
}

@Test("MDX file-URL metadata maps source data and permits a missing PDX")
func mdxFileURLUsesBoundedHeaderReader() throws {
    var data = Data("Untitled sequence".utf8)
    data.append(contentsOf: [0x0D, 0x0A, 0x1A, 0x00])
    data.append(contentsOf: [0x00, 0x04, 0x00, 0x00])
    data.append(Data(repeating: 0x5A, count: 2 * 1024 * 1024))
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-MDX-\(UUID().uuidString).mdx")
    try data.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let document = try MetaManCore.read(fileURL: url)
    #expect(document.fields.title == "Untitled sequence")
    #expect(document.technicalFacts["mdx.requiresPDX"] == "false")
    #expect(document.technicalFacts["mdx.sequenceDataOffset"] != nil)
    #expect(document.technicalFacts["mdx.sequenceTiming"] == "unavailable")
    #expect(try MetaManCore.readResult(fileURL: url).tracks.first?.document == document)
}

@Test("MDX duration comes from the timed MML sequence rather than a playback helper")
func mdxTimingUsesSequenceCommands() throws {
    let document = try MetaManCore.read(data: makeMDXFixture(streams: mdxTracks(first: [
        0xFF, 200,       // tempo 200
        0x80, 0x01,      // a two-tick note
        0xF1, 0x00, 0x00 // end this sequence
    ])), formatHint: "mdx")

    #expect(document.timing == MetadataTiming(
        introLengthMs: 29,
        loopLengthMs: 0,
        playLengthMs: 29,
        fadeLengthMs: 0
    ))
    #expect(document.technicalFacts["mdx.sequenceTiming"] == "available")
    #expect(document.technicalFacts["mdx.timingMethod"] == "bounded-mml-sequence-walk")
    #expect(document.technicalFacts["mdx.timingTicks"] == "2")
}

@Test("MDX counted repeats contribute their sequence ticks")
func mdxTimingWalksCountedRepeats() throws {
    let document = try MetaManCore.read(data: makeMDXFixture(streams: mdxTracks(first: [
        0xF6, 0x02,             // repeat twice
        0x80, 0x00,             // one-tick note
        0xF5, 0xFF, 0xFB,       // jump back to the note
        0xF1, 0x00, 0x00        // end
    ])), formatHint: "mdx")

    #expect(document.timing?.playLengthMs == 29)
    #expect(document.technicalFacts["mdx.timingTicks"] == "2")
}

@Test("MDX tempo changes alter the measured tick duration")
func mdxTimingUsesCurrentTempo() throws {
    let document = try MetaManCore.read(data: makeMDXFixture(streams: mdxTracks(first: [
        0xFF, 128,          // tempo 128
        0x80, 0x02,         // three ticks
        0xF1, 0x00, 0x00
    ])), formatHint: "mdx")

    #expect(document.timing?.playLengthMs == 98)
    #expect(document.technicalFacts["mdx.timingTicks"] == "3")
}

@Test("MDX infinite F1 loops use the documented bounded loop and fade policy")
func mdxTimingBoundsInfiniteLoops() throws {
    let document = try MetaManCore.read(data: makeMDXFixture(streams: mdxTracks(first: [
        0x80, 0x00,          // one-tick loop body
        0xF1, 0xFF, 0xFB     // return to the note until the loop policy fades
    ])), formatHint: "mdx")

    #expect(document.timing?.playLengthMs == 9_146)
    #expect(document.technicalFacts["mdx.timingTicks"] == "638")
}

@Test("MDX LZX bodies retain clear tags but report sequence timing as unavailable")
func mdxCompressedBodyDoesNotClaimNativeDuration() throws {
    var data = Data("Compressed fixture".utf8)
    data.append(contentsOf: [0x0D, 0x0A, 0x1A, 0x00])
    data.append(contentsOf: [0x60, 0x26, 0x60, 0x32])
    data.append(contentsOf: Array("LZX 0.42".utf8))
    data.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

    let document = try MetaManCore.read(data: data, formatHint: "mdx")
    #expect(document.fields.title == "Compressed fixture")
    #expect(document.timing == nil)
    #expect(document.technicalFacts["mdx.sequenceTiming"] == "unavailable")
    #expect(document.diagnostics.contains { $0.contains("LZX-compressed") })
}

@Test("MDX rejects an unterminated or oversized text header")
func mdxRejectsMalformedTextHeader() {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data(repeating: 0x41, count: 40), formatHint: "mdx")
    }

    var oversized = Data(repeating: 0x41, count: 1_025)
    oversized.append(contentsOf: [0x0D, 0x0A, 0x1A, 0x00, 0x00, 0x00, 0x00, 0x00])
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: oversized, formatHint: "mdx")
    }

    var unterminatedBank = Data("Title".utf8)
    unterminatedBank.append(contentsOf: [0x0D, 0x0A, 0x1A])
    unterminatedBank.append(Data(repeating: 0x41, count: 1_025))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: unterminatedBank, formatHint: "mdx")
    }
}
