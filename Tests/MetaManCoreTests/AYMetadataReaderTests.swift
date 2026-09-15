import Foundation
import Testing
@testable import MetaManCore

@Test("AY readResult preserves native track order, raw metadata, and authored lengths")
func ayReadResultPreservesTracksAndMetadata() throws {
    let fixture = makeAYFixture(
        author: "  Composer  ",
        comment: "Copyright 1987",
        tracks: [("Opening", 125), ("<?>", 0)]
    )
    let result = try MetaManCore.readResult(
        data: fixture.data,
        formatHint: ".AY",
        displayName: "fixture.ay"
    )

    #expect(result.tracks.map(\.sourceTrackIndex) == [0, 1])
    #expect(result.tracks.map { $0.document.fields.title } == ["Opening", nil])
    #expect(result.tracks.map { $0.document.fields.system } == ["ZX Spectrum", "ZX Spectrum"])
    #expect(result.tracks.map { $0.document.fields.artist } == ["Composer", "Composer"])
    #expect(result.tracks.map { $0.document.fields.comment } == ["Copyright 1987", "Copyright 1987"])
    #expect(result.tracks.map { $0.document.timing?.playLengthMs } == [2_500, 150_000])
    #expect(result.tracks.allSatisfy {
        $0.document.timing == MetadataTiming(
            introLengthMs: -1,
            loopLengthMs: -1,
            playLengthMs: $0.document.timing?.playLengthMs ?? 0,
            fadeLengthMs: -1
        )
    })
    #expect(result.tracks[0].document.technicalFacts["version"] == "1")
    #expect(result.tracks[0].document.technicalFacts["playerID"] == "3")
    #expect(result.tracks[0].document.technicalFacts["firstTrack"] == "1")
    #expect(result.tracks[0].document.technicalFacts["declaredTrackCount"] == "2")
    #expect(result.tracks[0].document.technicalFacts["lengthFrames"] == "125")
    #expect(result.tracks[0].document.rawMetadataBlocks?["ayHeader"] == Data(fixture.data[..<0x14]))
    #expect(result.tracks[0].document.rawMetadataBlocks?["ayTrackPointerTable"] == Data(fixture.data[fixture.tableOffset..<(fixture.tableOffset + 8)]))
    #expect(result.tracks[0].document.rawMetadataBlocks?["track0Title"] == Data("Opening\0".utf8))
    #expect(result.tracks[0].document.rawMetadataBlocks?["track0Info"]?.count == 6)
    #expect(result.tracks[0].document.tags.isEmpty)
}

@Test("AY file URL dispatch uses the same track-aware reader; singular reads cannot flatten tracks")
func ayFileURLUsesTrackAwareAPI() throws {
    let fixture = makeAYFixture(author: "Author", comment: "", tracks: [("Only", 50)])
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("metaman-ay-\(UUID().uuidString)")
        .appendingPathExtension("ay")
    try fixture.data.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let result = try MetaManCore.readResult(fileURL: fileURL)
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].document.fields.title == "Only")
    #expect(result.tracks[0].document.timing?.playLengthMs == 1_000)
    #expect(try MetaManCore.readResult(data: fixture.data).tracks == result.tracks)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(fileURL: fileURL)
    }
}

@Test("AY optional invalid relative pointers preserve the row and report source diagnostics")
func ayInvalidOptionalPointersAreDiagnosedWithoutDroppingTheTrack() throws {
    var fixture = makeAYFixture(author: "Author", comment: "Comment", tracks: [("Title", 30)])
    writeAYRelativePointerWord(0x7FFF, into: &fixture.data, at: fixture.tableOffset)
    writeAYRelativePointerWord(0x7FFF, into: &fixture.data, at: fixture.tableOffset + 2)

    let result = try MetaManCore.readResult(data: fixture.data, formatHint: "ay", displayName: "bad-pointers.ay")
    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].sourceTrackIndex == 0)
    #expect(result.tracks[0].document.fields.title == nil)
    #expect(result.tracks[0].document.timing?.playLengthMs == 150_000)
    #expect(result.tracks[0].document.diagnostics.contains { $0.contains("track 0 title pointer") })
    #expect(result.tracks[0].document.diagnostics.contains { $0.contains("track 0 info pointer") })
}

@Test("AY requires a complete header and declared track pointer table")
func ayRejectsMalformedTopLevelStructure() {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data("not-ay".utf8), formatHint: "ay", displayName: "invalid.ay")
    }

    var truncated = Data(repeating: 0, count: 0x14)
    truncated.replaceSubrange(0..<8, with: Data("ZXAYEMUL".utf8))
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: truncated, formatHint: "ay", displayName: "truncated.ay")
    }
}

private struct AYFixture {
    var data: Data
    let tableOffset: Int
}

private func makeAYFixture(
    author: String,
    comment: String,
    tracks: [(String, UInt16)]
) -> AYFixture {
    precondition((1...256).contains(tracks.count))
    var data = Data(repeating: 0, count: 0x14)
    data.replaceSubrange(0..<8, with: Data("ZXAYEMUL".utf8))
    data[8] = 1
    data[9] = 3
    data[16] = UInt8(tracks.count - 1)
    data[17] = 1

    let authorOffset = appendAYCString(author, to: &data)
    writeAYRelativePointer(&data, at: 12, target: authorOffset)
    let commentOffset = appendAYCString(comment, to: &data)
    writeAYRelativePointer(&data, at: 14, target: commentOffset)
    let titleOffsets = tracks.map { appendAYCString($0.0, to: &data) }

    let tableOffset = data.count
    data.append(contentsOf: repeatElement(0, count: tracks.count * 4))
    writeAYRelativePointer(&data, at: 18, target: tableOffset)
    for (index, track) in tracks.enumerated() {
        let rowOffset = tableOffset + index * 4
        writeAYRelativePointer(&data, at: rowOffset, target: titleOffsets[index])
        let infoOffset = data.count
        data.append(contentsOf: [0, 0, 0, 0, UInt8(track.1 >> 8), UInt8(track.1 & 0xFF)])
        writeAYRelativePointer(&data, at: rowOffset + 2, target: infoOffset)
    }
    return AYFixture(data: data, tableOffset: tableOffset)
}

private func appendAYCString(_ value: String, to data: inout Data) -> Int {
    let offset = data.count
    data.append(contentsOf: value.utf8)
    data.append(0)
    return offset
}

private func writeAYRelativePointer(_ data: inout Data, at offset: Int, target: Int) {
    let relative = Int16(target - offset)
    writeAYRelativePointerWord(UInt16(bitPattern: relative), into: &data, at: offset)
}

private func writeAYRelativePointerWord(_ value: UInt16, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(value >> 8)
    data[offset + 1] = UInt8(value & 0xFF)
}
