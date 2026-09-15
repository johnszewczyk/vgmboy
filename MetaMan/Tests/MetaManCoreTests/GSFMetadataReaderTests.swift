import Foundation
import Testing
import zlib
@testable import MetaManCore

@Test("GSF complete reader preserves ordered tags and scanner metadata projections")
func gsfCompleteReaderRetainsSourceAndProjectsMetadata() throws {
    let root = try makeGSFContainer(
        tags: "_lib=libraries/shared.gsflib\ntitle=Mini title\nlength=1:23.500\nfade=4.250\nunknown_key=first\nunknown_key=second\n",
        executable: makeGSFExecutable(payload: [0x01, 0x02, 0x03])
    )
    let shared = try makeGSFContainer(
        tags: "game=Shared game\nartist=Shared composer\nlength=9:00\nfade=8.000\ncomment=Library note\n",
        executable: makeGSFExecutable(payload: [0xAA, 0xBB])
    )
    let context = MetadataReadContext(companionFiles: [
        MetadataCompanionFile(relativePath: "libraries/shared.gsflib", data: shared)
    ])

    let result = try MetaManCore.readResult(
        data: root,
        formatHint: "minigsf",
        displayName: "folder/track.minigsf",
        context: context
    )
    let document = try #require(result.tracks.first?.document)

    #expect(result.tracks.count == 1)
    #expect(document.format == "gsf")
    #expect(document.fields.title == "Mini title")
    #expect(document.fields.game == "Shared game")
    #expect(document.fields.system == "Game Boy Advance")
    #expect(document.fields.artist == "Shared composer")
    #expect(document.fields.comment == "Library note")
    #expect(document.values(forTag: "unknown_key") == ["first", "second"])
    #expect(document.values(forTag: "length") == ["1:23.500", "9:00"])
    #expect(document.timing == MetadataTiming(
        introLengthMs: 540_000,
        loopLengthMs: 0,
        playLengthMs: 83_500,
        fadeLengthMs: 4_250
    ))
    #expect(document.rawTagBlock?.starts(with: Data("[TAG]".utf8)) == true)
    #expect(document.rawMetadataBlocks?["psfTags[0]/track.minigsf"]?.starts(with: Data("[TAG]".utf8)) == true)
    #expect(document.rawMetadataBlocks?["psfHeader[1]/libraries/shared.gsflib"]?.count == 16)
    #expect(document.technicalFacts["sourceFileCount"] == "2")
    #expect(document.technicalFacts["dependencyFileCount"] == "1")
    #expect(document.technicalFacts["assembledROMImageBytes"] == String(0xB3))
    #expect(document.diagnostics.isEmpty)

    let sniffed = try MetaManCore.read(
        data: root,
        displayName: "folder/track.minigsf",
        context: context
    )
    #expect(sniffed == document)
}

@Test("GSF file API safely loads only the declared recursive PSFLib chain")
func gsfFileReadResolvesRecursiveSiblingLibraries() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-GSF-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let rootURL = directory.appendingPathComponent("track.minigsf")
    try makeGSFContainer(
        tags: "_lib=libraries/shared.gsflib\ntitle=Track\nlength=0::33\n",
        executable: makeGSFExecutable(payload: [0x10])
    ).write(to: rootURL)
    let librariesURL = directory.appendingPathComponent("libraries", isDirectory: true)
    try FileManager.default.createDirectory(at: librariesURL, withIntermediateDirectories: true)
    try makeGSFContainer(
        tags: "_lib=base.gsflib\ngame=GBA game\nlength=9:00\nfade=8.000\n",
        executable: makeGSFExecutable(payload: [0x20])
    ).write(to: librariesURL.appendingPathComponent("shared.gsflib"))
    try makeGSFContainer(
        tags: "artist=Composer\n",
        executable: makeGSFExecutable(payload: [0x30])
    ).write(to: directory.appendingPathComponent("base.gsflib"))

    let result = try MetaManCore.readResult(fileURL: rootURL)
    let document = try #require(result.tracks.first?.document)
    #expect(document.fields.game == "GBA game")
    #expect(document.fields.artist == "Composer")
    #expect(document.timing?.introLengthMs == 540_000)
    #expect(document.timing?.playLengthMs == 33_000)
    #expect(document.timing?.fadeLengthMs == 8_000)
    #expect(document.technicalFacts["sourceFileCount"] == "3")
}

