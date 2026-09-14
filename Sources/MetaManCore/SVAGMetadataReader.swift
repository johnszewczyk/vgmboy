import Foundation

/// Reads Konami and SNK SVAG source headers without decoding PS-ADPCM.
/// Header-derived loop timing preserves ScanSong's established two-loop,
/// ten-second-fade projection.
enum SVAGMetadataReader {
    private enum Layout: String {
        case konami = "Konami"
        case snk = "SNK"
    }

    private static let fixedHeaderSize = 0x20
    private static let konamiAudioOffset = 0x800

    static func matches(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data.prefix(4) == Data("Svag".utf8) || data.prefix(4) == Data("VAGm".utf8)
    }

    static func supports(fileURL: URL) -> Bool {
        guard let file = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? file.close() }
        guard let header = try? file.read(upToCount: 4), header.count == 4 else { return false }
        return matches(header)
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        let header = try file.read(upToCount: konamiAudioOffset) ?? Data()
        return try read(data: header, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard matches(data) else {
            throw MetadataReadError.unsupportedFormat("Konami/SNK SVAG signature")
        }
        guard data.count >= fixedHeaderSize else {
            throw malformed("Truncated SVAG header.")
        }

        let fields: Fields
        if data.prefix(4) == Data("Svag".utf8) {
            fields = try readKonami(data)
        } else {
            fields = try readSNK(data)
        }

        guard fields.channels > 0, fields.channels <= 64,
              (300...192_000).contains(fields.sampleRate),
              fields.sampleCount > 0, fields.sampleCount <= 1_000_000_000 else {
            throw malformed("SVAG channel, sample, or rate fields are invalid.")
        }

        var loopStart = fields.rawLoopStartSample
        var loopEnd = fields.rawLoopEndSample
        var diagnostics: [String] = []
        if fields.loopDeclared && (loopStart < 0 || loopEnd <= loopStart || loopEnd > fields.sampleCount) {
            loopStart = 0
            loopEnd = 0
            diagnostics.append("Invalid SVAG loop bounds were retained as source facts but omitted from timing.")
        } else if !fields.loopDeclared {
            loopStart = 0
            loopEnd = 0
        }

        let loopLength = loopEnd > loopStart ? loopEnd - loopStart : 0
        let playSamples = loopLength > 0
            ? loopStart + loopLength * 2 + fields.sampleRate * 10
            : fields.sampleCount
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }

        var technicalFacts = fields.technicalFacts
        technicalFacts["layout"] = "interleave"
        technicalFacts["codecName"] = "PS-ADPCM"
        technicalFacts["sampleRateHz"] = String(fields.sampleRate)
        technicalFacts["sampleCount"] = String(fields.sampleCount)
        technicalFacts["channels"] = String(fields.channels)
        technicalFacts["loopDeclared"] = String(fields.loopDeclared)
        technicalFacts["loopEnabled"] = String(loopLength > 0)
        technicalFacts["loopStartSample"] = String(loopStart)
        technicalFacts["loopEndSample"] = String(loopEnd)
        technicalFacts["metadataSource"] = "\(fields.layout.rawValue) SVAG header"

        let retainedHeaderSize = fields.layout == .konami
            ? min(konamiAudioOffset, data.count)
            : fixedHeaderSize
        return MetadataDocument(
            format: "svag",
            fields: MetadataFields(title: title, comment: "\(fields.layout.rawValue) SVAG header"),
            rawMetadataBlocks: ["svagHeader": Data(data.prefix(retainedHeaderSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopLength * 1_000 / fields.sampleRate),
                playLengthMs: Int(playSamples * 1_000 / fields.sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: technicalFacts,
            diagnostics: diagnostics
        )
    }

    private static func readKonami(_ data: Data) throws -> Fields {
        guard let dataSize = uint32LE(data, at: 0x04),
              let sampleRate = uint32LE(data, at: 0x08),
              let channels = uint16LE(data, at: 0x0C),
              let interleaveBlockSize = uint32LE(data, at: 0x10),
              let loopFlag = uint32LE(data, at: 0x14),
              let rawLoopStartBytes = uint32LE(data, at: 0x18) else {
            throw malformed("Truncated Konami SVAG header.")
        }

        let paddingMarker = uint32BE(data, at: 0x400) ?? 0
        guard channels <= 1 || paddingMarker == 0
            || paddingMarker == 0x5376_6167 /* Svag */
            || paddingMarker == 0x4465_7369 /* Desi */ else {
            throw malformed("Konami SVAG padding signature is invalid.")
        }

        let channelCount = Int64(channels)
        guard channelCount > 0 else { throw malformed("Konami SVAG channel count is zero.") }
        let sampleCount = Int64(dataSize) / channelCount / 0x10 * 28
        let loopStart = Int64(rawLoopStartBytes) / 0x10 * 28
        return Fields(
            layout: .konami,
            channels: channelCount,
            sampleRate: Int64(sampleRate),
            sampleCount: sampleCount,
            loopDeclared: loopFlag == 1,
            rawLoopStartSample: loopStart,
            rawLoopEndSample: sampleCount,
            technicalFacts: [
                "dataSizeBytes": String(dataSize),
                "interleaveBlockSizeBytes": String(interleaveBlockSize),
                "loopFlag": String(loopFlag),
                "rawLoopStartBytes": String(rawLoopStartBytes),
                "rawLoopStartSample": String(loopStart),
                "rawLoopEndSample": String(sampleCount),
                "paddingMarker": String(paddingMarker),
                "paddingMarkerName": paddingMarker == 0x5376_6167 ? "Svag"
                    : paddingMarker == 0x4465_7369 ? "Desi" : "none"
            ]
        )
    }

    private static func readSNK(_ data: Data) throws -> Fields {
        guard let sampleRate = uint32LE(data, at: 0x08),
              let channels = uint32LE(data, at: 0x0C),
              let blockCount = uint32LE(data, at: 0x10),
              let rawLoopStartBlock = uint32LE(data, at: 0x18),
              let rawLoopEndBlock = uint32LE(data, at: 0x1C) else {
            throw malformed("Truncated SNK SVAG header.")
        }

        let sampleCount = Int64(blockCount) * 28
        let rawLoopStart = Int64(rawLoopStartBlock) * 28
        let rawLoopEnd = Int64(rawLoopEndBlock) * 28
        return Fields(
            layout: .snk,
            channels: Int64(channels),
            sampleRate: Int64(sampleRate),
            sampleCount: sampleCount,
            loopDeclared: rawLoopEndBlock > 0,
            rawLoopStartSample: rawLoopStart,
            rawLoopEndSample: rawLoopEnd,
            technicalFacts: [
                "blockCount": String(blockCount),
                "rawLoopStartBlock": String(rawLoopStartBlock),
                "rawLoopEndBlock": String(rawLoopEndBlock),
                "rawLoopStartSample": String(rawLoopStart),
                "rawLoopEndSample": String(rawLoopEnd)
            ]
        )
    }

    private struct Fields {
        let layout: Layout
        let channels: Int64
        let sampleRate: Int64
        let sampleCount: Int64
        let loopDeclared: Bool
        let rawLoopStartSample: Int64
        let rawLoopEndSample: Int64
        var technicalFacts: [String: String]
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("SVAG metadata reader: \(reason)")
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

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }
}
