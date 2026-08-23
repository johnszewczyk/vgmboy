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

@Test func materializesPSFDependencyBesideSelectedTrack() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArchiveMaterializerPSF-\(UUID().uuidString)")
    let source = root.appendingPathComponent("source", isDirectory: true)
    let archive = root.appendingPathComponent("library.tar")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let psf = Data("PSF\u{1}\n[TAG]\n_lib=re2.psflib\n[/TAG]\n".utf8)
    let library = Data("shared-library".utf8)
    try psf.write(to: source.appendingPathComponent("06 Prologue.psf"))
    try library.write(to: source.appendingPathComponent("re2.psflib"))

    let tar = Process()
    tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
    tar.arguments = ["-cf", archive.path, "-C", source.path, "."]
    try tar.run()
    tar.waitUntilExit()
    #expect(tar.terminationStatus == 0)

    let materializer = ArchiveMaterializer(configuration: .init(
        temporaryDirectoryName: "FrontendCoreTests",
        bsdtarCandidates: ["/usr/bin/bsdtar"],
        zstdCandidates: []
    ))
    let selected = try materializer.materialize(archivePath: archive.path, entry: "06 Prologue.psf")
    let dependency = selected.deletingLastPathComponent().appendingPathComponent("re2.psflib")
    #expect(FileManager.default.fileExists(atPath: selected.path))
    #expect(FileManager.default.fileExists(atPath: dependency.path))
    #expect(try Data(contentsOf: dependency) == library)
    materializer.release()
}
