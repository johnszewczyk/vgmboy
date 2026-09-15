import Foundation

/// Reads Atomic Planet AUS timing and source facts without decoding its audio.
/// The 32-byte header is retained verbatim so undocumented/reserved fields are
/// not lost when clients build richer tools on top of MetaMan.
enum AtomicPlanetAUSMetadataReader {
    private static let headerSize = 0x20
    private static let metadataSource = "Atomic Planet AUS header"
    private static let signature = Data("AUS ".utf8)

    static func matches(_ data: Data) -> Bool {
        data.count >= signature.count && data.prefix(signature.count) == signature
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= headerSize,
              matches(data),
              let codec = uint16LE(data, at: 0x06),
              let rawSampleCount = int32LE(data, at: 0x08),
              let rawChannels = uint16LE(data, at: 0x0C),
              let legacyLoopFlag = uint16LE(data, at: 0x0E),
              let sampleRate = int32LE(data, at: 0x10),
              let rawLoopStart = int32LE(data, at: 0x14),
              let rawLoopEnd = int32LE(data, at: 0x18),
              let loopMarker = uint32LE(data, at: 0x1C) else {
            throw malformed("Missing or truncated Atomic Planet AUS header.")
        }

        let sampleCount = Int64(rawSampleCount)
        guard rawChannels > 0, rawChannels <= 64,
              sampleCount > 0, sampleCount <= 1_000_000_000,
              (300...192_000).contains(sampleRate) else {
            throw malformed("Atomic Planet AUS channel, sample, or rate fields are invalid.")
        }

        // vgmstream treats codec 0x02 as Xbox IMA and every other codec value
        // as PS-ADPCM. Codec selection changes decoding, not header timing.
        let loopEnabled = legacyLoopFlag != 0 || loopMarker == 1
        var loopStart: Int64 = 0
        var loopEnd: Int64 = 0
        if loopEnabled {
            loopStart = Int64(rawLoopStart)
            loopEnd = Int64(rawLoopEnd)
            if loopStart < 0 || loopEnd <= loopStart || loopEnd > sampleCount {
                loopStart = 0
                loopEnd = 0
            }
        }

        let loopLength = loopEnd > loopStart ? loopEnd - loopStart : 0
        let playSamples: Int64
        if loopLength > 0 {
            playSamples = loopStart + loopLength * 2 + Int64(sampleRate) * 10
        } else {
            playSamples = sampleCount
        }

        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        return MetadataDocument(
            format: "aus",
            fields: MetadataFields(title: title, comment: metadataSource),
            rawMetadataBlocks: ["ausHeader": Data(data.prefix(headerSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopLength * 1_000 / Int64(sampleRate)),
                playLengthMs: Int(playSamples * 1_000 / Int64(sampleRate)),
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "metadataSource": metadataSource,
                "codec": String(codec),
                "codecName": codec == 0x02 ? "Xbox IMA ADPCM" : "PS-ADPCM",
                "sampleCount": String(rawSampleCount),
                "sampleRateHz": String(sampleRate),
                "channels": String(rawChannels),
                "legacyLoopFlag": String(legacyLoopFlag),
                "loopMarker": String(loopMarker),
                "loopEnabled": String(loopEnabled),
                "rawLoopStartSample": String(rawLoopStart),
                "rawLoopEndSample": String(rawLoopEnd),
                "loopStartSample": String(loopStart),
                "loopEndSample": String(loopEnd)
            ]
        )
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("Atomic Planet AUS metadata reader: \(reason)")
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, data.count - offset >= 2 else { return nil }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32? {
        uint32LE(data, at: offset).map(Int32.init(bitPattern:))
    }
}
