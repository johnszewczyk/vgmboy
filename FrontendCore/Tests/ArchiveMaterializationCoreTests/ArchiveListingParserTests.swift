import Foundation
import Testing
@testable import ArchiveMaterializationCore

@Test func parsesSevenZipReportsAndRetainsScanSignature() throws {
    let data = Data("Path = music/track.spc\nSize = 12\n".utf8)

    let listing = try ArchiveListingParser.parseSevenZipReport(data)

    #expect(listing.entries == ["music/track.spc"])
    #expect(listing.scanSignature == "7zz-report:\nPath = music/track.spc\nSize = 12\n")
}

@Test func parsesTarListingsWithReversibleOctalNames() throws {
    var data = Data("music/".utf8)
    data.append(0xFF)
    data.append(contentsOf: Data(".spc\n".utf8))

    let listing = try ArchiveListingParser.parseTarListing(data)

    #expect(listing.entries == ["music/\\377.spc"])
}

@Test func parsesRSNJSONListingsThroughTheSharedParser() throws {
    let object: [String: Any] = [
        "lsarContents": [["XADFileName": "music/track.spc"]]
    ]
    let data = try JSONSerialization.data(withJSONObject: object)

    let listing = try ArchiveListingParser.parseRSNListing(data)

    #expect(listing.entries == ["music/track.spc"])
}

@Test func listingParserRejectsEntryCountAndOutputOverflow() {
    #expect(throws: ArchiveListingParserError.entryCountLimitExceeded) {
        try ArchiveListingParser.validate(
            entries: Array(repeating: "track.spc", count: ArchiveListingParser.maximumEntries + 1),
            scanSignature: nil
        )
    }
    #expect(throws: ArchiveListingParserError.outputLimitExceeded) {
        try ArchiveListingParser.parseTarListing(
            Data(repeating: 0x61, count: ArchiveListingParser.maximumOutputBytes + 1)
        )
    }
}
