import Foundation
import Testing
@testable import MetaManCore

@Test("VGM reads all ordered GD3 fields, date, and header timing")
func vgmReadsCompleteGD3AndHeaderFacts() throws {
    let fields = [
        "", "曲名", "English Game", "日本のゲーム", "System", "システム",
        "Composer", "作曲者", "1994/09/22", "VGM Converter", "Line one\nLine two"
    ]
    let data = makeVGM(gd3Fields: fields, totalSamples: 441_000, loopSamples: 220_500)
    let expectedGD3 = makeGD3(fields: fields)

    let document = try MetaManCore.read(data: data, formatHint: ".VGM")

    #expect(document.format == "vgm")
    #expect(document.fields.title == "曲名")
    #expect(document.fields.game == "English Game")
    #expect(document.fields.system == "System")
    #expect(document.fields.artist == "Composer")
    #expect(document.fields.date == "1994/09/22")
    #expect(document.fields.year == "1994")
    #expect(document.fields.encodedBy == "VGM Converter")
    #expect(document.fields.comment == "Line one\nLine two")
    #expect(document.sourceEncoding == "UTF-16LE")
    #expect(document.rawTagBlock == expectedGD3)
    #expect(document.tags.map(\.name) == [
        "title_english", "title_original", "game_english", "game_original",
        "system_english", "system_original", "artist_english", "artist_original",
        "date", "converted_by", "notes"
    ])
    #expect(document.values(forTag: "title_original") == ["曲名"])
    #expect(document.timing?.introLengthMs == 5_000)
    #expect(document.timing?.loopLengthMs == 5_000)
    #expect(document.timing?.playLengthMs == 10_000)
    #expect(document.technicalFacts["version"] == "1.71")
    #expect(document.technicalFacts["dataOffset"] == "64")
    #expect(document.technicalFacts["sampleRate"] == "44100")
    #expect(document.diagnostics.isEmpty)
}

@Test("VGM without GD3 uses a supplied filename and keeps zero metadata neutral")
func vgmFilenameFallbackIsAvailableForFileAndDataReads() throws {
    let data = makeVGM(gd3Fields: nil, totalSamples: 88_200, loopSamples: 0)
    let fromData = try MetaManCore.read(data: data, formatHint: "vgm", displayName: "folder/Short.vgm")

    #expect(fromData.fields.title == "Short")
    #expect(fromData.fields.game == nil)
    #expect(fromData.tags.isEmpty)
    #expect(fromData.sourceEncoding == nil)
    #expect(fromData.timing?.introLengthMs == 2_000)
    #expect(fromData.timing?.loopLengthMs == 0)
    #expect(fromData.timing?.playLengthMs == 2_000)

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-No-GD3-\(UUID().uuidString).vgm")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    try data.write(to: fileURL)
    #expect(try MetaManCore.read(fileURL: fileURL).fields.title == fileURL.deletingPathExtension().lastPathComponent)
}

@Test("VGZ gzip is accepted through both data and file APIs, including concatenated members")
func vgzGzipDataAndFileReads() throws {
    let data = makeVGM(gd3Fields: ["Song", "", "Game", "", "System", "", "Artist", "", "", "", ""], totalSamples: 44_100)
    let split = data.count / 2
    let compressed = makeGzip(Data(data[..<split])) + makeGzip(Data(data[split...]))
    let document = try MetaManCore.read(data: compressed, formatHint: "vgz", displayName: "Song.vgz")

    #expect(document.fields.title == "Song")
    #expect(document.fields.game == "Game")
    #expect(document.timing?.playLengthMs == 1_000)

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-VGZ-\(UUID().uuidString).vgz")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    try compressed.write(to: fileURL)
    #expect(try MetaManCore.read(fileURL: fileURL) == document)
}

@Test("VGM validates declared GD3 bounds and diagnoses incomplete but readable fields")
func vgmMalformedGD3AndPartialFieldDiagnostics() throws {
    var badPointer = makeVGM(gd3Fields: nil, totalSamples: 0)
    writeLE32(UInt32.max, into: &badPointer, at: 0x14)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: badPointer, formatHint: "vgm")
    }

    var badLength = makeVGM(gd3Fields: ["Song"], totalSamples: 0)
    let gd3Offset = 0x14 + Int(readLE32(badLength, at: 0x14))
    writeLE32(3, into: &badLength, at: gd3Offset + 8)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: badLength, formatHint: "vgm")
    }

    let partial = try MetaManCore.read(
        data: makeVGM(gd3Fields: ["Song"], totalSamples: 0),
        formatHint: "vgm"
    )
    #expect(partial.fields.title == "Song")
    #expect(partial.tags.count == 11)
    #expect(partial.diagnostics.contains { $0.contains("missing standard fields") })
}

