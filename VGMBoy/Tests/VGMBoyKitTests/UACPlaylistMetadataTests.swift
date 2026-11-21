import Foundation
import Testing
import UACWrapperCore
import VGMBoyArchiveCore
@testable import VGMBoyKit

@Test func uacSubsongPlaylistRowsExposeTrackTagsAndIndices() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-playlist-metadata-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let payloadURL = root.appendingPathComponent("payload.tar.zst")
    try Data([0x28, 0xB5, 0x2F, 0xFD, 0x01]).write(to: payloadURL)
    let destinationURL = root.appendingPathComponent("tracks.uac")
    let digest = String(repeating: "a", count: 64)
    let manifest = UACManifest(
        packageID: "playlist-metadata-test",
        payload: UACPayload(format: "tar+zstd", compressionProfile: "uac-zstd-3-v1",
                            encoderVersion: "test", blake3: digest),
        game: UACGame(id: "fixture-game", title: "Fixture Game", console: "Game Boy",
                      metadata: ["Publisher": .string("Fixture Publisher")]),
        variants: [UACVariant(id: "usa", label: "USA", kind: "retail")],
        members: [UACMember(path: "payload/shared.ngbd", originalName: "shared.ngbd",
                            variantID: "usa", role: "track", format: "UACNGB v3",
                            byteSize: 4, blake3: digest,
                            metadata: ["Format": .string("UACNGB v3")])],
        playlists: [UACPlaylist(
            id: "music",
            title: "Fixture Soundtrack",
            variantID: "usa",
            entries: [
                UACPlaylistEntry(targetMemberPath: "payload/shared.ngbd", entryKind: "subsong",
                                 trackIndex: "0", title: "Opening Theme", artist: "Composer",
                                 extraFields: ["Cue Type": .string("Music")]),
                UACPlaylistEntry(targetMemberPath: "payload/shared.ngbd", entryKind: "subsong",
                                 trackIndex: "1", title: "Stage Clear", artist: "Composer",
                                 extraFields: ["Cue Type": .string("Jingle")]),
            ]
        )]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let manifestData = try encoder.encode(manifest)
    let framedManifest = Data([0x28, 0xB5, 0x2F, 0xFD, 0x01])
    let decodeManifest: UACManifestFrameDecoder = { _, expectedByteCount, _ in
        guard manifestData.count == expectedByteCount else { throw FixtureError.invalidManifestLength }
        return manifestData
    }
    _ = try UACContainerWriter.write(
        manifest: manifest,
        compressedTarPayloadURL: payloadURL,
        to: destinationURL,
        compressManifestFrame: { _ in framedManifest },
        decompressManifestFrame: decodeManifest
    )

    let materializer = ArchiveMaterializer(decompressUACManifestFrame: decodeManifest)
    let entries = try materializer.listEntriesWithMetadata(archivePath: destinationURL.path)
    #expect(entries.count == 2)
    #expect(entries.map(\.path) == ["payload/shared.ngbd", "payload/shared.ngbd"])
    #expect(entries.map(\.subsongIndex) == [0, 1])
    #expect(entries.allSatisfy { $0.playlistID == "music" })
    #expect(entries[0].metadata["Title"] == "Opening Theme")
    #expect(entries[1].metadata["Title"] == "Stage Clear")
    #expect(entries[0].metadata["Artist"] == "Composer")
    #expect(entries[1].metadata["Cue Type"] == "Jingle")
    #expect(entries[0].metadata["Publisher"] == "Fixture Publisher")
    #expect(entries[0].metadata["Format"] == "UACNGB v3")
    #expect(try materializer.listEntries(archivePath: destinationURL.path) == ["payload/shared.ngbd"])
}

@Test func uacngbSelectorsAreNotRejectedAsSingleTrackInput() throws {
    try DecoderFactory.validateTrackIndex(12, path: "castlevania.ngbd", sourceData: nil)
}

@Test func nativeGameBoyDecoderRejectsRetiredV2SlicePayloads() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uacngb-retired-v2-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    var payload = Data(repeating: 0, count: 86)
    payload.replaceSubrange(0..<8, with: Data([0x55, 0x41, 0x43, 0x4E, 0x47, 0x42, 0, 0]))
    payload[8] = 2
    payload[10] = 85
    payload[44] = 1
    payload[48] = 1
    let payloadURL = root.appendingPathComponent("retired-v2.ngbd")
    try payload.write(to: payloadURL)

    #expect(throws: PlaybackControlError.self) {
        try NativeGameBoyDecoder(path: payloadURL.path, helperURL: URL(fileURLWithPath: "/dev/null"))
    }
}

