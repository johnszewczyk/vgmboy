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
          case .object(let game)? = packageValue["game"],
          case .object(let gameMetadata)? = game["metadata"],
          case .array(let covers)? = gameMetadata["cover_front"],
          case .object(let cover)? = covers.first,
          case .object(let playlist)? = playlists.first,
          case .array(let entries)? = playlist["entries"],
          case .object(let firstEntry)? = entries.first,
          case .object(let secondEntry)? = entries.dropFirst().first else {
        Issue.record("The package document should retain ordered playlist entries.")
        return
    }
    #expect(entries.count == 2)
    #expect(cover["memberPath"] == .string("variants/original/scans/front.png"))
    #expect(cover["mediaType"] == .string("image/png"))
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
    #expect(track.tags.first(where: { $0.name == "emptyTag" }) == nil)

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

@Test("MetaMan reads version-two UACs with source-relative single-variant members")
func uacManifestVersionTwoUsesFlatMemberPaths() throws {
    let fixture = try makeUACMetadataFixture(compressedManifest: false, manifestVersion: 2)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let result = try MetaManCore.readResult(fileURL: fixture.packageURL)
    #expect(result.containerDocument?.technicalFacts["uac.manifestVersion"] == "2")
    #expect(result.tracks.first?.document.technicalFacts["uac.memberPath"] == "song.vgm")
    #expect(result.tracks.first?.document.fields.title == "Manifest Song")
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

@Test("UAC subsong playlist entries project NSF tracks from one unchanged member")
func uacSubsongEntriesBecomeMetaManTracks() throws {
    let fixture = try makeUACMetadataFixture(compressedManifest: false, subsongTracks: true)
    defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }

    let result = try MetaManCore.readResult(fileURL: fixture.packageURL)
    #expect(result.tracks.count == 3)
    #expect(result.tracks.compactMap(\.sourceTrackIndex) == [0, 1, 2])
    #expect(result.tracks.map(\.document.fields.title) == ["NSF Track 1", "NSF Track 2", "NSF Track 3"])
    #expect(result.tracks.allSatisfy { $0.document.fields.game == "Fixture Game" })
    #expect(result.tracks.allSatisfy { $0.document.timing?.playLengthMs == 150_000 })
    #expect(result.tracks.allSatisfy { $0.document.technicalFacts["uac.memberPath"] == "variants/original/song.vgm" })
    #expect(result.tracks.map { $0.document.technicalFacts["uac.trackIndex"] } == ["0", "1", "2"])
    #expect(result.tracks.allSatisfy { $0.document.technicalFacts["uac.trackCount"] == "3" })
    #expect(result.tracks.allSatisfy { $0.document.technicalFacts["uac.memberBLAKE3"] == String(repeating: "b", count: 64) })
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

private func makeUACMetadataFixture(
    compressedManifest: Bool,
    subsongTracks: Bool = false,
    manifestVersion: Int = 1
) throws -> UACMetadataFixture {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-uac-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let repeatedMetadata: UACJSONValue = compressedManifest
        ? .string(String(repeating: "x", count: 2_048))
        : .array([.string("kept"), .integer(7)])
    let memberRoot = manifestVersion == 2 ? "" : "variants/original/"
    let manifest = UACManifest(
        manifestVersion: manifestVersion,
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
            metadata: [
                "region": .string("US"),
                "cover_front": .array([.object([
                    "memberPath": .string("\(memberRoot)scans/front.png"),
                    "mediaType": .string("image/png")
                ])]),
                "cue_sheet": .object([
                    "memberPath": .string("\(memberRoot)disc.cue"),
                    "mediaType": .string("application/x-cue")
                ])
            ],
            extensions: ["futureGame": .object(["kept": .bool(true)])]
        ),
        variants: [UACVariant(id: "original", label: "Original", kind: "source")],
        members: [
            UACMember(
                path: "\(memberRoot)song.vgm",
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
                    "emptyTag": .string("   "),
                    "custom": .integer(42)
                ],
                extensions: ["future": .array([.string("kept"), .integer(7)])]
            ),
            UACMember(
                path: "\(memberRoot)scans/front.png",
                originalName: "front.png",
                variantID: "original",
                role: "artwork",
                format: "png",
                byteSize: 5,
                blake3: String(repeating: "c", count: 64)
            ),
            UACMember(
                path: "\(memberRoot)disc.cue",
                originalName: "disc.cue",
                variantID: "original",
                role: "cue-sheet",
                format: "cue",
                byteSize: 5,
                blake3: String(repeating: "d", count: 64)
            )
        ],
        playlists: [
            UACPlaylist(
                id: "main",
                title: "Main",
                variantID: "original",
                entries: subsongTracks
                    ? (0..<3).map { index in
                        let title = "NSF Track \(index + 1)"
                        return UACPlaylistEntry(
                            targetMemberPath: "\(memberRoot)song.vgm",
                            entryKind: "subsong",
                            formatTag: "nsf",
                            trackIndex: String(index),
                            title: title,
                            artist: "NSF Composer",
                            extraFields: [
                                "visibleTrackIndex": .integer(Int64(index)),
                                "trackCount": .integer(3),
                                "metaManMetadata": .object([
                                    "title": .string(title),
                                    "game": .string("Fixture Game"),
                                    "system": .string("Nintendo NES"),
                                    "artist": .string("NSF Composer"),
                                    "playLengthMs": .integer(150_000),
                                    "nativeMetadata": .object(["format": .string("nsf")])
                                ])
                            ]
                        )
                    }
                    : [
                        UACPlaylistEntry(
                            targetMemberPath: "\(memberRoot)song.vgm",
                            trackIndex: "1",
                            title: "First occurrence"
                        ),
                        UACPlaylistEntry(
                            targetMemberPath: "\(memberRoot)song.vgm",
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
