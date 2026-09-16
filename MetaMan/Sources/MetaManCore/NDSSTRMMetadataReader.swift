import Foundation

/// Reads Nintendo DS STRM stream facts from its header without opening or
/// decoding the sample payload. Other formats sharing `.strm` are not claimed.
enum NDSSTRMMetadataReader {
    private static let headerSize = 0x60
    private static let dataChunkHeaderSize = 0x08
    private static let metadataSource = "Nintendo STRM header"

    static func matches(_ data: Data) -> Bool {
        guard data.count >= headerSize,
              fourCC(data, at: 0) == "STRM",
              fourCC(data, at: 0x10) == "HEAD",
              uint32LE(data, at: 0x14) == 0x50,
              let marker = uint32BE(data, at: 0x04) else {
            return false
        }
        return marker == 0xFFFE0001 || marker == 0xFEFF0001
    }

    static func supports(fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: headerSize) else { return false }
        return matches(data)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard matches(data) else {
            throw MetadataReadError.unsupportedFormat("Nintendo DS STRM signature")
        }
        guard data.count >= headerSize + dataChunkHeaderSize,
              fourCC(data, at: headerSize) == "DATA",
              let codec = byte(data, at: 0x18),
              let loopFlag = byte(data, at: 0x19),
              let channelCount = byte(data, at: 0x1A), (1...2).contains(channelCount),
              let sampleRate = uint16LE(data, at: 0x1C), sampleRate > 0,
              let loopStart = uint32LE(data, at: 0x20),
              let sampleCount = uint32LE(data, at: 0x24),
              let dataOffsetRaw = uint32LE(data, at: 0x28),
              let interleaveBlockSize = uint32LE(data, at: 0x30),
              let interleaveLastBlockSize = uint32LE(data, at: 0x38),
              [0, 1, 2].contains(codec) else {
            throw malformed("Truncated or unsupported NDS STRM header.")
        }

        let dataOffset = Int(dataOffsetRaw)
        guard dataOffset >= headerSize + dataChunkHeaderSize,
              dataOffset <= data.count else {
            throw malformed("NDS STRM sample-data offset is outside the source file.")
        }
        guard loopFlag == 0 || loopStart <= sampleCount else {
            throw malformed("NDS STRM loop start exceeds its declared sample count.")
        }

        let rate = Int64(sampleRate)
        let samples = Int64(sampleCount)
        let loopStartSamples = Int64(loopStart)
        let loopFrames = loopFlag != 0 ? max(0, samples - loopStartSamples) : 0
        let playFrames: Int64
        if loopFlag != 0 {
            // vgmstream's scanner-info defaults are two loop iterations and
            // a ten-second fade; keep that catalog duration without decoding.
            playFrames = loopStartSamples + loopFrames * 2 + rate * 10
        } else {
            playFrames = samples
        }

        let filename = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let dataChunkSize = uint32LE(data, at: headerSize + 4)
        let codecName: String
        switch codec {
        case 0: codecName = "PCM8"
        case 1: codecName = "PCM16LE"
        default: codecName = "Nintendo DS IMA ADPCM"
        }

        var facts: [String: String] = [
            "byteOrderMarker": String(format: "0x%08X", uint32BE(data, at: 0x04) ?? 0),
            "codec": String(codec),
            "codecName": codecName,
            "channels": String(channelCount),
            "sampleRateHz": String(sampleRate),
            "sampleCount": String(sampleCount),
            "loopDeclared": String(loopFlag != 0),
            "loopStartSample": String(loopStart),
            "loopEndSample": String(sampleCount),
            "dataOffset": String(dataOffset),
            "interleaveBlockSize": String(interleaveBlockSize),
            "interleaveLastBlockSize": String(interleaveLastBlockSize),
            "metadataSource": metadataSource
        ]
        if let fileSize = uint32LE(data, at: 0x08) { facts["declaredFileSize"] = String(fileSize) }
        if let headerLength = uint16LE(data, at: 0x0C) { facts["declaredHeaderSize"] = String(headerLength) }
        if let blockCount = uint16LE(data, at: 0x0E) { facts["declaredBlockCount"] = String(blockCount) }
        if let dataChunkSize { facts["declaredDataChunkSize"] = String(dataChunkSize) }

