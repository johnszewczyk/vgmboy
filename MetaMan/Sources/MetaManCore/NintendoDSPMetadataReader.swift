import Foundation

/// Header-only readers for the three `.dsp` layouts found in the live
/// CocoaSpice catalog. These are separate formats sharing one extension.
enum NintendoDSPMetadataReader {
    private static let standardHeaderSize = 0x60
    private static let rs03HeaderSize = 0x60

    private struct StandardHeader: Equatable {
        let sampleCount: UInt32
        let nibbleCount: UInt32
        let sampleRate: UInt32
        let loopFlag: UInt16
        let format: UInt16
        let loopStartNibbles: UInt32
        let loopEndNibbles: UInt32
        let initialOffsetNibbles: UInt32
        let initialPredictorScale: UInt16
        let channelHint: Int16
        let blockSizeHint: UInt16
    }

    private struct THPLayout {
        let bigEndian: Bool
        let version: UInt32
        let maximumAudioBufferSize: UInt32
        let maximumAudioSize: UInt32
        let blockCount: UInt32
        let firstBlockSize: UInt32
        let declaredDataSize: UInt32
        let componentTypeOffset: Int
        let componentCount: Int
        let componentHeadersOffset: Int
        let audioHeaderOffset: Int
        let audioHeaderLength: Int
        let dataOffset: Int
        let channels: UInt32
        let sampleRate: UInt32
        let sampleCount: UInt32
    }

    static func matches(_ data: Data) -> Bool {
        if fourCC(data, at: 0) == "THP\0" || uint32BE(data, at: 0) == 0x52530003 {
            return true
        }
        return readStandardHeader(data, at: 0) != nil
            && data.count > standardHeaderSize
            && uint16BE(data, at: 0x3E) == UInt16(data[standardHeaderSize])
    }

    static func supports(fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let prefix = try? handle.read(upToCount: standardHeaderSize + 1) else {
            return false
        }
        return matches(prefix)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        if fourCC(data, at: 0) == "THP\0" {
            return try readTHP(data, displayName: displayName)
        }
        if uint32BE(data, at: 0) == 0x52530003 {
            return try readRS03(data, displayName: displayName)
        }
        guard let header = readStandardHeader(data, at: 0) else {
            throw MetadataReadError.unsupportedFormat("Nintendo DSP, RS03, or THP signature")
        }
        guard data.count > standardHeaderSize,
              uint16BE(data, at: 0x3E) == UInt16(data[standardHeaderSize]) else {
            throw malformed("Standard DSP initial predictor does not match its first audio frame.")
        }

        // vgmstream rejects a mono interpretation when an otherwise matching
        // second header is present at either conventional channel position.
        for candidateOffset in [standardHeaderSize, 0x10000] {
            if let second = readStandardHeader(data, at: candidateOffset),
               header.sampleCount == second.sampleCount,
               header.nibbleCount == second.nibbleCount,
               header.sampleRate == second.sampleRate,
               header.loopFlag == second.loopFlag {
                throw MetadataReadError.unsupportedFormat("multi-channel Nintendo DSP alias")
            }
        }

        let sampleCount = Int64(header.sampleCount)
        let loopStart = nibblesToSamples(header.loopStartNibbles)
        let decodedLoopEnd = nibblesToSamples(header.loopEndNibbles) + 1
        let loopEnd = min(sampleCount, decodedLoopEnd)
        let looping = header.loopFlag != 0
        var facts: [String: String] = [
            "metadataSource": "Nintendo DSP header",
            "channels": "1",
            "sampleCount": String(header.sampleCount),
            "nibbleCount": String(header.nibbleCount),
            "sampleRateHz": String(header.sampleRate),
            "loopDeclared": String(looping),
            "loopStartNibbles": String(header.loopStartNibbles),
            "loopEndNibbles": String(header.loopEndNibbles),
            "loopStartSample": String(loopStart),
            "loopEndSample": String(loopEnd),
            "initialOffsetNibbles": String(header.initialOffsetNibbles),
            "format": String(header.format),
            "initialPredictorScale": String(header.initialPredictorScale),
            "headerChannelHint": String(header.channelHint),
            "headerBlockSizeHint": String(header.blockSizeHint)
        ]
        facts["coefficientCount"] = "16"

        return document(
            format: "ngc-dsp-standard",
            source: "Nintendo DSP header",
            displayName: displayName,
            sampleCount: sampleCount,
            sampleRate: Int64(header.sampleRate),
            loopDeclared: looping,
            loopStart: loopStart,
            loopEnd: loopEnd,
            facts: facts,
            blocks: ["dspHeader": Data(data.prefix(standardHeaderSize))]
        )
    }

