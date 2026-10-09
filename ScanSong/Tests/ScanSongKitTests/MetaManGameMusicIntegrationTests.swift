import Foundation
import Testing
@testable import ScanSongKit

@Test("GBS scanning adapts MetaMan's ordered header result without a playback reader")
func gbsScannerUsesMetaManTrackDocuments() async throws {
    var data = Data(repeating: 0, count: 0x70)
    data.replaceSubrange(0..<3, with: Data("GBS".utf8))
    data[0x03] = 1
    data[0x04] = 2
    data[0x05] = 1
    data.replaceSubrange(0x10..<(0x10 + 8), with: Data("GBS Game".utf8))
    data.replaceSubrange(0x30..<(0x30 + 6), with: Data("Author".utf8))

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-metaman-gbs-\(UUID().uuidString).gbs")
    try data.write(to: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)

    #expect(route.pluginID == "game-music-direct")
    #expect(inspection.tracks.map(\.trackIndex) == [0, 1])
    #expect(inspection.tracks.map(\.trackCount) == [2, 2])
    #expect(inspection.tracks.allSatisfy { $0.metadata?.game == "GBS Game" })
    #expect(inspection.tracks.allSatisfy { $0.metadata?.author == "Author" })
    #expect(inspection.tracks.allSatisfy { $0.metadata?.system == "Nintendo Game Boy" })
    #expect(inspection.tracks.allSatisfy { $0.metadata?.playLengthMs == -1 })
}

@Test("GBS scanner projects fractional sibling-M3U timing through MetaMan")
func gbsScannerProjectsFractionalPlaylistTiming() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("scansong-metaman-gbs-m3u-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    var data = Data(repeating: 0, count: 0x70)
    data.replaceSubrange(0..<3, with: Data("GBS".utf8))
    data[0x03] = 1
    data[0x04] = 2
    data[0x05] = 1
    let fileURL = directory.appendingPathComponent("fixture.gbs")
    try data.write(to: fileURL)
    try "fixture.gbs::GBS,0,Opening,1:23.456,0:10.500-,0:02.250,3\n"
        .write(to: directory.appendingPathComponent("01 Opening.m3u"), atomically: true, encoding: .utf8)

    let route = try #require(BuiltInScannerPlugins.registry.route(forPath: fileURL.path))
    let handler = try #require(BuiltInFormatInspectors.registry.handler(for: route))
    let inspection = try await handler.inspect(fileURL: fileURL, route: route)
    let track = try #require(inspection.tracks.first?.metadata)

    #expect(track.song == "Opening")
    #expect(track.playLengthMs == 83_456)
    #expect(track.introLengthMs == 10_500)
    #expect(track.loopLengthMs == -1)
    #expect(track.fadeLengthMs == 2_250)
}
