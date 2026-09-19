import Foundation
import Testing
@testable import MetaManCore

@Test("canonical loop tags become sample-accurate metadata")
func canonicalLoopTagsProjectExactSamples() {
    let loop = MetadataLoopParser.parse(tags: [
        MetadataTag(name: "LOOP_START_SAMPLES", value: "4882752"),
        MetadataTag(name: "LOOP_END_SAMPLES", value: "7156800"),
        MetadataTag(name: "XA_SAMPLE_RATE", value: "37800"),
        MetadataTag(name: "LOOP_SOURCE", value: "txtp-reference")
    ])
    #expect(loop?.startSample == 4_882_752)
    #expect(loop?.endSample == 7_156_800)
    #expect(loop?.sampleRateHz == 37_800)
    #expect(loop?.loopLengthMs == 60_160)
    #expect(loop?.source == "txtp-reference")
}

@Test("loop metadata is optional when decoding older documents")
func oldMetadataDocumentsDecodeWithoutLoopObject() throws {
    let data = Data(#"{"format":"standard-audio","fields":{"title":null,"game":null,"system":null,"artist":null,"album":null,"date":null,"year":null,"genre":null,"comment":null,"copyright":null,"encodedBy":null},"tags":[],"rawTagBlock":null,"sourceEncoding":null,"timing":null,"technicalFacts":{},"diagnostics":[]}"#.utf8)
    let document = try JSONDecoder().decode(MetadataDocument.self, from: data)
    #expect(document.loop == nil)
}
