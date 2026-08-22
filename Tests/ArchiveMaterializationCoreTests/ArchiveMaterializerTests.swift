import Foundation
import Testing
@testable import ArchiveMaterializationCore

@Test func rejectsMissingSourceBeforeCreatingTemporaryFiles() {
    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: [],
        zstdCandidates: []
    ))

    #expect(throws: ArchiveMaterializationError.missingSource("/private/tmp/no-such-archive")) {
        try materializer.materialize(archivePath: "/private/tmp/no-such-archive", entry: "track.spc")
    }
}

@Test func rejectsEmptyEntry() {
    let source = FileManager.default.temporaryDirectory.appendingPathComponent("archive-placeholder")
    FileManager.default.createFile(atPath: source.path, contents: Data())
    defer { try? FileManager.default.removeItem(at: source) }

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: [],
        zstdCandidates: []
    ))
    #expect(throws: ArchiveMaterializationError.invalidEntry) {
        try materializer.materialize(archivePath: source.path, entry: "")
    }
}