private enum FixtureError: Error {
    case invalidManifestLength
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V3_UAC"] != nil
               && ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"] != nil))
func castlevaniaUACNGBV3ListsTagsAndStreamsNativePCM() throws {
    let packagePath = try #require(ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V3_UAC"])
    let hostPath = try #require(ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"])
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }

    let entries = try materializer.listEntriesWithMetadata(archivePath: packagePath)
    #expect(entries.count == 13)
    #expect(entries.map(\.subsongIndex) == Array(0..<13))
    #expect(entries.map { $0.metadata["Title"] }[0] == "Battle of the Holy [Stage 1 BGM]")
    #expect(entries[0].metadata["Composer"] == "Norio Hanzawa, Hidehiro Funauchi")
    #expect(entries[1].metadata["CUE Type"] == "Sound effect")
    #expect(entries[0].metadata["Source ROM SHA 256"] == "edb101e924f22149bdcbcfe6603801fdb4ec0139a40493d700fa0205f6dab30c")

    let entryPath = entries[0].path
    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entryPath]))
    let prepared = try materializer.materializeSource(
        archivePath: packagePath,
        entry: entryPath,
        requirement: requirement
    )
    let decoder = try NativeGameBoyDecoder(
        path: prepared.url.path,
        sampleRate: 44_100,
        helperURL: URL(fileURLWithPath: hostPath)
    )
    defer { decoder.close() }
    try decoder.startTrack(entries[0].subsongIndex ?? 0)
    let pcm = try decoder.readFrames(22_050)
    #expect(pcm.left.count == 22_050)
    #expect(pcm.right.count == 22_050)
    let rms = sqrt(pcm.left.reduce(0.0) { $0 + Double($1 * $1) } / Double(pcm.left.count))
    #expect(rms > 0.005)
    #expect(!decoder.trackEnded)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V4_UAC"] != nil
               && ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"] != nil))
func castlevaniaUACNGBV4ListsTagsAndStreamsNativeStatePCM() throws {
    let packagePath = try #require(ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V4_UAC"])
    let hostPath = try #require(ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"])
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }

    let entries = try materializer.listEntriesWithMetadata(archivePath: packagePath)
    #expect(entries.count == 13)
    #expect(entries.map(\.subsongIndex) == Array(0..<13))
    #expect(entries[0].path.contains("payload/nintendo_gameboy/v4/"))
    #expect(entries[0].metadata["Title"] == "Battle of the Holy [Stage 1 BGM]")
    #expect(entries[0].metadata["Format"] == "UACNGB v4")
    #expect(entries[0].metadata["ROM Included"] == "false")
    #expect(entries[0].metadata["Source Audio Region SHA 256"] == "78b775a4fde195af891e148fb4b74a1f4bf51f3a13018df1a8513d4640a01332")
    #expect(entries.allSatisfy {
        !($0.metadata["Title"] ?? "").isEmpty && $0.metadata["Format"] == "UACNGB v4"
    })

    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entries[0].path]))
    let prepared = try materializer.materializeSource(
        archivePath: packagePath,
        entry: entries[0].path,
        requirement: requirement
    )
    let decoder = try NativeGameBoyDecoder(
        path: prepared.url.path,
        sampleRate: 44_100,
        helperURL: URL(fileURLWithPath: hostPath)
    )
    defer { decoder.close() }
    #expect(decoder.trackCount == 13)
    for index in entries.indices {
        try decoder.startTrack(entries[index].subsongIndex ?? index)
        let pcm = try decoder.readFrames(220_500)
        #expect(pcm.left.count == 220_500)
        #expect(pcm.right.count == 220_500)
        let sampleCount = Double(pcm.left.count + pcm.right.count)
        let rms = sqrt((pcm.left + pcm.right).reduce(0.0) { $0 + Double($1 * $1) } / sampleCount)
        #expect(rms > 0.005)
        #expect((pcm.left + pcm.right).allSatisfy { $0.isFinite && abs($0) < 1.0 })
        #expect(!decoder.trackEnded)
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_BELMONT_UACNGB_V4_UAC"] != nil
               && ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"] != nil))
func belmontRevengeUACNGBV4ListsAll25TracksAndStreamsNativeStatePCM() throws {
    let packagePath = try #require(ProcessInfo.processInfo.environment["VGMBOY_BELMONT_UACNGB_V4_UAC"])
    let hostPath = try #require(ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"])
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }

    let entries = try materializer.listEntriesWithMetadata(archivePath: packagePath)
    #expect(entries.count == 25)
    #expect(entries.map(\.subsongIndex) == Array(0..<25))
    #expect(entries[0].path.contains("payload/nintendo_gameboy/v4/"))
    #expect(entries[0].metadata["Title"] == "Start [Start SFX]")
    #expect(entries[0].metadata["Format"] == "UACNGB v4")
    #expect(entries[0].metadata["ROM Included"] == "false")
    #expect(entries[0].metadata["Source Audio Region SHA 256"] == "680d77faed4257b9c210450ca79fe5638c132219266794ddaa6b8e0f39ed1ae6")
    #expect(entries[1].metadata["Title"] == "All Clear")
    #expect(entries[24].metadata["Title"] == "Soleiyu's Room")
    #expect(entries.allSatisfy {
        !($0.metadata["Title"] ?? "").isEmpty && $0.metadata["Format"] == "UACNGB v4"
    })

    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entries[0].path]))
    let prepared = try materializer.materializeSource(
        archivePath: packagePath,
        entry: entries[0].path,
        requirement: requirement
    )
    let decoder = try NativeGameBoyDecoder(
        path: prepared.url.path,
        sampleRate: 44_100,
        helperURL: URL(fileURLWithPath: hostPath)
    )
    defer { decoder.close() }
    #expect(decoder.trackCount == 25)
    for index in [0, 1, 2, 3, 13, 23, 24] {
        try decoder.startTrack(entries[index].subsongIndex ?? index)
        let pcm = try decoder.readFrames(44_100)
        #expect(pcm.left.count == 44_100)
        #expect(pcm.right.count == 44_100)
        let sampleCount = Double(pcm.left.count + pcm.right.count)
        let rms = sqrt((pcm.left + pcm.right).reduce(0.0) { $0 + Double($1 * $1) } / sampleCount)
        #expect(rms > 0.005)
        #expect((pcm.left + pcm.right).allSatisfy { $0.isFinite && abs($0) < 1.0 })
        #expect(!decoder.trackEnded)
    }
}



