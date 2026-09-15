import Foundation
import Testing
import UACContainerCore
@testable import UACManCore

@Test func realSPCContainerCanBeHarvestedAndManifestRewrittenWithoutTouchingPayload() throws {
    guard let packagePath = ProcessInfo.processInfo.environment["UACMAN_REAL_SPC_PACKAGE"] else {
        return
    }
    let sourceURL = URL(fileURLWithPath: packagePath).standardizedFileURL
    let manifestDecoder: UACManifestFrameDecoder = { frame, expected, maximumMemory in
        try runZstandard(
            frame,
            arguments: ["-q", "-d", "-c", "--memory=\(max(1, maximumMemory / (1024 * 1024)))MB"],
            maximumOutput: expected,
            exactOutput: expected
        )
    }
    let frameDecoder: @Sendable (Data, UInt32?) throws -> Data = { frame, checksum in
        let decoded = try runZstandard(
            frame,
            arguments: ["-q", "-d", "-c", "--memory=64MB"],
            maximumOutput: Int(UACZstandardSeekTable.maximumFrameTarByteCount),
            exactOutput: nil
        )
        if let checksum, !UACSeekableFrameChecksum.matches(decoded, checksum: checksum) {
            throw IntegrationError.seekTableChecksumMismatch
        }
        return decoded
    }
    let original = try UACContainerReader.read(from: sourceURL, decompressManifestFrame: manifestDecoder)
    let spcPaths = original.manifest.members.compactMap { member -> String? in
        guard member.format?.lowercased() == "spc"
                || URL(fileURLWithPath: member.originalName).pathExtension.lowercased() == "spc" else { return nil }
        return member.path
    }
    #expect(original.seekTable != nil)
    #expect(spcPaths.count > 0)

    let harvested = try SPCMetadataHarvester.harvest(
        packageURL: sourceURL,
        memberPaths: spcPaths,
        decompressManifestFrame: manifestDecoder,
        decompressFrame: frameDecoder
    )
    #expect(harvested.items.count == spcPaths.count)
    #expect(harvested.failures.isEmpty)
    #expect(harvested.diagnosticCount == 0)
    #expect(harvested.items.allSatisfy { $0.projection.memberFields["title"] != nil })
    #expect(harvested.items.allSatisfy { $0.projection.memberFields["nativeMetadata"] != nil })

    let merged = try SPCMetadataProjector.merge(items: harvested.items, into: original.manifestJSON)
    let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("uacman-real-spc-rewrite-\(UUID().uuidString).uac")
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    let rewritten = try UACContainerWriter.rewriteManifest(
        manifestJSON: merged.manifestJSON,
        in: sourceURL,
        to: temporaryURL,
        compressManifestFrame: { data in
            try runZstandard(data, arguments: ["-q", "-c", "-3"], maximumOutput: data.count + 64 * 1024, exactOutput: nil)
        },
        decompressManifestFrame: manifestDecoder
    )
    let reopened = try UACContainerReader.read(from: temporaryURL, decompressManifestFrame: manifestDecoder)
    #expect(rewritten.manifestJSON == merged.manifestJSON)
    #expect(reopened.manifest.members.filter { $0.metadata["nativeMetadata"] != nil }.count == spcPaths.count)
    #expect(try readPayload(url: sourceURL, offset: original.payloadOffset, length: original.payloadLength)
        == readPayload(url: temporaryURL, offset: reopened.payloadOffset, length: reopened.payloadLength))
}

private func runZstandard(
    _ input: Data,
    arguments: [String],
    maximumOutput: Int,
    exactOutput: Int?
) throws -> Data {
    let executable = URL(fileURLWithPath: "/opt/homebrew/bin/zstd")
    guard FileManager.default.isExecutableFile(atPath: executable.path) else {
        throw IntegrationError.zstandardNotFound
    }
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("uacman-real-spc-codec-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let inputURL = directory.appendingPathComponent("frame.zst")
    try input.write(to: inputURL)

    let process = Process()
    let outputPipe = Pipe()
    process.executableURL = executable
    process.arguments = arguments + ["--", inputURL.path]
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw IntegrationError.zstandardFailed(process.terminationStatus)
    }
    guard output.count <= maximumOutput,
          exactOutput == nil || output.count == exactOutput else {
        throw IntegrationError.invalidOutputSize
    }
    return output
}

private func readPayload(url: URL, offset: UInt64, length: UInt64) throws -> Data {
    guard length <= UInt64(Int.max) else { throw IntegrationError.invalidOutputSize }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: offset)
    guard let payload = try handle.read(upToCount: Int(length)), payload.count == Int(length) else {
        throw IntegrationError.invalidOutputSize
    }
    return payload
}

private enum IntegrationError: Error {
    case zstandardNotFound
    case zstandardFailed(Int32)
    case invalidOutputSize
    case seekTableChecksumMismatch
}
