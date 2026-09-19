import Foundation

/// Reads X68000 MDX identity and sequence timing without invoking a player or
/// resolving its PDX sample bank.
enum MDXMetadataReader {
    static let titleByteLimit = 1_024
    static let dependencyByteLimit = 1_024
    private static let delimiter = [UInt8(0x0D), 0x0A, 0x1A]

    static func read(fileURL: URL) throws -> MetadataDocument {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        } catch {
            throw MetadataReadError.malformedFile("Could not read MDX file: \(error.localizedDescription)")
        }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.uint64Value >= 5 else {
            throw MetadataReadError.malformedFile("MDX file is not a regular file or is truncated.")
        }
        do {
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            return try read(data: data, displayName: fileURL.lastPathComponent)
        } catch let error as MetadataReadError {
            throw error
        } catch {
            throw MetadataReadError.malformedFile("Could not read MDX file: \(error.localizedDescription)")
        }
    }

    static func read(data: Data, displayName: String? = nil) throws -> MetadataDocument {
        guard data.count >= 5 else {
            throw MetadataReadError.malformedFile("MDX header is truncated.")
        }
        let titleEnd = min(data.count - delimiter.count, titleByteLimit)
        var delimiterOffset: Int?
        if titleEnd >= 0 {
            for offset in 0...titleEnd {
                if data[offset] == delimiter[0],
                   data[offset + 1] == delimiter[1],
                   data[offset + 2] == delimiter[2] {
                    delimiterOffset = offset
                    break
                }
            }
        }
        guard let delimiterOffset,
              delimiterOffset <= titleByteLimit else {
            throw MetadataReadError.malformedFile("MDX title is missing its CR/LF/0x1A terminator or exceeds 1,024 bytes.")
        }

        let dependencyStart = delimiterOffset + delimiter.count
        let dependencySearchEnd = min(data.count, dependencyStart + dependencyByteLimit + 1)
        guard dependencyStart < dependencySearchEnd,
              let dependencyEnd = data[dependencyStart..<dependencySearchEnd].firstIndex(of: 0),
              data.count >= dependencyEnd + 5 else {
            throw MetadataReadError.malformedFile("MDX PDX name is unterminated, oversized, or has no sequence data.")
        }

        let titleBytes = Data(data[..<delimiterOffset])
        let dependencyBytes = Data(data[dependencyStart..<dependencyEnd])
        let title = decode(titleBytes)
        let dependency = decode(dependencyBytes)
        let visibleTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleDependency = dependency.trimmingCharacters(in: .whitespacesAndNewlines)
        var tags: [MetadataTag] = []
        if !visibleTitle.isEmpty { tags.append(MetadataTag(name: "TITLE", value: visibleTitle)) }
        if !visibleDependency.isEmpty { tags.append(MetadataTag(name: "PDX", value: visibleDependency)) }

        var facts = [
            "mdx.sequenceCount": "1",
            "mdx.sequenceDataOffset": String(dependencyEnd + 1),
            "mdx.requiresPDX": visibleDependency.isEmpty ? "false" : "true"
        ]
        if !visibleDependency.isEmpty { facts["mdx.pdxName"] = visibleDependency }
        if let displayName {
            facts["mdx.sourceName"] = URL(fileURLWithPath: displayName).lastPathComponent
        }

        let timingResult = MDXSequenceTimingReader.analyze(data: data, headerOffset: dependencyEnd + 1)
        facts["mdx.sequenceTiming"] = timingResult.status
        facts["mdx.timingMethod"] = "bounded-mml-sequence-walk"
        if let tickCount = timingResult.tickCount {
            facts["mdx.timingTicks"] = String(tickCount)
        }
        if timingResult.timing != nil {
            facts["mdx.timingLoopPolicy"] = "three F1 loop traversals then five-tick fade"
            facts["mdx.timingMaximumSeconds"] = "1200"
        }
        if let reason = timingResult.reason {
            facts["mdx.timingUnavailableReason"] = reason
        }
        let nativeHeader = Data(data[..<(dependencyEnd + 1)])
        return MetadataDocument(
            format: "mdx",
            fields: MetadataFields(
                title: visibleTitle.isEmpty ? nil : visibleTitle,
                system: "Sharp X68000"
            ),
            tags: tags,
            rawMetadataBlocks: ["mdxTextHeader": nativeHeader],
            structuredMetadata: .object([
                "title": .string(title),
                "pdxName": .string(dependency),
                "requiresPDX": .bool(!visibleDependency.isEmpty)
            ]),
            sourceEncoding: "Shift-JIS",
            timing: timingResult.timing,
            technicalFacts: facts,
            diagnostics: timingResult.reason.map { ["MDX timing unavailable: \($0)."] } ?? []
        )
    }

    static func matches(_ data: Data) -> Bool {
        let bytes = [UInt8](data.prefix(titleByteLimit + delimiter.count))
        guard bytes.count >= delimiter.count else { return false }
        return (0...(bytes.count - delimiter.count)).contains { offset in
            Array(bytes[offset..<(offset + delimiter.count)]) == delimiter
        }
    }

    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .shiftJIS) ?? String(decoding: data, as: UTF8.self)
    }
}
