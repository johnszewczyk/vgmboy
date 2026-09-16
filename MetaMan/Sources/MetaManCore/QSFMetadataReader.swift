import Foundation
import zlib

/// Reads complete QSF/miniQSF PSF v0x41 containers and their declared
/// QSFLib companions without starting the QSound/Z80 playback core.
enum QSFMetadataReader {
    static let supportedExtensions: Set<String> = ["qsf", "miniqsf"]

    private static let version: UInt8 = 0x41
    private static let maximumContainerBytes = 64 * 1_024 * 1_024
    private static let maximumAggregateBytes = 512 * 1_024 * 1_024
    private static let maximumInflatedBytes = 32 * 1_024 * 1_024 + 12
    private static let maximumTagBytes = 4 * 1_024 * 1_024
    private static let z80ROMBytes: UInt64 = 512 * 1_024
    private static let qsoundSampleBytes: UInt64 = 8 * 1_024 * 1_024
    private static let tagMarker = Data("[TAG]".utf8)

    private struct ParsedTags {
        var ordered: [MetadataTag] = []
        var compatibility: [String: String] = [:]
        var rawBlock: Data?
        var diagnostics: [String] = []
    }

    private struct Container {
        let version: UInt8
        let reservedSize: UInt32
        let compressedSize: UInt32
        let expectedCRC: UInt32
        let tags: ParsedTags
        let dependencyNames: [String]
        let blockCount: Int
        let blockFacts: [String: String]
    }

    private struct Source {
        let relativePath: String
        let data: Data
        let container: Container
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4
            && data[0] == 0x50 && data[1] == 0x53 && data[2] == 0x46
            && data[3] == version
    }

