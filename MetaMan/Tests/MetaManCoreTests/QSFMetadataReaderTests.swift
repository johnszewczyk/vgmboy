import Foundation
import Testing
import zlib
@testable import MetaManCore

@Test("QSF reader preserves root tags, validates ordered libraries, and projects legacy fields")
func qsfReaderProjectsMetadataAndRetainsSourceFacts() throws {
    let root = try makeQSFContainer(
        tags: "_lib=shared.qsflib\n_lib2=extra.qsflib\nTITLE=First title\ntitle=Last title\ngame=QSF game\nartist=Composer\ncomment=Root note\nlength=1:23.500\nfade=0:02.250\nunknown=one\nunknown=two\n",
        program: makeQSFBlock(0x5A, offset: 4, payload: [0x01, 0x02, 0x03])
            + makeQSFBlock(0x53, offset: 128, payload: [0x04, 0x05])
    )
    let shared = try makeQSFContainer(
        tags: "game=Ignored library game\n_lib=not-recursively-loaded.qsflib\n",
        program: makeQSFBlock(0x53, offset: 12, payload: [0x10]),
        version: 0x22
    )
    let extra = try makeQSFContainer(
        tags: "artist=Ignored composer\n",
        program: makeQSFBlock(0x5A, offset: 0, payload: [0x20])
    )
    let context = MetadataReadContext(companionFiles: [
        MetadataCompanionFile(relativePath: "shared.qsflib", data: shared),
        MetadataCompanionFile(relativePath: "extra.qsflib", data: extra)
    ])

    let result = try MetaManCore.readResult(
        data: root,
        formatHint: "miniqsf",
        displayName: "folder/track.miniqsf",
        context: context
    )
    let document = try #require(result.tracks.first?.document)

    #expect(result.tracks.count == 1)
    #expect(document.format == "qsf")
    #expect(document.fields.title == "Last title")
    #expect(document.fields.game == "QSF game")
    #expect(document.fields.system == "Capcom QSound")
    #expect(document.fields.artist == "Composer")
    #expect(document.fields.comment == "Root note")
    #expect(document.values(forTag: "title") == ["First title", "Last title"])
    #expect(document.values(forTag: "unknown") == ["one", "two"])
    #expect(document.values(forTag: "_lib") == ["shared.qsflib"])
    #expect(document.timing == MetadataTiming(
        introLengthMs: 0,
        loopLengthMs: 0,
        playLengthMs: 83_500,
        fadeLengthMs: 2_250
    ))
    #expect(document.rawTagBlock?.starts(with: Data("[TAG]".utf8)) == true)
    #expect(document.rawMetadataBlocks?["psfHeader[1]/shared.qsflib"]?.count == 16)
    #expect(document.rawMetadataBlocks?["psfTags[0]/track.miniqsf"]?.starts(with: Data("[TAG]".utf8)) == true)
    #expect(document.technicalFacts["sourceFileCount"] == "3")
    #expect(document.technicalFacts["dependencyFileCount"] == "2")
    #expect(document.technicalFacts["source[0].qsfBlockCount"] == "2")
    #expect(document.technicalFacts["source[0].block[0].kind"] == "0x5A")
    #expect(document.technicalFacts["source[0].block[0].offset"] == "4")
    #expect(document.technicalFacts["source[0].block[1].bytes"] == "2")
    #expect(document.diagnostics.isEmpty)

    let sniffed = try MetaManCore.read(data: root, displayName: "folder/track.miniqsf", context: context)
    #expect(sniffed == document)
}

