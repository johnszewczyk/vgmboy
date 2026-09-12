import Foundation
import Testing
@testable import LocalFileBrowserCore

@Test func listsFoldersBeforePlayableFilesAndSkipsHiddenEntries() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("LocalFileBrowserCore-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: root.appendingPathComponent("10 Folder"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("2 Folder"), withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: root.appendingPathComponent("track10.spc").path, contents: Data())
    FileManager.default.createFile(atPath: root.appendingPathComponent("track2.spc").path, contents: Data())
    FileManager.default.createFile(atPath: root.appendingPathComponent("ignored.txt").path, contents: Data())
    FileManager.default.createFile(atPath: root.appendingPathComponent(".hidden.spc").path, contents: Data())

    let session = try LocalFileBrowserSession(rootURL: root) { $0.pathExtension.lowercased() == "spc" }
    let children = try session.children(of: root)

    #expect(children.map(\.name) == ["2 Folder", "10 Folder", "track2.spc", "track10.spc"])
    #expect(children.allSatisfy { !$0.name.hasPrefix(".") })
}

@Test func resolvesFilesToTheirContainingFolderAndRejectsOutsidePaths() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("LocalFileBrowserCore-\(UUID().uuidString)")
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    let track = nested.appendingPathComponent("track.spc")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: track.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: root) }

    let session = try LocalFileBrowserSession(rootURL: root) { _ in true }
    let target = try session.target(for: track)
    #expect(target.rootPath == root.standardizedFileURL.path)
    #expect(target.selectedPath == nested.standardizedFileURL.path)

    let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString)")
    FileManager.default.createFile(atPath: outside.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: outside) }
    #expect(throws: LocalFileBrowserError.pathOutsideRoot(outside.standardizedFileURL.path)) {
        try session.resolve(path: outside.path)
    }
}
