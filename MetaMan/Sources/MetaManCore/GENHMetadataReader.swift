import Foundation

/// Reads vgmstream's generic header format without opening the payload codec.
/// GENH carries its own stream identity fallback, timing, and layout facts.
enum GENHMetadataReader {
    private static let fixedHeaderSize = 0x24
    private static let extendedHeaderSize = 0x100
    private static let maximumHeaderSize = 1 * 1024 * 1024
    private static let metadataSource = "GENH generic header"
    private static let codecNames: [UInt32: String] = [
        0: "PlayStation ADPCM",
        1: "Xbox IMA ADPCM",
        2: "Nintendo GameCube DTK ADPCM",
        3: "16-bit big-endian PCM",
        4: "16-bit little-endian PCM",
        5: "signed 8-bit PCM",
        6: "SDX2 ADPCM",
        7: "DVI IMA ADPCM",
        8: "MPEG audio",
        9: "IMA ADPCM",
        10: "Yamaha AICA ADPCM",
        11: "Microsoft ADPCM",
        12: "Nintendo DSP ADPCM",
        13: "interleaved unsigned 8-bit PCM",
        14: "PlayStation ADPCM with bad flags",
        15: "Microsoft IMA ADPCM",
        16: "unsigned 8-bit PCM",
        17: "Apple IMA4",
        18: "ATRAC3",
        19: "ATRAC3plus",
        20: "XMA1",
        21: "XMA2",
        22: "FFmpeg-supported audio",
        23: "AC-3",
        24: "PC-FX ADPCM",
        25: "signed 4-bit PCM",
        26: "unsigned 4-bit PCM",
        27: "OKI ADPCM",
        28: "AAC"
    ]

    private struct Header {
        let channels: Int64
        let interleave: UInt32
        let sampleRate: Int64
        let loopStart: Int64
        let loopEnd: Int64
        let codecID: UInt32
        let audioOffset: Int
        let declaredHeaderSize: Int
        let headerSize: Int
        let sampleCount: Int64
        let skipSamples: Int64
        let skipSamplesMode: Int
        let codecMode: Int
        let dataSize: Int64
        let interleaveLast: UInt32
        let coefficientOffset: UInt32?
        let coefficientSpacing: Int32?
        let coefficientInterleaveType: UInt32?
        let coefficientType: UInt32?
        let splitCoefficientOffset: UInt32?
        let splitCoefficientSpacing: Int32?
    }

