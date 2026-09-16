import Foundation

/// Reads the two Konami XMD headers vgmstream recognizes, without touching
/// their audio payload. File-URL reads are bounded to the 12/17-byte header.
enum KonamiXMDMetadataReader {
    private enum Version {
        case silentHill4
        case castlevaniaCurseOfDarkness

        var headerSize: Int {
            switch self {
            case .silentHill4: 0x0C
            case .castlevaniaCurseOfDarkness: 0x11
            }
        }

        var frameSize: UInt64 {
            switch self {
            case .silentHill4: 0x0D
            case .castlevaniaCurseOfDarkness: 0x15
            }
        }

        var samplesPerFrame: UInt64 {
            switch self {
            case .silentHill4: 16
            case .castlevaniaCurseOfDarkness: 32
            }
        }

        var name: String {
            switch self {
            case .silentHill4: "v1"
            case .castlevaniaCurseOfDarkness: "v2"
            }
        }
    }

    private static let comment = "Konami XMD header"
    private static let maximumHeaderSize = 0x11

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        try read(
            header: Data(data.prefix(maximumHeaderSize)),
            totalSize: Int64(data.count),
            displayName: displayName
        )
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = resourceValues.fileSize, fileSize >= 0 else {
            throw malformed("Could not determine the XMD source size.")
        }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: maximumHeaderSize) ?? Data()
        return try read(
            header: header,
            totalSize: Int64(fileSize),
            displayName: fileURL.lastPathComponent
        )
    }

    static func supports(fileURL: URL) -> Bool {
        (try? read(fileURL: fileURL)) != nil
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4
            && data[0] == 0x78
            && data[1] == 0x6D
            && data[2] == 0x64
    }

    private static func read(
        header: Data,
        totalSize: Int64,
        displayName: String?
    ) throws -> MetadataDocument {
        let version: Version
        if header.count >= 4,
           header[0] == 0x78, header[1] == 0x6D, header[2] == 0x64 {
            version = .castlevaniaCurseOfDarkness
        } else {
            version = .silentHill4
        }

        guard totalSize >= Int64(version.headerSize),
              header.count >= version.headerSize else {
            throw malformed("XMD header is truncated.")
        }

        let channelsOffset = version == .silentHill4 ? 0x00 : 0x03
        let sampleRateOffset = version == .silentHill4 ? 0x01 : 0x04
        let dataSizeOffset = version == .silentHill4 ? 0x03 : 0x06
        let loopFlagOffset = version == .silentHill4 ? 0x07 : 0x0A
        let loopStartOffset = version == .silentHill4 ? 0x08 : 0x0B

        guard let channelsByte = headerByte(header, at: channelsOffset),
              let sampleRate = uint16LE(header, at: sampleRateOffset),
              let dataSize = uint32LE(header, at: dataSizeOffset),
              let loopFlag = headerByte(header, at: loopFlagOffset),
              let loopStartBytes = uint32LE(header, at: loopStartOffset) else {
            throw malformed("XMD header fields are truncated.")
        }

        let channels = UInt64(channelsByte)
        let rate = UInt64(sampleRate)
        let payloadSize = UInt64(dataSize)
        guard (1...2).contains(channels),
              rate > 0,
              payloadSize > 0,
              payloadSize <= UInt64(totalSize - Int64(version.headerSize)) else {
            throw malformed("XMD channel, sample-rate, or data-size fields are invalid.")
        }

        let framesPerChannel = payloadSize / version.frameSize / channels
        let sampleCount = framesPerChannel * version.samplesPerFrame
        guard sampleCount > 0 else {
            throw malformed("XMD data does not contain a complete audio frame.")
        }

        let loopEnabled = loopFlag != 0
        let loopStartSample = UInt64(loopStartBytes) / version.frameSize / channels
            * version.samplesPerFrame
        guard !loopEnabled || loopStartSample <= sampleCount else {
            throw malformed("XMD loop start lies beyond the declared audio data.")
        }

        let loopEndSample = sampleCount
        let loopLength = loopEnabled ? loopEndSample - loopStartSample : 0
        // vgmstream-cli's metadata contract defaults to two loop passes plus
        // a ten-second fade. Keep that scanner projection while exposing the
        // source-derived sample and loop facts separately below.
        let playSamples = loopEnabled
            ? loopStartSample + loopLength * 2 + rate * 10
            : sampleCount
        let playLengthMs = playSamples * 1_000 / rate
        let loopLengthMs = loopLength * 1_000 / rate
        guard playLengthMs <= UInt64(Int.max), loopLengthMs <= UInt64(Int.max) else {
            throw malformed("XMD sample timing exceeds the supported integer range.")
        }

        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let headerBlock = Data(header.prefix(version.headerSize))
        return MetadataDocument(
            format: "xmd",
            fields: MetadataFields(title: title, comment: comment),
            rawMetadataBlocks: ["xmdHeader": headerBlock],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: Int(loopLengthMs),
                playLengthMs: Int(playLengthMs),
                fadeLengthMs: 0
            ),
            technicalFacts: [
                "headerVersion": version.name,
                "channels": String(channels),
                "sampleRateHz": String(rate),
                "dataBytes": String(payloadSize),
                "frameBytes": String(version.frameSize),
                "framesPerChannel": String(framesPerChannel),
                "sampleCountPerChannel": String(sampleCount),
                "loopEnabled": loopEnabled ? "true" : "false",
                "loopStartBytes": String(loopStartBytes),
                "loopStartSample": String(loopStartSample),
                "loopEndSample": String(loopEndSample),
                "vgmstreamDefaultPlaySamples": String(playSamples)
            ]
        )
    }

    private static func headerByte(_ data: Data, at offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[offset]
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, data.count - offset >= 2 else { return nil }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
