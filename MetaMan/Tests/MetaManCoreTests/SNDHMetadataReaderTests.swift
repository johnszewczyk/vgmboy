import Foundation
import Testing
@testable import MetaManCore

@Test("SNDH direct reader exposes ordered tracks, tags, raw bytes, and FRMS timing")
func sndhReaderPreservesTagsAndSubtuneFacts() throws {
    let source = makeSNDH(
        trackCount: 3,
        titleBytes: Array("File title".utf8),
        names: ["Opening", "Stage 1", "Ending"],
        timerFrequency: 50,
        frameCounts: [500, 1_001, 2_000],
        times: [3, 5, 7],
        defaultSubtune: 2
    )

    let result = try MetaManCore.readResult(data: source, formatHint: "sndh", displayName: "demo.sndh")
    #expect(result.tracks.map(\.sourceTrackIndex) == [1, 2, 3])
    #expect(result.tracks.map { $0.document.fields.title } == ["Opening", "Stage 1", "Ending"])
    #expect(result.tracks.allSatisfy { $0.document.fields.system == "Atari ST" })
    #expect(result.tracks.allSatisfy { $0.document.fields.artist == "Composer" })
    #expect(result.tracks.allSatisfy { $0.document.fields.year == "1994" })
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [10_000, 20_020, 40_000])

    let first = try #require(result.tracks.first?.document)
    #expect(first.format == "sndh")
    #expect(first.sourceEncoding == "Atari ST")
    #expect(first.values(forTag: "TITL") == ["File title"])
    #expect(first.values(forTag: "!#SN") == ["Opening", "Stage 1", "Ending"])
    #expect(first.values(forTag: "TIME") == ["3", "5", "7"])
    #expect(first.values(forTag: "FRMS") == ["500", "1001", "2000"])
    #expect(first.technicalFacts["trackCount"] == "3")
    #expect(first.technicalFacts["sourceTrackIndex"] == "1")
    #expect(first.technicalFacts["defaultSubtune"] == "2")
    #expect(first.technicalFacts["timerTag"] == "!V")
    #expect(first.technicalFacts["timerFrequency"] == "50")
    #expect(first.rawTagBlock == Data(source[16..<(source.count - 1)]))
    #expect(first.diagnostics.isEmpty)
    #expect(MetaManCore.supportedFormats.contains { $0.identifier == "sndh" })
    #expect(throws: MetadataReadError.trackAwareResultRequired("SNDH")) {
        try MetaManCore.read(data: source, formatHint: "sndh", displayName: "demo.sndh")
    }
}

@Test("SNDH TIME fallback and zero timer frequency use the 50 Hz default")
func sndhTimeFallbackAndTimerDefaultArePreserved() throws {
    let source = makeSNDH(
        trackCount: 2,
        names: [],
        timerFrequency: 0,
        frameCounts: [500, 1_001],
        times: [3, 5]
    )
    let result = try MetaManCore.readResult(data: source, formatHint: "sndh")
    #expect(result.tracks.map { $0.document.fields.title } == ["File title", "File title"])
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [10_000, 20_020])

    let timeOnly = makeSNDH(trackCount: 2, names: [], times: [3, 5])
    let fallback = try MetaManCore.readResult(data: timeOnly, formatHint: "sndh")
    #expect(fallback.tracks.map { $0.document.timing?.playLengthMs } == [3_000, 5_000])
    #expect(fallback.tracks.allSatisfy { $0.document.technicalFacts["timerFrequency"] == nil })
}

@Test("SNDH Atari ST text bytes are converted without relying on the playback package")
func sndhAtariTextUsesAtariSTEncoding() throws {
    let source = makeSNDH(titleBytes: [0x43, 0x61, 0x66, 0x82], names: [])
    let result = try MetaManCore.readResult(data: source, formatHint: "sndh")
    #expect(result.tracks[0].document.fields.title == "Café")
}

@Test("SNDH malformed ICE sizes, pointers, and signatures fail or diagnose safely")
func sndhMalformedInputsStayBounded() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data("not SNDH".utf8), formatHint: "sndh")
    }

    var invalidICE = Data("ICE!".utf8) + Data(repeating: 0, count: 8)
    invalidICE[11] = 1
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: invalidICE, formatHint: "sndh")
    }

    var invalidPointer = makeSNDH(trackCount: 2, names: ["One", "Two"])
    let marker = Data("!#SN".utf8)
    let markerRange = try #require(invalidPointer.range(of: marker))
    let tableStart = markerRange.lowerBound + marker.count
    invalidPointer[tableStart] = 0xFF
    invalidPointer[tableStart + 1] = 0xFF
    let result = try MetaManCore.readResult(data: invalidPointer, formatHint: "sndh")
    #expect(result.tracks.count == 2)
    #expect(result.tracks[0].document.diagnostics.contains { $0.contains("subtune pointer") })
}

private func makeSNDH(
    trackCount: Int = 1,
    titleBytes: [UInt8] = Array("File title".utf8),
    names: [String],
    timerFrequency: Int? = nil,
    frameCounts: [UInt32] = [],
    times: [UInt16] = [],
    defaultSubtune: Int = 1
) -> Data {
    var data = Data(repeating: 0, count: 12)
    data.append(contentsOf: "SNDH".utf8)
    appendStringTag("TITL", bytes: titleBytes, to: &data)
    appendStringTag("COMM", bytes: Array("Composer".utf8), to: &data)
    appendStringTag("YEAR", bytes: Array("1994".utf8), to: &data)
    if let timerFrequency {
        appendStringTag("!V", bytes: Array(String(timerFrequency).utf8), to: &data)
    }
    let countText = String(format: "%02d", trackCount)
    data.append(contentsOf: "##".utf8)
    data.append(contentsOf: countText.utf8)
    appendStringTag("!#", bytes: Array(String(defaultSubtune).utf8), to: &data)
    if names.count == trackCount, !names.isEmpty {
        appendSubtuneTable("!#SN", values: names.map { Array($0.utf8) }, to: &data)
    }
    if times.count == trackCount {
        data.append(contentsOf: "TIME".utf8)
        for value in times { appendBE16(value, to: &data) }
    }
    if frameCounts.count == trackCount {
        data.append(contentsOf: "FRMS".utf8)
        for value in frameCounts { appendBE32(value, to: &data) }
    }
    data.append(contentsOf: "HDNS".utf8)
    data.append(0)
    return data
}

private func appendStringTag(_ name: String, bytes: [UInt8], to data: inout Data) {
    data.append(contentsOf: name.utf8)
    data.append(contentsOf: bytes)
    data.append(0)
}

private func appendSubtuneTable(_ name: String, values: [[UInt8]], to data: inout Data) {
    let tagOffset = data.count
    data.append(contentsOf: name.utf8)
    let tableOffset = data.count
    data.append(Data(repeating: 0, count: values.count * 2))
    for (index, value) in values.enumerated() {
        let relative = UInt16(data.count - tagOffset)
        data[tableOffset + index * 2] = UInt8(relative >> 8)
        data[tableOffset + index * 2 + 1] = UInt8(relative & 0xFF)
        data.append(contentsOf: value)
        data.append(0)
    }
}

private func appendBE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(value >> 8))
    data.append(UInt8(value & 0xFF))
}

private func appendBE32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xFF))
    data.append(UInt8((value >> 16) & 0xFF))
    data.append(UInt8((value >> 8) & 0xFF))
    data.append(UInt8(value & 0xFF))
}
