import CryptoKit
import Foundation
import Testing
@testable import UACWrapperCore

@Test func defaultPayloadMatchesTheCurrentMeasuredBuilderProfile() {
    let payload = UACPayload(
        encoderVersion: "zstd-cli-test; uacman-known-size-frame-writer-v1",
        blake3: String(repeating: "a", count: 64)
    )
    #expect(payload.compressionProfile == "uac-zstd-seekable-level-3-frame-4194304-v1")
}

@Test func readsManifestWithoutInspectingCompressedPayload() throws {
    let fixture = try makeFixture(payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0xFF, 0x10, 0x20]))
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let container = try UACContainerReader.read(from: fixture.url)
    #expect(container.payloadOffset == UInt64(fixture.manifestData.count + UACContainerReader.skippableFrameHeaderByteCount + UACContainerReader.metadataFrameHeaderByteCount))
    #expect(container.payloadLength == 8)
    #expect(container.manifestEncoding == .json)
    #expect(container.manifestByteCount == fixture.manifestData.count)
    #expect(container.storedManifestByteCount == fixture.manifestData.count)
    #expect(container.manifestJSON == fixture.manifestData)
    #expect(container.manifest.game.title == "Fixture Game")
    #expect(container.manifest.members.first?.path == "variants/original/track.spc")
    #expect(container.manifest.game.metadata["publisher"] == .string("Example"))
    #expect(container.manifest.extensions["x-test"] == .object(["flag": .bool(true)]))
    #expect(container.manifest.transformations.first?.operation == "rename")
    #expect(container.manifest.transformations.first?.inputs.first?.sourcePath == "old/track.spc")
}

@Test func readsCompressedManifestThroughInjectedBoundedDecoder() throws {
    let manifestData = Data(validManifestJSON.utf8)
    let compressedFrame = Data([0x28, 0xB5, 0x2F, 0xFD, 0x01, 0x02])
    let fixture = try makeCompressedFixture(payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x00]), manifestData: manifestData, compressedFrame: compressedFrame)
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let decoder: UACManifestFrameDecoder = { bytes, expectedByteCount, maximumMemoryByteCount in
        #expect(bytes == compressedFrame)
        #expect(expectedByteCount == manifestData.count)
        #expect(maximumMemoryByteCount == UACContainerReader.maximumManifestDecoderMemoryByteCount)
        return manifestData
    }
    let container = try UACContainerReader.read(from: fixture.url, decompressManifestFrame: decoder)
    #expect(container.manifestEncoding == .zstandardJSON)
    #expect(container.manifestByteCount == manifestData.count)
    #expect(container.storedManifestByteCount == compressedFrame.count + UACContainerReader.compressedManifestExtensionByteCount)
    #expect(container.manifestJSON == manifestData)
    #expect(container.manifest.game.title == "Fixture Game")
}

@Test func compressedManifestRequiresAHostDecoderAndEnforcesDeclaredSize() throws {
    let manifestData = Data(validManifestJSON.utf8)
    let compressedFrame = Data([0x28, 0xB5, 0x2F, 0xFD, 0x01])
    let fixture = try makeCompressedFixture(payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x00]), manifestData: manifestData, compressedFrame: compressedFrame)
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(throws: UACContainerError.manifestDecoderRequired) {
        try UACContainerReader.read(from: fixture.url)
    }
    let wrongSizeDecoder: UACManifestFrameDecoder = { _, _, _ in Data() }
    #expect(throws: UACContainerError.manifestDecodedSizeMismatch) {
        try UACContainerReader.read(from: fixture.url, decompressManifestFrame: wrongSizeDecoder)
    }
}

@Test func rejectsCompressedManifestThatDoesNotSaveSpace() throws {
    let manifestData = Data(validManifestJSON.utf8)
    var oversizedFrame = Data([0x28, 0xB5, 0x2F, 0xFD])
    oversizedFrame.append(Data(repeating: 0, count: manifestData.count))
    let fixture = try makeCompressedFixture(
        payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x00]),
        manifestData: manifestData,
        compressedFrame: oversizedFrame
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let decoder: UACManifestFrameDecoder = { _, _, _ in
        Issue.record("Reader must reject the non-saving encoding before invoking its decoder.")
        return manifestData
    }
    #expect(throws: UACContainerError.invalidCompressedManifestFrame) {
        try UACContainerReader.read(from: fixture.url, decompressManifestFrame: decoder)
    }
}