@Test(.enabled(if: ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V4_UAC"] != nil
               && ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"] != nil))
func castlevaniaUACNGBV4RepeatsFiniteCuesInsteadOfStreamingSilence() throws {
    let packagePath = try #require(ProcessInfo.processInfo.environment["VGMBOY_UACNGB_V4_UAC"])
    let hostPath = try #require(ProcessInfo.processInfo.environment["VGMBoySameBoyUACNGBHostPath"])
    let materializer = ArchiveMaterializer()
    defer { materializer.release() }

    let entries = try materializer.listEntriesWithMetadata(archivePath: packagePath)
    let requirement = try #require(FormatRegistry.archiveMaterializationRequirement(for: [entries[0].path]))
    let prepared = try materializer.materializeSource(
        archivePath: packagePath,
        entry: entries[0].path,
        requirement: requirement
    )
    let decoder = try NativeGameBoyDecoder(
        path: prepared.url.path,
        sampleRate: 44_100,
        helperURL: URL(fileURLWithPath: hostPath)
    )
    defer { decoder.close() }

    // These ROM cues naturally finish. The v4 host must repeat them after the
    // documented 250 ms digital-silence fallback rather than stream silence.
    for index in [1, 2, 9, 12] {
        try decoder.startTrack(index)
        let pcm = try decoder.readFrames(44_100 * 12)
        #expect(pcm.left.count == 44_100 * 12)
        #expect(pcm.right.count == 44_100 * 12)

        var windowRMS: [Double] = []
        for start in stride(from: 0, to: pcm.left.count, by: 44_100) {
            let end = min(start + 44_100, pcm.left.count)
            let energy = zip(pcm.left[start..<end], pcm.right[start..<end]).reduce(0.0) { partial, pair in
                partial + Double(pair.0 * pair.0 + pair.1 * pair.1)
            }
            let sampleCount = Double((end - start) * 2)
            windowRMS.append(sqrt(energy / sampleCount))
        }
        let firstAudibleWindow = windowRMS.firstIndex(where: { $0 > 0.005 })
        #expect(firstAudibleWindow != nil)
        if let firstAudibleWindow {
            #expect(windowRMS[firstAudibleWindow...].allSatisfy { $0 > 0.001 })
        }
        #expect(!decoder.trackEnded)
    }
}



