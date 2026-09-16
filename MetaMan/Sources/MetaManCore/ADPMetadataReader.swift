import Foundation

/// Reads the two complete `.adp` layouts that are identifiable in the live
/// catalog without a playback decoder:
///
/// * headerless Nintendo GameCube DTK, whose first ten 0x20-byte frames are
///   probed exactly as vgmstream probes them; and
/// * raw mono/stereo IMA whose complete layout is declared by an adjacent
///   `.adp.txth` companion.
///
/// `.adp` is a collision extension.  Unknown signatures deliberately throw
/// rather than being flattened into a partial document; ScanSong leaves those
/// sources on its vgmstream fallback route.
enum ADPMetadataReader {
    static let supportedExtensions: Set<String> = ["adp"]

    private static let dtkFrameSize = 0x20
    // The reference decoder probes ten 0x20-byte frames: 0x140 bytes.
    private static let dtkProbeSize = dtkFrameSize * 10
    private static let sampleRate = Int64(48_000)
    private static let txthByteLimit = 64 * 1024
    private static let maximumSamples = Int64(10_000_000_000)

    private struct TXTHLayout {
        let codec: String
        let sampleRate: Int64
        let channels: Int
        let sidecar: Data
    }

    static func matches(_ data: Data) -> Bool {
        matchesDTK(data)
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("adp") == .orderedSame,
              let fileSize = regularFileSize(at: fileURL),
              fileSize > 0 else {
            return false
        }

        if let probe = try? readPrefix(from: fileURL, count: dtkProbeSize),
           matchesDTK(probe) {
            return true
        }

        guard let sidecar = txthURL(beside: fileURL),
              let sidecarSize = regularFileSize(at: sidecar),
              sidecarSize <= Int64(txthByteLimit),
              let sidecarData = try? Data(contentsOf: sidecar),
              (try? parseTXTH(sidecarData)) != nil else {
            return false
        }
        return true
    }

    static func read(fileURL: URL, context: MetadataReadContext = MetadataReadContext()) throws -> MetadataDocument {
        guard fileURL.pathExtension.caseInsensitiveCompare("adp") == .orderedSame else {
            throw MetadataReadError.unsupportedFormat("ADP extension")
        }
        guard let fileSize = regularFileSize(at: fileURL), fileSize > 0 else {
            throw malformed("ADP source is empty or is not a regular file.")
        }

        let probe = try readPrefix(from: fileURL, count: dtkProbeSize)
        if matchesDTK(probe) {
            return try readDTK(
                fileSize: fileSize,
                probe: probe,
                displayName: fileURL.lastPathComponent
            )
        }

        let sidecar: Data
        if let suppliedSidecar = context.companionData(named: ".adp.txth") {
            sidecar = suppliedSidecar
        } else {
            guard let sidecarURL = txthURL(beside: fileURL) else {
                throw unsupported("Nintendo DTK probe or exact .adp.txth IMA layout")
            }
            guard let sidecarSize = regularFileSize(at: sidecarURL),
                  sidecarSize <= Int64(txthByteLimit) else {
                throw malformed("ADP TXTH companion exceeds the 64 KiB safety limit.")
            }
            sidecar = try Data(contentsOf: sidecarURL)
        }
        let layout = try parseTXTH(sidecar)
        return try readTXTH(
            fileSize: fileSize,
            layout: layout,
            displayName: fileURL.lastPathComponent
        )
    }

    static func read(data: Data, displayName: String?, context: MetadataReadContext) throws -> MetadataDocument {
        if matchesDTK(data) {
            return try readDTK(
                fileSize: Int64(data.count),
                probe: Data(data.prefix(dtkProbeSize)),
                displayName: displayName
            )
        }

        guard let sidecar = context.companionData(named: ".adp.txth") else {
            throw unsupported("Nintendo DTK probe or exact .adp.txth IMA layout")
        }
        let layout = try parseTXTH(sidecar)
        return try readTXTH(
            fileSize: Int64(data.count),
            layout: layout,
            displayName: displayName
        )
    }

