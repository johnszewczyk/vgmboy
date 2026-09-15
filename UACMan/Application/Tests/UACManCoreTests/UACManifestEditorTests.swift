import Foundation
import Testing
import UACWrapperCore
@testable import UACManCore

@Test func packageEditsPreserveUnknownManifestFields() throws {
    let original = Data(manifestJSON.utf8)
    let edited = try UACManifestEditor.updateGameFields(
        in: original,
        title: "Edited Title",
        console: "Nintendo SNES",
        metadataJSON: "{\"publisher\":\"Example\",\"nested\":[1,true]}",
        extensionsJSON: "{\"x-editor\":{\"mode\":\"manual\"}}"
    )
    let decoded = try UACManifestEditor.decode(edited)

    #expect(decoded.game.title == "Edited Title")
    #expect(decoded.game.metadata["publisher"] == UACJSONValue.string("Example"))
    #expect(String(decoding: edited, as: UTF8.self).contains("futureRootField"))
    #expect(String(decoding: edited, as: UTF8.self).contains("keepMe"))
}

@Test func memberEditsAreTypedAndPathScoped() throws {
    let edited = try UACManifestEditor.updateMemberFields(
        in: Data(manifestJSON.utf8),
        memberPath: "variants/original/track.spc",
        metadataJSON: "{\"trackNumber\":7,\"durationMs\":12345}",
        extensionsJSON: "{\"x-sample\":[\"a\",\"b\"]}"
    )
    let manifest = try UACManifestEditor.decode(edited)
    let member = try #require(manifest.members.first)

    #expect(member.metadata["trackNumber"] == UACJSONValue.integer(7))
    #expect(member.metadata["durationMs"] == UACJSONValue.integer(12345))
    #expect(String(decoding: edited, as: UTF8.self).contains("futureMemberField"))
}

@Test func rejectsNonObjectMetadataEditors() {
    #expect(throws: UACManifestEditorError.invalidMetadataJSON("Member metadata")) {
        try UACManifestEditor.updateMemberFields(
            in: Data(manifestJSON.utf8),
            memberPath: "variants/original/track.spc",
            metadataJSON: "[1,2,3]",
            extensionsJSON: "{}"
        )
    }
}

@Test func batchEditsAreScopedAndSupportSafeOperations() throws {
    let initial = try UACManifestEditor.updateMemberFields(
        in: Data(manifestJSON.utf8),
        memberPath: "variants/original/track.spc",
        metadataJSON: "{\"artist\":\"Old Artist\",\"title\":\"Old title\",\"keep\":7}",
        extensionsJSON: "{}"
    )
    let filled = try UACManifestEditor.applyBatchMetadataEdit(
        in: initial,
        memberPaths: ["variants/original/track.spc"],
        key: "artist",
        operation: .fillMissing,
        value: "New Artist"
    )
    let replaced = try UACManifestEditor.applyBatchMetadataEdit(
        in: filled,
        memberPaths: ["variants/original/track.spc"],
        key: "title",
        operation: .replaceText,
        value: "Remastered",
        searchText: "Old"
    )
    let removed = try UACManifestEditor.applyBatchMetadataEdit(
        in: replaced,
        memberPaths: ["variants/original/track.spc"],
        key: "keep",
        operation: .remove
    )
    let member = try #require(UACManifestEditor.decode(removed).members.first)

    #expect(member.metadata["artist"] == .string("Old Artist"))
    #expect(member.metadata["title"] == .string("Remastered title"))
    #expect(member.metadata["keep"] == nil)
}

@Test func batchFillAddsMissingFieldsWithoutOverwritingExistingValues() throws {
    let original = Data(manifestJSON.utf8)
    let edited = try UACManifestEditor.applyBatchMetadataEdit(
        in: original,
        memberPaths: ["variants/original/track.spc"],
        key: "artist",
        operation: .fillMissing,
        value: "New Artist"
    )
    let member = try #require(UACManifestEditor.decode(edited).members.first)

    #expect(member.metadata["artist"] == .string("New Artist"))
    #expect(member.metadata["title"] == .string("Old title"))
}

private let manifestJSON = """
{
  "manifestVersion": 1,
  "packageID": "fixture-game",
  "payload": {"format": "tar+zstd", "compressionProfile": "uac-zstd-3-v1", "encoderVersion": "zstd 1.5.7", "blake3": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "game": {"id": "fixture-game", "title": "Fixture Game", "console": "Nintendo SNES", "canonicalIDs": [], "metadata": {}, "extensions": {}},
  "variants": [{"id": "original", "label": "Original", "kind": "release", "canonicalReleaseIDs": [], "metadata": {}, "extensions": {}}],
  "members": [{"path": "variants/original/track.spc", "originalName": "track.spc", "variantID": "original", "sourceIDs": [], "role": "playable", "format": "spc", "byteSize": 4, "blake3": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "hashes": [], "metadata": {"title": "Old title"}, "extensions": {}, "futureMemberField": {"keepMe": true}}],
  "playlists": [], "sources": [], "transformations": [], "extensions": {"futureRootField": {"keepMe": true}}
}
"""
