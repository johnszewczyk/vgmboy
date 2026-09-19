import Foundation
import Testing
@testable import MetaManCore

@Test("SAP readResult preserves ordered directives and one native TIME hint per subsong")
func sapReadResultPreservesHeaderAndSubsongTiming() throws {
    let fixture = makeSAPFixture("""
    AUTHOR "Composer"
    NAME "Sample Game"
    DATE "1992"
    SONGS 3
    TYPE C
    MUSIC 8000
    PLAYER 9000
    FASTPLAY 156
    STEREO
    TIME 01:20.125 LOOP
    TIME 0:45.5
    TIME invalid
    X-CUSTOM preserved
    """)
    let result = try MetaManCore.readResult(data: fixture.data, formatHint: "sap", displayName: "sample.sap")

    #expect(result.tracks.map(\.sourceTrackIndex) == [0, 1, 2])
    #expect(result.tracks.map { $0.document.fields.game } == Array(repeating: "Sample Game", count: 3))
    #expect(result.tracks.map { $0.document.fields.artist } == Array(repeating: "Composer", count: 3))
    #expect(result.tracks.map { $0.document.fields.copyright } == Array(repeating: "1992", count: 3))
    #expect(result.tracks.allSatisfy { $0.document.fields.system == "Atari XL" })
    #expect(result.tracks.map { $0.document.timing?.introLengthMs } == [80_125, -1, -1])
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [150_000, 45_500, 150_000])
    #expect(result.tracks.allSatisfy { $0.document.timing?.loopLengthMs == -1 && $0.document.timing?.fadeLengthMs == -1 })
    #expect(result.tracks[0].document.values(forTag: "TIME") == ["01:20.125 LOOP", "0:45.5", "invalid"])
    #expect(result.tracks[0].document.value(forTag: "X-CUSTOM") == "preserved")
    #expect(result.tracks[0].document.rawMetadataBlocks?["sapInformationHeader"] == Data(fixture.data[..<fixture.headerEnd]))
    #expect(result.tracks[0].document.rawTagBlock == Data(fixture.data[5..<fixture.markerOffset]))
    #expect(result.tracks[0].document.technicalFacts["playerType"] == "C")
    #expect(result.tracks[0].document.technicalFacts["songCount"] == "3")
    #expect(result.tracks[0].document.technicalFacts["initAddress"] == nil)
    #expect(result.tracks[0].document.technicalFacts["musicAddress"] == "0x8000")
    #expect(result.tracks[0].document.technicalFacts["playerAddress"] == "0x9000")
    #expect(result.tracks[0].document.technicalFacts["fastPlayScanlines"] == "156")
    #expect(result.tracks[0].document.technicalFacts["isStereo"] == "true")
    #expect(result.tracks[0].document.technicalFacts["dataMarkerOffset"] == String(fixture.markerOffset))
    #expect(result.tracks[2].document.diagnostics.contains { $0.contains("Invalid SAP TIME") })
}

@Test("SAP defaults to one untimed track and normalizes unknown identity placeholders")
func sapDefaultsAndPlaceholders() throws {
    let fixture = makeSAPFixture("""
    TYPE B
    NAME "?"
    AUTHOR "<?>"
    """)
    let result = try MetaManCore.readResult(data: fixture.data)
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].sourceTrackIndex == 0)
    #expect(result.tracks[0].document.fields.game == nil)
    #expect(result.tracks[0].document.fields.artist == nil)
    #expect(result.tracks[0].document.timing?.playLengthMs == 150_000)
}

@Test("SAP reader recognizes each ASAP player type without losing the source type")
func sapReaderRecognizesASAPPlayerTypes() throws {
    for type in ["B", "C", "D", "S"] {
        let typeSpecificAddress = type == "C" ? "MUSIC 8000" : "INIT 8000"
        let fixture = makeSAPFixture("TYPE \(type)\n\(typeSpecificAddress)")
        let result = try MetaManCore.readResult(data: fixture.data, formatHint: "sap", displayName: "type-\(type).sap")

        #expect(result.tracks.count == 1)
        #expect(result.tracks[0].document.technicalFacts["playerType"] == type)
    }
}

@Test("SAP URL dispatch is track-aware and the single-document API refuses flattening")
func sapFileURLUsesTrackAwareAPI() throws {
    let fixture = makeSAPFixture("SONGS 2\r\nTIME 0:30\r\nTIME 0:45")
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-sap-\(UUID().uuidString)")
        .appendingPathExtension("sap")
    try fixture.data.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let result = try MetaManCore.readResult(fileURL: fileURL)
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [30_000, 45_000])
    #expect(try MetaManCore.readResult(data: fixture.data).tracks == result.tracks)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(fileURL: fileURL)
    }
}

@Test("SAP rejects malformed headers, unsupported types, and invalid required values")
func sapRejectsMalformedHeadersAndCounts() {
    for data in [
        Data(repeating: 0, count: 20),
        makeSAPFixture("TYPE X").data,
        makeSAPFixture("SONGS 0").data,
        makeSAPFixture("SONGS 33").data,
        makeSAPFixture("SONGS 65537").data,
        makeSAPFixture("INIT XYZ").data,
        makeSAPFixture("FASTPLAY 0").data,
        Data("SAP\r\nTYPE B\r\n".utf8)
    ] {
        #expect(throws: MetadataReadError.self) {
            try MetaManCore.readResult(data: data, formatHint: "sap", displayName: "invalid.sap")
        }
    }
}

private struct SAPFixture {
    let data: Data
    let markerOffset: Int
    let headerEnd: Int
}

private func makeSAPFixture(_ lines: String) -> SAPFixture {
    var data = Data("SAP\r\n".utf8)
    let normalizedLines = lines
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\n", with: "\r\n")
    data.append(Data(normalizedLines.utf8))
    if !normalizedLines.isEmpty, !normalizedLines.hasSuffix("\r\n") {
        data.append(Data("\r\n".utf8))
    }
    let markerOffset = data.count
    data.append(contentsOf: [0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00])
    return SAPFixture(data: data, markerOffset: markerOffset, headerEnd: markerOffset + 2)
}
