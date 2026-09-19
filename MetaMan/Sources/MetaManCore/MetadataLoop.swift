import Foundation

/// A sample-accurate authored playback loop. `endSample` is exclusive and
/// `repeatCount == nil` means repeat forever. The source field records where
/// the instruction came from (for example a UAC manifest or a mirrored tag),
/// while the PCM/container reader remains responsible for the audio bytes.
public struct MetadataLoop: Codable, Equatable, Sendable {
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
        self.startSample = startSample
        self.endSample = endSample
        self.sampleRateHz = sampleRateHz
        self.mode = mode
        self.repeatCount = repeatCount
        self.source = source
    }

    public var lengthSamples: Int64 { max(0, endSample - startSample) }

    public var loopLengthMs: Int {
        guard sampleRateHz > 0 else { return 0 }
        return max(0, Int((Double(lengthSamples) * 1_000 / Double(sampleRateHz)).rounded()))
    }
}

/// Shared parser for the canonical loop tag vocabulary mirrored into FLAC
/// Vorbis comments and APEv2 items. Unknown tags remain untouched by callers.
enum MetadataLoopParser {
    static func parse(tags: [MetadataTag], sampleRateHz: Int? = nil, sourceFallback: String? = nil) -> MetadataLoop? {
        var values: [String: String] = [:]
        for tag in tags {
            let key = tag.normalizedName
            let value = tag.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty { values[key] = value }
        }
        let start = integer(values, keys: ["LOOP_START_SAMPLES", "LOOPSTART", "LOOP_START"])
        var end = integer(values, keys: ["LOOP_END_SAMPLES", "LOOPEND", "LOOP_END"])
        if end == nil,
           let length = integer(values, keys: ["LOOP_LENGTH_SAMPLES", "LOOPLENGTH", "LOOP_LENGTH"]),
           let start {
            end = start + length
        }
        guard let start, let end, end > start, start >= 0 else { return nil }
        let rate = integer(values, keys: ["LOOP_SAMPLE_RATE", "LOOP_SAMPLERATE", "XA_SAMPLE_RATE", "SAMPLE_RATE", "SAMPLERATE"])
            .map(Int.init)
            ?? sampleRateHz
            ?? 0
        guard rate > 0 else { return nil }
        let mode = values["LOOP_MODE"] ?? values["LOOP_TYPE"] ?? "forward"
        let repeatCount = repeatCount(values)
        let source = values["LOOP_SOURCE"] ?? sourceFallback
        return MetadataLoop(
            startSample: start,
            endSample: end,
            sampleRateHz: rate,
            mode: mode,
            repeatCount: repeatCount,
            source: source
        )
    }

    private static func integer(_ values: [String: String], keys: [String]) -> Int64? {
        for key in keys {
            guard let value = values[key] else { continue }
            if let parsed = Int64(value) { return parsed }
            if let parsed = Double(value), parsed.isFinite { return Int64(parsed.rounded(.towardZero)) }
        }
        return nil
    }

    private static func repeatCount(_ values: [String: String]) -> Int? {
        let raw = values["LOOP_REPEAT"] ?? values["LOOP_REPEATS"] ?? values["LOOP_COUNT"]
        guard let raw else { return nil }
        let normalized = raw.lowercased()
        if ["forever", "infinite", "unbounded", "inf", "0"].contains(normalized) { return nil }
        return Int(normalized).map { max(0, $0) }
    }
}
