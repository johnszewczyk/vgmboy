import Foundation

/// Reads Konami Saturn's `DVI.` streams without opening the IMA playback
/// path. The `.dvi` suffix is shared by unrelated Capcom `IDVI` streams, so
/// this reader claims only the Konami signature and a complete known layout.
enum DVIMetadataReader {
    static let supportedExtensions: Set<String> = ["dvi"]

    private static let fixedHeaderSize = 0x10
    private static let maximumHeaderRead = 1 * 1024 * 1024
    private static let maximumSampleCount = Int64(2_000_000_000)
    private static let sampleRate = Int64(44_100)
    private static let channels = Int64(2)
    private static let interleaveBytes = Int64(4)
    private static let signature = Data("DVI.".utf8)

    private struct Header {
        let dataOffset: Int64
        let sampleCount: Int64
        let loopStartSample: Int64
        let sourceHeader: Data
    }

    static func matches(_ data: Data) -> Bool {
        (try? parseHeader(data, fileSize: Int64(data.count))) != nil
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("dvi") == .orderedSame,
              let fileSize = regularFileSize(at: fileURL),
              fileSize >= Int64(fixedHeaderSize),
              let prefix = try? readPrefix(from: fileURL, count: maximumHeaderRead) else {
            return false
        }
        return (try? parseHeader(prefix, fileSize: fileSize)) != nil
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        guard fileURL.pathExtension.caseInsensitiveCompare("dvi") == .orderedSame else {
            throw unsupported("DVI extension")
        }
        guard let fileSize = regularFileSize(at: fileURL),
              fileSize >= Int64(fixedHeaderSize) else {
            throw malformed("source is empty or is not a regular file.")
        }
        let prefix = try readPrefix(from: fileURL, count: maximumHeaderRead)
        let header = try parseHeader(prefix, fileSize: fileSize)
        return makeDocument(
            header: header,
            fileSize: fileSize,
            displayName: fileURL.lastPathComponent
        )
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        let header = try parseHeader(data, fileSize: Int64(data.count))
        return makeDocument(
            header: header,
            fileSize: Int64(data.count),
            displayName: displayName
        )
    }

    private static func parseHeader(_ data: Data, fileSize: Int64) throws -> Header {
        guard data.count >= fixedHeaderSize else {
            throw malformed("header is truncated.")
        }
        guard Data(data.prefix(signature.count)) == signature else {
            throw unsupported("Konami DVI. signature")
        }
        guard let dataOffsetValue = int32BE(data, at: 0x04),
              let sampleCountValue = int32BE(data, at: 0x08),
              let loopStartValue = int32BE(data, at: 0x0C) else {
            throw malformed("header fields are truncated.")
        }

        let dataOffset = Int64(dataOffsetValue)
        let sampleCount = Int64(sampleCountValue)
        let loopStartSample = Int64(loopStartValue)
        guard dataOffset >= Int64(fixedHeaderSize),
              dataOffset <= Int64(maximumHeaderRead),
              dataOffset <= fileSize,
              dataOffset <= Int64(data.count),
              sampleCount > 0,
              sampleCount <= maximumSampleCount,
              loopStartSample == -1 || (loopStartSample >= 0 && loopStartSample < sampleCount) else {
            throw malformed("header contains an invalid offset, sample count, or loop point.")
        }

        let payloadBytes = fileSize - dataOffset
        guard payloadBytes > 0, payloadBytes == sampleCount else {
            throw malformed("payload bytes do not match the complete DVI sample layout.")
        }

        return Header(
            dataOffset: dataOffset,
            sampleCount: sampleCount,
            loopStartSample: loopStartSample,
            sourceHeader: Data(data.prefix(Int(dataOffset)))
        )
    }

    private static func makeDocument(
        header: Header,
        fileSize: Int64,
        displayName: String?
    ) -> MetadataDocument {
        let loopEnabled = header.loopStartSample >= 0
        let loopLength = loopEnabled ? header.sampleCount - header.loopStartSample : 0
        let playSamples = loopEnabled
            ? header.loopStartSample + loopLength * 2 + sampleRate * 10
            : header.sampleCount
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let payloadBytes = fileSize - header.dataOffset

        return MetadataDocument(
            format: "dvi",
            fields: MetadataFields(title: title, comment: "Konami DVI. header"),
            rawMetadataBlocks: ["dviHeader": header.sourceHeader],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: milliseconds(samples: loopLength),
                playLengthMs: milliseconds(samples: playSamples),
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "metadataSource": "Konami DVI. header",
                "codecName": "Intel DVI 4-bit IMA ADPCM (mono)",
                "layout": "interleave",
                "channels": String(channels),
                "sampleRateHz": String(sampleRate),
                "interleaveBytes": String(interleaveBytes),
                "dataOffset": String(header.dataOffset),
                "dataBytes": String(payloadBytes),
                "sampleCount": String(header.sampleCount),
                "loopEnabled": String(loopEnabled),
                "loopStartSample": String(header.loopStartSample),
                "loopEndSample": String(header.sampleCount),
                "playSamples": String(playSamples),
                "bitrateBps": String((fileSize * 8 * sampleRate) / header.sampleCount)
            ]
        )
    }

    private static func readPrefix(from fileURL: URL, count: Int) throws -> Data {
        let file = try FileHandle(forReadingFrom: fileURL)
        defer { try? file.close() }
        return try file.read(upToCount: count) ?? Data()
    }

    private static func regularFileSize(at fileURL: URL) -> Int64? {
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              let fileSize = values.fileSize,
              fileSize >= 0 else { return nil }
        return Int64(fileSize)
    }

    private static func milliseconds(samples: Int64) -> Int {
        let value = samples * 1_000 / sampleRate
        return value > Int64(Int.max) ? Int.max : Int(value)
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard let first = byte(data, at: offset),
              let second = byte(data, at: offset + 1),
              let third = byte(data, at: offset + 2),
              let fourth = byte(data, at: offset + 3) else { return nil }
        return UInt32(first) << 24 | UInt32(second) << 16 | UInt32(third) << 8 | UInt32(fourth)
    }

    private static func int32BE(_ data: Data, at offset: Int) -> Int32? {
        uint32BE(data, at: offset).map(Int32.init(bitPattern:))
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("DVI metadata reader: \(reason)")
    }

    private static func unsupported(_ reason: String) -> MetadataReadError {
        .unsupportedFormat("DVI metadata reader: \(reason)")
    }
}