    static func matches(_ data: Data) -> Bool {
        (try? parseHeader(data, fileSize: Int64(data.count))) != nil
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("genh") == .orderedSame,
              let fileSize = regularFileSize(at: fileURL),
              fileSize >= Int64(fixedHeaderSize),
              let prefix = try? readPrefix(from: fileURL, count: maximumHeaderSize) else {
            return false
        }
        return (try? parseHeader(prefix, fileSize: fileSize)) != nil
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        guard fileURL.pathExtension.caseInsensitiveCompare("genh") == .orderedSame else {
            throw unsupported("GENH extension")
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let header = try parseHeader(data, fileSize: Int64(data.count))
        return makeDocument(header: header, data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        let header = try parseHeader(data, fileSize: Int64(data.count))
        return makeDocument(header: header, data: data, displayName: displayName)
    }

    private static func parseHeader(_ data: Data, fileSize: Int64) throws -> Header {
        guard data.count >= fixedHeaderSize, fileSize >= Int64(fixedHeaderSize) else {
            throw malformed("fixed header is truncated.")
        }
        guard Data(data.prefix(4)) == Data("GENH".utf8) else {
            throw unsupported("GENH signature")
        }
        guard let channelsRaw = genhUInt32LE(data, at: 0x04),
              let interleave = genhUInt32LE(data, at: 0x08),
              let sampleRateRaw = genhUInt32LE(data, at: 0x0C),
              let loopStartRaw = genhUInt32LE(data, at: 0x10),
              let loopEndRaw = genhUInt32LE(data, at: 0x14),
              let codecID = genhUInt32LE(data, at: 0x18),
              let audioOffsetRaw = genhUInt32LE(data, at: 0x1C),
              let declaredHeaderSizeRaw = genhUInt32LE(data, at: 0x20) else {
            throw malformed("fixed header fields are truncated.")
        }
        guard codecNames[codecID] != nil else {
            throw malformed("codec ID is not recognized by the GENH layout.")
        }

        let channels = Int64(Int32(bitPattern: channelsRaw))
        let sampleRate = Int64(Int32(bitPattern: sampleRateRaw))
        let loopStart = Int64(Int32(bitPattern: loopStartRaw))
        let loopEnd = Int64(Int32(bitPattern: loopEndRaw))
        let declaredHeaderSize = Int(declaredHeaderSizeRaw)
        let headerSize = declaredHeaderSize == 0 ? 0x800 : declaredHeaderSize
        // vgmstream's legacy-size compatibility rule resets both values.
        let audioOffset = declaredHeaderSize == 0 ? 0x800 : Int(audioOffsetRaw)

        guard headerSize >= fixedHeaderSize,
              headerSize <= maximumHeaderSize,
              headerSize <= audioOffset,
              headerSize <= data.count,
              audioOffset < fileSize,
              channels > 0,
              channels <= 32,
              sampleRate > 0,
              sampleRate <= 768_000 else {
            throw malformed("header size, audio offset, channel count, or sample rate is invalid.")
        }

        var sampleCount = loopEnd
        var skipSamples: Int64 = 0
        var skipSamplesMode = 0
        var codecMode = 0
        var dataSize: Int64 = fileSize - Int64(audioOffset)
        var interleaveLast: UInt32 = 0
        var coefficientOffset: UInt32?
        var coefficientSpacing: Int32?
        var coefficientInterleaveType: UInt32?
        var coefficientType: UInt32?
        var splitCoefficientOffset: UInt32?
        var splitCoefficientSpacing: Int32?

        if headerSize >= 0x30 {
            guard let firstCoefficientOffset = genhUInt32LE(data, at: 0x24),
                  let secondCoefficientValue = genhUInt32LE(data, at: 0x28),
                  let interleaveType = genhUInt32LE(data, at: 0x2C) else {
                throw malformed("DSP coefficient fields are truncated.")
            }
            coefficientOffset = firstCoefficientOffset
            coefficientSpacing = channels == 2
                ? Int32(bitPattern: secondCoefficientValue &- firstCoefficientOffset)
                : Int32(bitPattern: secondCoefficientValue)
            coefficientInterleaveType = interleaveType
        }
        if headerSize >= 0x34 {
            guard let type = genhUInt32LE(data, at: 0x30) else {
                throw malformed("coefficient variant field is truncated.")
            }
            coefficientType = type
        }
        if headerSize >= 0x3C {
            guard let splitOffset = genhUInt32LE(data, at: 0x34),
                  let splitSpacingValue = genhUInt32LE(data, at: 0x38) else {
                throw malformed("split DSP coefficient fields are truncated.")
            }
            splitCoefficientOffset = splitOffset
            splitCoefficientSpacing = channels == 2
                ? Int32(bitPattern: splitSpacingValue &- splitOffset)
                : Int32(bitPattern: splitSpacingValue)
        }
        if headerSize >= extendedHeaderSize {
            guard let sampleCountRaw = genhUInt32LE(data, at: 0x40),
                  let skipSamplesRaw = genhUInt32LE(data, at: 0x44),
                  let skipMode = genhUInt8(data, at: 0x48),
                  let fallbackCodecMode = genhUInt8(data, at: 0x4B),
                  let dataSizeRaw = genhUInt32LE(data, at: 0x50),
                  let lastInterleave = genhUInt32LE(data, at: 0x54) else {
                throw malformed("extended header fields are truncated.")
            }
            let declaredSamples = Int64(Int32(bitPattern: sampleCountRaw))
            if declaredSamples > 0 { sampleCount = declaredSamples }
            skipSamples = Int64(Int32(bitPattern: skipSamplesRaw))
            skipSamplesMode = Int(skipMode)
            codecMode = Int(fallbackCodecMode)
            if codecMode == 0, [18, 19].contains(codecID), let mode = genhUInt8(data, at: 0x49) {
                codecMode = Int(mode)
            }
            if codecMode == 0, [20, 21].contains(codecID), let mode = genhUInt8(data, at: 0x4A) {
                codecMode = Int(mode)
            }
            if dataSizeRaw > 0 { dataSize = Int64(dataSizeRaw) }
            interleaveLast = lastInterleave
        }

        guard sampleCount > 0 else {
            throw malformed("header does not declare a positive sample count.")
        }

        return Header(
            channels: channels,
            interleave: interleave,
            sampleRate: sampleRate,
            loopStart: loopStart,
            loopEnd: loopEnd,
            codecID: codecID,
            audioOffset: audioOffset,
            declaredHeaderSize: declaredHeaderSize,
            headerSize: headerSize,
            sampleCount: sampleCount,
            skipSamples: skipSamples,
            skipSamplesMode: skipSamplesMode,
            codecMode: codecMode,
            dataSize: dataSize,
            interleaveLast: interleaveLast,
            coefficientOffset: coefficientOffset,
            coefficientSpacing: coefficientSpacing,
            coefficientInterleaveType: coefficientInterleaveType,
            coefficientType: coefficientType,
            splitCoefficientOffset: splitCoefficientOffset,
            splitCoefficientSpacing: splitCoefficientSpacing
        )
    }

    private static func makeDocument(
        header: Header,
        data: Data,
        displayName: String?
    ) -> MetadataDocument {
        let loopEnabled = header.loopStart >= 0
            && header.loopEnd > header.loopStart
            && header.loopEnd <= header.sampleCount
        let loopSamples = loopEnabled ? header.loopEnd - header.loopStart : 0
        let playSamples = loopEnabled
            ? header.loopStart + loopSamples * 2 + header.sampleRate * 10
            : header.sampleCount
        var facts: [String: String] = [
            "metadataSource": metadataSource,
            "channels": String(header.channels),
            "interleaveBytes": String(header.interleave),
            "sampleRateHz": String(header.sampleRate),
            "loopStartSample": String(header.loopStart),
            "loopEndSample": String(header.loopEnd),
            "loopEnabled": String(loopEnabled),
            "codecId": String(header.codecID),
            "codecName": codecNames[header.codecID] ?? "Unknown GENH codec \(header.codecID)",
            "audioOffset": String(header.audioOffset),
            "declaredHeaderSize": String(header.declaredHeaderSize),
            "headerSize": String(header.headerSize),
            "dataSize": String(header.dataSize),
            "payloadBytes": String(data.count - header.audioOffset),
            "sampleCount": String(header.sampleCount),
            "playSamples": String(playSamples)
        ]
        if header.headerSize >= 0x100 {
            facts["skipSamples"] = String(header.skipSamples)
            facts["skipSamplesMode"] = String(header.skipSamplesMode)
            facts["codecMode"] = String(header.codecMode)
            facts["interleaveLastBytes"] = String(header.interleaveLast)
        }
        if let coefficientOffset = header.coefficientOffset {
            facts["coefficientOffset"] = String(coefficientOffset)
            facts["coefficientSpacing"] = String(header.coefficientSpacing ?? 0)
            facts["coefficientInterleaveType"] = String(header.coefficientInterleaveType ?? 0)
        }
        if let coefficientType = header.coefficientType {
            facts["coefficientType"] = String(coefficientType)
        }
        if let splitCoefficientOffset = header.splitCoefficientOffset {
            facts["splitCoefficientOffset"] = String(splitCoefficientOffset)
            facts["splitCoefficientSpacing"] = String(header.splitCoefficientSpacing ?? 0)
        }
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }

        return MetadataDocument(
            format: "genh",
            fields: MetadataFields(title: title, comment: metadataSource),
            rawMetadataBlocks: ["genhHeader": Data(data.prefix(header.headerSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: genhMilliseconds(samples: loopSamples, sampleRate: header.sampleRate),
                playLengthMs: genhMilliseconds(samples: playSamples, sampleRate: header.sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func readPrefix(from fileURL: URL, count: Int) throws -> Data {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        return try file.read(upToCount: count) ?? Data()
    }

    private static func regularFileSize(at fileURL: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    private static func genhMilliseconds(samples: Int64, sampleRate: Int64) -> Int {
        Int(samples * 1_000 / sampleRate)
    }

    private static func genhUInt8(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func genhUInt32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset <= data.count - 4 else { return nil }
        return UInt32(data[offset]) | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private static func unsupported(_ format: String) -> MetadataReadError {
        .unsupportedFormat(format)
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("GENH metadata reader: \(message)")
    }
}
