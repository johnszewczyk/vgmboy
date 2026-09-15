import Foundation
import MetaManCore
import Testing
import UACContainerCore
@testable import UACManCore

@Test func spcProjectionRetainsDuplicateTagsAndOriginalBlocks() throws {
    let document = MetadataDocument(
        format: "spc",
        fields: MetadataFields(title: "Track", game: "Game", artist: "Composer", album: "Album", year: "1995"),
        tags: [MetadataTag(name: "Artist", value: "Short"), MetadataTag(name: "ARTIST", value: "Long")],
        rawMetadataBlocks: ["id666": Data([0, 1, 2]), "xid6": Data([3, 4])],
        timing: MetadataTiming(introLengthMs: 1200, loopLengthMs: 3000, playLengthMs: 4200),
        diagnostics: ["sample diagnostic"]
    )
    let projection = SPCMetadataProjector.project(document)
    guard case .object(let native)? = projection.memberFields["nativeMetadata"],
          case .array(let tags)? = native["tags"],
          case .object(let blockSizes)? = native["rawBlockByteCounts"] else {
        Issue.record("Native SPC metadata was not represented in the member map.")
        return
    }

    #expect(tags.count == 2)
    #expect(blockSizes["id666"] == .integer(3))
    #expect(projection.memberFields["introLengthMs"] == .integer(1200))
    #expect(projection.sharedCandidates["album"] == .string("Album"))
}

@Test func sharedMetadataRequiresEveryTrackToAgree() {
    let first = MetadataDocument(
        format: "spc",
        fields: MetadataFields(title: "One", game: "Game", album: "Album")
    )
    let second = MetadataDocument(
        format: "spc",
        fields: MetadataFields(title: "Two", game: "Game", album: "Different album")
    )
    let result = SPCMetadataProjector.sharedFields(from: [
        SPCMetadataProjector.project(first),
        SPCMetadataProjector.project(second)
    ])

    #expect(result.fields["sourceGameTitle"] == .string("Game"))
    #expect(result.fields["album"] == nil)
    #expect(result.conflicts.contains("album"))
}

@Test func spcImportKeepsManualFieldsAndAddsUnanimousSoundtrackData() throws {
    let document = MetadataDocument(
        format: "spc",
        fields: MetadataFields(title: "Native track", game: "Native game", artist: "Track artist", album: "Soundtrack")
    )
    let item = SPCMetadataHarvestItem(
        memberPath: "variants/original/track.spc",
        projection: SPCMetadataProjector.project(document)
    )
    let merged = try SPCMetadataProjector.merge(items: [item], into: Data(mergeManifestJSON.utf8))
    let manifest = try UACManifestEditor.decode(merged.manifestJSON)
    let member = try #require(manifest.members.first)

    #expect(member.metadata["title"] == .string("Manually corrected title"))
    #expect(member.metadata["artist"] == .string("Track artist"))
    #expect(manifest.game.metadata["sourceGameTitle"] == .string("Native game"))
    #expect(manifest.game.metadata["album"] == .string("Soundtrack"))
    #expect(manifest.game.metadata["curatorNote"] == .string("keep"))
}

private let mergeManifestJSON = """
{
  "manifestVersion": 1,
  "packageID": "merge-test",
  "payload": {"format": "tar+zstd", "compressionProfile": "uac-zstd-3-v1", "encoderVersion": "zstd", "blake3": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "game": {"id": "merge-test", "title": "Canonical game", "console": "Super Nintendo", "canonicalIDs": [], "metadata": {"curatorNote": "keep"}, "extensions": {}},
  "variants": [{"id": "original", "label": "Original", "kind": "release", "canonicalReleaseIDs": [], "metadata": {}, "extensions": {}}],
  "members": [{"path": "variants/original/track.spc", "originalName": "track.spc", "variantID": "original", "sourceIDs": [], "role": "playable", "format": "spc", "byteSize": 4, "blake3": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "hashes": [], "metadata": {"title": "Manually corrected title"}, "extensions": {}}],
  "playlists": [], "sources": [], "transformations": [], "extensions": {}
}
"""
