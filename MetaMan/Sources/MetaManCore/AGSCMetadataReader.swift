import Foundation

/// Reads Retro Studios AGSC bank headers without opening DSP playback.
/// The audio chunk is bounds-checked but never decoded or copied.
enum AGSCMetadataReader {
    private static let nameLimit = 0x20
    private static let recordSize = 0x20
    private static let coefficientSize = 0x28
    private static let maximumTracks = 1_000
    private static let metadataSource = "Retro Studios AGSC header"

    private struct Entry {
        let recordOffset: Int
        let dataOffset: Int
        let sampleRate: Int64
        let sampleCount: Int64
        let loopStart: Int64
        let loopLength: Int64
        let coefficientsOffset: Int
    }

    private struct Bank {
        let version: Int
        let name: String
        let nameRange: Range<Int>
        let unknownChunk1: Range<Int>
        let unknownChunk2: Range<Int>
        let unknownChunk1Size: Int
        let unknownChunk2Size: Int
        let headerOffset: Int
        let headerSize: Int
        let dataOffset: Int
        let dataSize: Int
        let entries: [Entry]
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("agsc") == .orderedSame,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              attributes[.type] as? FileAttributeType == .typeRegular,
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            return false
        }
        return (try? parse(data)) != nil
    }

    static func matches(_ data: Data) -> Bool {
        (try? parse(data)) != nil
    }

    static func readResult(fileURL: URL) throws -> MetadataReadResult {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try readResult(data: data)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        _ = displayName
        let result = try readResult(data: data)
        throw MetadataReadError.trackAwareResultRequired(
            result.tracks.first?.document.format.uppercased() ?? "AGSC"
        )
    }

    static func readResult(data: Data, displayName: String?) throws -> MetadataReadResult {
        _ = displayName
        return try readResult(data: data)
    }

    private static func readResult(data: Data) throws -> MetadataReadResult {
        let bank = try parse(data)
        let tracks = bank.entries.enumerated().map { index, entry in
            let loopFrames = entry.loopLength > 0 ? entry.loopLength - 1 : 0
            let playFrames = entry.loopLength > 0
                ? entry.loopStart + loopFrames * 2 + entry.sampleRate * 10
                : entry.sampleCount
            let playMilliseconds = milliseconds(samples: playFrames, rate: entry.sampleRate)
            let loopMilliseconds = milliseconds(samples: loopFrames, rate: entry.sampleRate)
            let streamSize = entry.sampleCount / 14 * 8
            var facts: [String: String] = [
                "metadataSource": metadataSource,
                "version": String(bank.version),
                "streamName": bank.name,
                "sourceTrackIndex": String(index + 1),
                "trackCount": String(bank.entries.count),
                "headerOffset": String(bank.headerOffset),
                "headerSize": String(bank.headerSize),
                "recordOffset": String(entry.recordOffset),
                "dataOffset": String(bank.dataOffset),
                "dataSize": String(bank.dataSize),
                "streamOffset": String(entry.dataOffset),
                "streamSizeBytes": String(streamSize),
                "sampleRateHz": String(entry.sampleRate),
                "sampleCount": String(entry.sampleCount),
                "playSampleCount": String(playFrames),
                "channels": "1",
                "codec": "Nintendo GameCube DSP ADPCM",
                "loopDeclared": String(entry.loopLength > 0),
                "loopStartSample": String(entry.loopStart),
                "loopLengthSamples": String(entry.loopLength),
                "loopEndSampleInclusive": String(entry.loopLength > 0 ? entry.loopStart + entry.loopLength - 1 : 0),
                "coefficientsOffset": String(entry.coefficientsOffset)
            ]
            facts["unknownChunk1Size"] = String(bank.unknownChunk1Size)
            facts["unknownChunk2Size"] = String(bank.unknownChunk2Size)

            let coefficientRange = entry.coefficientsOffset..<(entry.coefficientsOffset + coefficientSize)
            let document = MetadataDocument(
                format: "agsc",
                fields: MetadataFields(title: bank.name, comment: metadataSource),
                rawMetadataBlocks: [
                    "agscName": Data(data[bank.nameRange]),
                    "agscUnknownChunk1": Data(data[bank.unknownChunk1]),
                    "agscUnknownChunk2": Data(data[bank.unknownChunk2]),
                    "agscStreamRecord": Data(data[entry.recordOffset..<(entry.recordOffset + recordSize)]),
                    "agscCoefficients": Data(data[coefficientRange])
                ],
                timing: MetadataTiming(
                    introLengthMs: 0,
                    loopLengthMs: loopMilliseconds,
                    playLengthMs: playMilliseconds,
                    fadeLengthMs: 0
                ),
                technicalFacts: facts
            )
            return MetadataTrack(sourceTrackIndex: index + 1, document: document)
        }
        return MetadataReadResult(tracks: tracks)
    }

    private static func parse(_ data: Data) throws -> Bank {
        let version: Int
        if data.count >= 4, data.prefix(4) == Data("Audi".utf8) {
            version = 1
        } else if uint32BE(data, at: 0) == 1 {
            version = 2
        } else {
            throw unsupported()
        }

        var offset = version == 1 ? 0 : 4
        if version == 1 {
            let (prefix, _, nextOffset) = try readName(data, at: offset)
            guard prefix.hasPrefix("Audi") else { throw malformed("Version 1 bank prefix is invalid.") }
            offset = nextOffset
        }
        let (name, nameRange, afterName) = try readName(data, at: offset)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw malformed("AGSC stream name is empty.")
        }
        offset = afterName

        var unknown1Size = 0
        var unknown2Size = 0
        var unknown1 = 0..<0
        var unknown2 = 0..<0
        var headerOffset: Int
        var headerSize: Int
        var dataOffset: Int
        var dataSize: Int

        if version == 1 {
            (unknown1Size, unknown1, offset) = try readSizedChunk(data, at: offset)
            (unknown2Size, unknown2, offset) = try readSizedChunk(data, at: offset)
            let dataChunk = try readSizedChunk(data, at: offset)
            dataSize = dataChunk.0
            dataOffset = dataChunk.1.lowerBound
            let headerChunk = try readSizedChunk(data, at: dataChunk.2)
            headerSize = headerChunk.0
            headerOffset = headerChunk.1.lowerBound
        } else {
            guard contains(data, at: offset, count: 2) else { throw malformed("Version 2 song-id field is truncated.") }
            offset += 2
            guard contains(data, at: offset, count: 16),
                  let u1 = uint32BE(data, at: offset),
                  let u2 = uint32BE(data, at: offset + 4),
                  let head = uint32BE(data, at: offset + 8),
                  let audio = uint32BE(data, at: offset + 12) else {
                throw malformed("Version 2 AGSC chunk-size table is truncated.")
            }
            unknown1Size = Int(u1)
            unknown2Size = Int(u2)
            headerSize = Int(head)
            dataSize = Int(audio)
            let unknownChunksStart = offset + 16
            guard let secondChunkStart = checkedAdd(unknownChunksStart, unknown1Size),
                  let headerStart = checkedAdd(secondChunkStart, unknown2Size),
                  contains(data, at: unknownChunksStart, count: unknown1Size),
                  contains(data, at: secondChunkStart, count: unknown2Size),
                  contains(data, at: headerStart, count: headerSize),
                  let audioStart = checkedAdd(headerStart, headerSize),
                  contains(data, at: audioStart, count: dataSize) else {
                throw malformed("Version 2 AGSC chunks extend beyond the source file.")
            }
            unknown1 = unknownChunksStart..<(unknownChunksStart + unknown1Size)
            unknown2 = secondChunkStart..<(secondChunkStart + unknown2Size)
            headerOffset = headerStart
            dataOffset = audioStart
        }

        guard dataSize > 0, headerSize >= 0x20 + 4 + 0x28,
              contains(data, at: headerOffset, count: headerSize),
              contains(data, at: dataOffset, count: dataSize) else {
            throw malformed("AGSC data/header chunk sizes are empty or out of bounds.")
        }
        let trackCount = (headerSize - 4) / (recordSize + coefficientSize)
        guard (1...maximumTracks).contains(trackCount) else {
            throw malformed("AGSC declares no tracks or exceeds the safe 1,000-track limit.")
        }

        var entries: [Entry] = []
        entries.reserveCapacity(trackCount)
        for index in 0..<trackCount {
            let recordOffset = headerOffset + recordSize * index
            guard let relativeDataOffset = uint32BE(data, at: recordOffset + 4),
                  let sampleRate = uint16BE(data, at: recordOffset + 0x0E),
                  let sampleCountRaw = int32BE(data, at: recordOffset + 0x10),
                  let loopStartRaw = int32BE(data, at: recordOffset + 0x14),
                  let loopLengthRaw = int32BE(data, at: recordOffset + 0x18),
                  let coefficientsRelativeOffset = int32BE(data, at: recordOffset + 0x1C) else {
                throw malformed("AGSC track \(index + 1) record is truncated.")
            }
            let sampleCount = Int64(sampleCountRaw)
            let loopStart = Int64(loopStartRaw)
            let loopLength = Int64(loopLengthRaw)
            let streamOffset = Int(relativeDataOffset)
            let streamSize = sampleCount > 0 ? sampleCount / 14 * 8 : 0
            let coefficientsOffsetValue = Int64(headerOffset) + 8 + Int64(coefficientsRelativeOffset)
            guard sampleRate > 0, sampleCount > 0, loopStart >= 0, loopLength >= 0,
                  loopLength == 0 || (loopStart < sampleCount && loopStart + loopLength - 1 < sampleCount),
                  streamOffset <= dataSize, streamSize > 0,
                  streamSize <= Int64(dataSize - streamOffset),
                  coefficientsRelativeOffset >= 0,
                  coefficientsOffsetValue <= Int64(Int.max),
                  let coefficientsOffset = Int(exactly: coefficientsOffsetValue),
                  coefficientsOffset >= headerOffset,
                  contains(data, at: coefficientsOffset, count: coefficientSize) else {
                throw malformed("AGSC track \(index + 1) contains invalid sample, loop, stream, or coefficient bounds.")
            }
            entries.append(Entry(
                recordOffset: recordOffset,
                dataOffset: dataOffset + streamOffset,
                sampleRate: Int64(sampleRate),
                sampleCount: sampleCount,
                loopStart: loopStart,
                loopLength: loopLength,
                coefficientsOffset: coefficientsOffset
            ))
        }

        return Bank(
            version: version,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            nameRange: nameRange,
            unknownChunk1: unknown1,
            unknownChunk2: unknown2,
            unknownChunk1Size: unknown1Size,
            unknownChunk2Size: unknown2Size,
            headerOffset: headerOffset,
            headerSize: headerSize,
            dataOffset: dataOffset,
            dataSize: dataSize,
            entries: entries
        )
    }

    private static func readName(_ data: Data, at offset: Int) throws -> (String, Range<Int>, Int) {
        guard offset >= 0, offset < data.count else { throw malformed("AGSC name starts outside the source file.") }
        var bytes: [UInt8] = []
        for index in 0..<nameLimit {
            guard contains(data, at: offset + index, count: 1) else {
                throw malformed("AGSC name is truncated.")
            }
            let byte = data[offset + index]
            if byte == 0 {
                let end = offset + index + 1
                return (String(decoding: bytes, as: UTF8.self), offset..<end, end)
            }
            guard (0x20...0xF0).contains(byte) else { throw malformed("AGSC name contains an invalid byte.") }
            bytes.append(byte)
        }
        let end = offset + nameLimit + 1
        guard contains(data, at: offset, count: nameLimit + 1) else {
            throw malformed("AGSC fixed-width name field is truncated.")
        }
        return (String(decoding: bytes, as: UTF8.self), offset..<end, end)
    }

    private static func readSizedChunk(_ data: Data, at offset: Int) throws -> (Int, Range<Int>, Int) {
        guard let sizeRaw = uint32BE(data, at: offset),
              let payloadOffset = checkedAdd(offset, 4),
              let end = checkedAdd(payloadOffset, Int(sizeRaw)),
              contains(data, at: payloadOffset, count: Int(sizeRaw)) else {
            throw malformed("AGSC size-prefixed chunk is truncated or out of bounds.")
        }
        return (Int(sizeRaw), payloadOffset..<end, end)
    }

    private static func milliseconds(samples: Int64, rate: Int64) -> Int {
        Int(samples * 1_000 / rate)
    }

    private static func contains(_ data: Data, at offset: Int, count: Int) -> Bool {
        offset >= 0 && count >= 0 && offset <= data.count && count <= data.count - offset
    }

    private static func checkedAdd(_ lhs: Int, _ rhs: Int) -> Int? {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? nil : value
    }

    private static func uint16BE(_ data: Data, at offset: Int) -> UInt16? {
        guard contains(data, at: offset, count: 2) else { return nil }
        return UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard contains(data, at: offset, count: 4) else { return nil }
        return UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }

    private static func int32BE(_ data: Data, at offset: Int) -> Int32? {
        uint32BE(data, at: offset).map(Int32.init(bitPattern:))
    }

    private static func unsupported() -> MetadataReadError {
        .unsupportedFormat("Retro Studios AGSC bank")
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("AGSC metadata reader: \(message)")
    }
}
