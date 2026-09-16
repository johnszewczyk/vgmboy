import Foundation

/// Reads Sony's SSHD/ADS stream headers and PS-ADPCM framing without
/// decoding audio. The parser mirrors the complete vgmstream SSHD metadata
/// setup, including its documented PCM/IMA variants and loop-address forms.
enum SonySSHDMetadataReader {
    private static let headerSize = 0x28
    private static let maximumChannels = 32

    static func matches(_ data: Data) -> Bool {
        layoutOffset(in: data, physicalSize: data.count) != nil
    }

    static func supports(fileURL: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let physicalSize = (attributes[.size] as? NSNumber)?.intValue,
              let file = try? FileHandle(forReadingFrom: fileURL) else {
            return false
        }
        defer { try? file.close() }

        let probeSize = 0x800 + headerSize
        guard let probe = try? file.read(upToCount: probeSize), !probe.isEmpty else {
            return false
        }
        return layoutOffset(in: probe, physicalSize: physicalSize) != nil
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard let sourceOffset = layoutOffset(in: data, physicalSize: data.count) else {
            throw MetadataReadError.unsupportedFormat("Sony SSHD/ADS header")
        }
        let source = Data(data[sourceOffset...])
        return try readSource(source, sourceOffset: sourceOffset, displayName: displayName)
    }

