import CatalogSessionCore
import Testing

@MainActor
struct CatalogSessionCoreTests {
    @Test
    func latestTaskOwnerInvalidatesPreviousGenerations() {
        let owner = LatestTaskOwner()
        let firstGeneration = owner.begin()

        #expect(owner.isActive)
        #expect(owner.isCurrent(firstGeneration))

        let secondGeneration = owner.begin()
        #expect(owner.isActive)
        #expect(!owner.isCurrent(firstGeneration))
        #expect(owner.isCurrent(secondGeneration))

        owner.finish(generation: firstGeneration)
        #expect(owner.isActive)
        #expect(owner.isCurrent(secondGeneration))

        owner.cancel()
        #expect(!owner.isActive)
        #expect(!owner.isCurrent(secondGeneration))
    }

    @Test
    func latestTaskOwnerCompletionInvalidatesGeneration() {
        let owner = LatestTaskOwner()
        let generation = owner.begin()

        owner.finish(generation: generation)

        #expect(!owner.isActive)
        #expect(!owner.isCurrent(generation))
    }

    @Test
    func coordinatorKeepsCatalogScopesIndependent() {
        let coordinator = CatalogSessionCoordinator()
        let gameGeneration = coordinator.begin(.games)
        let playlistGeneration = coordinator.begin(.playlist)

        #expect(coordinator.isCurrent(gameGeneration, for: .games))
        #expect(coordinator.isCurrent(playlistGeneration, for: .playlist))

        let newerPlaylistGeneration = coordinator.begin(.playlist)
        #expect(coordinator.isCurrent(gameGeneration, for: .games))
        #expect(!coordinator.isCurrent(playlistGeneration, for: .playlist))
        #expect(coordinator.isCurrent(newerPlaylistGeneration, for: .playlist))
    }

    @Test
    func scopeMapsOnlyDatabaseReadMethods() {
        #expect(CatalogSessionScope.scope(for: "databaseGames") == .games)
        #expect(CatalogSessionScope.scope(for: "databaseGameTracks") == .playlist)
        #expect(CatalogSessionScope.scope(for: "databaseSearchGames") == .search)
        #expect(CatalogSessionScope.scope(for: "playbackQueueTransition") == nil)
    }
}
