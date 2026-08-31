import CatalogReader
import CatalogBrowserCore
import Testing

@Test func sidebarRowIntentIsRendererIndependent() {
    #expect(SidebarRowInteraction.intent(kind: .leaf, gesture: .primaryClick) == .preview)
    #expect(SidebarRowInteraction.intent(kind: .folder, gesture: .primaryClick) == .select)
    #expect(SidebarRowInteraction.intent(kind: .folder, gesture: .primaryClick, wasSelected: true) == .toggleExpansion)
    #expect(SidebarRowInteraction.intent(kind: .group, gesture: .activate) == .activate)
}

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

@Test func searchIndexReusesOnlyExtendingQueriesAndRestartsAfterBackspace() {
    var index = CatalogSearchIndex(searchValues: [
        "Actraiser SNES JoshW",
        "ActRaiser 2 SNES JoshW",
        "Chrono Trigger SNES JoshW"
    ])

    #expect(index.matchingIndices(query: "act") == [0, 1])
    #expect(index.matchingIndices(query: "act 2") == [1])
    #expect(index.matchingIndices(query: "chrono") == [2])
    #expect(index.matchingIndices(query: "") == [0, 1, 2])
}

@Test func fileTreeProjectionPreservesNativeFolderGraphAndRows() {
    let root = "/music/Library"
    let files = [
        CatalogFileBucket(rootID: 1, rootPath: root, folderPath: "\(root)/NES", path: "\(root)/NES/zelda.nsf", isArchive: true, trackCount: 2),
        CatalogFileBucket(rootID: 1, rootPath: root, folderPath: "\(root)/Neo Geo CD/KOF 96", path: "\(root)/Neo Geo CD/KOF 96/01.vgm", isArchive: false, trackCount: 1),
        CatalogFileBucket(rootID: 1, rootPath: root, folderPath: "\(root)/Neo Geo CD/KOF 96", path: "\(root)/Neo Geo CD/KOF 96/00.vgm", isArchive: false, trackCount: 1)
    ]
    let index = CatalogFileTreeIndex(files: files)
    let rootID = CatalogFileTreeIndex.folderID(rootID: 1, path: root)
    let consoleID = CatalogFileTreeIndex.folderID(rootID: 1, path: "\(root)/Neo Geo CD")
    let gameID = CatalogFileTreeIndex.folderID(rootID: 1, path: "\(root)/Neo Geo CD/KOF 96")

    #expect(index.allFolderIDs == [rootID, consoleID, gameID, CatalogFileTreeIndex.folderID(rootID: 1, path: "\(root)/NES")])
    #expect(index.rows(expandedFolderIDs: []).map { row in
        if case .folder(let id, _, _, _) = row { return id }
        return "file"
    } == [rootID])

    let rows = index.rows(expandedFolderIDs: [rootID, consoleID, gameID])
    #expect(rows.count == 6)
    if case .folder(_, let title, _, _) = rows[1] {
        #expect(title == "Neo Geo CD")
    } else {
        Issue.record("Expected Neo Geo CD folder row")
    }
    if case .file(let file, _) = rows[3] {
        #expect(file.path.hasSuffix("/00.vgm"))
    } else {
        Issue.record("Expected first KOF 96 file row")
    }

    let nodes = index.nodes()
    #expect(nodes.count == 1)
    #expect(nodes[0].folder?.folderPath == root)
    #expect(nodes[0].children.map(\.title) == ["Neo Geo CD", "NES"])
    #expect(nodes[0].children[0].children[0].children.last?.file?.path.hasSuffix("/01.vgm") == true)
}

@Test func fileSearchIndexSupportsCancellationAndSharedSearchFields() {
    let files = [
        CatalogFileBucket(rootID: 1, rootPath: "/music/Library", folderPath: "/music/Library/NES", path: "/music/Library/NES/ActRaiser.nsf", isArchive: true, trackCount: 1),
        CatalogFileBucket(rootID: 1, rootPath: "/music/Library", folderPath: "/music/Library/SNES", path: "/music/Library/SNES/Chrono.spc", isArchive: false, trackCount: 1)
    ]
    let index = CatalogFileSearchIndex(files: files)
    #expect(index.matchingFiles(query: "act nes") == [files[0]])
    #expect(index.matchingFiles(query: "", isCancelled: { false }) == files)
    #expect(index.matchingFiles(query: "act", isCancelled: { true }) == nil)
}

@Test func databaseGroupStateKeepsGroupClicksAwayFromGameActivation() {
    var state = CatalogBrowserGroupState(expandedGroupNames: ["SNES"])
    state = state.applying(.toggleGroup("SNES"))
    #expect(state.expandedGroupNames.isEmpty)
    #expect(state.selectedGroupName == "SNES")
    #expect(state.selectedGameID == nil)

    state = state.applying(.selectGame(groupName: "SNES", gameID: "game-1"))
    #expect(state.selectedGroupName == "SNES")
    #expect(state.selectedGameID == "game-1")
}