@Test func copiesEmbeddedPayloadByteForByte() throws {
    let payload = Data([0x28, 0xB5, 0x2F, 0xFD, 0x00, 0x7F])
    let fixture = try makeFixture(payload: payload)
    defer {
        try? FileManager.default.removeItem(at: fixture.url)
        try? FileManager.default.removeItem(at: fixture.copyURL)
    }

    try UACContainerReader.copyPayload(from: fixture.url, to: fixture.copyURL)
    #expect(try Data(contentsOf: fixture.copyURL) == payload)
}

@Test func writerAddsManifestFrameWithoutChangingCompressedPayload() throws {
    let payloadURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-source-\(UUID().uuidString).tar.zst")
    let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-output-\(UUID().uuidString).uac")
    let payload = Data([0x28, 0xB5, 0x2F, 0xFD, 0xAA, 0xBB, 0xCC, 0xDD])
    try payload.write(to: payloadURL, options: .atomic)
    defer {
        try? FileManager.default.removeItem(at: payloadURL)
        try? FileManager.default.removeItem(at: destinationURL)
    }

    let manifest = try JSONDecoder().decode(UACManifest.self, from: Data(validManifestJSON.utf8))
    let manifestEncoder = JSONEncoder()
    manifestEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let encodedManifest = try manifestEncoder.encode(manifest)
    let compressedManifestFrame = Data([0x28, 0xB5, 0x2F, 0xFD, 0x01, 0x02])
    let compressManifestFrame: UACManifestFrameEncoder = { _ in compressedManifestFrame }
    let decompressManifestFrame: UACManifestFrameDecoder = { bytes, expectedByteCount, maximumMemoryByteCount in
        #expect(bytes == compressedManifestFrame)
        #expect(expectedByteCount == encodedManifest.count)
        #expect(maximumMemoryByteCount == UACContainerReader.maximumManifestDecoderMemoryByteCount)
        return encodedManifest
    }
    let written = try UACContainerWriter.write(
        manifest: manifest,
        compressedTarPayloadURL: payloadURL,
        to: destinationURL,
        compressManifestFrame: compressManifestFrame,
        decompressManifestFrame: decompressManifestFrame
    )
    let reopened = try UACContainerReader.read(from: destinationURL, decompressManifestFrame: decompressManifestFrame)
    let extractedPayloadURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-extracted-\(UUID().uuidString).tar.zst")
    defer { try? FileManager.default.removeItem(at: extractedPayloadURL) }
    try UACContainerReader.copyPayload(
        from: destinationURL,
        to: extractedPayloadURL,
        decompressManifestFrame: decompressManifestFrame
    )

    #expect(written.manifest == manifest)
    #expect(reopened.manifestSHA256 == written.manifestSHA256)
    #expect(reopened.manifestEncoding == .zstandardJSON)
    #expect(reopened.storedManifestByteCount < reopened.manifestByteCount)
    #expect(try Data(contentsOf: extractedPayloadURL) == payload)
}

@Test func rewriteManifestKeepsUnknownJSONAndCopiesEmbeddedPayloadByteForByte() throws {
    let payload = Data([0x28, 0xB5, 0x2F, 0xFD, 0x10, 0x20, 0x30, 0x40])
    let sourceManifest = validManifestJSON.replacingOccurrences(
        of: "\"extensions\": {\"x-test\": {\"flag\": true}}",
        with: "\"extensions\": {\"x-test\": {\"flag\": true}}, \"futureRootField\": {\"preserve\": [1, \"yes\"]}"
    )
    let source = try makeFixture(payload: payload, manifestData: Data(sourceManifest.utf8))
    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-edited-\(UUID().uuidString).uac")
    let originalPayloadURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-original-payload-\(UUID().uuidString).zst")
    let editedPayloadURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("uac-edited-payload-\(UUID().uuidString).zst")
    defer {
        try? FileManager.default.removeItem(at: source.url)
        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.removeItem(at: originalPayloadURL)
        try? FileManager.default.removeItem(at: editedPayloadURL)
    }

    let updatedManifest = Data(sourceManifest.replacingOccurrences(of: "Fixture Game", with: "Edited Fixture").utf8)
    let compressedFrame = Data([0x28, 0xB5, 0x2F, 0xFD, 0x11, 0x22])
    let compressor: UACManifestFrameEncoder = { _ in compressedFrame }
    let decoder: UACManifestFrameDecoder = { bytes, expectedByteCount, _ in
        #expect(bytes == compressedFrame)
        #expect(expectedByteCount == updatedManifest.count)
        return updatedManifest
    }

    let rewritten = try UACContainerWriter.rewriteManifest(
        manifestJSON: updatedManifest,
        in: source.url,
        to: destinationURL,
        compressManifestFrame: compressor,
        decompressManifestFrame: decoder
    )
    try UACContainerReader.copyPayload(from: source.url, to: originalPayloadURL)
    try UACContainerReader.copyPayload(from: destinationURL, to: editedPayloadURL, decompressManifestFrame: decoder)

    #expect(rewritten.manifest.game.title == "Edited Fixture")
    #expect(rewritten.manifestJSON == updatedManifest)
    #expect(String(decoding: rewritten.manifestJSON, as: UTF8.self).contains("futureRootField"))
    #expect(try Data(contentsOf: originalPayloadURL) == payload)
    #expect(try Data(contentsOf: editedPayloadURL) == payload)
}

