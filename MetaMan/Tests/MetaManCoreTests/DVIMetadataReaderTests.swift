import Foundation
import Testing
@testable import MetaManCore

@Test("Konami DVI reads the bounded header and reproduces loop timing")
func dviReaderParsesHeaderAndLoopProjection() throws {
    let document = try MetaManCore.read(
        data: makeDVI(sampleCount: 1_600, loopStart: 400),
        formatHint: "dvi",
        displayName: "Doom.dvi"
    )

    #expect(document.format == "dvi")
    #expect(document.fields.title == "Doom")
    #expect(document.fields.comment == "Konami DVI. header")
    #expect(document.timing?.loopLengthMs == 27)
    #expect(document.timing?.playLengthMs == 10_063)
    #expect(document.technicalFacts["codecName"] == "Intel DVI 4-bit IMA ADPCM (mono)")
    #expect(document.technicalFacts["sampleRateHz"] == "44100")
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["interleaveBytes"] == "4")
    #expect(document.technicalFacts["dataOffset"] == "2048")
    #expect(document.technicalFacts["dataBytes"] == "1600")
    #expect(document.technicalFacts["sampleCount"] == "1600")
    #expect(document.technicalFacts["loopEnabled"] == "true")
    #expect(document.technicalFacts["loopStartSample"] == "400")
    #expect(document.technicalFacts["loopEndSample"] == "1600")
    #expect(document.technicalFacts["playSamples"] == "443800")
    #expect(document.rawMetadataBlocks?["dviHeader"]?.count == 0x800)
}

@Test("Konami DVI uses the native sample count when no loop is declared")
func dviReaderParsesNonLoopingStream() throws {
    let document = try MetaManCore.read(
        data: makeDVI(sampleCount: 1_600, loopStart: -1),
        formatHint: ".dvi",
        displayName: "short.dvi"
    )

    #expect(document.timing?.loopLengthMs == 0)
    #expect(document.timing?.playLengthMs == 36)
    #expect(document.technicalFacts["loopEnabled"] == "false")
    #expect(document.technicalFacts["loopStartSample"] == "-1")
    #expect(document.technicalFacts["playSamples"] == "1600")
}

@Test("DVI rejects Capcom IDVI aliases and incomplete payloads")
func dviReaderRejectsUnsafeAliasesAndPartialFiles() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-dvi-route-(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    var idvi = makeDVI(sampleCount: 1_600, loopStart: -1)
    idvi[0] = Character("I").asciiValue!
    let idviURL = directory.appendingPathComponent("capcom.dvi")
    try idvi.write(to: idviURL)
    #expect(!MetaManCore.canReadDirectly(fileURL: idviURL, formatHint: "dvi"))

    var partial = makeDVI(sampleCount: 1_600, loopStart: -1)
    partial.removeLast()
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: partial, formatHint: "dvi", displayName: "partial.dvi")
    }
}

private func makeDVI(sampleCount: Int, loopStart: Int) -> Data {
    var data = Data(repeating: 0, count: 0x800 + sampleCount)
    data[0] = 0x44
    data[1] = 0x56
    data[2] = 0x49
    data[3] = 0x2E
    putInt32BE(Int32(0x800), at: 0x04, in: &data)
    putInt32BE(Int32(sampleCount), at: 0x08, in: &data)
    putInt32BE(Int32(loopStart), at: 0x0C, in: &data)
    return data
}

private func putInt32BE(_ value: Int32, at offset: Int, in data: inout Data) {
    let bits = UInt32(bitPattern: value)
    data[offset] = UInt8((bits >> 24) & 0xFF)
    data[offset + 1] = UInt8((bits >> 16) & 0xFF)
    data[offset + 2] = UInt8((bits >> 8) & 0xFF)
    data[offset + 3] = UInt8(bits & 0xFF)
}
