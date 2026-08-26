import PlaylistIdentityCore
import Testing

@Test func playlistIdentityPreservesFileAndArchiveFormats() {
    #expect(
        PlaylistTrackIdentity.trackID(sourcePath: "/music/song.vgm", archiveEntry: nil, trackIndex: 0)
            == "pt1|f|15|/music/song.vgm|0"
    )
    #expect(
        PlaylistTrackIdentity.trackID(sourcePath: "/music/set.zip", archiveEntry: "disc/song.vgm", trackIndex: 2)
            == "pt1|a|14|/music/set.zip|13|disc/song.vgm|2"
    )
}
