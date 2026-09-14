import Foundation

/// Reads ATRAC3/ATRAC3+ metadata in RIFF/WAVE without initializing FFmpeg or
/// decoding audio. RIFF chunk bytes other than `data` remain available as
/// named raw blocks for clients that need fields this reader does not project.
enum RIFFATRAC3MetadataReader {
    private static let atrac3PlusGUID = Data([
        0xBF, 0xAA, 0x23, 0xE9, 0x58, 0xCB, 0x71, 0x44,
        0xA1, 0x19, 0xFF, 0xFA, 0x01, 0xE4, 0xCE, 0x62
    ])
    private static let maximumChunks = 256
    private static let maximumRetainedChunkBytes = 16 * 1024 * 1024

    private struct Chunk {
        let identifier: String
        let offset: Int
        let payloadOffset: Int
        let payloadEnd: Int
        let paddedEnd: Int

        var payloadSize: Int { payloadEnd - payloadOffset }
        var rawSize: Int { paddedEnd - offset }
    }

    static func matches(_ data: Data) -> Bool {
        guard data.count >= 12,
              fourCC(data, at: 0) == "RIFF",
              fourCC(data, at: 8) == "WAVE",
              let riffSize = uint32LE(data, at: 4),
              UInt64(riffSize) + 8 == UInt64(data.count),
              let chunks = try? scanChunks(data) else { return false }
        return chunks.first(where: { $0.identifier == "fmt " }).flatMap { chunk in
            isSupportedFormat(Data(data[chunk.payloadOffset..<chunk.payloadEnd]))
        } ?? false
    }

    static func supports(fileURL: URL) -> Bool {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let fileSize = try handle.seekToEnd()
            guard fileSize >= 20 else { return false }
            try handle.seek(toOffset: 0)
            guard let header = try handle.read(upToCount: 12),
                  header.count == 12,
                  header.prefix(4) == Data("RIFF".utf8),
                  header.subdata(in: 8..<12) == Data("WAVE".utf8),
                  let riffSize = uint32LE(header, at: 4),
                  UInt64(riffSize) + 8 == fileSize else { return false }

            var offset: UInt64 = 12
            var chunksRead = 0
            while offset <= fileSize - 8, chunksRead < maximumChunks {
                try handle.seek(toOffset: offset)
                guard let chunkHeader = try handle.read(upToCount: 8),
                      chunkHeader.count == 8,
                      let rawSize = uint32LE(chunkHeader, at: 4) else { return false }
                let payloadOffset = offset + 8
                let payloadSize = UInt64(rawSize)
                guard payloadSize <= fileSize - payloadOffset else { return false }
                let payloadEnd = payloadOffset + payloadSize
                let paddedEnd = payloadEnd + (payloadSize & 1)
                guard paddedEnd <= fileSize else { return false }

                if chunkHeader.prefix(4) == Data("fmt ".utf8) {
                    guard payloadSize >= 16, payloadSize <= 1_024 else { return false }
                    try handle.seek(toOffset: payloadOffset)
                    let amount = Int(min(payloadSize, 40))
                    guard let format = try handle.read(upToCount: amount),
                          format.count == amount else { return false }
                    return isSupportedFormat(format)
                }

                offset = paddedEnd
                chunksRead += 1
            }
        } catch {
            return false
        }
        return false
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= 12,
              fourCC(data, at: 0) == "RIFF",
              fourCC(data, at: 8) == "WAVE",
              let riffSize = uint32LE(data, at: 4),
              UInt64(riffSize) + 8 == UInt64(data.count) else {
            throw malformed("Invalid RIFF/WAVE boundary.")
        }

        let chunks = try scanChunks(data)
        var format: Data?
        var sampleCount: Int64 = 0
        var sampleSkip: Int64 = 0
        var smplLoopStart: Int64 = 0
        var smplLoopEnd: Int64 = 0
        var hasSMPLLoop = false
        var wsmpLoopStart: Int64 = 0
        var wsmpLoopEnd: Int64 = 0
        var hasWSMPLoop = false
        var dataChunkSize: Int64 = 0
        var dataChunkCount = 0
        var tags: [MetadataTag] = []
        var rawInfoTagBlock: Data?
        var infoSourceEncodings: Set<String> = []
        var rawBlocks: [String: Data] = ["riffHeader": Data(data.prefix(12))]
        var retainedBytes = 12
        var diagnostics: [String] = []
        var occurrences: [String: Int] = [:]
        var rawRetentionLimited = false

