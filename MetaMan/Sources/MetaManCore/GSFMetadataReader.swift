import Foundation
import zlib

/// Reads complete GSF/miniGSF containers and their PSFLib chain without
/// constructing a Game Boy Advance core. Playback remains in VGMBoy.
enum GSFMetadataReader {
    static let supportedExtensions: Set<String> = ["gsf", "minigsf"]

    private static let version: UInt8 = 0x22
    private static let maximumDependencyDepth = 10
    private static let maximumDependencyFiles = 256
    private static let maximumContainerBytes = 128 * 1_024 * 1_024
    private static let maximumAggregateBytes = 512 * 1_024 * 1_024
    private static let maximumInflatedBytes = 64 * 1_024 * 1_024
    private static let maximumROMImageBytes = 64 * 1_024 * 1_024
    private static let maximumTagBytes = 4 * 1_024 * 1_024

    private struct Tag: Sendable {
        var name: String
        var value: String
    }

    private struct ParsedTags {
        var original: [MetadataTag]
        var compatibility: [Tag]
        var rawBlock: Data?
        var diagnostics: [String]
    }

    private struct Container {
        let compressedRange: Range<Int>
        let tags: ParsedTags
        let dependencyNames: [String]
        let reservedSize: UInt32
        let compressedSize: UInt32
        let expectedCRC: UInt32
    }

    private struct ExecutableSegment {
        let offset: Int
        let declaredSize: Int
        let payload: Data
    }

    /// Only the first 0xB3 assembled ROM bytes are needed for the historical
    /// GBA image-recognition gate.
    private struct ROMHeader {
        private static let inspectedByteCount = 0xB3
        private var bytes = [UInt8](repeating: 0, count: inspectedByteCount)
        private var known = [Bool](repeating: false, count: inspectedByteCount)
        private(set) var imageSize = 0

        mutating func apply(_ segment: ExecutableSegment) {
            let previousImageSize = imageSize
            let requiredSize = segment.offset + segment.declaredSize
            if requiredSize > previousImageSize {
                let zeroStart = min(previousImageSize, Self.inspectedByteCount)
                let zeroEnd = min(requiredSize, Self.inspectedByteCount)
                if zeroStart < zeroEnd {
                    for index in zeroStart..<zeroEnd {
                        bytes[index] = 0
                        known[index] = true
                    }
                }
                imageSize = requiredSize
            }

            guard segment.offset < Self.inspectedByteCount else { return }
            let visibleSize = min(segment.declaredSize, Self.inspectedByteCount - segment.offset)
            let copiedSize = min(visibleSize, segment.payload.count)
            if copiedSize > 0 {
                for index in 0..<copiedSize {
                    bytes[segment.offset + index] = segment.payload[index]
                    known[segment.offset + index] = true
                }
            }
            if copiedSize < visibleSize {
                for index in (segment.offset + copiedSize)..<(segment.offset + visibleSize) {
                    known[index] = false
                }
            }
        }

        func validate(fileName: String) throws {
            guard imageSize >= Self.inspectedByteCount, known.allSatisfy({ $0 }) else {
                throw malformed("GSF dependency chain does not provide a complete GBA ROM header: \(fileName).")
            }
            guard bytes[3] == 0xEA else {
                throw malformed("GSF dependency chain is not recognized as a GBA ROM: \(fileName).")
            }
            if bytes[0xB2] != 0x96 && bytes[4..<0xA0].contains(where: { $0 != 0 }) {
                throw malformed("GSF dependency chain has an invalid GBA ROM header: \(fileName).")
            }
            let isBIOS = (0..<7).allSatisfy { vector in
                bytes[vector * 4 + 3] == 0xEA && bytes[vector * 4 + 2] == 0
            }
            guard !isBIOS else {
                throw malformed("GSF dependency chain resolves to a GBA BIOS image, not a game ROM: \(fileName).")
            }
        }
    }

    private struct MetadataCollector {
        var title = ""
        var game = ""
        var artist = ""
        var comments: [String] = []
        var playLengthMs: Int?
        var decoderLengthMs = 0
        var fadeMs: Int?

