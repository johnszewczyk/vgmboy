import Foundation
import Testing
@testable import MetaManCore

@Test("Single-track readers expose a one-entry ordered result")
func directReaderProvidesOneTrackResult() throws {
    let result = try MetaManCore.readResult(
        data: makeMinimalVGM(totalSamples: 44_100),
        formatHint: "vgm",
        displayName: "Short Song.vgm"
    )

    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].sourceTrackIndex == nil)
    #expect(result.tracks[0].document.fields.title == "Short Song")
    #expect(result.tracks[0].document.timing?.playLengthMs == 1_000)
}

@Test("Repeated native source indices retain distinct playlist occurrences and order")
func metadataResultPreservesRepeatedSourceEntries() throws {
    let opening = MetadataDocument(
        format: "nsfe",
        fields: MetadataFields(title: "Opening"),
        timing: MetadataTiming(introLengthMs: 1_000, loopLengthMs: 2_000, playLengthMs: 3_000)
    )
    let ending = MetadataDocument(
        format: "nsfe",
        fields: MetadataFields(title: "Ending"),
        timing: MetadataTiming(introLengthMs: 4_000, loopLengthMs: 0, playLengthMs: 4_000)
    )
    let result = MetadataReadResult(tracks: [
        MetadataTrack(sourceTrackIndex: 2, document: opening),
        MetadataTrack(sourceTrackIndex: 0, document: ending),
        MetadataTrack(sourceTrackIndex: 2, document: opening)
    ])

    let encoded = try JSONEncoder().encode(result)
    let decoded = try JSONDecoder().decode(MetadataReadResult.self, from: encoded)

    #expect(decoded == result)
    #expect(decoded.tracks.map(\.sourceTrackIndex) == [2, 0, 2])
    #expect(decoded.tracks.map { $0.document.fields.title } == ["Opening", "Ending", "Opening"])
    #expect(decoded.tracks.map { $0.document.timing?.playLengthMs } == [3_000, 4_000, 3_000])
}

private func makeMinimalVGM(totalSamples: UInt32) -> Data {
    var data = Data(repeating: 0, count: 0x40)
    data.replaceSubrange(0..<4, with: Data("Vgm ".utf8))
    for byteOffset in 0..<4 {
        data[0x08 + byteOffset] = UInt8(truncatingIfNeeded: 0x0000_0150 >> (byteOffset * 8))
        data[0x18 + byteOffset] = UInt8(truncatingIfNeeded: totalSamples >> (byteOffset * 8))
    }
    return data
}