        for chunk in chunks {
            let payload = data[chunk.payloadOffset..<chunk.payloadEnd]
            switch chunk.identifier {
            case "fmt ":
                guard format == nil else { throw malformed("Duplicate RIFF fmt chunk.") }
                guard chunk.payloadSize <= 1_024 else { throw malformed("RIFF fmt chunk is excessive.") }
                let bytes = Data(payload)
                guard isSupportedFormat(bytes) else {
                    throw malformed("RIFF codec is not ATRAC3 or ATRAC3+.")
                }
                format = bytes

            case "fact":
                if chunk.payloadSize == 4, let value = int32LE(data, at: chunk.payloadOffset) {
                    sampleCount = Int64(value)
                } else if let format, isATRAC3Format(format), chunk.payloadSize == 8 || chunk.payloadSize == 12 {
                    guard let count = int32LE(data, at: chunk.payloadOffset),
                          let skip = int32LE(data, at: chunk.payloadOffset + 4) else {
                        throw malformed("Truncated ATRAC3 fact chunk.")
                    }
                    sampleCount = Int64(count)
                    sampleSkip = Int64(skip)
                }

            case "smpl":
                // vgmstream accepts exactly one forward loop point.
                if chunk.payloadSize >= 0x3C,
                   uint32LE(data, at: chunk.payloadOffset + 0x1C) == 1,
                   uint32LE(data, at: chunk.payloadOffset + 0x28) == 0,
                   let start = int32LE(data, at: chunk.payloadOffset + 0x2C),
                   let end = int32LE(data, at: chunk.payloadOffset + 0x30) {
                    smplLoopStart = Int64(start)
                    smplLoopEnd = Int64(end)
                    hasSMPLLoop = true
                }

            case "wsmp":
                if chunk.payloadSize >= 0x24,
                   uint32LE(data, at: chunk.payloadOffset) == 0x14,
                   (int32LE(data, at: chunk.payloadOffset + 0x10) ?? 0) > 0,
                   uint32LE(data, at: chunk.payloadOffset + 0x14) == 0x10,
                   uint32LE(data, at: chunk.payloadOffset + 0x18) == 0,
                   let start = int32LE(data, at: chunk.payloadOffset + 0x1C),
                   let length = int32LE(data, at: chunk.payloadOffset + 0x20) {
                    wsmpLoopStart = Int64(start)
                    wsmpLoopEnd = Int64(start) + Int64(length)
                    hasWSMPLoop = true
                }

            case "LIST":
                let decoded = parseInfoList(data, chunk: chunk)
                tags.append(contentsOf: decoded.tags)
                if rawInfoTagBlock == nil,
                   chunk.payloadSize >= 4,
                   fourCC(data, at: chunk.payloadOffset) == "INFO" {
                    rawInfoTagBlock = Data(payload)
                }
                if let encoding = decoded.sourceEncoding { infoSourceEncodings.insert(encoding) }
                if let diagnostic = decoded.diagnostic { diagnostics.append(diagnostic) }

            case "data":
                dataChunkCount += 1
                dataChunkSize = Int64(chunk.payloadSize)

            default:
                break
            }

            guard chunk.identifier != "data" else { continue }
            let occurrence = occurrences[chunk.identifier, default: 0]
            occurrences[chunk.identifier] = occurrence + 1
            if chunk.rawSize <= maximumRetainedChunkBytes - retainedBytes {
                rawBlocks["riffChunk.\(chunk.identifier)#\(occurrence)"] = Data(data[chunk.offset..<chunk.paddedEnd])
                retainedBytes += chunk.rawSize
            } else if !rawRetentionLimited {
                diagnostics.append("RIFF non-audio chunk bytes exceed the 16 MiB raw-metadata retention limit; omitted chunk bytes remain identified in technicalFacts.")
                rawRetentionLimited = true
            }
        }

        guard let format, isSupportedFormat(format), dataChunkCount == 1 else {
            throw malformed("Missing ATRAC3 fmt or single data chunk.")
        }
        guard let codec = uint16LE(format, at: 0),
              let channels = uint16LE(format, at: 2),
              let sampleRate = uint32LE(format, at: 4),
              let averageBytesPerSecond = uint32LE(format, at: 8),
              let blockAlign = uint16LE(format, at: 12),
              let bitsPerSample = uint16LE(format, at: 14) else {
            throw malformed("Truncated ATRAC3 fmt chunk.")
        }

        let hasLoop = hasSMPLLoop || hasWSMPLoop
        if hasLoop {
            // vgmstream adjusts smpl points by the encoder skip; wsmp points
            // already use their native start/length representation.
            smplLoopStart -= sampleSkip
            smplLoopEnd -= sampleSkip
            if sampleCount == 0 { sampleCount = smplLoopEnd + 1 }
        }