@Test func writerFallsBackToRawManifestWhenCompressionWouldGrowIt() throws {
    let payloadURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-raw-source-\(UUID().uuidString).tar.zst")
    let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-raw-output-\(UUID().uuidString).uac")
    try Data([0x28, 0xB5, 0x2F, 0xFD, 0xAA]).write(to: payloadURL, options: .atomic)
    defer {
        try? FileManager.default.removeItem(at: payloadURL)
        try? FileManager.default.removeItem(at: destinationURL)
    }

    let manifest = try JSONDecoder().decode(UACManifest.self, from: Data(validManifestJSON.utf8))
    let compressor: UACManifestFrameEncoder = { manifestData in
        var output = Data([0x28, 0xB5, 0x2F, 0xFD])
        output.append(Data(repeating: 0, count: manifestData.count))
        return output
    }
    let decoder: UACManifestFrameDecoder = { _, _, _ in
        Issue.record("Raw fallback must not invoke the manifest decoder.")
        return Data()
    }
    let written = try UACContainerWriter.write(
        manifest: manifest,
        compressedTarPayloadURL: payloadURL,
        to: destinationURL,
        compressManifestFrame: compressor,
        decompressManifestFrame: decoder
    )

    #expect(written.manifestEncoding == .json)
    #expect(written.storedManifestByteCount == written.manifestByteCount)
}

@Test func readsSeekableTarIndexAndMapsMemberRangeToFrames() throws {
    let fixture = try makeFixture(
        payload: makeSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 2)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let container = try UACContainerReader.read(from: fixture.url)
    #expect(container.seekTable?.frames.count == 2)
    #expect(container.seekTable?.tarByteCount == 9)
    #expect(container.seekTable?.frames.map(\.compressedOffset) == [0, 5])
    #expect(container.seekTable?.frames.map(\.tarOffset) == [0, 4])
    #expect(container.seekTable?.frameIndexes(intersectingTarRange: 2..<6) == [0, 1])
    #expect(container.manifest.members.first?.tarDataOffset == 2)
}

@Test func readsSeekableMemberAcrossFramesWithoutExtracting() throws {
    let fixture = try makeFixture(
        payload: makeSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 2)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let decodeCounter = DecodeCounter()

    let memberFile = try UACSeekableMemberFile(url: fixture.url, memberPath: "variants/original/track.spc") { compressed, checksum in
        #expect(checksum == nil)
        decodeCounter.increment()
        guard let marker = compressed.last else { throw UACContainerError.invalidPayloadMagic }
        switch marker {
        case 1: return Data("ABCD".utf8)
        case 2: return Data("EFGHI".utf8)
        default: throw UACContainerError.invalidPayloadMagic
        }
    }

    #expect(try memberFile.read(at: 0, byteCount: 4) == Data("CDEF".utf8))
    #expect(try memberFile.read(at: 1, byteCount: 99) == Data("DEF".utf8))
    #expect(try memberFile.read(at: 4, byteCount: 1).isEmpty)
    #expect(decodeCounter.value == 2)
    #expect(throws: UACContainerError.invalidMemberReadRange) {
        try memberFile.read(at: 5, byteCount: 1)
    }
}

@Test func seekableMemberReaderRejectsMissingMemberAndInvalidCacheLimit() throws {
    let fixture = try makeFixture(
        payload: makeSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 2)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }
    let decoder: @Sendable (Data, UInt32?) throws -> Data = { _, _ in Data() }

    #expect(throws: UACContainerError.memberNotFound("missing.spc")) {
        try UACSeekableMemberFile(url: fixture.url, memberPath: "missing.spc", decompressFrame: decoder)
    }
    #expect(throws: UACContainerError.invalidSeekFrameCacheLimit) {
        try UACSeekableMemberFile(
            url: fixture.url,
            memberPath: "variants/original/track.spc",
            maximumCachedFrames: 0,
            decompressFrame: decoder
        )
    }
}

