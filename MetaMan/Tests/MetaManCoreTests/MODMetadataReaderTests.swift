import Foundation
import Testing
@testable import MetaManCore

@Test("MOD reader retains title, ordered sample names, layout facts, and native header bytes")
func modReadsProTrackerMetadataWithoutAnAudioDecoder() throws {
    let data = makeMODFixture(title: "River City Ransom", sampleNames: [1: "Bass", 4: "Snare"])
    let document = try MetaManCore.read(data: data, formatHint: ".MOD", displayName: "stage.mod")

    #expect(document.format == "mod")
    #expect(document.fields.title == "River City Ransom")
    #expect(document.fields.system == "Commodore Amiga")
    #expect(document.values(forTag: "title") == ["River City Ransom"])
    #expect(document.value(forTag: "sample_01_title") == "Bass")
    #expect(document.value(forTag: "sample_04_title") == "Snare")
    #expect(document.technicalFacts["mod.channels"] == "4")
    #expect(document.technicalFacts["mod.patternCount"] == "1")
    #expect(document.technicalFacts["mod.sampleDataBytes"] == "2")
    #expect(document.technicalFacts["mod.sourceName"] == "stage.mod")
    #expect(document.rawMetadataBlocks?["modHeader"] == Data(data.prefix(MODMetadataReader.headerSize)))

    let result = try MetaManCore.readResult(data: data, formatHint: "mod", displayName: "stage.mod")
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].document == document)
}

@Test("MOD file-URL reader inspects only the header and supports common channel signatures")
func modFileURLReaderUsesBoundedHeader() throws {
    let data = makeMODFixture(signature: "8CHN", channels: 8)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-MOD-\(UUID().uuidString).mod")
    try (data + Data(repeating: 0xA5, count: 2 * 1024 * 1024)).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(MetaManCore.canReadDirectly(fileURL: url, formatHint: "mod"))
    let document = try MetaManCore.read(fileURL: url)
    #expect(document.technicalFacts["mod.channels"] == "8")
    #expect(document.rawMetadataBlocks?["modHeader"]?.count == MODMetadataReader.headerSize)
    #expect(try MetaManCore.readResult(fileURL: url).tracks.first?.document == document)
}

@Test("MOD reader rejects malformed extents and leaves unknown dialects unclaimed")
func modRejectsMalformedAndUnknownSignatures() {
    #expect(throws: MetadataReadError.unsupportedFormat("unrecognized 31-sample MOD signature")) {
        try MetaManCore.read(data: makeMODFixture(signature: "XXXX"), formatHint: "mod")
    }
    #expect(throws: MetadataReadError.unsupportedFormat("MOD dialect without a recognized 31-sample header")) {
        try MetaManCore.read(data: Data(repeating: 0, count: 600), formatHint: "mod")
    }

    var truncated = makeMODFixture()
    truncated.removeLast(2)
    #expect(throws: MetadataReadError.malformedFile("MOD pattern or sample data extends beyond the file.")) {
        try MetaManCore.read(data: truncated, formatHint: "mod")
    }

    var badVolume = makeMODFixture()
    badVolume[45] = 65
    #expect(throws: MetadataReadError.malformedFile("MOD instrument 1 has an invalid volume.")) {
        try MetaManCore.read(data: badVolume, formatHint: "mod")
    }
}

private func makeMODFixture(
    signature: String = "M.K.",
    channels: Int = 4,
    title: String = "Example MOD",
    sampleNames: [Int: String] = [:]
) -> Data {
    let headerSize = 1_084
    let patternBytes = 64 * channels * 4
    var data = Data(repeating: 0, count: headerSize + patternBytes + 2)
    func write(_ text: String, at offset: Int, length: Int) {
        let bytes = Array(text.utf8.prefix(length))
        for (index, byte) in bytes.enumerated() {
            data[offset + index] = byte
        }
    }
    write(title, at: 0, length: 20)
    for (sampleNumber, name) in sampleNames where (1...31).contains(sampleNumber) {
        write(name, at: 20 + (sampleNumber - 1) * 30, length: 22)
    }
    data[42] = 0
    data[43] = 1 // First sample is one word (two bytes).
    data[45] = 64
    data[950] = 1
    data[951] = 0x7F
    data[952] = 0
    write(signature, at: 1_080, length: 4)
    return data
}
