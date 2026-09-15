import Foundation

/// Reads Sony MSF headers and encoded-frame boundaries without decoding PCM,
/// PlayStation ADPCM, ATRAC3, or MPEG audio.
enum SonyMSFMetadataReader {
    private static let headerSize = 0x40
    private static let encoderDelay = 1_162

    private struct MPEGFrame {
        let size: Int
        let samples: Int
    }

    private struct SampleFacts {
        let count: Int64
        let loopStart: Int64
        let loopEnd: Int64
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4
            && hasBytes(data, Array("MSF".utf8), at: 0)
            && byte(data, at: 3) != 0x20
    }

    static func supports(fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4) else { return false }
        return matches(data)
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= headerSize, matches(data),
              let codec = uint32BE(data, at: 0x04),
              let rawChannels = int32BE(data, at: 0x08), rawChannels > 0,
              let rawDataSize = uint32BE(data, at: 0x0C),
              let rawSampleRate = int32BE(data, at: 0x10),
              let flags = uint32BE(data, at: 0x14) else {
            throw malformed("Missing or truncated Sony MSF header.")
        }

        let channels = Int(rawChannels)
        guard channels <= 32 else {
            throw malformed("Sony MSF channel count exceeds vgmstream's supported range.")
        }

        let dataSize: Int
        if rawDataSize == UInt32.max {
            dataSize = data.count - headerSize
        } else {
            dataSize = Int(rawDataSize)
        }
        guard dataSize <= data.count - headerSize else {
            throw malformed("Sony MSF data size extends beyond the file.")
        }

        var sampleRate = Int(rawSampleRate)
        if sampleRate == 0 { sampleRate = 48_000 }

        let headerLooping = flags != UInt32.max && flags & 0x03 != 0
        var looping = headerLooping
        var loopStartBytes: UInt32 = 0
        var loopEndBytes: UInt32 = 0
        if looping {
            guard let start = uint32BE(data, at: 0x18),
                  let duration = uint32BE(data, at: 0x1C) else {
                throw malformed("Truncated Sony MSF loop markers.")
            }
            loopStartBytes = start
            // The legacy reader and vgmstream use 32-bit wrapping here.
            loopEndBytes = start &+ duration
        }

        var facts = try sampleFacts(
            codec: codec,
            channels: channels,
            sampleRate: &sampleRate,
            flags: flags,
            dataSize: dataSize,
            loopStartBytes: loopStartBytes,
            loopEndBytes: loopEndBytes,
            data: data
        )
        guard sampleRate > 0, facts.count > 0, facts.count <= Int64(Int32.max) else {
            throw malformed("Sony MSF sample rate or decoded sample count is invalid.")
        }

        // prepare_vgmstream() disables and clears loop markers that are
        // negative, empty, or beyond the decoded sample count.
        let invalidLoop = looping && (facts.loopStart < 0
            || facts.loopEnd <= facts.loopStart
            || facts.loopEnd > facts.count)
        if invalidLoop {
            looping = false
            facts = SampleFacts(count: facts.count, loopStart: 0, loopEnd: 0)
        }

        let loopLength = facts.loopEnd > facts.loopStart ? facts.loopEnd - facts.loopStart : 0
        let playSamples: Int64
        if looping {
            // vgmstream-cli defaults to two loop iterations followed by a
            // ten-second fade. Its non-fade body stops at the loop end.
            let intro = max(0, facts.loopStart)
            let repeatedLoop = max(0, loopLength) * 2
            let fade = Int64(sampleRate) * 10
            playSamples = max(0, intro + repeatedLoop + fade)
        } else {
            playSamples = max(0, facts.count)
        }

        let streamName = readStreamName(data)
        let fallbackTitle = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let title = streamName.name.isEmpty ? fallbackTitle : streamName.name
        let loopStartSample = looping ? facts.loopStart : 0
        let loopEndSample = looping ? facts.loopEnd : 0
        let loopLengthMs = Int(loopLength * 1_000 / Int64(sampleRate))
        let playLengthMs = Int(playSamples * 1_000 / Int64(sampleRate))