@Test func rejectsSeekableMemberOffsetOutsideTarStream() throws {
    let fixture = try makeFixture(
        payload: makeSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 7)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(throws: UACContainerError.memberSeekRangeOutOfBounds("variants/original/track.spc")) {
        try UACContainerReader.read(from: fixture.url)
    }
}

@Test func rejectsFramesAboveTheReaderMemoryBound() throws {
    let fixture = try makeFixture(
        payload: makeOversizedSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 0)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(throws: UACContainerError.invalidSeekTable("Frame 0 has an invalid size.")) {
        try UACContainerReader.read(from: fixture.url)
    }
}

@Test func rejectsMalformedSeekableFooter() throws {
    let fixture = try makeFixture(
        payload: makeSeekablePayload(),
        manifestData: seekableManifestJSON(tarDataOffset: 2)
    )
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let handle = try FileHandle(forWritingTo: fixture.url)
    let footerLastByteOffset = UInt64(fixture.manifestData.count
        + UACContainerReader.skippableFrameHeaderByteCount
        + UACContainerReader.metadataFrameHeaderByteCount
        + makeSeekablePayload().count - 1)
    try handle.seek(toOffset: footerLastByteOffset)
    try handle.write(contentsOf: Data([0]))
    try handle.close()

    #expect(throws: UACContainerError.invalidSeekTable("Missing Zstandard seekable footer.")) {
        try UACContainerReader.read(from: fixture.url)
    }
}

@Test func rejectsManifestChecksumMismatch() throws {
    let fixture = try makeFixture(payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x01, 0x02, 0x03, 0x04]))
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    let handle = try FileHandle(forWritingTo: fixture.url)
    try handle.seek(toOffset: UInt64(UACContainerReader.skippableFrameHeaderByteCount + 8))
    try handle.write(contentsOf: Data([0x7B]))
    try handle.close()

    #expect(throws: UACContainerError.manifestChecksumMismatch) {
        try UACContainerReader.read(from: fixture.url)
    }
}

@Test func rejectsTraversalAndVariantPathEscape() throws {
    let invalidManifest = validManifestJSON
        .replacingOccurrences(of: "variants/original/track.spc", with: "variants/original/../../escape.spc")
    let fixture = try makeFixture(payload: Data([0x28, 0xB5, 0x2F, 0xFD, 0x01, 0x02, 0x03, 0x04]), manifestData: Data(invalidManifest.utf8))
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(throws: UACContainerError.self) {
        try UACContainerReader.read(from: fixture.url)
    }
}

private struct Fixture {
    let url: URL
    let copyURL: URL
    let manifestData: Data
}

private final class DecodeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private func makeFixture(payload: Data, manifestData: Data = Data(validManifestJSON.utf8)) throws -> Fixture {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("uac-test-\(UUID().uuidString).uac")
    let copyURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-payload-\(UUID().uuidString).tar.zst")
    var metadataFrame = UACContainerReader.metadataMagic
    metadataFrame.append(contentsOf: littleEndian(UInt16(1)))
    metadataFrame.append(contentsOf: littleEndian(UInt16(0)))
    metadataFrame.append(contentsOf: SHA256.hash(data: manifestData))
    metadataFrame.append(manifestData)
    var fileData = Data(littleEndian(UACContainerReader.uacSkippableMagic))
    fileData.append(contentsOf: littleEndian(UInt32(metadataFrame.count)))
    fileData.append(metadataFrame)
    fileData.append(payload)
    try fileData.write(to: url, options: .atomic)
    return Fixture(url: url, copyURL: copyURL, manifestData: manifestData)
}

private func makeCompressedFixture(
    payload: Data,
    manifestData: Data,
    compressedFrame: Data
) throws -> Fixture {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("uac-compressed-test-\(UUID().uuidString).uac")
    let copyURL = FileManager.default.temporaryDirectory.appendingPathComponent("uac-compressed-payload-\(UUID().uuidString).tar.zst")
    var metadataFrame = UACContainerReader.metadataMagic
    metadataFrame.append(contentsOf: littleEndian(UInt16(1)))
    metadataFrame.append(contentsOf: littleEndian(UInt16(0)))
    metadataFrame.append(contentsOf: SHA256.hash(data: manifestData))
    metadataFrame.append(UACContainerReader.compressedManifestMagic)
    metadataFrame.append(contentsOf: littleEndian(UInt32(manifestData.count)))
    metadataFrame.append(compressedFrame)
    var fileData = Data(littleEndian(UACContainerReader.uacSkippableMagic))
    fileData.append(contentsOf: littleEndian(UInt32(metadataFrame.count)))
    fileData.append(metadataFrame)
    fileData.append(payload)
    try fileData.write(to: url, options: .atomic)
    return Fixture(url: url, copyURL: copyURL, manifestData: manifestData)
}

