import Foundation
import Testing
@testable import MetaManCore

@Test("Retro Studios AGSC v1 parses chunk order, name, DSP samples, and loop bounds")
func agscVersion1ReadsNativeMetadataWithoutDecoding() throws {
    let data = makeAGSCFixture(version: 1, tracks: [(32_000, 32_000, 16_000, 16_000)])
    let result = try MetaManCore.readResult(data: data, formatHint: ".AGSC", displayName: "bank.agsc")
    let track = try #require(result.tracks.first)
    let document = track.document

    #expect(result.tracks.count == 1)
    #expect(track.sourceTrackIndex == 1)
    #expect(document.format == "agsc")
    #expect(document.fields.title == "FrontEndMusic")
    #expect(document.fields.comment == "Retro Studios AGSC header")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 499, playLengthMs: 11_499))
    #expect(document.technicalFacts["version"] == "1")
    #expect(document.technicalFacts["sampleRateHz"] == "32000")
    #expect(document.technicalFacts["sampleCount"] == "32000")
    #expect(document.technicalFacts["loopStartSample"] == "16000")
    #expect(document.technicalFacts["loopLengthSamples"] == "16000")
    #expect(document.technicalFacts["channels"] == "1")
    #expect(document.rawMetadataBlocks?["agscName"] == Data("FrontEndMusic\0".utf8))
    #expect(document.rawMetadataBlocks?["agscStreamRecord"]?.count == 0x20)
    #expect(document.rawMetadataBlocks?["agscCoefficients"]?.count == 0x28)
    #expect(document.rawMetadataBlocks?["agscUnknownChunk1"] == Data([0xA1, 0xA2]))
    #expect(document.rawMetadataBlocks?["agscUnknownChunk2"] == Data([0xB1]))
}

@Test("Retro Studios AGSC v2 publishes ordered track records and sample timing")
func agscVersion2PreservesEachBankTrack() throws {
    let data = makeAGSCFixture(version: 2, tracks: [
        (32_000, 32_000, 16_000, 16_000),
        (48_000, 48_000, 12_000, 24_000)
    ])
    let result = try MetaManCore.readResult(data: data, formatHint: "agsc")

    #expect(result.tracks.count == 2)
    #expect(result.tracks.map(\.sourceTrackIndex) == [1, 2])
    #expect(result.tracks.map(\.document.fields.title) == ["FrontEndMusic", "FrontEndMusic"])
    #expect(result.tracks.map(\.document.timing?.playLengthMs) == [11_499, 11_249])
    #expect(result.tracks.map(\.document.timing?.loopLengthMs) == [499, 499])
    #expect(result.tracks.map(\.document.technicalFacts["version"]) == ["2", "2"])
    #expect(result.tracks.map(\.document.technicalFacts["trackCount"]) == ["2", "2"])
    #expect(result.tracks.map(\.document.technicalFacts["sourceTrackIndex"]) == ["1", "2"])
}

@Test("AGSC URL probe claims only complete supported banks and singular reads do not flatten tracks")
func agscURLProbeAndTrackAwareContract() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-agsc-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let validURL = directory.appendingPathComponent("valid.agsc")
    let data = makeAGSCFixture(version: 2, tracks: [(32_000, 32_000, 0, 0)])
    try data.write(to: validURL)
    #expect(MetaManCore.canReadDirectly(fileURL: validURL, formatHint: "agsc"))
    #expect(try MetaManCore.readResult(fileURL: validURL).tracks.count == 1)
    #expect(throws: MetadataReadError.trackAwareResultRequired("AGSC")) {
        try MetaManCore.read(fileURL: validURL)
    }

    let aliasURL = directory.appendingPathComponent("alias.agsc")
    try Data("not an AGSC bank".utf8).write(to: aliasURL)
    #expect(!MetaManCore.canReadDirectly(fileURL: aliasURL, formatHint: "agsc"))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(fileURL: aliasURL)
    }

    var truncated = data
    truncated.removeLast()
    #expect(!AGSCMetadataReader.matches(truncated))
}

@Test("AGSC has an independent MetaMan format registration")
func agscFormatIsRegisteredAsDirectMetadata() throws {
    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "agsc" })
    #expect(descriptor.fileExtensions == ["agsc"])
    #expect(descriptor.methodology.contains("without decoding audio"))
}

private func makeAGSCFixture(version: Int, tracks: [(Int, Int, Int, Int)]) -> Data {
    let encodedSizes = tracks.map { sampleCount, _, _, _ in sampleCount / 14 * 8 }
    let audio = Data(repeating: 0, count: encodedSizes.reduce(0, +))
    var header = Data(repeating: 0, count: tracks.count * 0x20 + 4 + tracks.count * 0x28)
    var streamOffset = 0
    for (index, track) in tracks.enumerated() {
        let record = index * 0x20
        writeAGSC32(UInt32(index + 1), into: &header, at: record)
        writeAGSC32(UInt32(streamOffset), into: &header, at: record + 4)
        writeAGSC16(UInt16(track.0), into: &header, at: record + 0x0E)
        writeAGSC32(UInt32(track.1), into: &header, at: record + 0x10)
        writeAGSC32(UInt32(track.2), into: &header, at: record + 0x14)
        writeAGSC32(UInt32(track.3), into: &header, at: record + 0x18)
        writeAGSC32(UInt32(tracks.count * 0x20 + 4 - 8 + index * 0x28), into: &header, at: record + 0x1C)
        streamOffset += encodedSizes[index]
    }
    writeAGSC32(UInt32.max, into: &header, at: tracks.count * 0x20)

    var data = Data()
    let unknown1 = Data([0xA1, 0xA2])
    let unknown2 = Data([0xB1])
    if version == 1 {
        data.append(contentsOf: "Audio/\0FrontEndMusic\0".utf8)
        appendAGSCChunk(unknown1, to: &data)
        appendAGSCChunk(unknown2, to: &data)
        appendAGSCChunk(audio, to: &data)
        appendAGSCChunk(header, to: &data)
    } else {
        appendAGSC32(1, to: &data)
        data.append(contentsOf: "FrontEndMusic\0".utf8)
        data.append(contentsOf: [0, 1])
        appendAGSC32(UInt32(unknown1.count), to: &data)
        appendAGSC32(UInt32(unknown2.count), to: &data)
        appendAGSC32(UInt32(header.count), to: &data)
        appendAGSC32(UInt32(audio.count), to: &data)
        data.append(unknown1)
        data.append(unknown2)
        data.append(header)
        data.append(audio)
    }
    return data
}

private func appendAGSCChunk(_ payload: Data, to data: inout Data) {
    appendAGSC32(UInt32(payload.count), to: &data)
    data.append(payload)
}

private func appendAGSC32(_ value: UInt32, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value >> 24))
    data.append(UInt8(truncatingIfNeeded: value >> 16))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
    data.append(UInt8(truncatingIfNeeded: value))
}

private func writeAGSC32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 24)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 3] = UInt8(truncatingIfNeeded: value)
}

private func writeAGSC16(_ value: UInt16, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 1] = UInt8(truncatingIfNeeded: value)
}