    private static func readDTK(fileSize: Int64, probe: Data, displayName: String?) throws -> MetadataDocument {
        guard fileSize >= Int64(dtkProbeSize), matchesDTK(probe) else {
            throw unsupported("Nintendo DTK frame probe")
        }

        let frameCount = fileSize / Int64(dtkFrameSize)
        let sampleCount = frameCount.multipliedReportingOverflow(by: 28)
        guard !sampleCount.overflow, sampleCount.partialValue > 0,
              sampleCount.partialValue <= maximumSamples else {
            throw malformed("Nintendo DTK decoded sample count is invalid.")
        }

        let title = title(from: displayName)
        let facts: [String: String] = [
            "codecName": "Nintendo DTK",
            "layout": "none",
            "sampleRateHz": String(sampleRate),
            "channels": "2",
            "frameSizeBytes": String(dtkFrameSize),
            "samplesPerFrame": "28",
            "frameCount": String(frameCount),
            "dataBytes": String(fileSize),
            "decodedSampleCount": String(sampleCount.partialValue),
            "loopEnabled": "false",
            "metadataSource": "Nintendo .DTK raw header",
            "sampleRateSource": "Nintendo GameCube hardware specification"
        ]
        return MetadataDocument(
            format: "ngc-dtk-adp",
            fields: MetadataFields(title: title, comment: "Nintendo .DTK raw header"),
            rawMetadataBlocks: ["dtkProbeHeader": Data(probe.prefix(dtkFrameSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: milliseconds(samples: sampleCount.partialValue, rate: sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func readTXTH(fileSize: Int64, layout: TXTHLayout, displayName: String?) throws -> MetadataDocument {
        guard fileSize > 0 else {
            throw malformed("TXTH-described ADP source is empty.")
        }
        let bytesPerSample = Int64(2)
        let decodedNumerator = fileSize.multipliedReportingOverflow(by: bytesPerSample)
        guard !decodedNumerator.overflow else {
            throw malformed("TXTH-described ADP sample count overflows.")
        }
        let sampleCount = decodedNumerator.partialValue / Int64(layout.channels)
        guard sampleCount > 0, sampleCount <= maximumSamples else {
            throw malformed("TXTH-described ADP decoded sample count is invalid.")
        }

        let title = title(from: displayName)
        let tags = [
            MetadataTag(name: "codec", value: layout.codec),
            MetadataTag(name: "sample_rate", value: String(layout.sampleRate)),
            MetadataTag(name: "channels", value: String(layout.channels)),
            MetadataTag(name: "num_samples", value: "data_size")
        ]
        let facts: [String: String] = [
            "codecName": "IMA 4-bit ADPCM",
            "layout": "raw",
            "sampleRateHz": String(layout.sampleRate),
            "channels": String(layout.channels),
            "dataBytes": String(fileSize),
            "decodedSampleCount": String(sampleCount),
            "loopEnabled": "false",
            "metadataSource": "TXTH generic header",
            "sampleCountSource": "num_samples = data_size; IMA bytes-to-samples conversion"
        ]
        return MetadataDocument(
            format: "txth-ima-adp",
            fields: MetadataFields(title: title, comment: "TXTH generic header"),
            tags: tags,
            rawMetadataBlocks: ["txth": layout.sidecar],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: milliseconds(samples: sampleCount, rate: layout.sampleRate),
                fadeLengthMs: 0
            ),
            technicalFacts: facts
        )
    }

    private static func matchesDTK(_ data: Data) -> Bool {
        guard data.count >= dtkProbeSize else { return false }
        var blanks = 0
        for frame in 0..<10 {
            let offset = frame * dtkFrameSize
            let header = data[offset]
            let index = (header >> 4) & 0x0F
            let shift = header & 0x0F
            guard index <= 4, shift <= 0x0C,
                  data[offset] == data[offset + 2],
                  data[offset + 1] == data[offset + 3] else {
                return false
            }
            if data[offset] == 0, data[offset + 1] == 0 {
                blanks += 1
            }
        }
        return blanks <= 3
    }

    private static func parseTXTH(_ data: Data) throws -> TXTHLayout {
        guard data.count <= txthByteLimit else {
            throw malformed("ADP TXTH companion exceeds the 64 KiB safety limit.")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw malformed("ADP TXTH companion is not UTF-8.")
        }

        var values: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") || line.hasPrefix("//") {
                continue
            }
            guard let separator = line.firstIndex(of: "=") else {
                throw malformed("ADP TXTH companion contains a directive without '='.")
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard ["codec", "sample_rate", "channels", "num_samples"].contains(key), !value.isEmpty else {
                throw unsupported("unimplemented ADP TXTH directive")
            }
            if let previous = values[key], previous.caseInsensitiveCompare(value) != .orderedSame {
                throw malformed("ADP TXTH companion defines conflicting values for \(key).")
            }
            values[key] = value
        }

        guard values["codec"]?.caseInsensitiveCompare("IMA") == .orderedSame,
              values["num_samples"]?.lowercased() == "data_size",
              let sampleRateText = values["sample_rate"],
              let sampleRate = Int64(sampleRateText),
              (1...1_000_000).contains(sampleRate),
              let channelsText = values["channels"],
              let channels = Int(channelsText),
              (1...2).contains(channels) else {
            throw unsupported("exact TXTH IMA data_size layout")
        }
        return TXTHLayout(
            codec: "IMA",
            sampleRate: sampleRate,
            channels: channels,
            sidecar: data
        )
    }

    private static func txthURL(beside fileURL: URL) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: fileURL.deletingLastPathComponent(),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return nil }
        return entries.first { candidate in
            candidate.lastPathComponent.caseInsensitiveCompare(".adp.txth") == .orderedSame
        }
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

    private static func title(from displayName: String?) -> String? {
        displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
    }

    private static func milliseconds(samples: Int64, rate: Int64) -> Int {
        let value = samples.multipliedReportingOverflow(by: 1_000)
        guard !value.overflow else { return Int.max }
        let milliseconds = value.partialValue / rate
        return milliseconds > Int64(Int.max) ? Int.max : Int(milliseconds)
    }

    private static func unsupported(_ message: String) -> MetadataReadError {
        .unsupportedFormat(message)
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
