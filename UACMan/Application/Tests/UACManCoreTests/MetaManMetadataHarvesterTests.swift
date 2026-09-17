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

@Test func genericHarvesterRejectsTrackAwareMetaManResultsWithoutFlattening() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-track-aware-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let memberURL = root.appendingPathComponent("subtunes.sap")
    var sapBytes = Data("SAP\r\nSONGS 2\r\nTIME 0:30\r\nTIME 0:45\r\n".utf8)
    sapBytes.append(contentsOf: [0xFF, 0xFF, 0, 0, 0, 0])
    try sapBytes.write(to: memberURL)
    let outcome = try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "sap")
    #expect(outcome.memberMetadata.isEmpty)
    #expect(outcome.failures.count == 1)
    #expect(outcome.failures[0].contains("2 logical tracks"))
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