@Test("VGM retains future GD3 fields and diagnoses malformed UTF-16")
func vgmFutureAndMalformedGD3ValuesAreRetained() throws {
    let fields = ["Song", "", "Game", "", "System", "", "Artist", "", "", "", "", "Future value"]
    let future = try MetaManCore.read(data: makeVGM(gd3Fields: fields, totalSamples: 0), formatHint: "vgm")
    #expect(future.value(forTag: "gd3_field_12") == "Future value")
    #expect(future.diagnostics.contains { $0.contains("additional strings") })

    var invalid = makeVGM(gd3Fields: ["Song", "", "Game", "", "System", "", "Artist", "", "", "", ""] , totalSamples: 0)
    let gd3Offset = 0x14 + Int(readLE32(invalid, at: 0x14))
    let titleStart = gd3Offset + 12
    invalid[titleStart] = 0x00
    invalid[titleStart + 1] = 0xD8 // Unpaired high surrogate.
    let malformed = try MetaManCore.read(data: invalid, formatHint: "vgm")
    #expect(malformed.fields.title?.contains("�") == true)
    #expect(malformed.diagnostics.contains { $0.contains("invalid UTF-16") })
}

@Test("VGM gzip rejects truncated data and enforces the decompressed-size limit")
func vgmGzipFailuresAreBoundedAndExplicit() {
    let compressed = makeGzip(makeVGM(gd3Fields: nil, totalSamples: 0))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data(compressed.dropLast()), formatHint: "vgz")
    }
    #expect(throws: MetadataReadError.self) {
        try GzipDataDecompressor.decompress(compressed, maximumOutputBytes: 16)
    }
}

@Test("VGM formats are registered as decoder-independent metadata readers")
func vgmFormatsAreRegistered() {
    let descriptor = MetaManCore.supportedFormats.first { $0.identifier == "vgm" }
    #expect(descriptor?.fileExtensions == ["vgm", "vgz"])
    #expect(descriptor?.methodology.contains("no playback decoder") == true)
}

private func makeVGM(gd3Fields: [String]?, totalSamples: UInt32, loopSamples: UInt32 = 0) -> Data {
    var data = Data(repeating: 0, count: 0x41)
    data.replaceSubrange(0..<4, with: Data("Vgm ".utf8))
    writeLE32(0x0000_0171, into: &data, at: 0x08)
    writeLE32(totalSamples, into: &data, at: 0x18)
    writeLE32(loopSamples, into: &data, at: 0x20)
    data[0x40] = 0x66
    if let gd3Fields {
        let gd3 = makeGD3(fields: gd3Fields)
        writeLE32(UInt32(data.count - 0x14), into: &data, at: 0x14)
        data.append(gd3)
    }
    writeLE32(UInt32(data.count - 4), into: &data, at: 0x04)
    return data
}

private func makeGD3(fields: [String]) -> Data {
    var payload = Data()
    for field in fields {
        for unit in field.utf16 {
            payload.append(UInt8(truncatingIfNeeded: unit))
            payload.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        payload.append(contentsOf: [0, 0])
    }
    var gd3 = Data("Gd3 ".utf8)
    gd3.append(contentsOf: [0x00, 0x01, 0x00, 0x00])
    gd3.append(contentsOf: littleEndianBytes(UInt32(payload.count)))
    gd3.append(payload)
    return gd3
}

private func makeGzip(_ data: Data) -> Data {
    var gzip = Data([0x1F, 0x8B, 0x08, 0x00, 0, 0, 0, 0, 0, 0xFF])
    var offset = 0
    repeat {
        let count = min(65_535, data.count - offset)
        let isFinal = offset + count == data.count
        gzip.append(isFinal ? 0x01 : 0x00) // Final stored DEFLATE block.
        gzip.append(UInt8(truncatingIfNeeded: count))
        gzip.append(UInt8(truncatingIfNeeded: count >> 8))
        let inverted = count ^ 0xFFFF
        gzip.append(UInt8(truncatingIfNeeded: inverted))
        gzip.append(UInt8(truncatingIfNeeded: inverted >> 8))
        if count > 0 { gzip.append(data[offset..<(offset + count)]) }
        offset += count
    } while offset < data.count
    gzip.append(contentsOf: littleEndianBytes(crc32(data)))
    gzip.append(contentsOf: littleEndianBytes(UInt32(truncatingIfNeeded: data.count)))
    return gzip
}

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
        }
    }
    return crc ^ 0xFFFF_FFFF
}

private func writeLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}

private func readLE32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
}

private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ]
}
