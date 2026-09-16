import Foundation
import Testing
@testable import MetaManCore

@Test("CRI AHX preserves header facts and matches the scanner's payload timing")
func ahxReaderParsesHeaderAndFixedBitrateDuration() throws {
    let document = try MetaManCore.read(
        data: makeAHX(payloadBytes: 1_600),
        formatHint: "ahx",
        displayName: "dm1.ahx"
    )

    #expect(document.format == "ahx")
    #expect(document.fields.title == "dm1")
    #expect(document.fields.comment == "FFmpeg format (CRI ADX)")
    #expect(document.timing?.playLengthMs == 80)
    #expect(document.technicalFacts["codecName"] == "CRI AHX")
    #expect(document.technicalFacts["dataOffset"] == "36")
    #expect(document.technicalFacts["dataBytes"] == "1600")
    #expect(document.technicalFacts["sampleRateHz"] == "21819")
    #expect(document.technicalFacts["bitrateBps"] == "160000")
    #expect(document.technicalFacts["declaredSampleCount"] == "123456")
    #expect(document.technicalFacts["decodedSampleCount"] == "1746")
    #expect(document.rawMetadataBlocks?["ahxHeader"]?.count == 0x24)
    #expect(document.diagnostics.count == 1)
}

@Test("AHX rejects aliases and incomplete headers without claiming the route")
func ahxReaderRejectsUnsafeSignatures() throws {
    let unknown = Data(repeating: 0x7F, count: 0x80)
    let unknownURL = try temporaryFile(unknown, name: "unknown.ahx")
    defer { try? FileManager.default.removeItem(at: unknownURL) }
    #expect(!MetaManCore.canReadDirectly(fileURL: unknownURL, formatHint: "ahx"))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data(repeating: 0, count: 0x23), formatHint: "ahx", displayName: "short.ahx")
    }
}

@Test("AHX is registered as a decoder-independent metadata format")
func ahxFormatIsRegistered() throws {
    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "ahx" })
    #expect(descriptor.fileExtensions == ["ahx"])
    #expect(descriptor.methodology.contains("does not open"))
}

private func makeAHX(payloadBytes: Int) -> Data {
    var data = Data(repeating: 0, count: 0x24 + payloadBytes)
    data[0] = 0x80
    data[1] = 0x00
    data[2] = 0x00
    data[3] = 0x20
    data[4] = 0x10
    data[5] = 0x00
    data[6] = 0x00
    data[7] = 0x01
    putUInt32BE(21_819, at: 0x08, in: &data)
    putUInt32BE(123_456, at: 0x0C, in: &data)
    data[0x12] = 0x06
    data[0x13] = 0x00
    data[0x1E] = 0x28
    data[0x1F] = 0x63
    data[0x20] = 0x29
    data[0x21] = 0x43
    data[0x22] = 0x52
    data[0x23] = 0x49
    data[0x24] = 0xFF
    data[0x25] = 0xF5
    data[0x26] = 0xE0
    data[0x27] = 0xC0
    return data
}

private func putUInt32BE(_ value: UInt32, at offset: Int, in data: inout Data) {
    data[offset] = UInt8((value >> 24) & 0xFF)
    data[offset + 1] = UInt8((value >> 16) & 0xFF)
    data[offset + 2] = UInt8((value >> 8) & 0xFF)
    data[offset + 3] = UInt8(value & 0xFF)
}

private func temporaryFile(_ data: Data, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-ahx-\(UUID().uuidString)-\(name)")
    try data.write(to: url)
    return url
}