    private static func readRS03(_ data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= rs03HeaderSize,
              uint32BE(data, at: 0) == 0x52530003,
              let channels = uint32BE(data, at: 0x04), (1...2).contains(channels),
              let sampleCountRaw = uint32BE(data, at: 0x08), sampleCountRaw > 0,
              sampleCountRaw <= 0x10000000,
              let sampleRateRaw = uint32BE(data, at: 0x0C), (5_000...192_000).contains(sampleRateRaw),
              let loopFlagRaw = uint16BE(data, at: 0x14), loopFlagRaw <= 1,
              let loopStartBytes = uint32BE(data, at: 0x18),
              let loopEndBytes = uint32BE(data, at: 0x1C) else {
            throw malformed("Truncated or invalid Retro Studios RS03 header.")
        }

        let sampleCount = Int64(sampleCountRaw)
        let loopStart = bytesToSamples(loopStartBytes)
        let loopEnd = bytesToSamples(loopEndBytes)
        let looping = loopFlagRaw != 0
        let facts: [String: String] = [
            "metadataSource": "Retro Studios RS03 header",
            "channels": String(channels),
            "sampleCount": String(sampleCountRaw),
            "sampleRateHz": String(sampleRateRaw),
            "loopDeclared": String(looping),
            "loopStartByteOffset": String(loopStartBytes),
            "loopEndByteOffset": String(loopEndBytes),
            "loopStartSample": String(loopStart),
            "loopEndSample": String(loopEnd),
            "audioOffset": String(rs03HeaderSize),
            "interleaveBytes": String(0x8F00),
            "audioByteCount": String(data.count - rs03HeaderSize)
        ]

        return document(
            format: "rs03",
            source: "Retro Studios RS03 header",
            displayName: displayName,
            sampleCount: sampleCount,
            sampleRate: Int64(sampleRateRaw),
            loopDeclared: looping,
            loopStart: loopStart,
            loopEnd: loopEnd,
            facts: facts,
            blocks: ["rs03Header": Data(data.prefix(rs03HeaderSize))]
        )
    }

    private static func readTHP(_ data: Data, displayName: String?) throws -> MetadataDocument {
        guard let layout = parseTHP(data) else {
            throw malformed("Truncated or unsupported Nintendo THP audio header.")
        }
        let componentTypesEnd = layout.componentHeadersOffset
        let audioHeaderEnd = layout.audioHeaderOffset + layout.audioHeaderLength
        var blocks: [String: Data] = [
            "thpHeader": Data(data.prefix(0x30)),
            "thpComponentTypes": Data(data[layout.componentTypeOffset..<componentTypesEnd]),
            "thpAudioHeader": Data(data[layout.audioHeaderOffset..<audioHeaderEnd])
        ]
        if layout.audioHeaderOffset > layout.componentHeadersOffset {
            blocks["thpComponentHeaders"] = Data(data[layout.componentHeadersOffset..<layout.audioHeaderOffset])
        }
        let facts: [String: String] = [
            "metadataSource": "Nintendo THP header",
            "byteOrder": layout.bigEndian ? "big" : "little",
            "version": String(format: "0x%08X", layout.version),
            "maximumAudioBufferSize": String(layout.maximumAudioBufferSize),
            "maximumAudioSize": String(layout.maximumAudioSize),
            "blockCount": String(layout.blockCount),
            "firstBlockSize": String(layout.firstBlockSize),
            "declaredDataSize": String(layout.declaredDataSize),
            "componentTypeOffset": String(layout.componentTypeOffset),
            "componentCount": String(layout.componentCount),
            "audioHeaderOffset": String(layout.audioHeaderOffset),
            "audioHeaderLength": String(layout.audioHeaderLength),
            "dataOffset": String(layout.dataOffset),
            "channels": String(layout.channels),
            "sampleRateHz": String(layout.sampleRate),
            "sampleCount": String(layout.sampleCount)
        ]
        return document(
            format: "ngc-thp-audio",
            source: "Nintendo THP header",
            displayName: displayName,
            sampleCount: Int64(layout.sampleCount),
            sampleRate: Int64(layout.sampleRate),
            loopDeclared: false,
            loopStart: 0,
            loopEnd: 0,
            facts: facts,
            blocks: blocks
        )
    }

