import Foundation
import MetaManCore
import Testing
import UACWrapperCore
@testable import UACManCore

@Test func spcProjectionOmitsGenericNativeMetadataAndKeepsCanonicalFields() throws {
    let document = MetadataDocument(
        format: "spc",
        fields: MetadataFields(title: "Track", game: "Game", artist: "Composer", album: "Album", year: "1995"),
        tags: [
            MetadataTag(name: "Artist", value: "Short"),
            MetadataTag(name: "ARTIST", value: "Long"),
            MetadataTag(name: "Artist", value: "Second occurrence")
        ],
        rawMetadataBlocks: ["id666": Data([0, 1, 2]), "xid6": Data([3, 4])],
        timing: MetadataTiming(introLengthMs: 1200, loopLengthMs: 3000, playLengthMs: 4200),
        diagnostics: ["sample diagnostic"]
    )
    let projection = SPCMetadataProjector.project(document)
    #expect(projection.memberFields["nativeMetadata"] == nil)
    #expect(projection.memberFields["Intro Length (ms)"] == .integer(1200))
    #expect(projection.memberFields["Game"] == nil)
    #expect(projection.memberFields["System"] == nil)
    #expect(projection.memberFields["Album"] == nil)
    #expect(projection.sharedCandidates["Album"] == nil)
    #expect(projection.memberFields["Artist"] == .string("Composer"))
    #expect(projection.sharedCandidates["Album Artist"] == .string("Composer"))
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

    #expect(result.fields["Game Title"] == nil)
    #expect(result.fields["Album"] == nil)
    #expect(!result.conflicts.contains("Album"))
}

@Test func spcOstTrackBecomesTrackNumber() {
    let document = MetadataDocument(
        format: "spc",
        fields: MetadataFields(),
        technicalFacts: ["soundtrackTrack": "0007"]
    )
    #expect(SPCMetadataProjector.project(document).memberFields["Track Number"] == .integer(7))
}

@Test func spcImportKeepsManualFieldsAndPromotesSharedMetadataWithoutDuplication() throws {
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

    #expect(member.metadata["Title"] == .string("Manually corrected title"))
    #expect(member.metadata["Artist"] == nil)
    #expect(member.metadata["Album"] == nil)
    #expect(manifest.game.metadata["sourceGameTitle"] == nil)
    #expect(manifest.game.metadata["Artist"] == nil)
    #expect(manifest.game.metadata["Album Artist"] == .string("Track artist"))
    #expect(manifest.game.metadata["Album"] == nil)
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
