import Foundation
import Testing
import UACWrapperCore
@testable import MetaManCore

@Test("UAC file-URL reading returns package and ordered member metadata without expanding payload")
func uacManifestProducesStructuredMetaManDocuments() throws {
    let fixture = try makeUACMetadataFixture(compressedManifest: false)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let result = try MetaManCore.readResult(fileURL: fixture.packageURL)
    #expect(result.tracks.count == 1)
    let package = try #require(result.containerDocument)
    let track = try #require(result.tracks.first?.document)

    #expect(package.format == "uac")
    #expect(package.fields.title == "Package Game")
    #expect(package.fields.system == "Sega Genesis")
    #expect(package.technicalFacts["uac.manifestSHA256"] == fixture.manifestSHA256)
    #expect(package.rawMetadataBlocks?["uac-manifest"] == fixture.manifestJSON)
    #expect(package.structuredMetadata == fixture.manifestValue)

    guard case .object(let packageValue)? = package.structuredMetadata,
          case .array(let playlists)? = packageValue["playlists"],
          case .object(let playlist)? = playlists.first,
          case .array(let entries)? = playlist["entries"],
          case .object(let firstEntry)? = entries.first,
          case .object(let secondEntry)? = entries.dropFirst().first else {
        Issue.record("The package document should retain ordered playlist entries.")
        return
    }
    #expect(entries.count == 2)
    #expect(firstEntry["title"] == .string("First occurrence"))
    #expect(secondEntry["title"] == .string("Second occurrence"))
    #expect(firstEntry["targetMemberPath"] == secondEntry["targetMemberPath"])

    #expect(track.format == "uac")
    #expect(result.tracks.first?.sourceTrackIndex == 0)
    #expect(track.fields.title == "Manifest Song")
    #expect(track.fields.game == "Manifest Game")
    #expect(track.fields.system == "Mega Drive")
    #expect(track.fields.artist == "Manifest Artist")
    #expect(track.timing == MetadataTiming(introLengthMs: 1_250, loopLengthMs: 3_500, playLengthMs: 10_000, fadeLengthMs: 500))
    #expect(track.technicalFacts["uac.memberPath"] == "variants/original/song.vgm")
    #expect(track.technicalFacts["uac.memberFormat"] == "vgm")
    #expect(track.technicalFacts["uac.memberBLAKE3"] == String(repeating: "b", count: 64))
    #expect(track.tags.first(where: { $0.name == "custom" })?.value == "42")

    guard case .object(let scoped)? = track.structuredMetadata,
          case .object(let member)? = scoped["member"],
          case .object(let extensions)? = member["extensions"] else {
        Issue.record("The member document should retain typed unknown UAC fields.")
        return
    }
    #expect(extensions["future"] == .array([.string("kept"), .integer(7)]))

    #expect(throws: MetadataReadError.trackAwareResultRequired("UAC")) {
        try MetaManCore.read(fileURL: fixture.packageURL)
    }
}

@Test("UAC compressed manifests use the host decoder with the declared bounds")
func uacCompressedManifestUsesInjectedCodec() throws {
    let fixture = try makeUACMetadataFixture(compressedManifest: true)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let result = try MetaManCore.readResult(
        fileURL: fixture.packageURL,
        decompressContainerManifestFrame: { frame, expectedByteCount, maximumMemoryByteCount in
            #expect(frame.count >= 4)
            #expect(Array(frame.prefix(4)) == [0x28, 0xB5, 0x2F, 0xFD])
            #expect(expectedByteCount == fixture.manifestJSON.count)
            #expect(maximumMemoryByteCount == UACContainerReader.maximumManifestDecoderMemoryByteCount)
            return fixture.manifestJSON
        }
    )
    #expect(result.containerDocument?.rawMetadataBlocks?["uac-manifest"] == fixture.manifestJSON)
    #expect(result.tracks.first?.document.fields.title == "Manifest Song")
}

@Test("UAC metadata advertises its payload-preserving read boundary")
func uacMetadataReaderIsRegistered() throws {
    let descriptor = try #require(MetaManCore.supportedFormats.first { $0.identifier == "uac" })
    #expect(descriptor.fileExtensions == ["uac"])
    #expect(descriptor.methodology.contains("without decompressing the TAR/audio payload"))
}