        mutating func consume(_ tags: [Tag]) {
            for tag in tags {
                let key = tag.name.lowercased()
                guard !tag.value.isEmpty else { continue }
                let firstLine = tag.value.components(separatedBy: .newlines).first ?? ""
                switch key {
                case "title":
                    if title.isEmpty { title = tag.value }
                case "game", "album":
                    if game.isEmpty { game = tag.value }
                case "artist", "composer":
                    if artist.isEmpty { artist = tag.value }
                case "comment", "copyright":
                    comments.append(tag.value)
                case "length":
                    if playLengthMs == nil { playLengthMs = Self.parseTagTimeMilliseconds(firstLine) }
                    decoderLengthMs = Self.parseDecoderTimeMilliseconds(firstLine)
                case "fade":
                    if fadeMs == nil { fadeMs = Self.parseTagTimeMilliseconds(firstLine) }
                default:
                    break
                }
            }
        }

        private static func parseTagTimeMilliseconds(_ value: String) -> Int {
            let components = value.split(separator: ":", omittingEmptySubsequences: false)
            guard let secondsComponent = components.last,
                  let seconds = Double(secondsComponent.trimmingCharacters(in: .whitespaces)) else { return 0 }
            var total = seconds
            var multiplier = 60.0
            for component in components.dropLast().reversed() {
                let part = Double(component.trimmingCharacters(in: .whitespaces)) ?? 0
                total += part * multiplier
                multiplier *= 60
            }
            total *= 1_000
            guard total.isFinite, total >= 0 else { return 0 }
            let rounded = total.rounded(.toNearestOrAwayFromZero)
            guard rounded < Double(Int.max) else { return Int.max }
            return Int(rounded)
        }

        private static func parseDecoderTimeMilliseconds(_ value: String) -> Int {
            let components = value.split(separator: ":", omittingEmptySubsequences: false)
            guard !components.isEmpty else { return 0 }
            var multiplier = 1_000.0
            var total = 0.0
            for component in components.reversed() {
                let scanner = Scanner(string: component.trimmingCharacters(in: .whitespaces))
                scanner.locale = Locale(identifier: "en_US_POSIX")
                guard let part = scanner.scanDouble() else { return 0 }
                total += part * multiplier
                multiplier *= 60
            }
            guard total.isFinite, total >= 0 else { return 0 }
            let rounded = total.rounded(.toNearestOrAwayFromZero)
            guard rounded < Double(Int.max) else { return Int.max }
            return Int(rounded)
        }
    }

    private struct ReadState {
        var collector = MetadataCollector()
        var romHeader = ROMHeader()
        var tags: [MetadataTag] = []
        var rawBlocks: [String: Data] = [:]
        var diagnostics: [String] = []
        var facts: [String: String] = [:]
        var sourceCount = 0
        var visitedContainerBytes = 0
        var containerPaths: Set<String> = []
        var rootRawTagBlock: Data?
    }

    static func matches(_ data: Data) -> Bool {
        data.count >= 4
            && data[0] == 0x50 && data[1] == 0x53 && data[2] == 0x46
            && data[3] == version
    }

    static func read(fileURL: URL, context: MetadataReadContext = MetadataReadContext()) throws -> MetadataDocument {
        let sourceURL = fileURL.standardizedFileURL
        let sourceData = try readSource(at: sourceURL)
        let resolvedContext = try contextIncludingGSFDependencies(
            sourceData: sourceData,
            sourceURL: sourceURL,
            context: context
        )
        return try read(
            data: sourceData,
            displayName: sourceURL.lastPathComponent,
            context: resolvedContext
        )
    }