    private static func parseTHP(_ data: Data) -> THPLayout? {
        guard data.count >= 0x30,
              fourCC(data, at: 0) == "THP\0",
              let versionBE = uint32BE(data, at: 0x04),
              let versionLE = uint32LE(data, at: 0x04) else { return nil }
        let bigEndian: Bool
        let version: UInt32
        if versionBE == 0x00010000 || versionBE == 0x00011000 {
            bigEndian = true
            version = versionBE
        } else if versionLE == 0x00010000 || versionLE == 0x00011000 {
            bigEndian = false
            version = versionLE
        } else {
            return nil
        }
        func u32(_ offset: Int) -> UInt32? {
            bigEndian ? uint32BE(data, at: offset) : uint32LE(data, at: offset)
        }
        guard let maximumAudioBufferSize = u32(0x08),
              let maximumAudioSize = u32(0x0C), maximumAudioSize > 0,
              let blockCount = u32(0x14),
              let firstBlockSize = u32(0x18), firstBlockSize > 0,
              let declaredDataSize = u32(0x1C),
              let componentOffsetRaw = u32(0x20),
              let dataOffsetRaw = u32(0x28) else { return nil }

        let componentOffset = Int(componentOffsetRaw)
        guard componentOffset >= 0, componentOffset + 0x14 <= data.count,
              let componentCountRaw = u32(componentOffset),
              (1...16).contains(componentCountRaw) else { return nil }
        let componentCount = Int(componentCountRaw)
        let componentTypesOffset = componentOffset + 4
        let componentHeadersOffset = componentTypesOffset + 0x10
        var componentDataOffset = componentHeadersOffset
        var audioHeaderOffset: Int?

        for index in 0..<componentCount {
            guard componentTypesOffset + index < data.count else { return nil }
            switch data[componentTypesOffset + index] {
            case 0x00:
                componentDataOffset += version == 0x00010000 ? 0x08 : 0x0C
            case 0x01:
                audioHeaderOffset = componentDataOffset
            default:
                return nil
            }
            if audioHeaderOffset != nil { break }
        }
        let audioHeaderLength = version == 0x00010000 ? 0x0C : 0x10
        guard let audioHeaderOffset,
              audioHeaderOffset + audioHeaderLength <= data.count,
              let channels = u32(audioHeaderOffset), (1...16).contains(channels),
              let sampleRate = u32(audioHeaderOffset + 4), (5_000...192_000).contains(sampleRate),
              let sampleCount = u32(audioHeaderOffset + 8), sampleCount > 0,
              sampleCount <= 0x10000000,
              Int(dataOffsetRaw) >= audioHeaderOffset + audioHeaderLength,
              Int(dataOffsetRaw) < data.count else { return nil }

        return THPLayout(
            bigEndian: bigEndian,
            version: version,
            maximumAudioBufferSize: maximumAudioBufferSize,
            maximumAudioSize: maximumAudioSize,
            blockCount: blockCount,
            firstBlockSize: firstBlockSize,
            declaredDataSize: declaredDataSize,
            componentTypeOffset: componentOffset,
            componentCount: componentCount,
            componentHeadersOffset: componentHeadersOffset,
            audioHeaderOffset: audioHeaderOffset,
            audioHeaderLength: audioHeaderLength,
            dataOffset: Int(dataOffsetRaw),
            channels: channels,
            sampleRate: sampleRate,
            sampleCount: sampleCount
        )
    }