private struct UACMetadataFixture {
    let directoryURL: URL
    let packageURL: URL
    let manifestJSON: Data
    let manifestValue: MetadataJSONValue
    let manifestSHA256: String
}

private func makeUACMetadataFixture(compressedManifest: Bool) throws -> UACMetadataFixture {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-uac-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let repeatedMetadata: UACJSONValue = compressedManifest
        ? .string(String(repeating: "x", count: 2_048))
        : .array([.string("kept"), .integer(7)])
    let manifest = UACManifest(
        packageID: "metaman-uac-fixture",
        payload: UACPayload(
            format: "tar+zstd",
            compressionProfile: "uac-zstd-3-v1",
            encoderVersion: "test",
            blake3: String(repeating: "a", count: 64)
        ),
        game: UACGame(
            id: "package-game-id",
            title: "Package Game",
            console: "Sega Genesis",
            metadata: ["region": .string("US")],
            extensions: ["futureGame": .object(["kept": .bool(true)])]
        ),
        variants: [UACVariant(id: "original", label: "Original", kind: "source")],
        members: [
            UACMember(
                path: "variants/original/song.vgm",
                originalName: "song.vgm",
                variantID: "original",
                role: "playable",
                format: "vgm",
                byteSize: 5,
                blake3: String(repeating: "b", count: 64),
                metadata: [
                    "title": .string("Manifest Song"),
                    "game": .string("Manifest Game"),
                    "system": .string("Mega Drive"),
                    "artist": .string("Manifest Artist"),
                    "introLengthMs": .integer(1_250),
                    "loopLengthMs": .integer(3_500),
                    "playLengthMs": .integer(10_000),
                    "fadeLengthMs": .integer(500),
                    "custom": .integer(42)
                ],
                extensions: ["future": .array([.string("kept"), .integer(7)])]
            )
        ],
        playlists: [
            UACPlaylist(
                id: "main",
                title: "Main",
                variantID: "original",
                entries: [
                    UACPlaylistEntry(
                        targetMemberPath: "variants/original/song.vgm",
                        trackIndex: "1",
                        title: "First occurrence"
                    ),
                    UACPlaylistEntry(
                        targetMemberPath: "variants/original/song.vgm",
                        trackIndex: "2",
                        title: "Second occurrence"
                    )
                ]
            )
        ],
        extensions: ["futureRoot": repeatedMetadata]
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let manifestJSON = try encoder.encode(manifest)
    let manifestValue = try JSONDecoder().decode(MetadataJSONValue.self, from: manifestJSON)
    let encodedManifestFrame = Data([0x28, 0xB5, 0x2F, 0xFD, 0x00])
        + Data(repeating: 0, count: compressedManifest ? 0 : manifestJSON.count)

    let payloadURL = directoryURL.appendingPathComponent("payload.tar.zst")
    // The metadata reader validates the outer Zstandard marker and does not
    // inflate or inspect sequential TAR payload frames.
    try Data([0x28, 0xB5, 0x2F, 0xFD, 0x00]).write(to: payloadURL)
    let packageURL = directoryURL.appendingPathComponent("Fixture.uac")
    let written = try UACContainerWriter.write(
        manifest: manifest,
        compressedTarPayloadURL: payloadURL,
        to: packageURL,
        compressManifestFrame: { _ in
            // UACWrapperCore delegates frame correctness to the supplied
            // decoder; this fixture validates MetaMan's bounded handoff.
            encodedManifestFrame
        },
        decompressManifestFrame: { _, expectedByteCount, _ in
            guard expectedByteCount == manifestJSON.count else {
                throw MetadataReadError.malformedFile("Fixture manifest size mismatch.")
            }
            return manifestJSON
        }
    )

    return UACMetadataFixture(
        directoryURL: directoryURL,
        packageURL: packageURL,
        manifestJSON: written.manifestJSON,
        manifestValue: manifestValue,
        manifestSHA256: written.manifestSHA256
    )
}