@Test("QSF file API loads only declared sibling QSFLib files")
func qsfFileReadLoadsBoundedSiblingLibrariesOnly() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-QSF-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let libraryDirectory = directory.appendingPathComponent("libraries", isDirectory: true)
    try FileManager.default.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
    try makeQSFContainer(
        tags: "game=Library game\n_lib=absent.qsflib\n",
        program: makeQSFBlock(0x53, offset: 0, payload: [0xAA])
    ).write(to: libraryDirectory.appendingPathComponent("shared.qsflib"))
    let rootURL = directory.appendingPathComponent("track.miniqsf")
    try makeQSFContainer(
        tags: "_lib=libraries/shared.qsflib\ntitle=Track\ngame=Root game\nlength=3.5seconds\n",
        program: makeQSFBlock(0x5A, offset: 0, payload: [0xBB]),
        reserved: Data([0xCA, 0xFE, 0x41])
    ).write(to: rootURL)

    let document = try MetaManCore.read(fileURL: rootURL)
    let result = try MetaManCore.readResult(fileURL: rootURL)
    #expect(document.fields.title == "Track")
    #expect(document.fields.game == "Root game")
    #expect(document.timing?.playLengthMs == 3_500)
    #expect(document.technicalFacts["sourceFileCount"] == "2")
    #expect(document.technicalFacts["source[1].path"] == "libraries/shared.qsflib")
    #expect(document.rawMetadataBlocks?["psfReserved[0]/track.miniqsf"] == Data([0xCA, 0xFE, 0x41]))
    #expect(result.tracks.map(\.document) == [document])
}

@Test("QSF data reads require caller-supplied companions and reject unsafe paths")
func qsfDataReadsRequireSafeCompanions() throws {
    let validProgram = makeQSFBlock(0x5A, offset: 0, payload: [0x01])
    let missing = try makeQSFContainer(tags: "_lib=missing.qsflib\n", program: validProgram)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: missing, formatHint: "qsf", displayName: "track.qsf")
    }

    let traversal = try makeQSFContainer(tags: "_lib=../outside.qsflib\n", program: validProgram)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: traversal, formatHint: "qsf", displayName: "track.qsf")
    }

    let absolute = try makeQSFContainer(tags: "_lib=/tmp/outside.qsflib\n", program: validProgram)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: absolute, formatHint: "qsf", displayName: "track.qsf")
    }
}

@Test("QSF file API rejects dependency symlinks that escape their source directory")
func qsfFileReadRejectsEscapingSymlinkDependencies() throws {
    let identifier = UUID().uuidString
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-QSF-Symlink-\(identifier)", isDirectory: true)
    let externalURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-QSF-Outside-\(identifier).qsflib")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.removeItem(at: externalURL)
    }

    try makeQSFContainer(tags: "", program: makeQSFBlock(0x53, offset: 0, payload: [0x01]))
        .write(to: externalURL)
    let rootURL = directory.appendingPathComponent("track.miniqsf")
    try makeQSFContainer(
        tags: "_lib=shared.qsflib\n",
        program: makeQSFBlock(0x5A, offset: 0, payload: [0x02])
    ).write(to: rootURL)
    try FileManager.default.createSymbolicLink(
        at: directory.appendingPathComponent("shared.qsflib"),
        withDestinationURL: externalURL
    )

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(fileURL: rootURL)
    }
}

@Test("QSF rejects invalid versions, CRCs, zlib streams, data blocks, and sizes")
func qsfReaderRejectsMalformedContainersAndBlocks() throws {
    let block = makeQSFBlock(0x5A, offset: 0, payload: [0x01])
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makeQSFContainer(tags: "", program: block, version: 0x22), formatHint: "qsf")
    }

    var badCRC = try makeQSFContainer(tags: "", program: block)
    badCRC[12] ^= 0xFF
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: badCRC, formatHint: "qsf")
    }

    var badInflate = try makeQSFContainer(tags: "", program: block)
    let compressedSize = Int(qsfUInt32(badInflate, at: 8))
    badInflate[16] ^= 0xFF
    let updatedCRC = badInflate[16..<(16 + compressedSize)].withUnsafeBytes { bytes in
        crc32(crc32(0, nil, 0), bytes.bindMemory(to: Bytef.self).baseAddress, uInt(compressedSize))
    }
    qsfWriteUInt32(UInt32(updatedCRC), into: &badInflate, at: 12)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: badInflate, formatHint: "qsf")
    }

    for invalidProgram in [
        Data([0x5A, 0x38]),
        makeQSFBlock(0x5A, offset: 512 * 1_024, payload: [0x01]),
        makeQSFBlock(0x53, offset: 8 * 1_024 * 1_024, payload: [0x01]),
        makeQSFBlock(0x4B, offset: 0, payload: Array(repeating: 0, count: 10))
    ] {
        #expect(throws: MetadataReadError.self) {
            try MetaManCore.read(data: makeQSFContainer(tags: "", program: invalidProgram), formatHint: "qsf")
        }
    }

    var truncated = try makeQSFContainer(tags: "", program: block)
    qsfWriteUInt32(UInt32.max, into: &truncated, at: 4)
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: truncated, formatHint: "qsf")
    }
}

