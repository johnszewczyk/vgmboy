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

@Test func genericHarvesterRejectsFormatsMetaManDoesNotAdvertise() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-unknown-harvest-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(throws: (any Error).self) {
        try MetaManMetadataHarvester.harvest(directoryURL: root, formatExtension: "unknown")
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