    static func readResult(
        data: Data,
        displayName: String?,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataReadResult {
        guard let displayName, !displayName.isEmpty else {
            return MetadataReadResult(tracks: [MetadataTrack(document: try read(data: data, displayName: "GSF", context: context))])
        }
        return MetadataReadResult(tracks: [MetadataTrack(document: try read(data: data, displayName: displayName, context: context))])
    }

    static func read(
        data: Data,
        displayName: String?,
        context: MetadataReadContext = MetadataReadContext()
    ) throws -> MetadataDocument {
        let fileName = URL(fileURLWithPath: displayName ?? "GSF").lastPathComponent
        guard let root = try parse(data: data, fileName: fileName) else {
            throw malformed("Not a valid GSF/miniGSF PSF v0x22 file: \(fileName)")
        }
        var resolvedContext = context
        if resolvedContext.companionData(named: fileName) == nil {
            resolvedContext = resolvedContext.appending(MetadataCompanionFile(relativePath: fileName, data: data))
        }

        var state = ReadState()
        try visit(
            data: data,
            relativePath: fileName,
            container: root,
            depth: 1,
            activePaths: [],
            context: resolvedContext,
            state: &state
        )
        try state.romHeader.validate(fileName: fileName)
        state.facts["dependencyFileCount"] = String(state.sourceCount - 1)
        state.facts["sourceFileCount"] = String(state.sourceCount)
        state.facts["assembledROMImageBytes"] = String(state.romHeader.imageSize)

        let title = state.collector.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedCommonTags = state.tags
        func firstTag(_ key: String) -> String? {
            parsedCommonTags.first { $0.name.caseInsensitiveCompare(key) == .orderedSame && !$0.value.isEmpty }?.value
        }
        let timing = MetadataTiming(
            introLengthMs: state.collector.decoderLengthMs,
            loopLengthMs: 0,
            playLengthMs: state.collector.playLengthMs ?? state.collector.decoderLengthMs,
            fadeLengthMs: state.collector.fadeMs ?? 0
        )
        return MetadataDocument(
            format: "gsf",
            fields: MetadataFields(
                title: title.isEmpty ? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent : title,
                game: state.collector.game.isEmpty ? nil : state.collector.game,
                system: "Game Boy Advance",
                artist: state.collector.artist.isEmpty ? nil : state.collector.artist,
                album: firstTag("album"),
                date: firstTag("date"),
                year: firstTag("year"),
                genre: firstTag("genre"),
                comment: state.collector.comments.isEmpty ? nil : state.collector.comments.joined(separator: " | "),
                copyright: firstTag("copyright"),
                encodedBy: firstTag("psfby") ?? firstTag("encodedby")
            ),
            tags: state.tags,
            rawTagBlock: state.rootRawTagBlock,
            rawMetadataBlocks: state.rawBlocks.isEmpty ? nil : state.rawBlocks,
            sourceEncoding: state.tags.isEmpty ? nil : "UTF-8",
            timing: timing,
            technicalFacts: state.facts,
            diagnostics: state.diagnostics
        )
    }

    /// The file URL API follows only the PSFLib names declared in a valid GSF
    /// tag block. The data API instead consumes caller-supplied bounded bytes.
    private static func contextIncludingGSFDependencies(
        sourceData: Data,
        sourceURL: URL,
        context initialContext: MetadataReadContext
    ) throws -> MetadataReadContext {
        let baseURL = sourceURL.deletingLastPathComponent().standardizedFileURL
        let sourceName = sourceURL.lastPathComponent
        var context = initialContext
        if context.companionData(named: sourceName) == nil {
            context = context.appending(MetadataCompanionFile(relativePath: sourceName, data: sourceData))
        }
        var aggregateBytes = sourceData.count
        var pending: [(String, Data, Int)] = [(sourceName, sourceData, 1)]
        var visited = Set<String>()
        var scheduled: Set<String> = [sourceName.lowercased()]
        var cursor = 0

        while cursor < pending.count {
            let (relativePath, data, depth) = pending[cursor]
            cursor += 1
            let canonicalPath = try normalizedDependencyPath(relativePath)
            guard visited.insert(canonicalPath.lowercased()).inserted else { continue }
            guard let container = try parse(data: data, fileName: relativePath) else {
                throw malformed("Not a valid GSF/miniGSF PSF v0x22 file: \(relativePath)")
            }
            guard depth < maximumDependencyDepth else { continue }

            for dependencyName in container.dependencyNames {
                let dependencyPath = try normalizedDependencyPath(dependencyName)
                let suppliedData = context.companionData(named: dependencyPath)
                let loadedData = suppliedData == nil
                    ? try readDependency(dependencyPath, relativeTo: baseURL, aggregateBytes: &aggregateBytes)
                    : suppliedData
                guard let dependencyData = loadedData else {
                    throw malformed("GSF dependency is missing or unreadable: \(dependencyPath)")
                }
                if context.companionData(named: dependencyPath) == nil {
                    context = context.appending(
                        MetadataCompanionFile(relativePath: dependencyPath, data: dependencyData)
                    )
                }
                if scheduled.insert(dependencyPath.lowercased()).inserted {
                    guard pending.count < maximumDependencyFiles else {
                        throw malformed("GSF dependency chain exceeds the reader file-count safety limit.")
                    }
                    pending.append((dependencyPath, dependencyData, depth + 1))
                }
            }
        }
        return context
    }

    private static func readSource(at url: URL) throws -> Data {
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw malformed("GSF source is missing or unreadable: \(url.lastPathComponent)")
        }
        if let size = (attributes[.size] as? NSNumber)?.intValue, size > maximumContainerBytes {
            throw malformed("GSF container exceeds the 128 MiB reader safety limit: \(url.lastPathComponent)")
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumContainerBytes else {
                throw malformed("GSF container exceeds the 128 MiB reader safety limit: \(url.lastPathComponent)")
            }
            return data
        } catch let error as MetadataReadError {
            throw error
        } catch {
            throw malformed("GSF source is missing or unreadable: \(url.lastPathComponent)")
        }
    }

