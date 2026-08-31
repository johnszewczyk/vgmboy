import Foundation
import Testing
@testable import ArchiveMaterializationCore

@Test func detectsCocoaSpiceArchiveContainerKinds() {
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.zip")) == .zip)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.7z")) == .sevenZip)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.lha")) == .lha)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.rsn")) == .rsn)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.tar")) == .tar)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.tar.zst")) == .tarZstandard)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.tar.zstd")) == .tarZstandard)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.tzst")) == .tarZstandard)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "track.vgm.zst")) == .singleFileZstandard)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "track.flac.zstd")) == .singleFileZstandard)
    #expect(ArchiveContainerKind(archiveURL: URL(fileURLWithPath: "set.rar")) == nil)
}

@Test func preservesExactSelectedAndCompleteSetToolArguments() {
    let archiveURL = URL(fileURLWithPath: "/tmp/library.zip")
    let destinationURL = URL(fileURLWithPath: "/tmp/materialized")

    #expect(ArchiveToolRouting.selectedEntryToStdout(
        kind: .zip,
        archiveURL: archiveURL,
        entryPath: "music/track.spc"
    ) == .process(
        executableName: "7zz",
        arguments: ["x", "-mmt=1", "-so", "/tmp/library.zip", "music/track.spc"]
    ))
    #expect(ArchiveToolRouting.selectedEntryToStdout(
        kind: .lha,
        archiveURL: archiveURL,
        entryPath: "Xpose/mod.xpose-end"
    ) == .process(
        executableName: "7zz",
        arguments: ["x", "-mmt=1", "-so", "/tmp/library.zip", "Xpose/mod.xpose-end"]
    ))
    #expect(ArchiveToolRouting.completeSet(
        kind: .rsn,
        archiveURL: URL(fileURLWithPath: "/tmp/library.rsn"),
        destinationURL: destinationURL
    ) == .process(
        executableName: "unar",
        arguments: ["-q", "-f", "-D", "-o", "/tmp/materialized", "/tmp/library.rsn"]
    ))
    #expect(ArchiveToolRouting.selectedEntryToStdout(
        kind: .singleFileZstandard,
        archiveURL: URL(fileURLWithPath: "/tmp/track.vgm.zst"),
        entryPath: "track.vgm"
    ) == .process(
        executableName: "zstd",
        arguments: ["-d", "-q", "-c", "--", "/tmp/track.vgm.zst"]
    ))
}

@Test func preservesTarPipelineAndLiteralSelectionRules() {
    let invocation = ArchiveToolRouting.selectedEntries(
        kind: .tarZstandard,
        archiveURL: URL(fileURLWithPath: "/tmp/library.tar.zst"),
        entryPaths: ["music/[track]?.spc"],
        destinationURL: URL(fileURLWithPath: "/tmp/materialized")
    )
    #expect(invocation == .zstandardTar(
        zstdExecutableName: "zstd",
        zstdArguments: ["-d", "-q", "-c", "/tmp/library.tar.zst"],
        tarExecutableName: "tar",
        tarArguments: ["-xf", "-", "-C", "/tmp/materialized", "music/\\[track]\\?.spc"],
        allowEarlyConsumerExit: true
    ))
}
