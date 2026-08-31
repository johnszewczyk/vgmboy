import Testing
@testable import FavoriteTrackCore

@Test
func favoriteHistoryAndGroupToggleAreStable() {
    let first = FavoriteTrackIdentity(sourcePath: "/music/album.spc", trackIndex: 0, trackCount: 2)
    let second = FavoriteTrackIdentity(sourcePath: "/music/album.spc", trackIndex: 1, trackCount: 2)
    let third = FavoriteTrackIdentity(sourcePath: "/music/other.spc")
    var favorites = FavoriteTrackCollection()

    let addedGroup = favorites.toggleGroup([first, second])
    #expect(addedGroup)
    #expect(favorites.entries == [first, second])
    let addedThird = favorites.toggle(third)
    #expect(addedThird)
    #expect(favorites.entries == [first, second, third])
    let removedGroup = favorites.toggleGroup([first, second])
    #expect(!removedGroup)
    #expect(favorites.entries == [third])
}
