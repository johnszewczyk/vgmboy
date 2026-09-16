import Foundation
import Testing
@testable import MetaManCore

@Test("Nintendo DTK ADP reader mirrors the headerless GameCube probe and timing")
func nintendoDTKADPReaderParsesHeaderlessFrames() throws {
    let data = makeDTK(frameCount: 10, header: 0x33)
    let document = try MetaManCore.read(
        data: data,
        formatHint: "adp",
        displayName: "Doom.adp"
    )

    #expect(document.format == "ngc-dtk-adp")
    #expect(document.fields.title == "Doom")
    #expect(document.fields.comment == "Nintendo .DTK raw header")
    #expect(document.timing?.playLengthMs == 5)
    #expect(document.technicalFacts["channels"] == "2")
    #expect(document.technicalFacts["sampleRateHz"] == "48000")
    #expect(document.technicalFacts["decodedSampleCount"] == "280")
    #expect(document.rawMetadataBlocks?["dtkProbeHeader"]?.count == 0x20)
}

@Test("TXTH ADP reader preserves the sidecar and converts IMA data_size to samples")
func txthIMAADPReaderParsesExactSidecarLayout() throws {
    let source = Data(repeating: 0x55, count: 320)
    let sidecar = Data("codec = IMA\nsample_rate = 48000\nchannels = 1\nnum_samples = data_size\n".utf8)
    let context = MetadataReadContext(
        companionFiles: [MetadataCompanionFile(relativePath: ".ADP.txth", data: sidecar)]
    )
    let document = try MetaManCore.read(
        data: source,
        formatHint: "adp",
        displayName: "CON06423.ADP",
        context: context
    )

    #expect(document.format == "txth-ima-adp")
    #expect(document.fields.title == "CON06423")
    #expect(document.timing?.playLengthMs == 13)
    #expect(document.technicalFacts["codecName"] == "IMA 4-bit ADPCM")
    #expect(document.technicalFacts["decodedSampleCount"] == "640")
    #expect(document.tags.map(\.name) == ["codec", "sample_rate", "channels", "num_samples"])
    #expect(document.rawMetadataBlocks?["txth"] == sidecar)
}

@Test("ADP direct recognition rejects incomplete or unrelated aliases")
func adpDirectRecognitionRejectsIncompleteAndUnknownLayouts() throws {
    let short = Data(repeating: 0x33, count: 0x13F)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: short, formatHint: "adp", displayName: "short.adp")
    }

    let unknown = Data(repeating: 0x7F, count: 0x220)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: unknown, formatHint: "adp", displayName: "unknown.adp")
    }
}

@Test("ADP metadata formats are separately documented")
func adpFormatsAreRegisteredSeparately() {
    let formats = MetaManCore.supportedFormats.filter { $0.fileExtensions == ["adp"] }
    #expect(formats.map(\.identifier) == ["ngc-dtk-adp", "txth-ima-adp"])
}

private func makeDTK(frameCount: Int, header: UInt8) -> Data {
    var data = Data(repeating: 0, count: frameCount * 0x20)
    for frame in 0..<frameCount {
        let offset = frame * 0x20
        data[offset] = header
        data[offset + 1] = 0x44
        data[offset + 2] = header
        data[offset + 3] = 0x44
    }
    return data
}
