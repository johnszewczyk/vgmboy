import Foundation

/// Reads CRI and Monster Games ADX headers without opening an audio decoder.
/// The looped play window matches vgmstream's default of two loop iterations
/// followed by a ten-second fade.
enum ADXMetadataReader {
    private static let criSignature = Data("(c)CRI".utf8)
    private static let monsterSignature: UInt32 = 0x0200_0000

    static func matches(_ data: Data) -> Bool {
        uint16BE(data, at: 0) == 0x8000 || uint32BE(data, at: 0) == monsterSignature
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        if uint32BE(data, at: 0) == monsterSignature {
            return try readMonsterADX(data, displayName: displayName)
        }
        return try readCRIADX(data, displayName: displayName)
    }

    private static func readCRIADX(_ data: Data, displayName: String?) throws -> MetadataDocument {
        guard uint16BE(data, at: 0) == 0x8000,
              data.count >= 0x14,
              let offsetField = uint16BE(data, at: 0x02) else {
            throw malformed("Missing CRI ADX header.")
        }

        let dataOffset = Int(offsetField) + 4
        guard dataOffset >= criSignature.count,
              dataOffset <= data.count,
              data.subdata(in: (dataOffset - criSignature.count)..<dataOffset) == criSignature else {
            throw malformed("Invalid CRI ADX data offset or signature.")
        }

        guard let encoding = byte(data, at: 0x04), [0x02, 0x03, 0x04].contains(encoding),
              let frameSize = byte(data, at: 0x05), frameSize == 0x12,
              let sampleBitDepth = byte(data, at: 0x06), sampleBitDepth == 4,
              let channelCount = byte(data, at: 0x07), (1...8).contains(channelCount),
              let sampleRate = int32BE(data, at: 0x08),
              let sampleCount = int32BE(data, at: 0x0C),
              let highpassFrequency = uint16BE(data, at: 0x10),
              let rawVersion = uint16BE(data, at: 0x12) else {
            throw malformed("Unsupported CRI ADX encoding, channel count, or truncated header.")
        }

        let version: UInt16
        switch rawVersion {
        case 0x0300, 0x0500:
            version = rawVersion
        case 0x0400, 0x0408, 0x0409:
            version = 0x0400
        default:
            throw malformed("Unsupported CRI ADX version 0x\(String(rawVersion, radix: 16)).")
        }

        var loopFlag = false
        var loopStart: Int32 = 0
        var loopEnd: Int32 = 0
        let metadataSource: String

        switch version {
        case 0x0300:
            metadataSource = "CRI ADX header (type 03)"
            let loopOffset = 0x14
            if dataOffset - 6 >= loopOffset + 0x18 {
                loopFlag = int32BE(data, at: loopOffset + 0x04) != 0
                guard let start = int32BE(data, at: loopOffset + 0x08),
                      let end = int32BE(data, at: loopOffset + 0x10) else {
                    throw malformed("Truncated CRI ADX type-03 loop header.")
                }
                loopStart = start
                loopEnd = end
            }
        case 0x0400:
            metadataSource = "CRI ADX header (type 04)"
            let baseOffset = 0x18
            let historySize = channelCount > 1 ? Int(channelCount) * 4 : 8
            let loopOffset = baseOffset + historySize
            let ainfOffset = loopOffset + 4
            var ainfSize = 0
            if fourCC(data, at: ainfOffset) == Data("AINF".utf8),
               let size = uint32BE(data, at: ainfOffset + 4) {
                ainfSize = Int(size)
            }
            if ainfSize <= dataOffset - 6,
               dataOffset - ainfSize - 6 >= loopOffset + 0x18 {
                loopFlag = int32BE(data, at: loopOffset + 0x04) != 0
                guard let start = int32BE(data, at: loopOffset + 0x08),
                      let end = int32BE(data, at: loopOffset + 0x10) else {
                    throw malformed("Truncated CRI ADX type-04 loop header.")
                }
                loopStart = start
                loopEnd = end
            }
        case 0x0500:
            metadataSource = "CRI ADX header (type 05)"
        default:
            throw malformed("Unsupported CRI ADX header.")
        }

        return makeDocument(
            displayName: displayName,
            sampleRate: sampleRate,
            sampleCount: sampleCount,
            channelCount: Int(channelCount),
            loopFlag: loopFlag,
            loopStart: loopStart,
            loopEnd: loopEnd,
            metadataSource: metadataSource,
            headerVersion: "0x\(String(rawVersion, radix: 16))",
            headerBytes: Data(data.prefix(dataOffset)),
            additionalFacts: [
                "dataOffset": String(dataOffset),
                "encodingType": String(encoding),
                "frameSizeBytes": String(frameSize),
                "sampleBitDepth": String(sampleBitDepth),
                "highpassFrequencyHz": String(highpassFrequency)
            ]
        )
    }

