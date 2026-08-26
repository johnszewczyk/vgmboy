import ArchiveCacheCore
import Foundation
import Testing

@Test
func reclaimsOnlyKnownAbandonedRoots() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheCoreTests-\(UUID().uuidString)", isDirectory: true)
    let lifecycle = ArchiveCacheLifecycle(cacheRootURL: root)
    try FileManager.default.createDirectory(at: lifecycle.disposableRootURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: root.appendingPathComponent("old-staging"), withIntermediateDirectories: true)
    try Data(repeating: 1, count: 4).write(to: lifecycle.disposableRootURL.appendingPathComponent("entry"))
    defer { try? FileManager.default.removeItem(at: root) }

    let recovery = lifecycle.reclaimAbandonedMaterialization()

    #expect(recovery.rootCount == 2)
    #expect(recovery.byteCount == 4)
    #expect(!FileManager.default.fileExists(atPath: lifecycle.disposableRootURL.path))
    #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("old-staging").path))
}

@Test
func preservesProtectedAndActiveRootsDuringPrune() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheCoreTests-\(UUID().uuidString)", isDirectory: true)
    let lifecycle = ArchiveCacheLifecycle(cacheRootURL: root)
    let protected = lifecycle.durableRootURL.appendingPathComponent("protected", isDirectory: true)
    let active = lifecycle.durableRootURL.appendingPathComponent("active", isDirectory: true)
    let old = lifecycle.durableRootURL.appendingPathComponent("old", isDirectory: true)
    try FileManager.default.createDirectory(at: protected, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: active, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 4).write(to: protected.appendingPathComponent("entry"))
    try Data(repeating: 2, count: 4).write(to: active.appendingPathComponent("entry"))
    try Data(repeating: 3, count: 4).write(to: old.appendingPathComponent("entry"))
    defer { try? FileManager.default.removeItem(at: root) }

    let fits = try lifecycle.pruneDurableMaterialization(
        maximumBytes: 8,
        preserving: protected,
        activePlaybackRoot: active
    )

    #expect(fits)
    #expect(FileManager.default.fileExists(atPath: protected.path))
    #expect(FileManager.default.fileExists(atPath: active.path))
    #expect(!FileManager.default.fileExists(atPath: old.path))
}

@Test
func reclaimsHiddenInterruptedDurableStaging() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ArchiveCacheCoreTests-\(UUID().uuidString)", isDirectory: true)
    let lifecycle = ArchiveCacheLifecycle(cacheRootURL: root)
    let staging = lifecycle.durableRootURL.appendingPathComponent(".set-interrupted", isDirectory: true)
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 3).write(to: staging.appendingPathComponent("partial"))
    defer { try? FileManager.default.removeItem(at: root) }

    let recovery = lifecycle.reclaimAbandonedMaterialization()

    #expect(recovery.rootCount == 1)
    #expect(recovery.byteCount == 3)
    #expect(!FileManager.default.fileExists(atPath: staging.path))
}