    private static func readStandardHeader(_ data: Data, at offset: Int) -> StandardHeader? {
        guard offset >= 0, offset + standardHeaderSize <= data.count,
              let sampleCount = uint32BE(data, at: offset),
              (1...0x10000000).contains(sampleCount),
              let nibbleCount = uint32BE(data, at: offset + 4),
              (1...0x20000000).contains(nibbleCount),
              let sampleRate = uint32BE(data, at: offset + 8),
              (5_000...48_000).contains(sampleRate),
              let loopFlag = uint16BE(data, at: offset + 0x0C), loopFlag <= 1,
              let format = uint16BE(data, at: offset + 0x0E), format == 0,
              let loopStart = uint32BE(data, at: offset + 0x10),
              let loopEnd = uint32BE(data, at: offset + 0x14),
              let initialOffset = uint32BE(data, at: offset + 0x18),
              initialOffset == 0 || initialOffset == 2 || initialOffset == loopStart,
              let gain = uint16BE(data, at: offset + 0x3C), gain == 0,
              let initialPredictorScale = uint16BE(data, at: offset + 0x3E),
              let channelHint = int16BE(data, at: offset + 0x4A),
              let blockSizeHint = uint16BE(data, at: offset + 0x4C) else { return nil }

        var hasNonZeroCoefficient = false
        for index in 0..<16 {
            guard let coefficient = int16BE(data, at: offset + 0x1C + index * 2) else { return nil }
            hasNonZeroCoefficient = hasNonZeroCoefficient || coefficient != 0
        }
        guard hasNonZeroCoefficient else { return nil }

        return StandardHeader(
            sampleCount: sampleCount,
            nibbleCount: nibbleCount,
            sampleRate: sampleRate,
            loopFlag: loopFlag,
            format: format,
            loopStartNibbles: loopStart,
            loopEndNibbles: loopEnd,
            initialOffsetNibbles: initialOffset,
            initialPredictorScale: initialPredictorScale,
            channelHint: channelHint,
            blockSizeHint: blockSizeHint
        )
    }

    private static func document(
        format: String,
        source: String,
        displayName: String?,
        sampleCount: Int64,
        sampleRate: Int64,
        loopDeclared: Bool,
        loopStart: Int64,
        loopEnd: Int64,
        facts: [String: String],
        blocks: [String: Data]
    ) -> MetadataDocument {
        let loopSamples = loopDeclared ? max(0, loopEnd - loopStart) : 0
        let playSamples = loopDeclared
            ? loopStart + loopSamples * 2 + sampleRate * 10
            : sampleCount
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        return MetadataDocument(
            format: format,
            fields: MetadataFields(title: title, comment: source),
            rawMetadataBlocks: blocks,
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopSamples * 1_000 / sampleRate),
                playLengthMs: Int(max(0, playSamples) * 1_000 / sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func nibblesToSamples(_ nibbles: UInt32) -> Int64 {
        let wholeFrames = nibbles / 16
        let remainder = nibbles % 16
        return Int64(wholeFrames) * 14 + (remainder > 0 ? Int64(remainder) - 2 : 0)
    }

    private static func bytesToSamples(_ bytes: UInt32) -> Int64 {
        Int64(bytes / 8) * 14
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("Nintendo DSP metadata reader: \(message)")
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String? {
        guard offset >= 0, offset + 4 <= data.count else { return nil }
        return String(decoding: data[offset..<(offset + 4)], as: UTF8.self)
    }

    private static func uint16BE(_ data: Data, at offset: Int) -> UInt16? {
        guard let high = byte(data, at: offset), let low = byte(data, at: offset + 1) else { return nil }
        return UInt16(high) << 8 | UInt16(low)
    }

    private static func int16BE(_ data: Data, at offset: Int) -> Int16? {
        uint16BE(data, at: offset).map { Int16(bitPattern: $0) }
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard let b0 = byte(data, at: offset), let b1 = byte(data, at: offset + 1),
              let b2 = byte(data, at: offset + 2), let b3 = byte(data, at: offset + 3) else { return nil }
        return UInt32(b0) << 24 | UInt32(b1) << 16 | UInt32(b2) << 8 | UInt32(b3)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard let b0 = byte(data, at: offset), let b1 = byte(data, at: offset + 1),
              let b2 = byte(data, at: offset + 2), let b3 = byte(data, at: offset + 3) else { return nil }
        return UInt32(b3) << 24 | UInt32(b2) << 16 | UInt32(b1) << 8 | UInt32(b0)
    }
}