        let activeLoop: (start: Int64, end: Int64, smpl: Bool)
        if hasSMPLLoop {
            activeLoop = (smplLoopStart, smplLoopEnd + 1, true)
        } else if hasWSMPLoop {
            activeLoop = (wsmpLoopStart, wsmpLoopEnd, false)
        } else {
            activeLoop = (0, 0, false)
        }
        let loopEndExclusive = activeLoop.smpl && activeLoop.end - 1 == sampleCount
            ? activeLoop.end - 1
            : activeLoop.end
        let loopFrames = hasLoop ? max(0, loopEndExclusive - activeLoop.start) : 0
        let rate = Int64(max(1, sampleRate))
        let playFrames: Int64
        if hasLoop {
            playFrames = max(0, activeLoop.start + loopFrames * 2 + Int64(sampleRate) * 10)
        } else {
            playFrames = max(0, sampleCount)
        }

        let tagValues = Dictionary(grouping: tags, by: { $0.name.uppercased() })
        func firstValue(_ key: String) -> String? {
            tagValues[key]?.map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty })
        }

        let fallbackTitle = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let title = firstValue("INAM") ?? fallbackTitle
        let product = firstValue("IPRD")
        let comment = firstValue("ICMT") ?? (hasSMPLLoop
            ? "RIFF WAVE header (smpl looping)"
            : (hasWSMPLoop ? "RIFF WAVE header (wsmp looping)" : "RIFF WAVE header"))

        var facts: [String: String] = [
            "container": "RIFF/WAVE",
            "riffSizeBytes": String(riffSize),
            "fileSizeBytes": String(data.count),
            "codecTag": String(codec),
            "codecTagHex": "0x\(String(codec, radix: 16))",
            "codecName": codec == 0x0270 ? "ATRAC3" : "ATRAC3+",
            "channels": String(channels),
            "sampleRateHz": String(sampleRate),
            "averageBytesPerSecond": String(averageBytesPerSecond),
            "blockAlignBytes": String(blockAlign),
            "bitsPerSample": String(bitsPerSample),
            "factSampleCount": String(sampleCount),
            "encoderSkipSamples": String(sampleSkip),
            "dataChunkCount": String(dataChunkCount),
            "dataChunkBytes": String(dataChunkSize),
            "loopSource": hasSMPLLoop ? "smpl" : (hasWSMPLoop ? "wsmp" : "none"),
            "loopEnabled": String(hasLoop),
            "rawSMPLLoopStartSample": String(hasSMPLLoop ? smplLoopStart + sampleSkip : 0),
            "rawSMPLLoopEndSample": String(hasSMPLLoop ? smplLoopEnd + sampleSkip : 0),
            "rawWSMPLoopStartSample": String(hasWSMPLoop ? wsmpLoopStart : 0),
            "rawWSMPLoopEndSample": String(hasWSMPLoop ? wsmpLoopEnd : 0),
            "effectiveLoopStartSample": String(hasLoop ? activeLoop.start : 0),
            "effectiveLoopEndSampleExclusive": String(hasLoop ? loopEndExclusive : 0),
            "loopLengthSamples": String(loopFrames),
            "metadataSource": comment,
            "riffChunkIDs": chunks.map(\.identifier).joined(separator: ",")
        ]
        if let extensionSize = uint16LE(format, at: 16) {
            facts["formatExtensionBytes"] = String(extensionSize)
        }
        if codec == 0xFFFE {
            if let validBits = uint16LE(format, at: 18) { facts["validBitsPerSample"] = String(validBits) }
            if let channelMask = uint32LE(format, at: 20) { facts["channelMask"] = String(channelMask) }
            if format.count >= 40 {
                facts["subFormatGUID"] = format[24..<40].map { String(format: "%02x", $0) }.joined()
            }
        }
        if !tags.isEmpty { facts["infoTagCount"] = String(tags.count) }
        if !infoSourceEncodings.isEmpty { facts["infoTagEncodings"] = infoSourceEncodings.sorted().joined(separator: ",") }

        return MetadataDocument(
            format: "at3",
            fields: MetadataFields(
                title: title,
                game: product,
                artist: firstValue("IART"),
                album: product,
                date: firstValue("ICRD"),
                genre: firstValue("IGNR"),
                comment: comment,
                copyright: firstValue("ICOP"),
                encodedBy: firstValue("ISFT")
            ),
            tags: tags,
            rawTagBlock: rawInfoTagBlock,
            rawMetadataBlocks: rawBlocks,
            sourceEncoding: infoSourceEncodings.count == 1 ? infoSourceEncodings.first : nil,
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopFrames * 1_000 / rate),
                playLengthMs: Int(playFrames * 1_000 / rate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func scanChunks(_ data: Data) throws -> [Chunk] {
        var chunks: [Chunk] = []
        var offset = 12
        while offset < data.count {
            guard chunks.count < maximumChunks else { throw malformed("RIFF has too many chunks.") }
            guard data.count - offset >= 8,
                  let identifier = fourCC(data, at: offset),
                  let rawSize = uint32LE(data, at: offset + 4) else {
                throw malformed("Truncated RIFF chunk header.")
            }
            let payloadOffset = offset + 8
            let size = Int(rawSize)
            guard size <= data.count - payloadOffset else {
                throw malformed("RIFF chunk extends beyond the file.")
            }
            let payloadEnd = payloadOffset + size
            let paddedEnd = payloadEnd + (size & 1)
            guard paddedEnd <= data.count else { throw malformed("Missing RIFF chunk padding.") }
            chunks.append(Chunk(
                identifier: identifier,
                offset: offset,
                payloadOffset: payloadOffset,
                payloadEnd: payloadEnd,
                paddedEnd: paddedEnd
            ))
            offset = paddedEnd
        }
        return chunks
    }

    private static func parseInfoList(_ data: Data, chunk: Chunk) -> (tags: [MetadataTag], sourceEncoding: String?, diagnostic: String?) {
        guard chunk.payloadSize >= 4,
              fourCC(data, at: chunk.payloadOffset) == "INFO" else { return ([], nil, nil) }
        var tags: [MetadataTag] = []
        var encodings: Set<String> = []
        var offset = chunk.payloadOffset + 4
        while offset < chunk.payloadEnd {
            guard chunk.payloadEnd - offset >= 8,
                  let name = fourCC(data, at: offset),
                  let rawSize = uint32LE(data, at: offset + 4) else {
                return (tags, encodings.count == 1 ? encodings.first : nil, "Malformed RIFF LIST/INFO item header; remaining items were preserved raw.")
            }
            let valueStart = offset + 8
            let size = Int(rawSize)
            guard size <= chunk.payloadEnd - valueStart else {
                return (tags, encodings.count == 1 ? encodings.first : nil, "Malformed RIFF LIST/INFO item size; remaining items were preserved raw.")
            }
            let valueEnd = valueStart + size
            let paddedEnd = valueEnd + (size & 1)
            guard paddedEnd <= chunk.payloadEnd else {
                return (tags, encodings.count == 1 ? encodings.first : nil, "Missing padding in RIFF LIST/INFO item; remaining items were preserved raw.")
            }
            var bytes = Data(data[valueStart..<valueEnd])
            if let terminator = bytes.firstIndex(of: 0) { bytes = Data(bytes[..<terminator]) }
            if !bytes.isEmpty {
                if let value = String(data: bytes, encoding: .utf8) {
                    tags.append(MetadataTag(name: name, value: value))
                    encodings.insert("UTF-8")
                } else if let value = String(data: bytes, encoding: .windowsCP1252) {
                    tags.append(MetadataTag(name: name, value: value))
                    encodings.insert("Windows-1252")
                } else {
                    tags.append(MetadataTag(name: name, value: String(decoding: bytes, as: UTF8.self)))
                    encodings.insert("UTF-8-lossy")
                }
            } else {
                tags.append(MetadataTag(name: name, value: ""))
                encodings.insert("ASCII")
            }
            offset = paddedEnd
        }
        return (tags, encodings.count == 1 ? encodings.first : nil, nil)
    }

    private static func isSupportedFormat(_ data: Data) -> Bool {
        guard data.count >= 16, let codec = uint16LE(data, at: 0) else { return false }
        if codec == 0x0270 { return true }
        guard codec == 0xFFFE,
              data.count >= 40,
              uint16LE(data, at: 16).map({ $0 >= 0x16 }) == true else { return false }
        return data.subdata(in: 24..<40) == atrac3PlusGUID
    }

    private static func isATRAC3Format(_ data: Data) -> Bool {
        guard let codec = uint16LE(data, at: 0) else { return false }
        return codec == 0x0270 || codec == 0xFFFE && isSupportedFormat(data)
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("RIFF ATRAC3 metadata reader: \(reason)")
    }

    private static func fourCC(_ data: Data, at offset: Int) -> String? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        let bytes = Array(data[offset..<(offset + 4)])
        if bytes.allSatisfy({ (0x20...0x7E).contains($0) }) {
            return String(decoding: bytes, as: UTF8.self)
        }
        return "0x" + bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1) else { return nil }
        return UInt16(first) | UInt16(second) << 8
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard let first = byte(data, at: offset), let second = byte(data, at: offset + 1),
              let third = byte(data, at: offset + 2), let fourth = byte(data, at: offset + 3) else { return nil }
        return UInt32(first) | UInt32(second) << 8 | UInt32(third) << 16 | UInt32(fourth) << 24
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32? {
        uint32LE(data, at: offset).map(Int32.init(bitPattern:))
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }
}
