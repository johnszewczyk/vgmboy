import Foundation

/// Reads CRI AHX metadata without opening the MPEG/AHX playback path.
///
/// AHX has a small fixed header followed by a variable-size payload. The
/// existing scanner's FFmpeg projection uses the payload's fixed 160 kbps
/// rate for duration, rather than the authored sample-count field at 0x0C.
/// MetaMan preserves both values and reproduces the scanner-visible result.
enum AHXMetadataReader {
    static let supportedExtensions: Set<String> = ["ahx"]

    private static let fixedHeaderSize = 0x14
    // The offset field is u16 BE and the first frame word is four bytes;
    // include the complete possible header-relative probe at 0xFFFF + 4.
    private static let maximumHeaderRead = 0x10008
    private static let maximumSampleRate = Int64(192_000)
    private static let bitrate = Int64(160_000)
    private static let maximumSamples = Int64(10_000_000_000)
    private static let ahxFrameHeader: UInt32 = 0xFFF5_E0C0
    private static let footer = Data([0x80, 0x01, 0x00, 0x0C]) + Data("AHXE(c)CRI\0\0".utf8)

    private struct Header {
        let dataOffset: Int
        let type: UInt8
        let sampleRate: Int64
        let declaredSampleCount: Int64
        let encryptionType: UInt8
        let sourceHeader: Data
    }

    static func matches(_ data: Data) -> Bool {
        (try? parseHeader(data, fileSize: Int64(data.count))) != nil
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("ahx") == .orderedSame,
              let fileSize = regularFileSize(at: fileURL),
              fileSize > 0,
              let prefix = try? readPrefix(from: fileURL, count: maximumHeaderRead) else {
            return false
        }
        return (try? parseHeader(prefix, fileSize: fileSize)) != nil
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        guard fileURL.pathExtension.caseInsensitiveCompare("ahx") == .orderedSame else {
            throw MetadataReadError.unsupportedFormat("AHX extension")
        }
        guard let fileSize = regularFileSize(at: fileURL), fileSize > 0 else {
            throw malformed("AHX source is empty or is not a regular file.")
        }
        let prefix = try readPrefix(from: fileURL, count: maximumHeaderRead)
        let header = try parseHeader(prefix, fileSize: fileSize)
        let trailer = try readAHXFooter(from: fileURL, fileSize: fileSize)
        return try makeDocument(
            header: header,
            fileSize: fileSize,
            displayName: fileURL.lastPathComponent,
            footer: trailer
        )
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        let header = try parseHeader(data, fileSize: Int64(data.count))
        let trailer = data.count >= footer.count && Data(data.suffix(footer.count)) == footer ? footer : nil
        return try makeDocument(
            header: header,
            fileSize: Int64(data.count),
            displayName: displayName,
            footer: trailer
        )
    }

    private static func parseHeader(_ data: Data, fileSize: Int64) throws -> Header {
        guard data.count >= fixedHeaderSize else {
            throw malformed("AHX header is truncated.")
        }
        guard uint16BE(data, at: 0) == 0x8000,
              let offsetField = uint16BE(data, at: 0x02) else {
            throw unsupported("CRI AHX signature")
        }

        let dataOffset = Int(offsetField) + 4
        guard dataOffset >= fixedHeaderSize,
              Int64(dataOffset) + 4 <= fileSize,
              dataOffset + 4 <= data.count,
              uint16BE(data, at: dataOffset - 0x06) == 0x2863,
              uint32BE(data, at: dataOffset - 0x04) == 0x2943_5249,
              uint32BE(data, at: dataOffset) == ahxFrameHeader else {
            throw unsupported("CRI AHX header or first frame")
        }

        guard let type = byte(data, at: 0x04), type == 0x10 || type == 0x11,
              byte(data, at: 0x05) == 0,
              byte(data, at: 0x06) == 0,
              byte(data, at: 0x07) == 1,
              let sampleRate = int32BE(data, at: 0x08),
              sampleRate > 0,
              sampleRate <= maximumSampleRate,
              let declaredSampleCount = int32BE(data, at: 0x0C),
              declaredSampleCount > 0,
              byte(data, at: 0x12) == 0x06,
              let encryptionType = byte(data, at: 0x13) else {
            throw malformed("CRI AHX header has invalid type, channel, rate, or version fields.")
        }

        return Header(
            dataOffset: dataOffset,
            type: type,
            sampleRate: Int64(sampleRate),
            declaredSampleCount: Int64(declaredSampleCount),
            encryptionType: encryptionType,
            sourceHeader: Data(data.prefix(dataOffset))
        )
    }