    private static func readMonsterADX(_ data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= 0x80,
              let channels = int32LE(data, at: 0), (1...2).contains(channels),
              let loopValue = uint16LE(data, at: 0x6E),
              let sampleRate = int32LE(data, at: 0x70),
              let sampleCount = int32LE(data, at: 0x74),
              let loopStart = int32LE(data, at: 0x78),
              let loopEnd = int32LE(data, at: 0x7C) else {
            throw malformed("Truncated or invalid Monster Games ADX header.")
        }

        var streamOffsets: [String] = []
        for channel in 0..<Int(channels) {
            let offset = 0x34 + channel * 0x34
            guard let streamOffset = uint32LE(data, at: offset),
                  UInt64(streamOffset) <= UInt64(data.count) else {
                throw malformed("Invalid Monster Games ADX channel offset.")
            }
            streamOffsets.append(String(streamOffset))
        }

        return makeDocument(
            displayName: displayName,
            sampleRate: sampleRate,
            sampleCount: sampleCount,
            channelCount: Int(channels),
            loopFlag: loopValue != 0,
            loopStart: loopStart,
            loopEnd: loopEnd,
            metadataSource: "Monster Games .ADX header",
            headerVersion: "Monster Games",
            headerBytes: Data(data.prefix(0x80)),
            additionalFacts: ["channelDataOffsets": streamOffsets.joined(separator: ",")]
        )
    }

    private static func makeDocument(
        displayName: String?,
        sampleRate: Int32,
        sampleCount: Int32,
        channelCount: Int,
        loopFlag: Bool,
        loopStart: Int32,
        loopEnd: Int32,
        metadataSource: String,
        headerVersion: String,
        headerBytes: Data,
        additionalFacts: [String: String]
    ) -> MetadataDocument {
        let rate = Int64(max(1, sampleRate))
        let start = Int64(loopStart)
        let end = Int64(loopEnd)
        let loopFrames = max(0, end - start)
        var playFrames = Int64(sampleCount)
        if loopFlag {
            // Match the old ScanSong/vgmstream projection: two loop iterations
            // followed by ten seconds of fade, folded into play length.
            playFrames = start + (end - start) * 2 + Int64(sampleRate) * 10
        }
        playFrames = max(0, playFrames)

        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        var facts = additionalFacts
        facts["headerVersion"] = headerVersion
        facts["sampleRateHz"] = String(sampleRate)
        facts["sampleCount"] = String(sampleCount)
        facts["channels"] = String(channelCount)
        facts["loopEnabled"] = String(loopFlag)
        facts["loopStartSample"] = String(loopStart)
        facts["loopEndSample"] = String(loopEnd)
        facts["metadataSource"] = metadataSource

        return MetadataDocument(
            format: "adx",
            fields: MetadataFields(title: title, comment: metadataSource),
            rawMetadataBlocks: ["adxHeader": headerBytes],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopFrames * 1_000 / rate),
                playLengthMs: Int(playFrames * 1_000 / rate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("ADX metadata reader: \(reason)")
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint16BE(_ data: Data, at offset: Int) -> UInt16? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1) else { return nil }
        return UInt16(first) << 8 | UInt16(second)
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1),
              let third = byte(data, at: offset + 2), let fourth = byte(data, at: offset + 3) else { return nil }
        return UInt32(first) << 24 | UInt32(second) << 16 | UInt32(third) << 8 | UInt32(fourth)
    }

    private static func int32BE(_ data: Data, at offset: Int) -> Int32? {
        uint32BE(data, at: offset).map(Int32.init(bitPattern:))
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1) else { return nil }
        return UInt16(second) << 8 | UInt16(first)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1),
              let third = byte(data, at: offset + 2), let fourth = byte(data, at: offset + 3) else { return nil }
        return UInt32(fourth) << 24 | UInt32(third) << 16 | UInt32(second) << 8 | UInt32(first)
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32? {
        uint32LE(data, at: offset).map(Int32.init(bitPattern:))
    }

    private static func fourCC(_ data: Data, at offset: Int) -> Data? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return data.subdata(in: offset..<(offset + 4))
    }
}