    private static func readDependency(
        _ relativePath: String,
        relativeTo baseURL: URL,
        aggregateBytes: inout Int
    ) throws -> Data? {
        let url = try dependencyURL(relativePath, relativeTo: baseURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let resolvedBase = baseURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedURL.path.hasPrefix(resolvedBase.path + "/") else {
            throw malformed("GSF dependency escapes its source directory: \(relativePath)")
        }
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: resolvedURL.path)
        } catch {
            return nil
        }
        if let size = (attributes[.size] as? NSNumber)?.intValue,
           size > maximumContainerBytes {
            throw malformed("GSF dependency exceeds the 128 MiB reader safety limit: \(relativePath)")
        }
        let data: Data
        do {
            data = try Data(contentsOf: resolvedURL, options: .mappedIfSafe)
        } catch {
            return nil
        }
        guard data.count <= maximumContainerBytes else {
            throw malformed("GSF dependency exceeds the 128 MiB reader safety limit: \(relativePath)")
        }
        let nextTotal = aggregateBytes.addingReportingOverflow(data.count)
        guard !nextTotal.overflow, nextTotal.partialValue <= maximumAggregateBytes else {
            throw malformed("GSF dependency data exceeds the 512 MiB aggregate safety limit.")
        }
        aggregateBytes = nextTotal.partialValue
        return data
    }

    private static func visit(
        data: Data,
        relativePath: String,
        container: Container,
        depth: Int,
        activePaths: Set<String>,
        context: MetadataReadContext,
        state: inout ReadState
    ) throws {
        guard depth <= maximumDependencyDepth else {
            throw malformed("GSF dependency chain exceeds the PSFLib depth limit.")
        }
        let canonicalPath = try normalizedDependencyPath(relativePath).lowercased()
        guard !activePaths.contains(canonicalPath) else {
            throw malformed("GSF dependency cycle detected at \(relativePath).")
        }
        if state.containerPaths.insert(canonicalPath).inserted {
            let total = state.visitedContainerBytes.addingReportingOverflow(data.count)
            guard !total.overflow, total.partialValue <= maximumAggregateBytes else {
                throw malformed("GSF dependency data exceeds the 512 MiB aggregate safety limit.")
            }
            state.visitedContainerBytes = total.partialValue
        }

        guard state.sourceCount < maximumDependencyFiles else {
            throw malformed("GSF dependency chain exceeds the reader file-count safety limit.")
        }
        let index = state.sourceCount
        state.sourceCount += 1
        state.collector.consume(container.tags.compatibility)
        state.tags.append(contentsOf: container.tags.original)
        state.diagnostics.append(contentsOf: container.tags.diagnostics.map { "\(relativePath): \($0)" })
        state.facts["source[\(index)].path"] = relativePath
        state.facts["source[\(index)].psfVersion"] = String(format: "0x%02X", version)
        state.facts["source[\(index)].reservedBytes"] = String(container.reservedSize)
        state.facts["source[\(index)].compressedBytes"] = String(container.compressedSize)
        state.facts["source[\(index)].storedCRC32"] = String(format: "%08X", container.expectedCRC)
        state.rawBlocks["psfHeader[\(index)]/\(relativePath)"] = Data(data.prefix(16))
        if let rawTagBlock = container.tags.rawBlock {
            state.rawBlocks["psfTags[\(index)]/\(relativePath)"] = rawTagBlock
            if index == 0 { state.rootRawTagBlock = rawTagBlock }
        }

        var nextActive = activePaths
        nextActive.insert(canonicalPath)
        if !container.dependencyNames.isEmpty, depth >= maximumDependencyDepth {
            throw malformed("GSF dependency chain exceeds the PSFLib depth limit.")
        }
        if let firstDependency = container.dependencyNames.first {
            let dependencyData = context.companionData(named: firstDependency)
            guard let dependencyData else {
                throw malformed("GSF dependency is missing or unreadable: \(firstDependency)")
            }
            guard let dependency = try parse(data: dependencyData, fileName: firstDependency) else {
                throw malformed("Not a valid GSF/miniGSF PSF v0x22 file: \(firstDependency)")
            }
            try visit(
                data: dependencyData,
                relativePath: firstDependency,
                container: dependency,
                depth: depth + 1,
                activePaths: nextActive,
                context: context,
                state: &state
            )
        }

        let compressed = Data(data[container.compressedRange])
        let executable = try inflate(compressed, fileName: relativePath)
        let segment = try parseGSFExecutable(executable, fileName: relativePath)
        state.romHeader.apply(segment)
        state.facts["source[\(index)].segmentOffset"] = String(segment.offset)
        state.facts["source[\(index)].declaredSegmentBytes"] = String(segment.declaredSize)
        state.facts["source[\(index)].inflatedExecutableBytes"] = String(executable.count)

        for dependencyName in container.dependencyNames.dropFirst() {
            guard let dependencyData = context.companionData(named: dependencyName) else {
                throw malformed("GSF dependency is missing or unreadable: \(dependencyName)")
            }
            guard let dependency = try parse(data: dependencyData, fileName: dependencyName) else {
                throw malformed("Not a valid GSF/miniGSF PSF v0x22 file: \(dependencyName)")
            }
            try visit(
                data: dependencyData,
                relativePath: dependencyName,
                container: dependency,
                depth: depth + 1,
                activePaths: nextActive,
                context: context,
                state: &state
            )
        }
    }

    private static func parse(data: Data, fileName: String) throws -> Container? {
        guard data.count >= 16, data.count <= maximumContainerBytes,
              data[0] == 0x50, data[1] == 0x53, data[2] == 0x46, data[3] == version else {
            return nil
        }
        let reservedSize = littleEndianUInt32(data, offset: 4)
        let compressedSize = littleEndianUInt32(data, offset: 8)
        let compressedStart = UInt64(16).addingReportingOverflow(UInt64(reservedSize))
        let compressedEnd = compressedStart.partialValue.addingReportingOverflow(UInt64(compressedSize))
        guard !compressedStart.overflow, !compressedEnd.overflow,
              compressedEnd.partialValue <= UInt64(data.count) else {
            throw malformed("Truncated PSF payload in \(fileName).")
        }

        let start = Int(compressedStart.partialValue)
        let end = Int(compressedEnd.partialValue)
        let expectedCRC = littleEndianUInt32(data, offset: 12)
        if compressedSize > 0 {
            let actualCRC = data[start..<end].withUnsafeBytes { bytes -> UInt32 in
                let initial = crc32(0, nil, 0)
                return UInt32(crc32(
                    initial,
                    bytes.bindMemory(to: Bytef.self).baseAddress,
                    uInt(compressedSize)
                ))
            }
            guard actualCRC == expectedCRC else {
                throw malformed("GSF executable CRC mismatch in \(fileName) (stored \(String(expectedCRC, radix: 16)), computed \(String(actualCRC, radix: 16))).")
            }
        }

        var parsedTags = ParsedTags(original: [], compatibility: [], rawBlock: nil, diagnostics: [])
        if data.count - end >= 5, data[end..<(end + 5)] == Data("[TAG]".utf8) {
            let tagBytes = data[(end + 5)...]
            guard tagBytes.count <= maximumTagBytes else {
                throw malformed("PSF tag block exceeds the 4 MiB reader safety limit in \(fileName).")
            }
            parsedTags = parseTags(tagBytes)
            parsedTags.rawBlock = Data(data[end..<data.endIndex])
        }

        let tagValues = Dictionary(
            parsedTags.compatibility.map { ($0.name.lowercased(), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        var dependencyNames: [String] = []
        if let primary = tagValues["_lib"] { dependencyNames.append(try normalizedDependencyPath(primary)) }
        var libraryIndex = 2
        while let dependency = tagValues["_lib\(libraryIndex)"] {
            dependencyNames.append(try normalizedDependencyPath(dependency))
            libraryIndex += 1
        }
        return Container(
            compressedRange: start..<end,
            tags: parsedTags,
            dependencyNames: dependencyNames,
            reservedSize: reservedSize,
            compressedSize: compressedSize,
            expectedCRC: expectedCRC
        )
    }

    private static func parseTags(_ bytes: Data.SubSequence) -> ParsedTags {
        let nulTerminated = Data(bytes.prefix { $0 != 0 })
        let decoded = String(decoding: nulTerminated, as: UTF8.self)
        var result = ParsedTags(original: [], compatibility: [], rawBlock: nil, diagnostics: [])
        if String(data: nulTerminated, encoding: .utf8) == nil {
            result.diagnostics.append("Tag text contains invalid UTF-8; replacement characters were used.")
        }

        var compatibilityIndexes: [String: Int] = [:]
        for line in decoded.split(whereSeparator: \.isNewline) {
            guard let equals = line.firstIndex(of: "=") else { continue }
            let name = String(line[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            result.original.append(MetadataTag(name: name, value: value))
            guard !value.isEmpty else { continue }

            let key = name.lowercased()
            if let index = compatibilityIndexes[key] {
                if !key.hasPrefix("_") { result.compatibility[index].value += "\n\(value)" }
            } else {
                compatibilityIndexes[key] = result.compatibility.count
                result.compatibility.append(Tag(name: name, value: value))
            }
        }
        return result
    }

    private static func normalizedDependencyPath(_ path: String) throws -> String {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\"), !path.contains("\0") else {
            throw malformed("Unsafe GSF dependency path: \(path)")
        }
        let components = path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty, !components.contains("..") else {
            throw malformed("Unsafe GSF dependency path: \(path)")
        }
        let normalized = components.filter { $0 != "." }.joined(separator: "/")
        guard !normalized.isEmpty else { throw malformed("Unsafe GSF dependency path: \(path)") }
        return normalized
    }

    private static func dependencyURL(_ path: String, relativeTo baseURL: URL) throws -> URL {
        let normalized = try normalizedDependencyPath(path)
        let url = URL(fileURLWithPath: normalized, relativeTo: baseURL).standardizedFileURL
        guard url.path.hasPrefix(baseURL.path + "/") else {
            throw malformed("GSF dependency escapes its source directory: \(path)")
        }
        return url
    }

    private static func inflate(_ compressed: Data, fileName: String) throws -> Data {
        guard !compressed.isEmpty else { return Data() }
        guard compressed.count <= Int(UInt32.max) else {
            throw malformed("GSF compressed payload is too large in \(fileName).")
        }
        var capacity = min(maximumInflatedBytes, max(1_024, min(compressed.count * 3, maximumInflatedBytes)))
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
            if status == Z_OK { return Data(output.prefix(Int(outputSize))) }
            guard status == Z_BUF_ERROR, capacity < maximumInflatedBytes else {
                throw malformed("Could not inflate GSF executable payload in \(fileName) (zlib \(status)).")
            }
            capacity = min(maximumInflatedBytes, capacity * 2)
        }
    }

    private static func parseGSFExecutable(_ data: Data, fileName: String) throws -> ExecutableSegment {
        guard data.count >= 12 else {
            throw malformed("GSF executable segment is shorter than its 12-byte header in \(fileName).")
        }
        let offset = UInt64(littleEndianUInt32(data, offset: 4) & 0x01FF_FFFF)
        let imageSize = UInt64(littleEndianUInt32(data, offset: 8))
        guard imageSize >= UInt64(data.count - 12) else {
            throw malformed("GSF executable segment declares less data than it contains in \(fileName).")
        }
        let required = offset.addingReportingOverflow(imageSize)
        guard !required.overflow, required.partialValue <= UInt64(maximumROMImageBytes) else {
            throw malformed("GSF executable segment exceeds the supported GBA ROM image size in \(fileName).")
        }
        return ExecutableSegment(
            offset: Int(offset),
            declaredSize: Int(imageSize),
            payload: Data(data[12..<data.endIndex])
        )
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
