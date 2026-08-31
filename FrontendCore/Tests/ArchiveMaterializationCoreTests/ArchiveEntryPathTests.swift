import Testing
@testable import ArchiveMaterializationCore

@Test func normalizesArchiveSeparatorsAndEmptyComponents() {
    #expect(ArchiveEntryPath.normalized("/music\\disc//track.spc") == "music/disc/track.spc")
    #expect(ArchiveEntryPath.components("/music/./disc/track.spc") == ["music", "disc", "track.spc"])
}

@Test func preservesBSDTarOctalDisplayEscapes() {
    let path = "music\\255/track.spc"
    #expect(ArchiveEntryPath.normalized(path) == path)
    #expect(ArchiveEntryPath.components(path) == ["music\\255", "track.spc"])
}

@Test func rejectsTraversalAndKeepsSafeComponentsForDestinationPaths() {
    #expect(!ArchiveEntryPath.isSafe("music/../outside.spc"))
    #expect(ArchiveEntryPath.components("music/../outside.spc") == ["music", "outside.spc"])
    #expect(ArchiveEntryPath.isSafe("music/./track.spc"))
}