        return MetadataDocument(
            format: "nds-strm",
            fields: MetadataFields(title: filename, comment: metadataSource),
            rawMetadataBlocks: [
                "strmHeader": Data(data.prefix(headerSize)),
                "dataChunkHeader": Data(data[headerSize..<(headerSize + dataChunkHeaderSize)])
            ],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopFrames * 1_000 / rate),
                playLengthMs: Int(max(0, playFrames) * 1_000 / rate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("NDS STRM metadata reader: \(message)")
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard let low = byte(data, at: offset), let high = byte(data, at: offset + 1) else { return nil }
        return UInt16(high) << 8 | UInt16(low)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard let b0 = byte(data, at: offset), let b1 = byte(data, at: offset + 1),
              let b2 = byte(data, at: offset + 2), let b3 = byte(data, at: offset + 3) else { return nil }
        return UInt32(b3) << 24 | UInt32(b2) << 16 | UInt32(b1) << 8 | UInt32(b0)
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard let b0 = byte(data, at: offset), let b1 = byte(data, at: offset + 1),
              let b2 = byte(data, at: offset + 2), let b3 = byte(data, at: offset + 3) else { return nil }
        return UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(b2) << 8 | UInt32(b3)
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }
}

/// Reads Final Fantasy Tactics A2's RIFF/IMA `.strm` variant from its fixed
/// header. This remains a separate format from standard Nintendo STRM.
enum NDSSTRMFFTA2MetadataReader {
    private static let headerSize = 0x2C
    private static let dataOffset = 0x2C
    private static let metadataSource = "Square Enix RIFF IMA header"

    static func matches(_ data: Data) -> Bool {
        matches(header: data, fileSize: UInt64(data.count))
    }

    static func supports(fileURL: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? NSNumber,
              let handle = try? FileHandle(forReadingFrom: fileURL) else {
            return false
        }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: headerSize) else { return false }
        return matches(header: header, fileSize: fileSize.uint64Value)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard matches(data),
              let riffSize = uint32LE(data, at: 0x04),
              let sampleRateRaw = uint32LE(data, at: 0x0C), sampleRateRaw > 0,
              let loopStartRaw = uint32LE(data, at: 0x20),
              let channelCountRaw = uint32LE(data, at: 0x24), (1...2).contains(channelCountRaw),
              let loopEndRaw = uint32LE(data, at: 0x28) else {
            throw malformed("Truncated or unsupported Square Enix RIFF IMA header.")
        }

        let sampleCountRaw = riffSize - UInt32(dataOffset)
        let loopEnabled = loopStartRaw != 0
        guard sampleCountRaw > 0,
              !loopEnabled || (loopStartRaw < loopEndRaw && loopEndRaw <= sampleCountRaw) else {
            throw malformed("Square Enix RIFF IMA sample or loop bounds are invalid.")
        }

        let sampleRate = Int64(sampleRateRaw)
        let sampleCount = Int64(sampleCountRaw)
        let loopStart = Int64(loopStartRaw)
        let loopEnd = Int64(loopEnabled ? loopEndRaw : 0)
        let loopFrames = max(0, loopEnd - loopStart)
        let playFrames = loopEnabled
            ? loopStart + loopFrames * 2 + sampleRate * 10
            : sampleCount
        let filename = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }

        return MetadataDocument(
            format: "nds-strm-ffta2",
            fields: MetadataFields(title: filename, comment: metadataSource),
            rawMetadataBlocks: ["ffta2Header": Data(data.prefix(headerSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopFrames * 1_000 / sampleRate),
                playLengthMs: Int(playFrames * 1_000 / sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "codec": "IMA ADPCM",
                "channels": String(channelCountRaw),
                "sampleRateHz": String(sampleRateRaw),
                "sampleCount": String(sampleCountRaw),
                "loopDeclared": String(loopEnabled),
                "loopStartSample": String(loopStartRaw),
                "loopEndSample": loopEnabled ? String(loopEndRaw) : String(sampleCountRaw),
                "dataOffset": String(dataOffset),
                "interleaveBlockSize": "128",
                "declaredRIFFSize": String(riffSize),
                "metadataSource": metadataSource
            ]
        )
    }

    private static func matches(header: Data?, fileSize: UInt64) -> Bool {
        guard let header,
              header.count >= headerSize,
              fourCC(header, at: 0) == "RIFF",
              fourCC(header, at: 0x08) == "IMA ",
              let riffSize = uint32LE(header, at: 0x04),
              riffSize >= headerSize,
              UInt64(riffSize) == fileSize,
              let sampleRate = uint32LE(header, at: 0x0C), (8_000...192_000).contains(sampleRate),
              let channels = uint32LE(header, at: 0x24), (1...2).contains(channels) else {
            return false
        }
        return true
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("MetaMan Nintendo DS FFTA2 STRM reader: \(message)")
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard let b0 = byte(data, at: offset), let b1 = byte(data, at: offset + 1),
              let b2 = byte(data, at: offset + 2), let b3 = byte(data, at: offset + 3) else { return nil }
        return UInt32(b3) << 24 | UInt32(b2) << 16 | UInt32(b1) << 8 | UInt32(b0)
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }
}
