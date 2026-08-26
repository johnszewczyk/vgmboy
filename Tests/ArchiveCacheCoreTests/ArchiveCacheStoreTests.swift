import ArchiveCacheCore
import Foundation
import Testing

@Test
func archiveIdentityIncludesPathSizeAndModificationDate() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
    let archive = root.appendingPathComponent("source.zip")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("one".utf8).write(to: archive)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = ArchiveCacheStore(cacheRootURL: root.appendingPathComponent("cache"))
    let policy = ArchiveCachePolicy(mode: .enabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)
    let first = store.archiveCacheURL(for: archive, policy: policy)
    try Data("two-two".utf8).write(to: archive)
    let second = store.archiveCacheURL(for: archive, policy: policy)

    #expect(first != second)
    #expect(first.deletingLastPathComponent() == store.lifecycle.durableRootURL)
}

@Test
func archiveStoreSelectsDisposableRootWhenCacheIsDisabled() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
    let archive = root.appendingPathComponent("source.zip")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("source".utf8).write(to: archive)
    defer { try? FileManager.default.removeItem(at: root) }

    let store = ArchiveCacheStore(cacheRootURL: root.appendingPathComponent("cache"))
    let policy = ArchiveCachePolicy(mode: .disabled, maximumBytes: ArchiveCachePolicy.defaultLimitBytes)

    #expect(store.archiveCacheURL(for: archive, policy: policy).deletingLastPathComponent() == store.lifecycle.disposableRootURL)
}
