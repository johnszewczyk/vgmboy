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

@Test func metadataEditorsDoNotPersistEmptyTagValues() throws {
    let edited = try UACManifestEditor.updateMemberFields(
        in: Data(manifestJSON.utf8),
        memberPath: "variants/original/track.spc",
        metadataJSON: "{\"title\":\"   \",\"artist\":null,\"trackNumber\":7}",
        extensionsJSON: "{}"
    )
    let manifest = try UACManifestEditor.decode(edited)
    let member = try #require(manifest.members.first)
    #expect(member.metadata["title"] == nil)
    #expect(member.metadata["artist"] == nil)
    #expect(member.metadata["trackNumber"] == .integer(7))

    let removed = try UACManifestEditor.applyBatchMetadataEdit(
        in: edited,
        memberPaths: ["variants/original/track.spc"],
        key: "trackNumber",
        operation: .set,
        value: "   "
    )
    #expect(try UACManifestEditor.decode(removed).members.first?.metadata["trackNumber"] == nil)
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

@Test func packageWideRenamePreservesNamespacesAndUnknownFields() throws {
    let seeded = try UACManifestEditor.updateGameFields(
        in: Data(manifestJSON.utf8),
        title: "Fixture Game",
        console: "Nintendo SNES",
        metadataJSON: "{\"title\":\"Package title\"}",
        extensionsJSON: "{\"oldKey\":\"Package extension\"}"
    )
    let memberSeeded = try UACManifestEditor.updateMemberFields(
        in: seeded,
        memberPath: "variants/original/track.spc",
        metadataJSON: "{\"title\":\"Track title\"}",
        extensionsJSON: "{\"oldKey\":\"Track extension\"}"
    )

    let result = try UACManifestEditor.renameMetadataKey(
        in: memberSeeded,
        from: "extension.oldKey",
        to: "extension.newKey"
    )
    let manifest = try UACManifestEditor.decode(result.manifestJSON)

    #expect(result.affectedCount == 2)
    #expect(manifest.game.extensions["oldKey"] == nil)
    #expect(manifest.game.extensions["newKey"] == .string("Package extension"))
    #expect(manifest.members.first?.extensions["newKey"] == .string("Track extension"))
    #expect(String(decoding: result.manifestJSON, as: UTF8.self).contains("futureRootField"))
    #expect(String(decoding: result.manifestJSON, as: UTF8.self).contains("futureMemberField"))
}

@Test func selectedTrackTagAdditionIsAtomic() throws {
    let original = Data(manifestJSON.utf8)
    let result = try UACManifestEditor.addStringMetadataField(
        in: original,
        memberPaths: ["variants/original/track.spc"],
        key: "mood",
        value: "Dreamy"
    )
    let manifest = try UACManifestEditor.decode(result.manifestJSON)

    #expect(result.affectedCount == 1)
    #expect(manifest.members.first?.metadata["mood"] == .string("Dreamy"))
    #expect(throws: UACManifestEditorError.invalidMetadataJSON(
        "The tag already exists on one or more selected tracks: mood"
    )) {
        try UACManifestEditor.addStringMetadataField(
            in: result.manifestJSON,
            memberPaths: ["variants/original/track.spc"],
            key: "mood",
            value: "Different"
        )
    }
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
