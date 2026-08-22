import CatalogReader
import CatalogBrowserCore
import Testing

@Test func searchTemporarilyUsesCatalogConsoleView() {
    var state = CatalogBrowserState(mode: .paths)
    #expect(state.view == .paths)
    #expect(state.contentMode == .tree)

    state.setQuery("  sonic  ")
    #expect(state.view == .search)
    #expect(state.contentMode == .database)
    #expect(state.resultSource == .catalogConsoleIndex)

    state.setQuery("")
    #expect(state.view == .paths)
}

@Test func gameProjectionUsesStableIdentityAndSharedDisambiguation() {
    let buckets = [
        CatalogGameBucket(rootID: 2, rootPath: "/music/B", game: "Sonic 2", system: "Mega Drive", trackCount: 1),
        CatalogGameBucket(rootID: 1, rootPath: "/music/A", game: "Sonic 2", system: "Mega Drive", trackCount: 2),
        CatalogGameBucket(rootID: 1, rootPath: "/music/A", game: "Sonic 10", system: "Mega Drive", trackCount: 1)
    ]
    let games = CatalogBrowserProjection.games(from: buckets)

    #expect(games.map(\.name) == ["Sonic 2", "Sonic 2", "Sonic 10"])
    #expect(games[0].displayName == "Sonic 2 (Mega Drive • A)")
    #expect(games[0].id != games[1].id)
}