@Test("GSF rejects missing, escaping, cyclic, and structurally invalid dependencies")
func gsfRejectsInvalidDependencyAndContainerInputs() throws {
    let missing = try makeGSFContainer(
        tags: "_lib=missing.gsflib\n",
        executable: makeGSFExecutable(payload: [0x01])
    )
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: missing, formatHint: "gsf", displayName: "missing.gsf")
    }

    let escaping = try makeGSFContainer(
        tags: "_lib=../outside.gsflib\n",
        executable: makeGSFExecutable(payload: [0x02])
    )
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: escaping, formatHint: "gsf", displayName: "escape.gsf")
    }

    var badCRC = try makeGSFContainer(tags: "title=Bad CRC\n", executable: makeGSFExecutable(payload: [0x03]))
    badCRC[12] ^= 0xFF
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: badCRC, formatHint: "gsf")
    }

    let invalidROM = try makeGSFContainer(
        tags: "title=Not a ROM\n",
        executable: makeGSFExecutable(payload: Array(repeating: 0, count: 0xB3), validHeader: false)
    )
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: invalidROM, formatHint: "gsf")
    }

    let first = try makeGSFContainer(
        tags: "_lib=second.gsflib\n",
        executable: makeGSFExecutable(payload: [0x04])
    )
    let second = try makeGSFContainer(
        tags: "_lib=first.gsflib\n",
        executable: makeGSFExecutable(payload: [0x05])
    )
    let cyclicContext = MetadataReadContext(companionFiles: [
        MetadataCompanionFile(relativePath: "second.gsflib", data: second)
    ])
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: first, formatHint: "gsf", displayName: "first.gsflib", context: cyclicContext)
    }
}

@Test("GSF data reads enforce the dependency file-count limit")
func gsfDataReadEnforcesDependencyFileCountLimit() throws {
    let dependencyCount = 256
    var rootTags = ""
    var companions: [MetadataCompanionFile] = []
    for index in 0..<dependencyCount {
        let tag = index == 0 ? "_lib" : "_lib\(index + 1)"
        let name = "library-\(index).gsflib"
        rootTags += "\(tag)=\(name)\n"
        companions.append(
            MetadataCompanionFile(
                relativePath: name,
                data: try makeGSFContainer(
                    tags: "",
                    executable: makeGSFExecutable(payload: [UInt8(truncatingIfNeeded: index)])
                )
            )
        )
    }
    let root = try makeGSFContainer(
        tags: rootTags,
        executable: makeGSFExecutable(payload: [0x42])
    )

    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(
            data: root,
            formatHint: "gsf",
            displayName: "root.gsf",
            context: MetadataReadContext(companionFiles: companions)
        )
    }
}

@Test("GSF reader registry lists complete validation separately from generic PSF tags")
func gsfFormatDescriptorDocumentsCompleteMethodology() {
    let descriptor = MetaManCore.supportedFormats.first { $0.identifier == "gsf" }
    #expect(descriptor?.fileExtensions == ["gsf", "minigsf"])
    #expect(descriptor?.methodology.contains("stitches GBA load segments") == true)
    #expect(descriptor?.methodology.contains("without mGBA") == true)
}

private func makeGSFExecutable(
    payload: [UInt8],
    offset: UInt32 = 0,
    validHeader: Bool = true
) -> Data {
    var image = payload
    if image.count < 0xB3 { image.append(contentsOf: repeatElement(0, count: 0xB3 - image.count)) }
    if validHeader {
        image[3] = 0xEA
        image[0xB2] = 0x96
    }
    var executable = Data(repeating: 0, count: 12)
    writeLE32(0x0800_0000, into: &executable, at: 0)
    writeLE32(offset, into: &executable, at: 4)
    writeLE32(UInt32(image.count), into: &executable, at: 8)
    executable.append(contentsOf: image)
    return executable
}

private func makeGSFContainer(tags: String, executable: Data) throws -> Data {
    var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(executable.count))))
    var compressedSize = uLongf(compressed.count)
    let compressionStatus = executable.withUnsafeBytes { source in
        compressed.withUnsafeMutableBufferPointer { destination in
            compress2(
                destination.baseAddress,
                &compressedSize,
                source.bindMemory(to: Bytef.self).baseAddress,
                uLong(executable.count),
                Z_BEST_COMPRESSION
            )
        }
    }
    guard compressionStatus == Z_OK else {
        throw NSError(domain: "MetaManTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create compressed GSF fixture."])
    }
    compressed.removeSubrange(Int(compressedSize)..<compressed.count)
    let checksum = compressed.withUnsafeBytes { bytes in
        crc32(crc32(0, nil, 0), bytes.bindMemory(to: Bytef.self).baseAddress, uInt(compressed.count))
    }
    var data = Data([0x50, 0x53, 0x46, 0x22])
    data.append(contentsOf: littleEndianBytes(0))
    data.append(contentsOf: littleEndianBytes(UInt32(compressed.count)))
    data.append(contentsOf: littleEndianBytes(UInt32(checksum)))
    data.append(contentsOf: compressed)
    data.append(Data("[TAG]\n\(tags)".utf8))
    return data
}

private func writeLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data.replaceSubrange(offset..<(offset + 4), with: littleEndianBytes(value))
}

private func littleEndianBytes(_ value: UInt32) -> [UInt8] {
    [
        UInt8(truncatingIfNeeded: value),
        UInt8(truncatingIfNeeded: value >> 8),
        UInt8(truncatingIfNeeded: value >> 16),
        UInt8(truncatingIfNeeded: value >> 24)
    ]
}
