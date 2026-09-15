import Foundation
import Testing
@testable import MetaManCore

@Test("KSS base header is retained with the established compatibility result")
func kssBaseHeaderProvidesCompatibilityTracksAndFacts() throws {
    let source = makeKSS(signature: "KSCC", flags: 0x05)
    let result = try MetaManCore.readResult(data: source, formatHint: "kss", displayName: "MSX.kss")

    #expect(result.tracks.count == 256)
    #expect(result.tracks.map(\.sourceTrackIndex) == Array(0..<256).map(Optional.some))
    let document = try #require(result.tracks.first?.document)
    #expect(document.format == "kss")
    #expect(document.fields.system == "MSX")
    #expect(document.timing == MetadataTiming(introLengthMs: -1, loopLengthMs: -1, playLengthMs: 150_000, fadeLengthMs: -1))
    #expect(document.technicalFacts["loadAddress"] == "32768")
    #expect(document.technicalFacts["loadSize"] == "4096")
    #expect(document.technicalFacts["initAddress"] == "33024")
    #expect(document.technicalFacts["playAddress"] == "33280")
    #expect(document.technicalFacts["deviceFlags"] == "5")
    #expect(document.technicalFacts["trackCountSource"] == "256-slot compatibility listing")
    #expect(document.rawMetadataBlocks?["baseHeader"] == Data(source.prefix(0x10)))
    #expect(document.rawMetadataBlocks?["kssxExtendedHeader"] == nil)
    #expect(throws: MetadataReadError.trackAwareResultRequired("KSS")) {
        try MetaManCore.read(data: source, formatHint: "kss", displayName: "MSX.kss")
    }
}

@Test("KSSX extended header retains declared track facts without changing compatibility slots")
func kssxExtendedHeaderRetainsNativeTrackFacts() throws {
    let source = makeKSS(signature: "KSSX", flags: 0x07, lastTrack: 2)
    let result = try MetaManCore.readResult(data: source, formatHint: "kss")

    #expect(result.tracks.count == 256)
    #expect(result.tracks.prefix(3).map(\.sourceTrackIndex) == [0, 1, 2])
    let document = result.tracks[0].document
    #expect(document.fields.system == "Sega Mega Drive")
    #expect(document.technicalFacts["declaredFirstTrack"] == "1")
    #expect(document.technicalFacts["declaredLastTrack"] == "2")
    #expect(document.technicalFacts["declaredTrackCount"] == "3")
    #expect(document.technicalFacts["trackCount"] == "256")
    #expect(document.technicalFacts["declaredPayloadSize"] == "4096")
    #expect(document.technicalFacts["dataOffset"] == "32")
    #expect(document.technicalFacts["payloadByteCount"] == "0")
    #expect(document.technicalFacts["psgVolume"] == "10")
    #expect(document.technicalFacts["sccVolume"] == "11")
    #expect(document.technicalFacts["msxMusicVolume"] == "12")
    #expect(document.technicalFacts["msxAudioVolume"] == "13")
    #expect(document.rawMetadataBlocks?["kssxExtendedHeader"] == Data(source[0x10..<0x20]))
}

@Test("KSS hardware fields preserve established ScanSong system labels")
func kssHardwareNamesPreserveCatalogLabels() throws {
    let cases: [(UInt8, String)] = [
        (0x00, "MSX"),
        (0x01, "MSX"),
        (0x02, "Sega Master System"),
        (0x06, "Game Gear"),
        (0x07, "Sega Mega Drive"),
        (0x09, "MSX")
    ]

    for (flags, expectedSystem) in cases {
        let result = try MetaManCore.readResult(data: makeKSS(signature: "KSCC", flags: flags), formatHint: "kss")
        #expect(result.tracks.first?.document.fields.system == expectedSystem)
    }
}

@Test("Malformed KSS signatures and truncated declared KSSX extensions fail safely")
func kssMalformedHeadersAreRejected() throws {
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: Data(repeating: 0, count: 0x10), formatHint: "kss")
    }

    var truncated = makeKSS(signature: "KSSX", flags: 0, extended: false)
    truncated[0x0E] = 0x10
    #expect(throws: MetadataReadError.self) {
        try MetaManCore.readResult(data: truncated, formatHint: "kss")
    }

    var unknownExtension = makeKSS(signature: "KSSX", flags: 0, extended: false)
    unknownExtension[0x0E] = 0x08
    let result = try MetaManCore.readResult(data: unknownExtension, formatHint: "kss")
    #expect(result.tracks.count == 256)
    #expect(result.tracks[0].document.diagnostics.contains { $0.contains("Unsupported KSSX extra-header size") })
}

private func makeKSS(
    signature: String,
    flags: UInt8,
    lastTrack: UInt16 = 0x00FF,
    extended: Bool = true
) -> Data {
    let hasExtension = signature == "KSSX" && extended
    var data = Data(repeating: 0, count: hasExtension ? 0x20 : 0x10)
    data.replaceSubrange(0..<4, with: Data(signature.utf8))
    writeLE16(&data, at: 0x04, value: 0x8000)
    writeLE16(&data, at: 0x06, value: 0x1000)
    writeLE16(&data, at: 0x08, value: 0x8100)
    writeLE16(&data, at: 0x0A, value: 0x8200)
    data[0x0C] = 3
    data[0x0D] = 4
    data[0x0E] = hasExtension ? 0x10 : 0
    data[0x0F] = flags
    if hasExtension {
        writeLE32(&data, at: 0x10, value: 0x1000)
        writeLE16(&data, at: 0x18, value: 1)
        writeLE16(&data, at: 0x1A, value: lastTrack)
        data[0x1C] = 10
        data[0x1D] = 11
        data[0x1E] = 12
        data[0x1F] = 13
    }
    return data
}

private func writeLE16(_ data: inout Data, at offset: Int, value: UInt16) {
    data[offset] = UInt8(truncatingIfNeeded: value)
    data[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
}

private func writeLE32(_ data: inout Data, at offset: Int, value: UInt32) {
    for byte in 0..<4 {
        data[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
    }
}
