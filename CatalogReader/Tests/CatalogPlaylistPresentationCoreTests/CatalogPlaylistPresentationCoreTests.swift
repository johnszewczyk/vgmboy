import CatalogPlaylistCore
import CatalogPlaylistPresentationCore
import CatalogReader
import Foundation
import Testing

@Test func presentationProjectionUsesPlayableLeafAndVisibleFallbacks() {
    let archiveTrack = CatalogPlaylistTrack(
        sourcePath: "/music/Library/Game.zip",
        archivePath: "/music/Library/Game.zip",
        archiveEntry: "sound/Track 10.spc",
        trackIndex: 1,
        trackCount: 2,
        title: "",
        game: "",
        author: "",
        system: "",
        comment: "",
        introLengthMilliseconds: 0,
        loopLengthMilliseconds: 0,
        lengthMilliseconds: 120_000,
        fadeLengthMilliseconds: 0
    )
    let titledTrack = CatalogPlaylistTrack(
        sourcePath: "/music/Library/Theme.spc",
        archivePath: nil,
        archiveEntry: nil,
        trackIndex: 0,
        trackCount: 1,
        title: "A deliberately longer catalog title",
        game: "Game 11",
        author: "Composer",
        system: "Console",
        comment: "",
        introLengthMilliseconds: 0,
        loopLengthMilliseconds: 0,
        lengthMilliseconds: 5_000,
        fadeLengthMilliseconds: 0
    )

    let projection = CatalogPlaylistPresentation.project(tracks: [archiveTrack, titledTrack])
    let archiveDisplay = projection.rows[0].display
    #expect(archiveDisplay.sourceFilename == "Track 10.spc")
    #expect(archiveDisplay.fileText == "Track 10.spc [2]")
    #expect(archiveDisplay.displayName == "Track 10 [2]")
    #expect(archiveDisplay.titleText == "Track 10 [2]")
    #expect(archiveDisplay.gameText == "Game.zip")
    #expect(archiveDisplay.authorText == "—")
    #expect(archiveDisplay.systemText == "—")
    #expect(archiveDisplay.lengthText == "2:00")
    #expect(projection.columnContentHints.indexText == "2")
    #expect(projection.columnContentHints.titleText == "A deliberately longer catalog title")
    #expect(projection.columnContentHints.fileText == "Track 10.spc [2]")
}

@Test func readerTracksUseTheSameProjectionAndKeepTheirCatalogID() {
    let track = CatalogTrack(
        id: 42,
        rootID: 9,
        sourcePath: "/music/Library/Theme.spc",
        archivePath: nil,
        archiveEntry: nil,
        trackIndex: 0,
        trackCount: 1,
        title: "Theme",
        game: "Game",
        author: "Composer",
        system: "SNES",
        comment: "",
        browserGame: "Game",
        browserSystem: "SNES",
        introLengthMilliseconds: 0,
        loopLengthMilliseconds: 0,
        lengthMilliseconds: 30_000,
        fadeLengthMilliseconds: 0
    )

    let row = CatalogPlaylistPresentation.project(tracks: [track]).rows[0]
    #expect(row.metadataTrackID == 42)
    #expect(row.rootID == 9)
    #expect(row.display.fileText == "Theme.spc")
    #expect(row.display.titleText == "Theme")
    #expect(row.display.lengthText == "0:30")
}

@Test func explicitPlaylistSortUsesNaturalTextAndNaturalOrderTies() {
    let records = [
        CatalogPlaylistSortRecord(
            id: "track-10",
            naturalOrder: 2,
            fileText: "Track 10.spc",
            titleText: "Theme",
            gameText: "Game",
            authorText: "Composer",
            systemText: "SNES",
            pathText: "/Library/Track 10.spc",
            lengthMilliseconds: 20_000
        ),
        CatalogPlaylistSortRecord(
            id: "track-2",
            naturalOrder: 1,
            fileText: "Track 2.spc",
            titleText: "Theme",
            gameText: "Game",
            authorText: "Composer",
            systemText: "SNES",
            pathText: "/Library/Track 2.spc",
            lengthMilliseconds: 10_000
        ),
        CatalogPlaylistSortRecord(
            id: "track-1",
            naturalOrder: 0,
            fileText: "Track 1.spc",
            titleText: "Theme",
            gameText: "Game",
            authorText: "Composer",
            systemText: "SNES",
            pathText: "/Library/Track 1.spc",
            lengthMilliseconds: 10_000
        )
    ]

    #expect(CatalogPlaylistSortColumn(frontendColumn: "filename") == .file)
    #expect(CatalogPlaylistSortColumn(frontendColumn: "artist") == .author)
    #expect(CatalogPlaylistSortColumn(frontendColumn: "lengthLabel") == .length)
    #expect(
        CatalogPlaylistSorting.orderedIDs(
            records: records,
            column: .file,
            direction: .ascending
        ) == ["track-1", "track-2", "track-10"]
    )
    #expect(
        CatalogPlaylistSorting.orderedIDs(
            records: records,
            column: .length,
            direction: .ascending
        ) == ["track-1", "track-2", "track-10"]
    )
    #expect(
        CatalogPlaylistSorting.orderedIDs(
            records: records,
            column: .index,
            direction: .descending
        ) == ["track-10", "track-2", "track-1"]
    )
}

@Test func nonCatalogSortRequestRetainsFrontendColumnAliases() throws {
    let request = CatalogPlaylistSortRequest(
        records: [
            .init(
                id: "track",
                naturalOrder: 0,
                fileText: "Track 2",
                titleText: "",
                gameText: "",
                authorText: "",
                systemText: "",
                pathText: "/music/Track 2.spc",
                lengthMilliseconds: 0
            )
        ],
        frontendColumn: "filename",
        direction: .descending
    )
    let decoded = try JSONDecoder().decode(
        CatalogPlaylistSortRequest.self,
        from: JSONEncoder().encode(request)
    )

    #expect(decoded == request)
    #expect(decoded.column == CatalogPlaylistSortColumn.file)
}

@Test func trackNumberSortUsesTaggedValuesAndLeavesUntaggedRowsBlank() {
    let records = [
        CatalogPlaylistSortRecord(
            id: "untagged", naturalOrder: 0, fileText: "untagged.xa", titleText: "",
            gameText: "", authorText: "", systemText: "", pathText: "", lengthMilliseconds: 0
        ),
        CatalogPlaylistSortRecord(
            id: "track-12", naturalOrder: 1, fileText: "song.xa", titleText: "",
            gameText: "", authorText: "", systemText: "", pathText: "", lengthMilliseconds: 0, trackNumber: 12
        ),
        CatalogPlaylistSortRecord(
            id: "track-2", naturalOrder: 2, fileText: "song.xa", titleText: "",
            gameText: "", authorText: "", systemText: "", pathText: "", lengthMilliseconds: 0, trackNumber: 2
        )
    ]

    #expect(CatalogPlaylistSortColumn(frontendColumn: "trackNumber") == .trackNumber)
    #expect(CatalogPlaylistSorting.orderedIDs(records: records, column: .trackNumber, direction: .ascending) == ["track-2", "track-12", "untagged"])
    #expect(CatalogPlaylistSorting.orderedIDs(records: records, column: .trackNumber, direction: .descending) == ["track-12", "track-2", "untagged"])
}