        var technicalFacts: [String: String] = [
            "codec": "0x\(String(codec, radix: 16, uppercase: true))",
            "codecName": codecName(codec),
            "channels": String(channels),
            "declaredDataSizeBytes": String(rawDataSize),
            "dataSizeBytes": String(dataSize),
            "dataSizeUsesRemainder": String(rawDataSize == UInt32.max),
            "rawSampleRateHz": String(rawSampleRate),
            "sampleRateHz": String(sampleRate),
            "flags": "0x\(String(flags, radix: 16, uppercase: true))",
            "rawLoopStartBytes": String(loopStartBytes),
            "rawLoopDurationBytes": String(headerLooping ? (uint32BE(data, at: 0x1C) ?? 0) : 0),
            "rawLoopEndBytesExclusive": String(loopEndBytes),
            "loopEnabled": String(looping),
            "invalidLoopCleared": String(invalidLoop),
            "decodedSampleCount": String(facts.count),
            "effectiveLoopStartSample": String(loopStartSample),
            "effectiveLoopEndSampleExclusive": String(loopEndSample),
            "encoderDelaySamples": String(codec >= 0x04 && codec <= 0x06 ? encoderDelay : 0),
            "streamName": streamName.name,
            "streamNameSource": streamName.name.isEmpty ? "filename-fallback" : "header"
        ]
        if codec == 0x07 {
            technicalFacts["mpegVariableBitRate"] = String(flags & 0x20 != 0)
        }
        var diagnostics: [String] = []
        if let diagnostic = streamName.diagnostic { diagnostics.append(diagnostic) }

