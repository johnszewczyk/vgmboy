import Foundation

/// Reads Sony CD-XA sector structure and timing without decoding ADPCM.
/// The walk preserves vgmstream's interleaved file/channel subsong behavior.
enum SonyXAMetadataReader {
    private static let sectorSize = 0x930
    private static let dataSize = 0x900
    private static let sectorHeaderSize = 0x18
    private static let maxChannels = 128
    private static let maxScannerSubsongs = 1_000

    private struct ChannelState {
        var info: UInt32 = 0
        var subsong: Int = 0
    }

    private struct Subsong {
        let config: UInt16
        let submode: UInt8
        let header: UInt8
        let sampleRate: Int
        let sampleCountPerSector: Int64
        var sectorCount: Int64 = 0
    }

    static func supports(fileURL: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 0x2C) else { return false }
        return matches(header)
    }

    static func matches(_ data: Data) -> Bool {
        let rawSync: [UInt8] = [0x00] + Array(repeating: 0xFF, count: 10) + [0x00]
        let rawXA = hasBytes(data, rawSync, at: 0)
        let riffCDXA = data.count >= 0x10
            && hasBytes(data, Array("RIFF".utf8), at: 0)
            && hasBytes(data, Array("CDXA".utf8), at: 0x08)
            && hasBytes(data, Array("fmt ".utf8), at: 0x0C)
        return rawXA || riffCDXA
    }

    static func read(fileURL: URL) throws -> MetadataReadResult {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataReadResult {
        guard data.count <= Int(UInt32.max) else {
            throw malformed("Sony XA source exceeds vgmstream's 32-bit sector-offset range.")
        }

        let startOffset = try sectorStreamStart(in: data)
        if startOffset == 0 {
            try validateRawSectorFrames(data)
        }

        var states = Array(repeating: ChannelState(), count: maxChannels)
        var subsongs: [Subsong] = []
        var offset = startOffset

        while offset < data.count {
            let info = uint32BE(data, at: offset + 0x10) ?? 0
            let channel = Int((info >> 16) & 0xFF)
            let submode = UInt8((info >> 8) & 0xFF)
            let header = UInt8(info & 0xFF)

            if channel == 0xFF {
                offset += sectorSize
                continue
            }
            guard channel < maxChannels else {
                throw malformed("XA sector declares unsupported channel (channel).")
            }

            if isAudio(submode) {
                let currentInfo = info & 0xFFFF_00FF
                if states[channel].info != currentInfo {
                    guard subsongs.count < maxScannerSubsongs else {
                        throw malformed("vgmstream's scanner subsong limit of \(maxScannerSubsongs) was exceeded.")
                    }
                    let facts = try subsongFacts(
                        fileChannel: UInt16((currentInfo >> 16) & 0xFFFF),
                        submode: submode,
                        header: header
                    )
                    subsongs.append(facts)
                    states[channel].info = currentInfo
                    states[channel].subsong = subsongs.count
                }

                if states[channel].subsong > 0 {
                    subsongs[states[channel].subsong - 1].sectorCount += 1
                }

                if submode & 0x80 != 0 {
                    states[channel].info = 0
                    states[channel].subsong = 0
                }
            }

            offset += sectorSize
        }

        guard !subsongs.isEmpty else {
            throw malformed("No XA audio subsongs were found.")
        }

        let fallbackTitle = URL(fileURLWithPath: displayName ?? "XA")
            .deletingPathExtension()
            .lastPathComponent
        let tracks = subsongs.enumerated().map { index, subsong in
            let title = subsongs.count > 1
                ? String(format: "%04x", Int(subsong.config))
                : fallbackTitle
            let playLengthMs = Int(
                subsong.sectorCount * subsong.sampleCountPerSector * 1_000 / Int64(subsong.sampleRate)
            )
            var facts = technicalFacts(for: subsong, container: startOffset == 0 ? "raw-sector" : "RIFF/CDXA")
            facts["visibleTrackIndex"] = String(index)
            let document = MetadataDocument(
                format: "xa",
                fields: MetadataFields(title: title, comment: "Sony XA header"),
                timing: MetadataTiming(
                    introLengthMs: 0,
                    loopLengthMs: 0,
                    playLengthMs: playLengthMs,
                    fadeLengthMs: 0
                ),
                technicalFacts: facts
            )
            return MetadataTrack(document: document)
        }
        return MetadataReadResult(tracks: tracks)
    }

    private static func technicalFacts(for subsong: Subsong, container: String) -> [String: String] {
        let channels = (subsong.header & 0x03) == 0 ? 1 : 2
        let bitsPerSample = Int((subsong.header >> 4) & 0x03) == 0 ? 4 : 8
        return [
            "container": container,
            "sectorSizeBytes": String(sectorSize),
            "sectorHeaderBytes": String(sectorHeaderSize),
            "sectorPayloadBytes": String(dataSize),
            "xaFileNumber": String((subsong.config >> 8) & 0xFF),
            "xaChannelNumber": String(subsong.config & 0xFF),
            "xaConfiguration": String(format: "%04x", Int(subsong.config)),
            "submode": String(subsong.submode),
            "codingInfo": String(subsong.header),
            "form": subsong.submode & 0x20 == 0 ? "1" : "2",
            "channels": String(channels),
            "bitsPerSample": String(bitsPerSample),
            "sampleRateHz": String(subsong.sampleRate),
            "sampleCountPerSector": String(subsong.sampleCountPerSector),
            "audioSectorCount": String(subsong.sectorCount)
        ]
    }

    private static func sectorStreamStart(in data: Data) throws -> Int {
        let rawSync: [UInt8] = [0x00] + Array(repeating: 0xFF, count: 10) + [0x00]
        if hasBytes(data, rawSync, at: 0) {
            return 0
        }
        if hasBytes(data, Array("RIFF".utf8), at: 0),
           hasBytes(data, Array("CDXA".utf8), at: 0x08),
           hasBytes(data, Array("fmt ".utf8), at: 0x0C),
           data.count >= 0x2C {
            return 0x2C
        }
        throw malformed("Unrecognized Sony XA raw-sector or RIFF/CDXA header.")
    }

    private static func validateRawSectorFrames(_ data: Data) throws {
        var testOffset = 0
        var audioSectors = 0
        var skippedSectors = 0

        while audioSectors < 3 {
            // vgmstream's probe bounds skipped sectors only before the first
            // audio sector. Its UInt32 offset wraps after EOF; fold duplicate
            // probes instead of walking a potentially huge wrapped range.
            guard let submode = byte(data, at: testOffset + 0x12) else {
                guard audioSectors > 0 else {
                    throw malformed("Raw XA stream ended before an audio sector passed header validation.")
                }
                audioSectors = 3
                break
            }
            guard isAudio(submode) else {
                skippedSectors += 1
                if audioSectors == 0 && skippedSectors > 32 {
                    throw malformed("No XA audio sector was found in the decoder's initial probe window.")
                }
                testOffset += sectorSize
                continue
            }

            testOffset += sectorHeaderSize
            for frameIndex in 0..<(dataSize / 0x80) {
                let frame = (0..<0x10).map { byte(data, at: testOffset + $0) ?? 0 }
                for value in frame where (value >> 4) > 3 || (value & 0x0F) > 0x0D {
                    throw malformed("XA frame predictor or shift is outside the decoder's accepted range.")
                }
                guard frame[0..<4] == frame[4..<8], frame[8..<12] == frame[12..<16] else {
                    throw malformed("XA frame header copies do not match.")
                }
                if frameIndex == 0 && frame.allSatisfy({ $0 == 0 }) {
                    throw malformed("XA audio sector begins with an invalid blank frame.")
                }
                testOffset += 0x80
            }
            testOffset += sectorHeaderSize
            audioSectors += 1
        }
    }

    private static func subsongFacts(fileChannel: UInt16, submode: UInt8, header: UInt8) throws -> Subsong {
        let channels: Int
        switch header & 0x03 {
        case 0: channels = 1
        case 1: channels = 2
        default: throw malformed("XA header declares an unsupported channel count.")
        }

        let sampleRate: Int
        switch (header >> 2) & 0x03 {
        case 0: sampleRate = 37_800
        case 1: sampleRate = 18_900
        default: throw malformed("XA header declares an unsupported sample rate.")
        }

        let bitsPerSample: Int
        switch (header >> 4) & 0x03 {
        case 0: bitsPerSample = 4
        case 1: bitsPerSample = 8
        default: throw malformed("XA header declares an unsupported sample width.")
        }
        guard bitsPerSample != 8 || channels != 1 else {
            throw malformed("8-bit mono XA is not supported by the decoder.")
        }

        let subframes = bitsPerSample == 8 ? 4 : 8
        let formFrames = submode & 0x20 != 0 ? 18 : 16
        let samples = Int64((28 * subframes / channels) * formFrames)
        return Subsong(
            config: fileChannel,
            submode: submode,
            header: header,
            sampleRate: sampleRate,
            sampleCountPerSector: samples
        )
    }

    private static func isAudio(_ submode: UInt8) -> Bool {
        submode & 0x08 == 0 && submode & 0x04 != 0 && submode & 0x02 == 0
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile("Sony XA metadata reader: \(message)")
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
}