    static func read(
        fileURL: URL,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataDocument {
        let sourceURL = fileURL.standardizedFileURL
        let sourceData = try readSource(at: sourceURL, role: "source")
        let fileName = sourceURL.lastPathComponent
        let root = try parse(data: sourceData, fileName: fileName, requireQSFVersion: true)
        var sources = [Source(relativePath: fileName, data: sourceData, container: root)]
        var aggregateBytes = sourceData.count
        let baseURL = sourceURL.deletingLastPathComponent().standardizedFileURL
        for dependencyName in root.dependencyNames {
            let dependencyPath = try normalizedDependencyPath(dependencyName)
            let dependencyData: Data
            if let suppliedData = context.companionData(named: dependencyPath) {
                let nextTotal = aggregateBytes.addingReportingOverflow(suppliedData.count)
                guard !nextTotal.overflow, nextTotal.partialValue <= maximumAggregateBytes else {
                    throw malformed("QSF dependency data exceeds the 512 MiB aggregate safety limit.")
                }
                aggregateBytes = nextTotal.partialValue
                dependencyData = suppliedData
            } else {
                dependencyData = try readDependency(
                    dependencyPath,
                    relativeTo: baseURL,
                    aggregateBytes: &aggregateBytes
                )
            }
            let container = try parse(
                data: dependencyData,
                fileName: dependencyPath,
                requireQSFVersion: false
            )
            sources.append(Source(relativePath: dependencyPath, data: dependencyData, container: container))
        }
        return makeDocument(fileName: fileName, sources: sources)
    }

    static func readResult(
        data: Data,
        displayName: String?,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataReadResult {
        MetadataReadResult(tracks: [
            MetadataTrack(document: try read(data: data, displayName: displayName, context: context))
        ])
    }

    static func read(
        data: Data,
        displayName: String?,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataDocument {
        let fileName = URL(fileURLWithPath: displayName ?? "QSF").lastPathComponent
        let root = try parse(data: data, fileName: fileName, requireQSFVersion: true)
        var sources = [Source(relativePath: fileName, data: data, container: root)]
        var aggregateBytes = data.count
        for dependencyName in root.dependencyNames {
            let dependencyPath = try normalizedDependencyPath(dependencyName)
            guard let dependencyData = context.companionData(named: dependencyPath) else {
                throw malformed("QSF dependency is missing or unreadable: \(dependencyPath)")
            }
            let nextTotal = aggregateBytes.addingReportingOverflow(dependencyData.count)
            guard !nextTotal.overflow, nextTotal.partialValue <= maximumAggregateBytes else {
                throw malformed("QSF dependency data exceeds the 512 MiB aggregate safety limit.")
            }
            aggregateBytes = nextTotal.partialValue
            let container = try parse(
                data: dependencyData,
                fileName: dependencyPath,
                requireQSFVersion: false
            )
            sources.append(Source(relativePath: dependencyPath, data: dependencyData, container: container))
        }
        return makeDocument(fileName: fileName, sources: sources)
    }

    private static func makeDocument(fileName: String, sources: [Source]) -> MetadataDocument {
        let root = sources[0].container
        let rootTags = root.tags.compatibility
        func nonempty(_ key: String) -> String? {
            guard let value = rootTags[key], !value.isEmpty else { return nil }
            return value
        }
        let fallbackTitle = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        var facts: [String: String] = [
            "sourceFileCount": String(sources.count),
            "dependencyFileCount": String(sources.count - 1)
        ]
        var rawBlocks: [String: Data] = [:]
        var diagnostics: [String] = []
        for (index, source) in sources.enumerated() {
            let container = source.container
            facts["source[\(index)].path"] = source.relativePath
            facts["source[\(index)].psfVersion"] = String(format: "0x%02X", container.version)
            facts["source[\(index)].reservedBytes"] = String(container.reservedSize)
            facts["source[\(index)].compressedBytes"] = String(container.compressedSize)
            facts["source[\(index)].storedCRC32"] = String(format: "%08X", container.expectedCRC)
            facts["source[\(index)].qsfBlockCount"] = String(container.blockCount)
            rawBlocks["psfHeader[\(index)]/\(source.relativePath)"] = Data(source.data.prefix(16))
            if container.reservedSize > 0 {
                let reservedEnd = 16 + Int(container.reservedSize)
                rawBlocks["psfReserved[\(index)]/\(source.relativePath)"] = Data(source.data[16..<reservedEnd])
            }
            if let rawTagBlock = container.tags.rawBlock {
                rawBlocks["psfTags[\(index)]/\(source.relativePath)"] = rawTagBlock
            }
            for (key, value) in container.blockFacts {
                facts["source[\(index)].\(key)"] = value
            }
            diagnostics.append(contentsOf: container.tags.diagnostics.map { "\(source.relativePath): \($0)" })
        }

        let title = nonempty("title") ?? fallbackTitle
        return MetadataDocument(
            format: "qsf",
            fields: MetadataFields(
                title: title,
                game: nonempty("game"),
                system: "Capcom QSound",
                artist: nonempty("artist"),
                album: nonempty("album"),
                date: nonempty("date"),
                year: nonempty("year"),
                genre: nonempty("genre"),
                comment: nonempty("comment"),
                copyright: nonempty("copyright"),
                encodedBy: nonempty("psfby") ?? nonempty("encodedby")
            ),
            tags: root.tags.ordered,
            rawTagBlock: root.tags.rawBlock,
            rawMetadataBlocks: rawBlocks.isEmpty ? nil : rawBlocks,
            sourceEncoding: root.tags.rawBlock == nil ? nil : "UTF-8",
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: timeMilliseconds(rootTags["length"]),
                fadeLengthMs: timeMilliseconds(rootTags["fade"])
            ),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private static func parse(
        data: Data,
        fileName: String,
        requireQSFVersion: Bool
    ) throws -> Container {
        guard data.count >= 16, data.count <= maximumContainerBytes,
              data[0] == 0x50, data[1] == 0x53, data[2] == 0x46,
              !requireQSFVersion || data[3] == version else {
            throw malformed("Not a valid QSF PSF container: \(fileName)")
        }

        let reservedSize = littleEndianUInt32(data, offset: 4)
        let compressedSize = littleEndianUInt32(data, offset: 8)
        let compressedStart = UInt64(16).addingReportingOverflow(UInt64(reservedSize))
        let compressedEnd = compressedStart.partialValue.addingReportingOverflow(UInt64(compressedSize))
        guard !compressedStart.overflow, !compressedEnd.overflow,
              compressedEnd.partialValue <= UInt64(data.count) else {
            throw malformed("Truncated QSF PSF payload: \(fileName)")
        }

        let start = Int(compressedStart.partialValue)
        let end = Int(compressedEnd.partialValue)
        let compressed = data.subdata(in: start..<end)
        let expectedCRC = littleEndianUInt32(data, offset: 12)
        if !compressed.isEmpty {
            let actualCRC = compressed.withUnsafeBytes { bytes -> UInt32 in
                let initial = crc32(0, nil, 0)
                return UInt32(crc32(
                    initial,
                    bytes.bindMemory(to: Bytef.self).baseAddress,
                    uInt(compressed.count)
                ))
            }
            guard actualCRC == expectedCRC else {
                throw malformed("QSF PSF payload CRC mismatch: \(fileName)")
            }
        }

        let program = try inflate(compressed, fileName: fileName)
        let (blockCount, blockFacts) = try validateQSoundBlocks(program, fileName: fileName)
        let tags = try parseTagBlock(data, offset: end, fileName: fileName)
        var dependencyNames: [String] = []
        if requireQSFVersion {
            for index in 1...9 {
                let key = index == 1 ? "_lib" : "_lib\(index)"
                if let value = tags.compatibility[key] { dependencyNames.append(value) }
            }
        }
        return Container(
            version: data[3],
            reservedSize: reservedSize,
            compressedSize: compressedSize,
            expectedCRC: expectedCRC,
            tags: tags,
            dependencyNames: dependencyNames,
            blockCount: blockCount,
            blockFacts: blockFacts
        )
    }

    private static func parseTagBlock(
        _ data: Data,
        offset: Int,
        fileName: String
    ) throws -> ParsedTags {
        guard data.count - offset >= tagMarker.count,
              data[offset..<(offset + tagMarker.count)] == tagMarker else {
            return ParsedTags()
        }
        let rawBlock = Data(data[offset...])
        let tagBytes = Data(data[(offset + tagMarker.count)...])
        guard tagBytes.count <= maximumTagBytes else {
            throw malformed("QSF tag block exceeds the 4 MiB reader safety limit: \(fileName)")
        }
        let visibleBytes = Data(tagBytes.prefix(while: { $0 != 0 }))
        let text = String(decoding: visibleBytes, as: UTF8.self)
        var result = ParsedTags(rawBlock: rawBlock)
        if String(data: visibleBytes, encoding: .utf8) == nil {
            result.diagnostics.append("QSF tag text contains invalid UTF-8; replacement characters were used.")
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let equals = line.firstIndex(of: "=") else { continue }
            let name = line[..<equals].drop(while: isTagWhitespace)
            let rawValue = line[line.index(after: equals)...].drop(while: isTagWhitespace)
            guard !name.isEmpty, !rawValue.isEmpty else { continue }
            let nameString = String(name)
            let value = String(rawValue)
            result.ordered.append(MetadataTag(name: nameString, value: value))
            result.compatibility[nameString.lowercased()] = value
        }
        return result
    }

    private static func validateQSoundBlocks(
        _ data: Data,
        fileName: String
    ) throws -> (Int, [String: String]) {
        var cursor = 0
        var count = 0
        var facts: [String: String] = [:]
        while cursor < data.count {
            guard data.count - cursor >= 11 else {
                throw malformed("Truncated QSF data-block header: \(fileName)")
            }
            let kind = data[cursor]
            let offset = UInt64(littleEndianUInt32(data, offset: cursor + 3))
            let length = UInt64(littleEndianUInt32(data, offset: cursor + 7))
            let payloadStart = cursor + 11
            guard length <= UInt64(data.count - payloadStart) else {
                throw malformed("Truncated QSF data block: \(fileName)")
            }

            let end = offset.addingReportingOverflow(length)
            guard !end.overflow else {
                throw malformed("QSF data-block range overflows: \(fileName)")
            }
            switch kind {
            case 0x5A: // Z80 program ROM
                guard end.partialValue <= z80ROMBytes else {
                    throw malformed("QSF Z80 block exceeds the supported ROM size: \(fileName)")
                }
            case 0x53: // QSound sample ROM
                guard end.partialValue <= qsoundSampleBytes else {
                    throw malformed("QSF sample block exceeds the supported ROM size: \(fileName)")
                }
            case 0x4B: // Kabuki decryption keys
                guard length >= 11 else {
                    throw malformed("QSF Kabuki key block is shorter than 11 bytes: \(fileName)")
                }
            default:
                // The playback loader ignores unknown block kinds.
                break
            }

            facts["block[\(count)].kind"] = String(format: "0x%02X", kind)
            facts["block[\(count)].offset"] = String(offset)
            facts["block[\(count)].bytes"] = String(length)
            cursor = payloadStart + Int(length)
            count += 1
        }
        return (count, facts)
    }

    private static func timeMilliseconds(_ value: String?) -> Int {
        guard let value, !value.isEmpty else { return 0 }
        let locale = Locale(identifier: "en_US_POSIX")
        var seconds: Double?

        // Preserve the QSF playback bridge's scanf("%d:%lf"), then atof-style
        // numeric-prefix parsing. The result is quantized through 44.1 kHz.
        let clockScanner = Scanner(string: value)
        clockScanner.locale = locale
        if let minutes = clockScanner.scanInt() {
            clockScanner.charactersToBeSkipped = []
            if clockScanner.scanString(":") != nil,
               let partSeconds = clockScanner.scanDouble() {
                seconds = Double(minutes) * 60 + partSeconds
            }
        }
        if seconds == nil {
            let numericScanner = Scanner(string: value)
            numericScanner.locale = locale
            seconds = numericScanner.scanDouble()
        }

        guard let seconds, seconds.isFinite, seconds > 0 else { return 0 }
        let frames = seconds * 44_100
        guard frames < Double(Int64.max) else { return Int.max }
        let frameCount = Int64(frames)
        guard frameCount <= Int64.max / 1_000 else { return Int.max }
        return Int(frameCount * 1_000 / 44_100)
    }

    private static func inflate(_ compressed: Data, fileName: String) throws -> Data {
        guard !compressed.isEmpty else { return Data() }
        var capacity = min(maximumInflatedBytes, max(1_024, compressed.count * 3))
        while true {
            var output = [UInt8](repeating: 0, count: capacity)
            var outputSize = uLongf(capacity)
            let status = compressed.withUnsafeBytes { input in
                output.withUnsafeMutableBufferPointer { destination in
                    uncompress(
                        destination.baseAddress,
                        &outputSize,
                        input.bindMemory(to: Bytef.self).baseAddress,
                        uLong(compressed.count)
                    )
                }
            }
            if status == Z_OK {
                return Data(output.prefix(Int(outputSize)))
            }
            guard status == Z_BUF_ERROR, capacity < maximumInflatedBytes else {
                throw malformed("Could not inflate QSF program payload: \(fileName) (zlib \(status))")
            }
            capacity = min(maximumInflatedBytes, capacity * 2)
        }
    }

    private static func normalizedDependencyPath(_ path: String) throws -> String {
        let normalizedSeparators = path.replacingOccurrences(of: "\\", with: "/")
        let components = normalizedSeparators.split(separator: "/", omittingEmptySubsequences: true)
        guard !path.isEmpty, !path.contains("\0"),
              !path.hasPrefix("/"), !path.hasPrefix("\\"),
              !components.isEmpty, !components.contains("..") else {
            throw malformed("Unsafe QSF dependency path: \(path)")
        }
        return components.filter { $0 != "." }.joined(separator: "/")
    }

    private static func readSource(at url: URL, role: String) throws -> Data {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw malformed("QSF \(role) is missing or unreadable: \(url.lastPathComponent)")
        }
        if let size = (attributes[.size] as? NSNumber)?.intValue,
           size > maximumContainerBytes {
            throw malformed("QSF container exceeds the 64 MiB reader safety limit: \(url.lastPathComponent)")
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumContainerBytes else {
                throw malformed("QSF container exceeds the 64 MiB reader safety limit: \(url.lastPathComponent)")
            }
            return data
        } catch let error as MetadataReadError {
            throw error
        } catch {
            throw malformed("QSF \(role) is missing or unreadable: \(url.lastPathComponent)")
        }
    }

    private static func readDependency(
        _ relativePath: String,
        relativeTo baseURL: URL,
        aggregateBytes: inout Int
    ) throws -> Data {
        let dependencyPath = try normalizedDependencyPath(relativePath)
        let candidate = URL(fileURLWithPath: dependencyPath, relativeTo: baseURL).standardizedFileURL
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw malformed("QSF dependency is missing or unreadable: \(dependencyPath)")
        }
        let resolvedBase = baseURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedURL = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedURL.path.hasPrefix(resolvedBase.path + "/") else {
            throw malformed("QSF dependency escapes its source directory: \(dependencyPath)")
        }
        let data = try readSource(at: resolvedURL, role: "dependency")
        let nextTotal = aggregateBytes.addingReportingOverflow(data.count)
        guard !nextTotal.overflow, nextTotal.partialValue <= maximumAggregateBytes else {
            throw malformed("QSF dependency data exceeds the 512 MiB aggregate safety limit.")
        }
        aggregateBytes = nextTotal.partialValue
        return data
    }

    private static func isTagWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\r" || character == "\n"
    }

    private static func littleEndianUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func malformed(_ message: String) -> MetadataReadError {
        .malformedFile(message)
    }
}
