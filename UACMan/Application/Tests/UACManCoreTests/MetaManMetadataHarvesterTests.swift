import Foundation
import Testing
import UACWrapperCore
@testable import UACManCore

@Test func sidDirectoryHarvestUsesMetaManAndKeepsRelativeMemberPaths() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-sid-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("variant-a/tune.sid")
    try FileManager.default.createDirectory(
        at: memberURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let fixture = makeSIDFixture(title: "Test Tune", artist: "Test Composer", released: "1992")
    try fixture.write(to: memberURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "sid")
    #expect(outcome.failures.isEmpty)
    #expect(outcome.diagnosticCount == 0)
    #expect(outcome.memberMetadata["variant-a/tune.sid"]?["title"] == .string("Test Tune"))
    #expect(outcome.memberMetadata["variant-a/tune.sid"]?["artist"] == .string("Test Composer"))
    #expect(outcome.memberMetadata["variant-a/tune.sid"]?["system"] == .string("Commodore 64"))
    #expect(outcome.memberMetadata["variant-a/tune.sid"]?["playLengthMs"] == nil)
    #expect(try Data(contentsOf: memberURL) == fixture)
}

@Test func vgmDirectoryHarvestUsesGD3MetadataAsOnePlayableMember() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-vgm-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("Genesis/track.vgm")
    try FileManager.default.createDirectory(
        at: memberURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let fixture = makeVGMFixture(
        gd3Fields: ["Tune", "曲", "Game", "", "Sega Mega Drive / Genesis", "", "Composer", "", "1994", "Converter", "Notes"],
        totalSamples: 44_100
    )
    try fixture.write(to: memberURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "vgm")
    let metadata = outcome.memberMetadata["Genesis/track.vgm"]
    #expect(outcome.failures.isEmpty)
    #expect(outcome.diagnosticCount == 0)
    #expect(metadata?["title"] == .string("Tune"))
    #expect(metadata?["game"] == .string("Game"))
    #expect(metadata?["system"] == .string("Sega Mega Drive / Genesis"))
    #expect(metadata?["artist"] == .string("Composer"))
    #expect(metadata?["playLengthMs"] == .integer(1_000))
    #expect(try Data(contentsOf: memberURL) == fixture)
}

@Test func apeDirectoryHarvestKeepsUnknownNativeTagsInTheUACProjection() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-ape-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("Album/track.ape")
    try FileManager.default.createDirectory(
        at: memberURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let fixture = makeAPEFixture(tags: [("Title", "Lossless track"), ("X-Producer", "Studio=One")])
    try fixture.write(to: memberURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "ape")
    let metadata = outcome.memberMetadata["Album/track.ape"]
    #expect(outcome.failures.isEmpty)
    #expect(metadata?["title"] == .string("Lossless track"))
    if case let .object(native)? = metadata?["nativeMetadata"],
       case let .array(tags)? = native["tags"] {
        #expect(tags.contains(.object([
            "name": .string("X-Producer"), "value": .string("Studio=One")
        ])))
    } else {
        Issue.record("The UAC projection must retain MetaMan's ordered native tags.")
    }
    #expect(try Data(contentsOf: memberURL) == fixture)
}

@Test func nsfDirectoryHarvestKeepsEachLogicalTrackAndLeavesTheMemberUntouched() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-nsf-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("NES/game.nsf")
    try FileManager.default.createDirectory(
        at: memberURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let fixture = makeNSFFixture(trackCount: 3, game: "Fixture Game", artist: "Fixture Composer")
    try fixture.write(to: memberURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "nsf")
    let member = outcome.memberMetadata["NES/game.nsf"]
    let tracks = outcome.trackMetadata["NES/game.nsf"]
    #expect(outcome.failures.isEmpty)
    #expect(outcome.diagnosticCount == 0)
    #expect(member?["game"] == .string("Fixture Game"))
    #expect(member?["system"] == .string("Nintendo NES"))
    #expect(member?["artist"] == .string("Fixture Composer"))
    #expect(member?["title"] == nil)
    #expect(member?["playLengthMs"] == nil)
    #expect(tracks?.count == 3)
    #expect(tracks?.compactMap(\.sourceTrackIndex) == [0, 1, 2])
    #expect(tracks?.allSatisfy { $0.metadata["playLengthMs"] == .integer(150_000) } == true)
    #expect(try Data(contentsOf: memberURL) == fixture)
}

