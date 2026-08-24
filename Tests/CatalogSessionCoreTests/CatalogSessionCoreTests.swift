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
}