    private static func readSource(
        _ data: Data,
        sourceOffset: Int,
        displayName: String?
    ) throws -> MetadataDocument {
        guard data.count >= headerSize,
              let headerMarker = string(data, at: 0x00, count: 4), headerMarker == "SShd",
              let headerVariant = uint32LE(data, at: 0x04),
              headerVariant == 0x18 || headerVariant == 0x20 || Int(headerVariant) == data.count - 8,
              string(data, at: 0x20, count: 4) == "SSbd",
              let codec = uint32LE(data, at: 0x08),
              let rawSampleRate = int32LE(data, at: 0x0C),
              let rawChannels = int32LE(data, at: 0x10),
              let rawInterleave = uint32LE(data, at: 0x14),
              let rawLoopStart = uint32LE(data, at: 0x18),
              let rawLoopEnd = uint32LE(data, at: 0x1C),
              let declaredBodySize = uint32LE(data, at: 0x24) else {
            throw malformed("Missing or truncated SSHD/ADS header.")
        }

        let channels = Int(rawChannels)
        guard (1...maximumChannels).contains(channels), rawSampleRate > 0 else {
            throw malformed("SSHD channel count or sample rate is invalid.")
        }

        var sampleRate = Int(rawSampleRate)
        var interleave = Int(rawInterleave)
        let coding: Coding
        switch codec {
        case 0x01, 0x8000_0001:
            if sampleRate == 12_000 && interleave == 0x200 {
                // Angel Studios/Rockstar San Diego's video variant uses the
                // PCM codec value for mono DVI IMA. This is the exact
                // vgmstream discriminator and layout adjustment.
                sampleRate = 48_000
                interleave = 0x40
                coding = .dviIMA
            } else {
                coding = .pcm16LE
            }
        case 0x02, 0x10:
            coding = .psx
        default:
            throw malformed("SSHD codec 0x\(String(codec, radix: 16, uppercase: true)) is unsupported.")
        }

        var bodySize = UInt64(declaredBodySize)
        let physicalSize = UInt64(data.count)
        guard physicalSize >= UInt64(headerSize) else {
            throw malformed("SSHD source is smaller than its fixed header.")
        }
        if bodySize > physicalSize - UInt64(headerSize) {
            bodySize = physicalSize - UInt64(headerSize)
        }
        if bodySize <= UInt64.max / 2,
           bodySize * 2 == physicalSize - 0x18 {
            bodySize = bodySize * 2 - 0x10
        }
        guard bodySize > 0 else {
            throw malformed("SSHD stream body is empty.")
        }

        var startOffset = headerSize
        if physicalSize - bodySize >= 0x800 {
            startOffset = 0x800
        }
        if coding == .psx,
           uint32LE(data, at: 0x28) == 0x1000,
           uint32LE(data, at: 0x2C) == 0,
           uint32LE(data, at: 0x1008) != 0,
           isZeroRange(data, offset: 0x2C, length: 0xFDC) {
            // The ADSC wrapper's apparent 0x1000 alignment includes an
            // eight-byte marker that vgmstream removes from the data start.
            startOffset = 0xFF8
        }

        var loopEnabled = false
        var loopUsesSamples = false
        var loopStartOffset: UInt64 = 0
        var loopEndOffset: UInt64 = 0
        var loopStartSample: Int64 = 0
        var loopEndSample: Int64 = 0
        var ignoresCaviaSilentFrame = false
        var ignoresCapcomSilentFrame = false

        if rawLoopStart != UInt32.max && rawLoopEnd == UInt32.max {
            if codec == 0x02 {
                let loopAddress = UInt64(rawLoopStart) * 0x10
                loopEnabled = loopAddress + 0x200 < bodySize
                loopStartOffset = loopAddress
                ignoresCapcomSilentFrame = true
            } else if string(data, at: 0x28, count: 4) == "PAD!" {
                loopEnabled = true
                loopUsesSamples = true
                loopStartSample = Int64(rawLoopStart) / 2 / Int64(channels)
            } else if rawLoopStart > 0 && rawLoopStart % 0x800 == 0 {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) - 0x800
                ignoresCaviaSilentFrame = true
            } else if rawLoopStart % 0x800 != 0 || rawLoopStart == 0 {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) * 0x10
            }
        } else if rawLoopStart != UInt32.max && rawLoopEnd != UInt32.max && rawLoopEnd > 0 {
            let end = UInt64(rawLoopEnd)
            if end <= bodySize / 0x200 && coding == .pcm16LE {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) * 0x200
                loopEndOffset = end * 0x200
            } else if end <= bodySize / 0x70 && coding == .pcm16LE {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) * 0x70
                loopEndOffset = end * 0x70
            } else if end <= bodySize / 0x20 && coding == .pcm16LE {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) * 0x20
                loopEndOffset = end * 0x20
            } else if end <= bodySize / 0x20 && coding == .psx {
                loopEnabled = true
                loopStartOffset = UInt64(rawLoopStart) * 0x20
                loopEndOffset = end * 0x20
            } else if end <= bodySize / 0x10 && coding == .psx,
                      hasPSXPaddingMarker(data, loopEnd: end) {
                // vgmstream recognizes this as a non-looping sound effect.
                loopEnabled = false
            } else if (end > bodySize / 0x20 && coding == .psx)
                        || (end > bodySize / 0x70 && coding == .pcm16LE) {
                loopEnabled = true
                loopUsesSamples = true
                loopStartSample = Int64(rawLoopStart)
                loopEndSample = Int64(rawLoopEnd)
            }
        }

        var streamSize = bodySize
        if coding == .psx {
            streamSize = trimTrailingPSXFrames(
                data,
                startOffset: startOffset,
                streamSize: streamSize,
                interleave: interleave,
                channels: channels,
                ignoresCaviaSilentFrame: ignoresCaviaSilentFrame,
                ignoresCapcomSilentFrame: ignoresCapcomSilentFrame
            )
        }

        let sampleCount = samples(bytes: streamSize, coding: coding, channels: channels)
        guard sampleCount > 0, sampleCount <= Int64(Int32.max) else {
            throw malformed("SSHD decoded sample count is invalid.")
        }

        if loopEnabled && !loopUsesSamples {
            loopStartSample = samples(bytes: loopStartOffset, coding: coding, channels: channels)
            loopEndSample = samples(bytes: loopEndOffset, coding: coding, channels: channels)
        }
        if loopEnabled && loopEndSample == 0 {
            loopEndSample = sampleCount
        }
        if loopEndSample > sampleCount {
            loopEndSample = sampleCount
        }
        if loopStartSample < 0 || loopEndSample <= loopStartSample || loopStartSample >= sampleCount {
            loopEnabled = false
            loopStartSample = 0
            loopEndSample = 0
        }

        let loopLength = loopEnabled ? loopEndSample - loopStartSample : 0
        let playSamples = loopEnabled
            ? loopStartSample + loopLength * 2 + Int64(sampleRate) * 10
            : sampleCount
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        var facts: [String: String] = [
            "headerOffset": String(sourceOffset),
            "codec": String(format: "0x%08X", codec),
            "codecName": coding.name,
            "channels": String(channels),
            "sampleRateHz": String(sampleRate),
            "interleaveBlockSizeBytes": String(rawInterleave),
            "effectiveInterleaveBlockSizeBytes": String(interleave),
            "declaredBodySizeBytes": String(declaredBodySize),
            "effectiveBodySizeBytes": String(bodySize),
            "streamStartOffset": String(startOffset),
            "decodedSampleCount": String(sampleCount),
            "rawLoopStart": String(rawLoopStart),
            "rawLoopEnd": String(rawLoopEnd),
            "loopEnabled": String(loopEnabled),
            "loopUsesSamples": String(loopUsesSamples),
            "loopStartSample": String(loopStartSample),
            "loopEndSample": String(loopEndSample),
            "trimmedStreamSizeBytes": String(streamSize),
            "metadataSource": "Sony SSHD header"
        ]
        if loopEnabled && !loopUsesSamples {
            facts["loopStartOffsetBytes"] = String(loopStartOffset)
            facts["loopEndOffsetBytes"] = String(loopEndOffset)
        }

        return MetadataDocument(
            format: "ads",
            fields: MetadataFields(title: title, comment: "Sony SSHD header"),
            rawMetadataBlocks: ["sshdHeader": Data(data.prefix(headerSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopLength * 1_000 / Int64(sampleRate)),
                playLengthMs: Int(playSamples * 1_000 / Int64(sampleRate)),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private enum Coding {
        case pcm16LE
        case psx
        case dviIMA

        var name: String {
            switch self {
            case .pcm16LE: "PCM16LE"
            case .psx: "PS-ADPCM"
            case .dviIMA: "DVI IMA"
            }
        }
    }

    private static func layoutOffset(in data: Data, physicalSize: Int?) -> Int? {
        let candidates: [Int] = {
            if hasBytes(data, "SShd", at: 0) { return [0] }
            if hasBytes(data, "ADSC", at: 0), uint32LE(data, at: 0x04) == 1 { return [8] }
            if hasBytes(data, "cavi a stream", at: 0) { return [0x7D8] }
            return []
        }()
        for offset in candidates {
            guard data.count - offset >= headerSize,
                  string(data, at: offset, count: 4) == "SShd",
                  let variant = uint32LE(data, at: offset + 0x04),
                  let innerSize = physicalSize.map({ $0 - offset }),
                  innerSize >= headerSize,
                  variant == 0x18 || variant == 0x20 || variant == innerSize - 8,
                  string(data, at: offset + 0x20, count: 4) == "SSbd" else {
                continue
            }
            return offset
        }
        return nil
    }

    private static func trimTrailingPSXFrames(
        _ data: Data,
        startOffset: Int,
        streamSize: UInt64,
        interleave: Int,
        channels: Int,
        ignoresCaviaSilentFrame: Bool,
        ignoresCapcomSilentFrame: Bool
    ) -> UInt64 {
        guard interleave > 0, streamSize >= 0x10 else { return streamSize }
        var result = streamSize
        var offset = UInt64(startOffset) + streamSize
        let minimum = offset >= UInt64(interleave) ? offset - UInt64(interleave) : 0
        while offset >= 0x10 {
            offset -= 0x10
            guard offset <= UInt64(Int.max),
                  Int(offset) <= data.count - 0x10 else { break }
            let index = Int(offset)
            let zero = isZeroRange(data, offset: index, length: 0x10)
            let seven = data[index + 1] == 0x07
            let sevenPattern = data[index] == 0x00 && data[index + 1] == 0x00
                && data[index + 2] == 0x77 && data[index + 3] == 0x77
                && isRepeatedByte(data, offset: index + 4, length: 12, value: 0x77)
            let cavia = ignoresCaviaSilentFrame
                && data[index] == 0x0C && data[index + 1] == 0x02
                && data[index + 2] == 0 && data[index + 3] == 0
                && isZeroRange(data, offset: index + 4, length: 12)
            let capcom = ignoresCapcomSilentFrame
                && data[index] == 0x0C && data[index + 1] == 0x01
                && data[index + 2] == 0 && data[index + 3] == 0
                && isZeroRange(data, offset: index + 4, length: 12)
            guard seven || zero || sevenPattern || cavia || capcom else { break }
            let removed = UInt64(0x10 * channels)
            guard result >= removed else { break }
            result -= removed
            if offset <= minimum { break }
        }
        return result
    }

    private static func hasPSXPaddingMarker(_ data: Data, loopEnd: UInt64) -> Bool {
        guard data.count >= headerSize + 0x24,
              loopEnd <= UInt64((data.count - headerSize - 0x24) / 0x10) else {
            return false
        }
        let base = headerSize + Int(loopEnd) * 0x10
        let first = base + 0x10
        let second = base + 0x20
        return uint32BE(data, at: first) == 0x0007_7777
            || uint32BE(data, at: second) == 0x0007_7777
    }

    private static func samples(bytes: UInt64, coding: Coding, channels: Int) -> Int64 {
        guard channels > 0 else { return 0 }
        switch coding {
        case .pcm16LE: return Int64(bytes / 2 / UInt64(channels))
        case .psx: return Int64(bytes / UInt64(channels) / 0x10 * 28)
        case .dviIMA: return Int64(bytes * 2 / UInt64(channels))
        }
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("Sony SSHD metadata reader: \(reason)")
    }

    private static func hasBytes(_ data: Data, _ value: String, at offset: Int) -> Bool {
        let bytes = Array(value.utf8)
        guard offset >= 0, data.count - offset >= bytes.count else { return false }
        return data[offset..<(offset + bytes.count)].elementsEqual(bytes)
    }

    private static func string(_ data: Data, at offset: Int, count: Int) -> String? {
        guard offset >= 0, count >= 0, data.count - offset >= count else { return nil }
        return String(bytes: data[offset..<(offset + count)], encoding: .ascii)
    }

    private static func isZeroRange(_ data: Data, offset: Int, length: Int) -> Bool {
        guard offset >= 0, length >= 0, data.count - offset >= length else { return false }
        return data[offset..<(offset + length)].allSatisfy { $0 == 0 }
    }

    private static func isRepeatedByte(_ data: Data, offset: Int, length: Int, value: UInt8) -> Bool {
        guard offset >= 0, length >= 0, data.count - offset >= length else { return false }
        return data[offset..<(offset + length)].allSatisfy { $0 == value }
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32? {
        uint32LE(data, at: offset).map { Int32(bitPattern: $0) }
    }

    private static func uint32BE(_ data: Data, at offset: UInt64) -> UInt32? {
        guard offset <= UInt64(Int.max) else { return nil }
        return uint32BE(data, at: Int(offset))
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }
}