private func littleEndian<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    withUnsafeBytes(of: value.littleEndian, Array.init)
}

private func seekableManifestJSON(tarDataOffset: UInt64) -> Data {
    let json = validManifestJSON
        .replacingOccurrences(of: "\"format\": \"tar+zstd\"", with: "\"format\": \"tar+zstd-seekable\"")
        .replacingOccurrences(of: "\"uac-zstd-3-v1\"", with: "\"uac-zstd-seekable-3-v1\"")
        .replacingOccurrences(of: "\"byteSize\": 4,", with: "\"byteSize\": 4, \"tarDataOffset\": \(tarDataOffset),")
    return Data(json.utf8)
}

private func makeSeekablePayload() -> Data {
    var payload = Data()
    payload.append(contentsOf: [0x28, 0xB5, 0x2F, 0xFD, 0x01])
    payload.append(contentsOf: [0x28, 0xB5, 0x2F, 0xFD, 0x02])

    var seekTable = Data()
    seekTable.append(contentsOf: littleEndian(UInt32(5)))
    seekTable.append(contentsOf: littleEndian(UInt32(4)))
    seekTable.append(contentsOf: littleEndian(UInt32(5)))
    seekTable.append(contentsOf: littleEndian(UInt32(5)))
    seekTable.append(contentsOf: littleEndian(UInt32(2)))
    seekTable.append(0)
    seekTable.append(contentsOf: littleEndian(UACZstandardSeekTable.seekableFooterMagic))

    payload.append(contentsOf: littleEndian(UACZstandardSeekTable.skippableFrameMagic))
    payload.append(contentsOf: littleEndian(UInt32(seekTable.count)))
    payload.append(seekTable)
    return payload
}

private func makeOversizedSeekablePayload() -> Data {
    var payload = Data([0x28, 0xB5, 0x2F, 0xFD, 0x01])
    var seekTable = Data()
    seekTable.append(contentsOf: littleEndian(UInt32(5)))
    seekTable.append(contentsOf: littleEndian(UACZstandardSeekTable.maximumFrameTarByteCount + 1))
    seekTable.append(contentsOf: littleEndian(UInt32(1)))
    seekTable.append(0)
    seekTable.append(contentsOf: littleEndian(UACZstandardSeekTable.seekableFooterMagic))
    payload.append(contentsOf: littleEndian(UACZstandardSeekTable.skippableFrameMagic))
    payload.append(contentsOf: littleEndian(UInt32(seekTable.count)))
    payload.append(seekTable)
    return payload
}

private let validManifestJSON = """
{
  "manifestVersion": 1,
  "packageID": "fixture-game",
  "payload": {"format": "tar+zstd", "compressionProfile": "uac-zstd-3-v1", "encoderVersion": "zstd 1.5.7", "blake3": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},
  "game": {"id": "fixture-game", "title": "Fixture Game", "console": "Nintendo SNES", "canonicalIDs": ["1234"], "metadata": {"publisher": "Example"}, "extensions": {}},
  "variants": [{"id": "original", "label": "Original", "kind": "retail", "canonicalReleaseIDs": ["1234"], "metadata": {}, "extensions": {}}],
  "members": [{"path": "variants/original/track.spc", "originalName": "track.spc", "variantID": "original", "sourceIDs": ["source-a"], "role": "playable", "format": "spc", "byteSize": 4, "blake3": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "streamBlake3": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "metadata": {"track": 1}, "extensions": {}}],
  "sources": [{"id": "source-a", "collection": "Example source", "setName": "SNES", "sourceName": "Fixture package.zip", "sourceURL": "https://example.invalid/fixture", "packageBlake3": "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd", "observedAt": "2026-09-13T00:00:00Z", "metadata": {}, "extensions": {}}],
  "transformations": [{"id": "rename-track-1", "operation": "rename", "inputs": [{"sourceID": "source-a", "sourcePath": "old/track.spc", "blake3": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "streamBlake3": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}], "outputs": [{"memberPath": "variants/original/track.spc", "blake3": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}], "tool": "AudioMan", "toolVersion": "fixture-1", "appliedAt": "2026-09-13T00:00:01Z", "reason": "Apply canonical track naming", "details": {"reviewed": true}}],
  "extensions": {"x-test": {"flag": true}}
}
"""
