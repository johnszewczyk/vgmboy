import Foundation
import Testing
import UACWrapperCore
@testable import UACManCore

@Test func collectionScanFindsNestedPackagesAndReportsUnreadableFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-collection-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let nested = root.appendingPathComponent("Console/Set", isDirectory: true)
    let hidden = root.appendingPathComponent(".hidden", isDirectory: true)
    let packageDirectory = root.appendingPathComponent("not-a-package.uac", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: packageDirectory, withIntermediateDirectories: true)
    try Data("good".utf8).write(to: root.appendingPathComponent("zeta.uac"))
    try Data("good".utf8).write(to: nested.appendingPathComponent("alpha.uac"))
    try Data("broken".utf8).write(to: root.appendingPathComponent("broken.uac"))
    try Data("ignored".utf8).write(to: hidden.appendingPathComponent("hidden.uac"))
    try Data("ignored".utf8).write(to: root.appendingPathComponent("notes.txt"))
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("alias.uac"),
        withDestinationURL: root.appendingPathComponent("zeta.uac")
    )

    let manifests = [
        "alpha.uac": makeManifest(title: "Alpha", memberRoles: ["playable", "track", "asset"]),
        "zeta.uac": makeManifest(title: "Zeta", memberRoles: ["playable"])
    ]
    let result = try UACCollectionScanner.scan(root: root) { url in
        guard let manifest = manifests[url.lastPathComponent] else {
            throw CollectionFixtureError.unreadable
        }
        return manifest
    }

    #expect(result.entries.map(\.relativePath) == ["Console/Set/alpha.uac", "zeta.uac"])
    #expect(result.entries.map(\.title) == ["Alpha", "Zeta"])
    #expect(result.entries[0].totalMemberCount == 3)
    #expect(result.entries[0].playableMemberCount == 2)
    #expect(result.entries.allSatisfy { $0.fileByteCount > 0 })
    #expect(result.issues.map(\.relativePath) == ["broken.uac"])
}

@Test func collectionScanRejectsNonDirectoryRoots() throws {
    let file = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-collection-file-\(UUID().uuidString).uac")
    try Data("fixture".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    #expect(throws: UACCollectionScannerError.rootIsNotDirectory) {
        try UACCollectionScanner.scan(root: file) { _ in
            throw CollectionFixtureError.unreadable
        }
    }
}

private enum CollectionFixtureError: Error {
    case unreadable
}

private func makeManifest(title: String, memberRoles: [String]) -> UACManifest {
    UACManifest(
        packageID: title.lowercased(),
        payload: UACPayload(encoderVersion: "test", blake3: String(repeating: "a", count: 64)),
        game: UACGame(id: title.lowercased(), title: title, console: "Test System"),
        variants: [],
        members: memberRoles.enumerated().map { index, role in
            UACMember(
                path: "track-\(index).bin",
                originalName: "track-\(index).bin",
                role: role,
                byteSize: 1,
                blake3: String(repeating: "b", count: 64)
            )
        }
    )
}
