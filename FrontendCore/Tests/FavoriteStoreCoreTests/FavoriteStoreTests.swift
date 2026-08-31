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
    let first = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/a.spc"), title: "A")
    let second = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/b.spc"), title: "B")

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
    let first = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/a.spc"), title: "A")
    let second = FavoriteTrackSnapshot(identity: FavoriteTrackIdentity(sourcePath: "/music/b.spc"), title: "B")

    #expect(try store.importLegacy([first, second, first]) == 1)
    #expect(try store.importLegacy([first, second]) == 1)
    let refreshedSecond = FavoriteTrackSnapshot(identity: second.identity, title: "Updated B")
    #expect(try store.importLegacy([refreshedSecond]) == 2)
    _ = try store.toggle([first])
    #expect(try store.snapshots() == [refreshedSecond])
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
    #expect(Set(try store.snapshots().map(\.identity)) == Set([first.identity, second.identity]))
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