    private static func makeDocument(
        header: Header,
        fileSize: Int64,
        displayName: String?,
        footer: Data?
    ) throws -> MetadataDocument {
        let payloadBytes = fileSize - Int64(header.dataOffset)
        guard payloadBytes > 0 else {
            throw malformed("CRI AHX payload is empty.")
        }
        let numerator = payloadBytes.multipliedReportingOverflow(by: header.sampleRate * 8)
        guard !numerator.overflow else {
            throw malformed("CRI AHX payload sample count overflows.")
        }
        let quotient = numerator.partialValue / bitrate
        let remainder = numerator.partialValue % bitrate
        let sampleCount = quotient + (remainder >= bitrate / 2 ? 1 : 0)
        guard sampleCount > 0, sampleCount <= maximumSamples else {
            throw malformed("CRI AHX payload sample count is invalid.")
        }

        var rawBlocks: [String: Data] = ["ahxHeader": header.sourceHeader]
        if let footer {
            rawBlocks["ahxFooter"] = footer
        }
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        return MetadataDocument(
            format: "ahx",
            fields: MetadataFields(title: title, comment: "FFmpeg format (CRI ADX)"),
            rawMetadataBlocks: rawBlocks,
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: milliseconds(samples: sampleCount, rate: header.sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "codecName": "CRI AHX",
                "layout": "flat",
                "headerType": String(format: "0x%02X", header.type),
                "headerVersion": "0x06",
                "encryptionType": String(format: "0x%02X", header.encryptionType),
                "dataOffset": String(header.dataOffset),
                "dataBytes": String(payloadBytes),
                "sampleRateHz": String(header.sampleRate),
                "channels": "1",
                "bitrateBps": String(bitrate),
                "declaredSampleCount": String(header.declaredSampleCount),
                "decodedSampleCount": String(sampleCount),
                "loopEnabled": "false",
                "metadataSource": "FFmpeg format (CRI ADX)",
                "sampleCountSource": "payload bytes at 160 kbps, matching the existing FFmpeg inspection"
            ],
            diagnostics: [
                "The source header declares \(header.declaredSampleCount) samples; the scanner-visible duration uses the \(sampleCount)-sample payload projection."
            ]
        )
    }

    private static func readAHXFooter(from fileURL: URL, fileSize: Int64) throws -> Data? {
        guard fileSize >= Int64(footer.count) else { return nil }
        let data = try readRange(from: fileURL, offset: fileSize - Int64(footer.count), count: footer.count)
        return data == footer ? data : nil
    }

    private static func readPrefix(from fileURL: URL, count: Int) throws -> Data {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        return try file.read(upToCount: count) ?? Data()
    }

    private static func readRange(from fileURL: URL, offset: Int64, count: Int) throws -> Data {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        try file.seek(toOffset: UInt64(offset))
        return try file.read(upToCount: count) ?? Data()
    }

    private static func regularFileSize(at fileURL: URL) -> Int64? {
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let fileSize = values.fileSize,
              fileSize >= 0 else { return nil }
        return Int64(fileSize)
    }

    private static func milliseconds(samples: Int64, rate: Int64) -> Int {
        let value = samples.multipliedReportingOverflow(by: 1_000)
        guard !value.overflow else { return Int.max }
        let milliseconds = value.partialValue / rate
        return milliseconds > Int64(Int.max) ? Int.max : Int(milliseconds)
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

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("AHX metadata reader: \(reason)")
    }

    private static func unsupported(_ reason: String) -> MetadataReadError {
        .unsupportedFormat("AHX metadata reader: \(reason)")
    }
}
