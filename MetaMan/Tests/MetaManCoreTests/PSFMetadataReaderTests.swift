import Foundation
import Testing
@testable import MetaManCore

@Test("PSF-family retains ordered tags and maps authored fields and timing")
func psfFamilyRetainsAllTagsAndProjectsCommonMetadata() throws {
    let tagText = """
        TITLE=
        title=Cyberbot
        TITLE=Later title
        game=Cyberbots
        artist=Capcom
        album=Arcade
        date=1999-02-01
        year=1999
        genre=Shooter
        comment=Cabinet mix
        copyright=Capcom
        psfby=Build tool
        length=1:23.500
        fade=4.250
        _lib=cyberbot.lib
        unknown_key=retained
        """
    let document = try MetaManCore.read(
        data: makePSF(tagText: tagText),
        formatHint: "psf",
        displayName: "fallback.psf"
    )

    #expect(document.format == "psf")
    #expect(document.fields.title == "Cyberbot")
    #expect(document.fields.game == "Cyberbots")
    #expect(document.fields.system == "Sony PlayStation")
    #expect(document.fields.artist == "Capcom")
    #expect(document.fields.album == "Arcade")
    #expect(document.fields.date == "1999-02-01")
    #expect(document.fields.year == "1999")
    #expect(document.fields.genre == "Shooter")
    #expect(document.fields.comment == "Cabinet mix")
    #expect(document.fields.copyright == "Capcom")
    #expect(document.fields.encodedBy == "Build tool")
    #expect(document.values(forTag: "title") == ["", "Cyberbot", "Later title"])
    #expect(document.value(forTag: "_lib") == "cyberbot.lib")
    #expect(document.value(forTag: "unknown_key") == "retained")
    #expect(document.rawTagBlock?.starts(with: Data("[TAG]".utf8)) == true)
    #expect(document.sourceEncoding == "UTF-8")
    #expect(document.timing == MetadataTiming(introLengthMs: 0, loopLengthMs: 0, playLengthMs: 83_500, fadeLengthMs: 4_250))
    #expect(document.diagnostics.isEmpty)
}

@Test("Every PSF-family extension gets its console identity without a decoder")
func psfFamilyExtensionMatrix() throws {
    let cases = [
        ("psf", "Sony PlayStation"), ("minipsf", "Sony PlayStation"),
        ("psf2", "Sony PlayStation 2"), ("minipsf2", "Sony PlayStation 2"),
        ("ssf", "Sega Saturn"), ("minissf", "Sega Saturn"),
        ("usf", "Nintendo 64"), ("miniusf", "Nintendo 64"),
        ("2sf", "Nintendo DS"), ("mini2sf", "Nintendo DS")
    ]

    for (ext, system) in cases {
        let document = try MetaManCore.read(
            data: makePSF(tagText: "title=Song"),
            formatHint: ext,
            displayName: "Song.\(ext)"
        )
        #expect(document.fields.system == system)
        #expect(document.format == (ext.hasPrefix("mini") ? String(ext.dropFirst(4)) : ext))
    }
}

@Test("PSF file API and content detection use the display-name fallback")
func psfFileAndSniffedReadsFallbackToFilename() throws {
    let data = makePSF(tagText: nil)
    let sniffed = try MetaManCore.read(data: data, displayName: "folder/Short.miniUSF")
    #expect(sniffed.format == "psf")
    #expect(sniffed.fields.title == "Short")
    #expect(sniffed.fields.system == nil)
    #expect(sniffed.tags.isEmpty)
    #expect(sniffed.rawTagBlock == nil)

    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("MetaMan-PSF-\(UUID().uuidString).ssf")
    defer { try? FileManager.default.removeItem(at: fileURL) }
    try data.write(to: fileURL)
    let fileRead = try MetaManCore.read(fileURL: fileURL)
    #expect(fileRead.format == "ssf")
    #expect(fileRead.fields.title == fileURL.deletingPathExtension().lastPathComponent)
    #expect(fileRead.fields.system == "Sega Saturn")
}

@Test("PSF bounds, invalid text, and timing tags are reported safely")
func psfMalformedHeaderAndTagBoundaries() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: Data("not psf".utf8), formatHint: "psf")
    }
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.read(data: makePSF(tagText: "title=Song"), formatHint: "qsf")
    }

    var outOfRange = makePSF(tagText: nil)
    psfWriteLE32(UInt32.max, into: &outOfRange, at: 4)
    let noFooter = try MetaManCore.read(data: outOfRange, formatHint: "psf", displayName: "NoFooter.psf")
    #expect(noFooter.fields.title == "NoFooter")
    #expect(noFooter.diagnostics.contains { $0.contains("tag offset points beyond") })

    let invalidUTF8 = makePSF(tagBytes: Data([0x74, 0x69, 0x74, 0x6C, 0x65, 0x3D, 0xFF]))
    let invalidDocument = try MetaManCore.read(data: invalidUTF8, formatHint: "psf")
    #expect(invalidDocument.fields.title == "�")
    #expect(invalidDocument.rawTagBlock?.last == 0xFF)
    #expect(invalidDocument.diagnostics.contains { $0.contains("invalid UTF-8") })

    let tooLarge = makePSF(tagBytes: Data(repeating: 0x41, count: 1_048_577))
    let bounded = try MetaManCore.read(data: tooLarge, formatHint: "psf")
    #expect(bounded.rawTagBlock?.count == 5 + 1_048_577)
    #expect(bounded.diagnostics.contains { $0.contains("1 MiB parsing limit") })

    let invalidTiming = try MetaManCore.read(
        data: makePSF(tagText: "length=NaN\nfade=1e999"),
        formatHint: "psf"
    )
    #expect(invalidTiming.timing?.playLengthMs == 0)
    #expect(invalidTiming.timing?.fadeLengthMs == 0)
}

private func makePSF(tagText: String?) -> Data {
    makePSF(tagBytes: tagText.map { Data($0.utf8) })
}

private func makePSF(tagBytes: Data?) -> Data {
    var data = Data([0x50, 0x53, 0x46, 0x41])
    data.append(contentsOf: repeatElement(0, count: 12))
    if let tagBytes {
        data.append(Data("[TAG]".utf8))
        data.append(tagBytes)
    }
    return data
}

private func psfWriteLE32(_ value: UInt32, into data: inout Data, at offset: Int) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
