import Foundation

/// Reads the bounded 31-sample ProTracker-family MOD header. Unknown MOD
/// dialects remain unsupported until their structure can be identified safely.
enum MODMetadataReader {
    static let headerSize = 1_084
    private static let orderTableOffset = 952
    private static let signatureOffset = 1_080

    static func read(fileURL: URL) throws -> MetadataDocument {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw MetadataReadError.malformedFile("Could not read MOD file: \(error.localizedDescription)")
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            throw MetadataReadError.malformedFile("MOD file is not a regular file or its size is unavailable.")
        }
        guard size.uint64Value >= UInt64(headerSize) else {
            throw MetadataReadError.unsupportedFormat("MOD dialect without a recognized 31-sample header")
        }
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let header = try handle.read(upToCount: headerSize) ?? Data()
            return try read(header: header, fileSize: size.uint64Value, displayName: fileURL.lastPathComponent)
        } catch let error as MetadataReadError {
            throw error
        } catch {
            throw MetadataReadError.malformedFile("Could not read MOD header: \(error.localizedDescription)")
        }
    }

    static func read(data: Data, displayName: String? = nil) throws -> MetadataDocument {
        try read(header: Data(data.prefix(headerSize)), fileSize: UInt64(data.count), displayName: displayName)
    }

    static func matches(_ data: Data) -> Bool {
        guard data.count >= headerSize else { return false }
        return channelCount(for: Array(data[signatureOffset..<headerSize])) != nil
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("mod") == .orderedSame else { return false }
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? handle.close() }
        let header: Data
        do {
            guard let prefix = try handle.read(upToCount: headerSize), prefix.count == headerSize else { return false }
            header = prefix
        } catch {
            return false
        }
        return channelCount(for: Array(header[signatureOffset..<headerSize])) != nil
    }

    private static func read(header: Data, fileSize: UInt64, displayName: String?) throws -> MetadataDocument {
        guard header.count == headerSize else {
            throw MetadataReadError.unsupportedFormat("MOD dialect without a recognized 31-sample header")
        }
        let bytes = [UInt8](header)
        let signatureBytes = Array(bytes[signatureOffset..<headerSize])
        guard let channels = channelCount(for: signatureBytes) else {
            throw MetadataReadError.unsupportedFormat("unrecognized 31-sample MOD signature")
        }

        let songLength = Int(bytes[950])
        guard (1...128).contains(songLength) else {
            throw MetadataReadError.malformedFile("MOD song length is outside the 1...128 order range.")
        }
        var highestPattern = 0
        for order in 0..<songLength {
            let pattern = Int(bytes[orderTableOffset + order])
            guard pattern <= 127 else {
                throw MetadataReadError.malformedFile("MOD order table references a pattern above 127.")
            }
            highestPattern = max(highestPattern, pattern)
        }

        let patternCount = highestPattern + 1
        let patternBytes = UInt64(patternCount) * 64 * UInt64(channels) * 4
        var sampleBytes: UInt64 = 0
        var sampleTitles: [(Int, String)] = []
        var facts: [String: String] = [
            "mod.channels": String(channels),
            "mod.instrumentCount": "31",
            "mod.orderCount": String(songLength),
            "mod.patternCount": String(patternCount),
            "mod.signature": String(decoding: signatureBytes, as: UTF8.self),
            "mod.restartPosition": String(bytes[951])
        ]

        for sampleIndex in 0..<31 {
            let sampleOffset = 20 + sampleIndex * 30
            let sampleName = decodeName(bytes[sampleOffset..<(sampleOffset + 22)])
            let sampleLength = UInt64(bytes[sampleOffset + 22]) << 9
                | UInt64(bytes[sampleOffset + 23]) << 1
            let volume = bytes[sampleOffset + 25]
            guard volume <= 64 else {
                throw MetadataReadError.malformedFile("MOD instrument \(sampleIndex + 1) has an invalid volume.")
            }
            sampleBytes += sampleLength
            facts[String(format: "mod.sample.%02d.lengthBytes", sampleIndex + 1)] = String(sampleLength)
            facts[String(format: "mod.sample.%02d.volume", sampleIndex + 1)] = String(volume)
            if !sampleName.isEmpty { sampleTitles.append((sampleIndex + 1, sampleName)) }
        }

        let payloadOffset = UInt64(headerSize) + patternBytes
        guard payloadOffset <= fileSize, sampleBytes <= fileSize - payloadOffset else {
            throw MetadataReadError.malformedFile("MOD pattern or sample data extends beyond the file.")
        }
        facts["mod.patternDataOffset"] = String(headerSize)
        facts["mod.sampleDataOffset"] = String(payloadOffset)
        facts["mod.sampleDataBytes"] = String(sampleBytes)
        if let displayName {
            facts["mod.sourceName"] = URL(fileURLWithPath: displayName).lastPathComponent
        }

        let title = decodeName(bytes[0..<20])
        var tags: [MetadataTag] = []
        if !title.isEmpty { tags.append(MetadataTag(name: "TITLE", value: title)) }
        for (index, sampleName) in sampleTitles {
            tags.append(MetadataTag(name: String(format: "SAMPLE_%02d_TITLE", index), value: sampleName))
        }
        return MetadataDocument(
            format: "mod",
            fields: MetadataFields(title: title.isEmpty ? nil : title, system: "Commodore Amiga"),
            tags: tags,
            rawMetadataBlocks: ["modHeader": header],
            sourceEncoding: "ISO-8859-1",
            technicalFacts: facts
        )
    }

    private static func channelCount(for signature: [UInt8]) -> Int? {
        guard signature.count == 4,
              let text = String(bytes: signature, encoding: .ascii) else { return nil }
        switch text {
        case "M.K.", "M!K!", "M&K!", "M.K!", "N.T.", "FLT4", "4CHN", "CD81": return 4
        case "8CHN", "FLT8", "OCTA", "OKTA": return 8
        case "FA04": return 4
        case "FA06": return 6
        case "FA08": return 8
        default:
            if text.hasSuffix("CHN"), let count = Int(text.dropLast(3)), (1...32).contains(count) {
                return count
            }
            if text.hasSuffix("CH"), let count = Int(text.dropLast(2)), (1...32).contains(count) {
                return count
            }
            return nil
        }
    }

    private static func decodeName(_ bytes: ArraySlice<UInt8>) -> String {
        let visible = bytes.prefix { $0 != 0 }
        let scalars = visible.map { UnicodeScalar($0) }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