@Test func gbsDirectoryHarvestAttachesNEZPlugM3UTracksToMetaManDocuments() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-gbs-m3u-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let gameBoy = root.appendingPathComponent("GB", isDirectory: true)
    try FileManager.default.createDirectory(at: gameBoy, withIntermediateDirectories: true)
    let gbsURL = gameBoy.appendingPathComponent("game.gbs")
    var gbs = Data(repeating: 0, count: 0x70)
    gbs.replaceSubrange(0..<3, with: Data("GBS".utf8))
    gbs[3] = 1
    gbs[4] = 2
    gbs[5] = 0
    gbs.replaceSubrange(0x10..<0x30, with: Data("Header Game".utf8) + Data(repeating: 0, count: 21))
    try gbs.write(to: gbsURL)

    let m3uURL = gameBoy.appendingPathComponent("01 Opening.m3u")
    let m3u = Data("""
    # @TITLE M3U Album
    # @ARTIST M3U Artist

    game.gbs::GBS,0,Opening Theme,0:42,0:20,0:05,3
    """.utf8)
    try m3u.write(to: m3uURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "gbs")
    let metadata = outcome.memberMetadata["GB/game.gbs"]
    let tracks = outcome.trackMetadata["GB/game.gbs"]
    #expect(outcome.failures.isEmpty)
    #expect(outcome.diagnosticCount == 0)
    #expect(metadata?["game"] == .string("M3U Album"))
    #expect(tracks?.count == 2)
    #expect(tracks?[0].metadata["title"] == .string("Opening Theme"))
    #expect(tracks?[0].metadata["playLengthMs"] == .integer(42_000))
    #expect(tracks?[0].metadata["loopLengthMs"] == .integer(20_000))
    #expect(tracks?[0].metadata["artist"] == .string("M3U Artist"))
    #expect(tracks?[1].metadata["title"] == nil)
    #expect(try Data(contentsOf: gbsURL) == gbs)
    #expect(try Data(contentsOf: m3uURL) == m3u)
}

@Test func genericHarvesterRejectsFormatsMetaManDoesNotAdvertise() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-unknown-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: (any Error).self) {
        try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "unknown")
    }
}

@Test func genericHarvesterRejectsUACPackagesAsContainerInputs() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-container-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    do {
        _ = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "uac")
        Issue.record("The native-source directory harvester must reject UAC containers.")
    } catch {
        #expect(error.localizedDescription.contains("package container"))
        #expect(error.localizedDescription.contains("UAC wrapper reader"))
    }
}

@Test func genericHarvesterRetainsTrackAwareMetaManResultsAsSeparateProjections() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-track-aware-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("subtunes.sap")
    var sapBytes = Data("SAP\r\nSONGS 2\r\nTIME 0:30\r\nTIME 0:45\r\n".utf8)
    sapBytes.append(contentsOf: [0xFF, 0xFF, 0, 0, 0, 0])
    try sapBytes.write(to: memberURL)
    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "sap")
    #expect(outcome.failures.isEmpty)
    #expect(outcome.memberMetadata["subtunes.sap"]?["title"] == nil)
    #expect(outcome.trackMetadata["subtunes.sap"]?.count == 2)
    #expect(outcome.trackMetadata["subtunes.sap"]?.compactMap(\.sourceTrackIndex) == [0, 1])
}

@Test func sndhDirectoryHarvestKeepsAtariSTSubtunesAndSourceBytes() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-sndh-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("Atari ST/score.sndh")
    try FileManager.default.createDirectory(
        at: memberURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let fixture = makeSNDHFixture(names: ["Intro", "Level 1"], frameCounts: [500, 1_000])
    try fixture.write(to: memberURL)

    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "sndh")
    let member = outcome.memberMetadata["Atari ST/score.sndh"]
    let tracks = outcome.trackMetadata["Atari ST/score.sndh"]
    #expect(outcome.failures.isEmpty)
    #expect(outcome.diagnosticCount == 0)
    #expect(member?["system"] == .string("Atari ST"))
    #expect(tracks?.count == 2)
    #expect(tracks?.compactMap(\.sourceTrackIndex) == [1, 2])
    #expect(tracks?.compactMap { $0.metadata["title"] } == [.string("Intro"), .string("Level 1")])
    #expect(tracks?.compactMap { $0.metadata["playLengthMs"] } == [.integer(10_000), .integer(20_000)])
    #expect(try Data(contentsOf: memberURL) == fixture)
}

private func makeNSFFixture(trackCount: UInt8, game: String, artist: String) -> Data {
    var data = Data(repeating: 0, count: 0x81)
    data.replaceSubrange(0..<5, with: Data([0x4E, 0x45, 0x53, 0x4D, 0x1A]))
    data[0x05] = 1
    data[0x06] = trackCount
    data[0x07] = 1
    writeNSFText(game, to: &data, range: 0x0E..<0x2E)
    writeNSFText(artist, to: &data, range: 0x2E..<0x4E)
    data[0x80] = 0x60
    return data
}