@Test("QSF retains exact tag bytes and diagnoses invalid UTF-8")
func qsfReaderRetainsAndDiagnosesRawTags() throws {
    let tags = Data([0x54, 0x49, 0x54, 0x4C, 0x45, 0x3D, 0x53, 0x6F, 0x6E, 0x67, 0x0A, 0x78, 0x3D, 0xFF, 0x00, 0x68, 0x69])
    let source = try makeQSFContainer(tagBytes: tags, program: makeQSFBlock(0x5A, offset: 0, payload: [0x01]))
    let document = try MetaManCore.read(data: source, formatHint: "qsf", displayName: "Fallback.qsf")

    #expect(document.fields.title == "Song")
    #expect(document.values(forTag: "x") == ["�"])
    #expect(document.rawTagBlock == Data("[TAG]".utf8) + tags)
    #expect(document.diagnostics.contains { $0.contains("invalid UTF-8") })
}

@Test("QSF descriptor registers both complete scanner formats")
func qsfReaderRegistryDocumentsCompleteMethodology() {
    let descriptor = MetaManCore.supportedFormats.first { $0.identifier == "qsf" }
    #expect(descriptor?.fileExtensions == ["miniqsf", "qsf"])
    #expect(descriptor?.methodology.contains("QSound block bounds") == true)
    #expect(descriptor?.methodology.contains("QSFLib companions") == true)
}

private func makeQSFBlock(_ kind: UInt8, offset: UInt32, payload: [UInt8]) -> Data {
    var block = Data([kind, 0, 0])
    block.append(contentsOf: qsfLE32(offset))
    block.append(contentsOf: qsfLE32(UInt32(payload.count)))
    block.append(contentsOf: payload)
    return block
}

private func makeQSFContainer(
    tags: String,
    program: Data,
    version: UInt8 = 0x41,
    reserved: Data = Data()
) throws -> Data {
    try makeQSFContainer(
        tagBytes: Data(tags.utf8),
        program: program,
        version: version,
        reserved: reserved
    )
}

private func makeQSFContainer(
    tagBytes: Data,
    program: Data,
    version: UInt8 = 0x41,
    reserved: Data = Data()
) throws -> Data {
    var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(program.count))))
    var compressedSize = uLongf(compressed.count)
    let compressionStatus = program.withUnsafeBytes { source in
        compressed.withUnsafeMutableBufferPointer { destination in
            compress2(
                destination.baseAddress,
                &compressedSize,
                source.bindMemory(to: Bytef.self).baseAddress,
                uLong(program.count),
                Z_BEST_COMPRESSION
            )
        }
    }
    guard compressionStatus == Z_OK else {
        throw NSError(domain: "MetaManTests", code: 40, userInfo: [NSLocalizedDescriptionKey: "Could not create compressed QSF fixture."])
    }
    compressed.removeSubrange(Int(compressedSize)..<compressed.count)
    let checksum = compressed.withUnsafeBytes { bytes in
        crc32(crc32(0, nil, 0), bytes.bindMemory(to: Bytef.self).baseAddress, uInt(compressed.count))
    }
    var data = Data([0x50, 0x53, 0x46, version])
    data.append(contentsOf: qsfLE32(UInt32(reserved.count)))
    data.append(contentsOf: qsfLE32(UInt32(compressed.count)))
    data.append(contentsOf: qsfLE32(UInt32(checksum)))
    data.append(reserved)
    data.append(contentsOf: compressed)
    data.append(Data("[TAG]".utf8))
    data.append(tagBytes)
    return data
}

private func qsfLE32(_ value: UInt32) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ]
}

private func qsfUInt32(_ data: Data, at offset: Int) -> UInt32 {
    UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}

private func qsfWriteUInt32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data.replaceSubrange(offset..<(offset + 4), with: qsfLE32(value))
}
