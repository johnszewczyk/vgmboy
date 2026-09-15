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
    #expect(inspection.tracks.allSatisfy { $0.metadata?.playLengthMs == 150_000 })
}