private func makeSNDHFixture(names: [String], frameCounts: [UInt32]) -> Data {
    var data = Data(repeating: 0, count: 12)
    data.append(contentsOf: "SNDH".utf8)
    appendSNDHStringTag("TITL", value: "File title", to: &data)
    appendSNDHStringTag("COMM", value: "Composer", to: &data)
    data.append(contentsOf: "##02".utf8)
    appendSNDHStringTag("!#", value: "1", to: &data)

    let tagOffset = data.count
    data.append(contentsOf: "!#SN".utf8)
    let tableOffset = data.count
    data.append(Data(repeating: 0, count: names.count * 2))
    for (index, name) in names.enumerated() {
        let relative = UInt16(data.count - tagOffset)
        data[tableOffset + index * 2] = UInt8(relative >> 8)
        data[tableOffset + index * 2 + 1] = UInt8(relative & 0xFF)
        data.append(contentsOf: name.utf8)
        data.append(0)
    }

    data.append(contentsOf: "FRMS".utf8)
    for value in frameCounts {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
    data.append(contentsOf: "HDNS".utf8)
    data.append(0)
    return data
}

private func appendSNDHStringTag(_ name: String, value: String, to data: inout Data) {
    data.append(contentsOf: name.utf8)
    data.append(contentsOf: value.utf8)
    data.append(0)
}

private func writeNSFText(_ text: String, to data: inout Data, range: Range<Int>) {
    let bytes = Array(text.utf8.prefix(range.count))
    data.replaceSubrange(range.lowerBound..<range.lowerBound + bytes.count, with: bytes)
}

private func makeSIDFixture(title: String, artist: String, released: String) -> Data {
    var data = Data(repeating: 0, count: 0x7C)
    data.replaceSubrange(0..<4, with: Data("PSID".utf8))
    data[5] = 2
    writeSIDText(title, to: &data, range: 0x16..<0x36)
    writeSIDText(artist, to: &data, range: 0x36..<0x56)
    writeSIDText(released, to: &data, range: 0x56..<0x76)
    return data
}

private func writeSIDText(_ text: String, to data: inout Data, range: Range<Int>) {
    let bytes = Array(text.utf8.prefix(range.count - 1))
    data.replaceSubrange(range.lowerBound..<range.lowerBound + bytes.count, with: bytes)
}

private func makeVGMFixture(gd3Fields: [String], totalSamples: UInt32) -> Data {
    var data = Data(repeating: 0, count: 0x41)
    data.replaceSubrange(0..<4, with: Data("Vgm ".utf8))
    writeLE32(0x0000_0171, into: &data, at: 0x08)
    writeLE32(totalSamples, into: &data, at: 0x18)
    data[0x40] = 0x66

    var payload = Data()
    for field in gd3Fields {
        for unit in field.utf16 {
            payload.append(UInt8(truncatingIfNeeded: unit))
            payload.append(UInt8(truncatingIfNeeded: unit >> 8))
        }
        payload.append(contentsOf: [0, 0])
    }
    var gd3 = Data("Gd3 ".utf8)
    gd3.append(contentsOf: [0x00, 0x01, 0x00, 0x00])
    appendLE32(UInt32(payload.count), to: &gd3)
    gd3.append(payload)

    writeLE32(UInt32(data.count - 0x14), into: &data, at: 0x14)
    data.append(gd3)
    writeLE32(UInt32(data.count - 4), into: &data, at: 0x04)
    return data
}

private func makeAPEFixture(tags: [(String, String)]) -> Data {
    var data = Data("MAC ".utf8)
    appendLE16(3_990, to: &data)
    appendLE16(0, to: &data)
    appendLE32(52, to: &data)
    appendLE32(24, to: &data)
    appendLE32(4, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    appendLE32(0, to: &data)
    data.append(contentsOf: repeatElement(0, count: 16))
    appendLE16(2_000, to: &data)
    appendLE16(0, to: &data)
    appendLE32(294_912, to: &data)
    appendLE32(44_100, to: &data)
    appendLE32(1, to: &data)
    appendLE16(16, to: &data)
    appendLE16(2, to: &data)
    appendLE32(44_100, to: &data)
    appendLE32(0, to: &data)
    data.append(contentsOf: [0, 0, 0, 0])

    var fields = Data()
    for (key, value) in tags {
        let valueBytes = Data(value.utf8)
        appendLE32(UInt32(valueBytes.count), to: &fields)
        appendLE32(0, to: &fields)
        fields.append(contentsOf: key.utf8)
        fields.append(0)
        fields.append(valueBytes)
    }
    let tagSize = UInt32(fields.count + 32)
    data.append(Data("APETAGEX".utf8))
    appendLE32(2_000, to: &data)
    appendLE32(tagSize, to: &data)
    appendLE32(UInt32(tags.count), to: &data)
    appendLE32(0xA000_0000, to: &data)
    data.append(contentsOf: repeatElement(0, count: 8))
    data.append(fields)
    data.append(Data("APETAGEX".utf8))
    appendLE32(2_000, to: &data)
    appendLE32(tagSize, to: &data)
    appendLE32(UInt32(tags.count), to: &data)
    appendLE32(0x8000_0000, to: &data)
    data.append(contentsOf: repeatElement(0, count: 8))
    return data
}

private func appendLE16(_ value: UInt16, to data: inout Data) {
    data.append(UInt8(truncatingIfNeeded: value))
    data.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func writeLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    for index in 0..<4 {
        data[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8))
    }
}

private func appendLE32(_ value: UInt32, to data: inout Data) {
    for index in 0..<4 {
        data.append(UInt8(truncatingIfNeeded: value >> (index * 8)))
    }
}