        let tags = streamName.name.isEmpty
            ? []
            : [MetadataTag(name: "streamName", value: streamName.name)]
        return MetadataDocument(
            format: "msf",
            fields: MetadataFields(title: title, comment: "Sony MSF header"),
            tags: tags,
            rawMetadataBlocks: ["msfHeader": Data(data.prefix(headerSize))],
            sourceEncoding: streamName.name.isEmpty ? nil : "UTF-8",
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: loopLengthMs,
                playLengthMs: playLengthMs,
                fadeLengthMs: 0
            ),
            technicalFacts: technicalFacts,
            diagnostics: diagnostics
        )
    }

    private static func sampleFacts(
        codec: UInt32,
        channels: Int,
        sampleRate: inout Int,
        flags: UInt32,
        dataSize: Int,
        loopStartBytes: UInt32,
        loopEndBytes: UInt32,
        data: Data
    ) throws -> SampleFacts {
        let bytes = Int64(dataSize)
        let startBytes = Int64(loopStartBytes)
        let endBytes = Int64(loopEndBytes)
        let looping = flags != UInt32.max && flags & 0x03 != 0

        switch codec {
        case 0x00, 0x01: // PCM16 BE / LE
            return SampleFacts(
                count: bytes * 8 / Int64(channels) / 16,
                loopStart: startBytes * 8 / Int64(channels) / 16,
                loopEnd: endBytes * 8 / Int64(channels) / 16
            )

        case 0x03: // PlayStation ADPCM
            return SampleFacts(
                count: bytes / Int64(channels) / 0x10 * 28,
                loopStart: startBytes / Int64(channels) / 0x10 * 28,
                loopEnd: endBytes / Int64(channels) / 0x10 * 28
            )

        case 0x04, 0x05, 0x06: // ATRAC3 low / mid / high
            if sampleRate == -1 { sampleRate = 44_100 }
            let frameBytes: Int64 = codec == 0x04 ? 0x60 : (codec == 0x05 ? 0x98 : 0xC0)
            let blockAlign = frameBytes * Int64(channels)
            var count = bytes / blockAlign * 1_024
            var loopStart = startBytes / blockAlign * 1_024
            var loopEnd = endBytes / blockAlign * 1_024
            let delay = looping && Int64(encoderDelay) > loopStart ? 0 : Int64(encoderDelay)
            count -= delay
            loopStart -= delay
            loopEnd -= delay
            return SampleFacts(count: count, loopStart: loopStart, loopEnd: loopEnd)

        case 0x07: // MPEG audio; frame counting is header-only.
            return try mpegSampleFacts(
                data: data,
                dataSize: dataSize,
                variableBitRate: flags & 0x20 != 0,
                loopStartBytes: startBytes,
                loopEndBytes: endBytes
            )

        default:
            throw malformed("Unsupported Sony MSF codec 0x\(String(codec, radix: 16)).")
        }
    }

    private static func mpegSampleFacts(
        data: Data,
        dataSize: Int,
        variableBitRate: Bool,
        loopStartBytes: Int64,
        loopEndBytes: Int64
    ) throws -> SampleFacts {
        let start = headerSize
        let end = start + dataSize
        guard let first = mpegFrame(data, at: start) else {
            throw malformed("Sony MSF MPEG stream has no valid first frame.")
        }

        if !variableBitRate {
            let count = Int64(dataSize / first.size * first.samples)
            let loopStart = loopStartBytes / Int64(first.size) * Int64(first.samples)
            let loopEnd = loopEndBytes / Int64(first.size) * Int64(first.samples)
            return SampleFacts(count: count, loopStart: loopStart, loopEnd: loopEnd)
        }

        var offset = start
        var sampleCount: Int64 = 0
        var loopStart: Int64 = 0
        var loopEnd: Int64 = 0
        while offset < end {
            guard let frame = mpegFrame(data, at: offset) else {
                throw malformed("Invalid Sony MSF MPEG frame at byte 0x\(String(offset, radix: 16)).")
            }
            if loopStartBytes + Int64(start) == Int64(offset) {
                loopStart = sampleCount
            }
            sampleCount += Int64(frame.samples)
            offset += frame.size
            if loopEndBytes + Int64(start) == Int64(offset) {
                loopEnd = sampleCount
            }
        }
        return SampleFacts(count: sampleCount, loopStart: loopStart, loopEnd: loopEnd)
    }

    private static func mpegFrame(_ data: Data, at offset: Int) -> MPEGFrame? {
        guard let header = uint32BE(data, at: offset), header >> 21 == 0x7FF else { return nil }

        let versionBits = Int((header >> 19) & 0x03)
        let version: Int
        switch versionBits {
        case 0: version = 3 // MPEG 2.5
        case 2: version = 2 // MPEG 2
        case 3: version = 1 // MPEG 1
        default: return nil
        }

        let layerTable = [-1, 3, 2, 1]
        let layer = layerTable[Int((header >> 17) & 0x03)]
        guard layer > 0 else { return nil }

        let bitRateTables: [[Int]] = [
            [0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, -1],
            [0, 32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, -1],
            [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, -1],
            [0, 32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256, -1],
            [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, -1]
        ]
        let bitRateTableIndex = version == 1 ? layer - 1 : (layer == 1 ? 3 : 4)
        let bitRate = bitRateTables[bitRateTableIndex][Int((header >> 12) & 0x0F)]
        guard bitRate > 0 else { return nil }

        let sampleRateTable = [
            [44_100, 48_000, 32_000, -1],
            [22_050, 24_000, 16_000, -1],
            [11_025, 12_000, 8_000, -1]
        ]
        let rate = sampleRateTable[version - 1][Int((header >> 10) & 0x03)]
        guard rate > 0 else { return nil }

        let samplesByVersionAndLayer = [
            [384, 1_152, 1_152],
            [384, 1_152, 576],
            [384, 1_152, 576]
        ]
        let samples = samplesByVersionAndLayer[version - 1][layer - 1]
        let padding = Int((header >> 9) & 1)
        let size: Int
        switch samples {
        case 384: size = (12 * bitRate * 1_000 / rate + padding) * 4
        case 576: size = 72 * bitRate * 1_000 / rate + padding
        case 1_152: size = 144 * bitRate * 1_000 / rate + padding
        default: return nil
        }
        return size > 0 ? MPEGFrame(size: size, samples: samples) : nil
    }

    private static func readStreamName(_ data: Data) -> (name: String, diagnostic: String?) {
        guard uint32BE(data, at: 0x28) != UInt32.max else { return ("", nil) }
        var bytes: [UInt8] = []
        // vgmstream's read_string() uses a 0x28-byte C buffer and forces its
        // final byte to NUL, so at most 0x27 source bytes survive.
        for index in 0..<0x27 {
            guard let value = byte(data, at: 0x18 + index) else { return ("", nil) }
            if value == 0 { break }
            guard value >= 0x20, value <= 0xF0 else {
                return ("", "MSF stream-name bytes are outside the accepted text range; filename fallback was used.")
            }
            bytes.append(value)
        }
        guard let name = String(bytes: bytes, encoding: .utf8) else {
            return ("", "MSF stream name is not valid UTF-8; filename fallback was used.")
        }
        return (name, nil)
    }

    private static func codecName(_ codec: UInt32) -> String {
        switch codec {
        case 0x00: "PCM16 big-endian"
        case 0x01: "PCM16 little-endian"
        case 0x03: "PlayStation ADPCM"
        case 0x04: "ATRAC3 low"
        case 0x05: "ATRAC3 mid"
        case 0x06: "ATRAC3 high"
        case 0x07: "MPEG audio"
        default: "Unknown"
        }
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("Sony MSF metadata reader: \(reason)")
    }

    private static func hasBytes(_ data: Data, _ expected: [UInt8], at offset: Int) -> Bool {
        guard offset >= 0, data.count - offset >= expected.count else { return false }
        return data[offset..<(offset + expected.count)].elementsEqual(expected)
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1),
              let third = byte(data, at: offset + 2), let fourth = byte(data, at: offset + 3) else {
            return nil
        }
        return UInt32(first) << 24 | UInt32(second) << 16 | UInt32(third) << 8 | UInt32(fourth)
    }

    private static func int32BE(_ data: Data, at offset: Int) -> Int32? {
        uint32BE(data, at: offset).map(Int32.init(bitPattern:))
    }
}
