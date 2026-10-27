import FavoriteStoreCore
import FavoriteTrackCore
import Foundation
import Testing

private func temporaryStore() throws -> FavoriteStore {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    return try FavoriteStore(databaseURL: directory.appendingPathComponent("UserData.sqlite"))
}

@Test
func storePreservesOrderAndPersistsAcrossInstances() throws {
    let store = try temporaryStore()
    let first = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/a.spc"), title: "A", addedAtMilliseconds: 1_000)
    let second = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/b.spc"), title: "B", addedAtMilliseconds: 2_000)

    let mutation = try store.toggle([first, second])
    #expect(mutation.added)
    #expect(mutation.revision == 1)
    #expect(try FavoriteStore(databaseURL: store.databaseURL).snapshots() == [first, second])

    let removal = try store.toggle([first])
    #expect(!removal.added)
    #expect(try store.snapshots() == [second])

    _ = try store.toggle([first])
    #expect(try store.snapshots() == [second, first])
}

@Test
func legacyImportIsIdempotentAndDoesNotRestoreRemovedEntries() throws {
    let store = try temporaryStore()
    let first = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/a.spc"), title: "A", addedAtMilliseconds: 1_000)
    let second = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/b.spc"), title: "B", addedAtMilliseconds: 2_000)

    #expect(try store.importLegacy([first, second, first]) == 1)
    #expect(try store.importLegacy([first, second]) == 1)
    let refreshedSecond = FavoriteTrackSnapshot(identity: second.identity, title: "Updated B", addedAtMilliseconds: 3_000)
    #expect(try store.importLegacy([refreshedSecond]) == 2)
    _ = try store.toggle([first])
    let persistedSecond = FavoriteTrackSnapshot(identity: second.identity, title: "Updated B", addedAtMilliseconds: 2_000)
    #expect(try store.snapshots() == [persistedSecond])
}

@Test
func twoStoreInstancesSerializeGroupMutations() async throws {
    let store = try temporaryStore()
    let other = try FavoriteStore(databaseURL: store.databaseURL)
    let first = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/a.spc"))
    let second = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/b.spc"))

    async let firstMutation = Task.detached { try store.toggle([first]) }.value
    async let secondMutation = Task.detached { try other.toggle([second]) }.value
    _ = try await (firstMutation, secondMutation)
    let saved = try store.snapshots()
    #expect(Set(saved.map(\.identity)) == Set([first.identity, second.identity]))
    #expect(saved.allSatisfy { ($0.addedAtMilliseconds ?? 0) > 0 })
    #expect(try store.revision() == 2)
}

@Test
func favoritePresentationIsPathFreeAndSortingDoesNotMutateHistory() {
    let zelda = FavoriteTrackSnapshot(
        identity: FavoriteTrackIdentity(sourcePath: "/music/Zelda/02 - Cave.spc"),
        filename: "02 - Cave.spc",
        title: "Cave",
        game: "Zelda"
    )
    let actRaiser = FavoriteTrackSnapshot(
        identity: FavoriteTrackIdentity(sourcePath: "/music/ActRaiser/01 Opening.spc"),
        filename: "01 Opening.spc",
        title: "Opening",
        game: "ActRaiser"
    )

    #expect(FavoriteListPresentation.displayName(for: zelda) == "Zelda-02-Cave")
    #expect(FavoriteListPresentation.ordered([zelda, actRaiser], by: .historical) == [zelda, actRaiser])
    #expect(FavoriteListPresentation.ordered([zelda, actRaiser], by: .alphabetical) == [actRaiser, zelda])
}
