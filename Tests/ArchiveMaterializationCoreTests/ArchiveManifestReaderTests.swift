import Foundation
import Testing
@testable import ArchiveMaterializationCore

@Test func manifestReaderUsesTemporaryMemberPathAndCleansItAfterRead() throws {
    var capturedRoot: URL?
    let data = try ArchiveManifestReader().read(entryPath: "playlists/queue.m3u") { rootURL, memberURL in
        capturedRoot = rootURL
        #expect(memberURL.path.hasSuffix("/playlists/queue.m3u"))
        try Data("#EXTM3U\ntrack.spc\n".utf8).write(to: memberURL)
    }

    #expect(String(data: data, encoding: .utf8) == "#EXTM3U\ntrack.spc\n")
    #expect(capturedRoot != nil)
    #expect(!FileManager.default.fileExists(atPath: capturedRoot!.path))
}
