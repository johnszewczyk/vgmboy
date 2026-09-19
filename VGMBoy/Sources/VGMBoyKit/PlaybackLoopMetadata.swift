import Foundation

/// Sample-accurate loop instructions supplied by a UAC manifest or mirrored
/// native tags. `endSample` is exclusive; a nil repeat count is unbounded.
public struct PlaybackLoopMetadata: Codable, Equatable, Sendable {
    public let startSample: Int64
    public let endSample: Int64
    public let sampleRateHz: Int
    public let mode: String
    public let repeatCount: Int?
    public let source: String?

    public init(
        startSample: Int64,
        endSample: Int64,
        sampleRateHz: Int,
        mode: String = "forward",
        repeatCount: Int? = nil,
        source: String? = nil
    ) {
        self.startSample = max(0, startSample)
        self.endSample = max(0, endSample)
        self.sampleRateHz = max(1, sampleRateHz)
        self.mode = mode
        self.repeatCount = repeatCount
        self.source = source
    }

    public var isValid: Bool {
        endSample > startSample && sampleRateHz > 0 && mode.lowercased() == "forward"
    }

    public var lengthSamples: Int64 { max(0, endSample - startSample) }
}

enum PlaybackLoopTagReader {
    static func read(path: String) -> PlaybackLoopMetadata? {
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return read(data: data, extensionName: url.pathExtension.lowercased())
    }

    static func read(data: Data, extensionName: String) -> PlaybackLoopMetadata? {
        let tags: [String: String]
        switch extensionName.lowercased() {
        case "flac": tags = flacTags(data)
        case "ape": tags = apeTags(data)
        default: return nil
        }
        let start = integer(tags, keys: ["LOOP_START_SAMPLES", "LOOPSTART", "LOOP_START"])
        var end = integer(tags, keys: ["LOOP_END_SAMPLES", "LOOPEND", "LOOP_END"])
        if end == nil,
           let length = integer(tags, keys: ["LOOP_LENGTH_SAMPLES", "LOOPLENGTH", "LOOP_LENGTH"]),
           let start {
            end = start + length
        }
        guard let start, let end, end > start else { return nil }
        let sampleRate = integer(tags, keys: ["LOOP_SAMPLE_RATE", "LOOP_SAMPLERATE", "XA_SAMPLE_RATE", "SAMPLE_RATE", "SAMPLERATE"]) ?? 44_100
        let mode = tags["LOOP_MODE"] ?? tags["LOOP_TYPE"] ?? "forward"
        guard mode.lowercased() == "forward" else { return nil }
        let rawRepeat = tags["LOOP_REPEAT"] ?? tags["LOOP_REPEATS"] ?? tags["LOOP_COUNT"]
        let repeatCount: Int?
        if let rawRepeat, !["0", "forever", "infinite", "unbounded", "inf"].contains(rawRepeat.lowercased()) {
            repeatCount = Int(rawRepeat).map { max(0, $0) }
        } else {
            repeatCount = nil
        }
        return PlaybackLoopMetadata(
            startSample: start,
            endSample: end,
            sampleRateHz: max(1, Int(sampleRate)),
            mode: mode,
            repeatCount: repeatCount,
            source: tags["LOOP_SOURCE"] ?? "audio-tag"
        )
    }

    private static func flacTags(_ data: Data) -> [String: String] {
        guard data.count >= 4, data.prefix(4) == Data("fLaC".utf8) else { return [:] }
        var offset = 4
        while offset + 4 <= data.count {
            let header = data[offset]
            let type = header & 0x7F
            let length = Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4
            guard length >= 0, offset + length <= data.count else { return [:] }
            if type == 4 {
                return parseVorbis(data[offset..<(offset + length)])
            }
            offset += length
            if header & 0x80 != 0 { break }
        }
        return [:]
    }

    private static func parseVorbis(_ block: Data.SubSequence) -> [String: String] {
        var bytes = Array(block)
        func u32() -> UInt32? {
            guard bytes.count >= 4 else { return nil }
            let value = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            bytes.removeFirst(4)
            return value
        }
        guard let vendorLength = u32(), Int(vendorLength) <= bytes.count else { return [:] }
        bytes.removeFirst(Int(vendorLength))
        guard let count = u32() else { return [:] }
        var tags: [String: String] = [:]
        for _ in 0..<count {
            guard let length = u32(), Int(length) <= bytes.count else { return [:] }
            let text = String(decoding: bytes.prefix(Int(length)), as: UTF8.self)
            bytes.removeFirst(Int(length))
            guard let separator = text.firstIndex(of: "=") else { continue }
            tags[String(text[..<separator]).uppercased()] = String(text[text.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return tags
    }

    private static func apeTags(_ data: Data) -> [String: String] {
        guard data.count >= 32, data.suffix(32).prefix(8) == Data("APETAGEX".utf8) else { return [:] }
        let footer = data.count - 32
        let size = Int(readUInt32(data, at: footer + 12))
        let count = Int(readUInt32(data, at: footer + 16))
        guard size >= 32, size <= data.count, count <= 100_000 else { return [:] }
        var offset = data.count - size
        if data[offset..<min(data.count, offset + 8)] == Data("APETAGEX".utf8) { offset += 32 }
        var tags: [String: String] = [:]
        for _ in 0..<count {
            guard offset + 8 <= data.count else { return [:] }
            let valueSize = Int(readUInt32(data, at: offset))
            offset += 8
            guard let terminator = data[offset...].firstIndex(of: 0) else { return [:] }
            let key = String(decoding: data[offset..<terminator], as: UTF8.self).uppercased()
            offset = terminator + 1
            guard valueSize >= 0, offset + valueSize <= data.count else { return [:] }
            tags[key] = String(decoding: data[offset..<(offset + valueSize)], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            offset += valueSize
        }
        return tags
    }

    private static func integer(_ tags: [String: String], keys: [String]) -> Int64? {
        for key in keys {
            if let value = tags[key], let parsed = Int64(value) { return parsed }
        }
        return nil
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 | UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }
}
