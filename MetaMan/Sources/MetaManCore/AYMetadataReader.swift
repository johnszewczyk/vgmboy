import Foundation

/// Reads ZXAYEMUL metadata and subtune lengths without executing its embedded
/// Z80 player. Track-array order and the native zero-based AY slot are retained.
enum AYMetadataReader {
    private static let signature = Array("ZXAYEMUL".utf8)
    private static let headerSize = 0x14
    private static let maxTextBytes = 255
    private static let defaultPlayLengthMs = 150_000

    static func matches(_ data: Data) -> Bool {
        data.count >= signature.count && data.prefix(signature.count).elementsEqual(signature)
    }

    static func readResult(data: Data, displayName: String?) throws -> MetadataReadResult {
        try data.withUnsafeBytes { rawBytes in
            let bytes = rawBytes.bindMemory(to: UInt8.self)
            let name = displayName ?? "AY source"
            guard bytes.count >= headerSize,
                  bytes[..<signature.count].elementsEqual(signature) else {
                throw malformed("Not a ZXAYEMUL file with a complete header", name)
            }

            let version = bytes[8]
            let playerID = bytes[9]
            let maximumTrack = Int(bytes[16])
            let firstTrack = bytes[17]
            let trackCount = maximumTrack + 1
            guard case let .target(tableOffset) = relativeTarget(
                in: bytes,
                pointerOffset: 18,
                minimumTargetBytes: trackCount * 4
            ) else {
                throw malformed("AY track pointer table is missing or truncated", name)
            }

            let authorText = readText(in: bytes, pointerOffset: 12, label: "author", displayName: name)
            let commentText = readText(in: bytes, pointerOffset: 14, label: "comment", displayName: name)
            let sharedDiagnostics = [authorText.diagnostic, commentText.diagnostic].compactMap { $0 }
            let pointerTableEnd = tableOffset + trackCount * 4
            let rawHeader = Data(bytes[..<headerSize])
            let rawTrackTable = Data(bytes[tableOffset..<pointerTableEnd])
            var tracks: [MetadataTrack] = []
            tracks.reserveCapacity(trackCount)

            for sourceTrackIndex in 0..<trackCount {
                let rowOffset = tableOffset + sourceTrackIndex * 4
                let titleText = readText(
                    in: bytes,
                    pointerOffset: rowOffset,
                    label: "track \(sourceTrackIndex) title",
                    displayName: name
                )
                let infoPointer = relativeTarget(
                    in: bytes,
                    pointerOffset: rowOffset + 2,
                    minimumTargetBytes: 6
                )
                let infoOffset: Int?
                switch infoPointer {
                case .target(let offset):
                    infoOffset = offset
                case .missing:
                    infoOffset = nil
                case .invalid:
                    infoOffset = nil
                }
                var diagnostics = sharedDiagnostics + [titleText.diagnostic].compactMap { $0 }
                if case .invalid = infoPointer {
                    diagnostics.append("AY track \(sourceTrackIndex) info pointer is outside the source bounds in \(name).")
                }

                let lengthFrames = infoOffset.flatMap { bigEndianUInt16(in: bytes, at: $0 + 4) }
                let authoredLengthMs = lengthFrames.map { Int($0) * 20 } ?? -1
                let playLengthMs = authoredLengthMs > 0 ? authoredLengthMs : defaultPlayLengthMs
                var technicalFacts = [
                    "version": String(version),
                    "playerID": String(playerID),
                    "firstTrack": String(firstTrack),
                    "maximumTrack": String(maximumTrack),
                    "declaredTrackCount": String(trackCount),
                    "sourceTrackIndex": String(sourceTrackIndex),
                    "lengthRateHz": "50"
                ]
                if let lengthFrames {
                    technicalFacts["lengthFrames"] = String(lengthFrames)
                }

                var rawBlocks: [String: Data] = [
                    "ayHeader": rawHeader,
                    "ayTrackPointerTable": rawTrackTable
                ]
                if let raw = authorText.rawBytes { rawBlocks["authorText"] = raw }
                if let raw = commentText.rawBytes { rawBlocks["commentText"] = raw }
                if let raw = titleText.rawBytes {
                    rawBlocks["track\(sourceTrackIndex)Title"] = raw
                }
                if let infoOffset {
                    rawBlocks["track\(sourceTrackIndex)Info"] = Data(bytes[infoOffset..<(infoOffset + 6)])
                }

                let document = MetadataDocument(
                    format: "ay",
                    fields: MetadataFields(
                        title: titleText.value.isEmpty ? nil : titleText.value,
                        system: "ZX Spectrum",
                        artist: authorText.value.isEmpty ? nil : authorText.value,
                        comment: commentText.value.isEmpty ? nil : commentText.value
                    ),
                    rawMetadataBlocks: rawBlocks,
                    sourceEncoding: "UTF-8",
                    timing: MetadataTiming(
                        introLengthMs: -1,
                        loopLengthMs: -1,
                        playLengthMs: playLengthMs,
                        fadeLengthMs: -1
                    ),
                    technicalFacts: technicalFacts,
                    diagnostics: diagnostics
                )
                tracks.append(MetadataTrack(sourceTrackIndex: sourceTrackIndex, document: document))
            }

            return MetadataReadResult(tracks: tracks)
        }
    }

    private static func readText(
        in bytes: UnsafeBufferPointer<UInt8>,
        pointerOffset: Int,
        label: String,
        displayName: String
    ) -> TextValue {
        switch relativeTarget(in: bytes, pointerOffset: pointerOffset, minimumTargetBytes: 1) {
        case .missing:
            return TextValue(value: "", rawBytes: nil, diagnostic: nil)
        case .invalid:
            return TextValue(
                value: "",
                rawBytes: nil,
                diagnostic: "AY \(label) pointer is outside the source bounds in \(displayName)."
            )
        case .target(let target):
            var start = target
            while start < bytes.count, bytes[start] != 0, bytes[start] <= 0x20 { start += 1 }
            let limit = start + min(bytes.count - start, maxTextBytes)
            var end = start
            while end < limit, bytes[end] != 0 { end += 1 }
            while end > start, bytes[end - 1] <= 0x20 { end -= 1 }

            let decoded = String(decoding: bytes[start..<end], as: UTF8.self)
            let value = ["?", "<?>", "< ? >"].contains(decoded) ? "" : decoded
            let rawLimit = min(bytes.count, target + maxTextBytes)
            var rawEnd = target
            while rawEnd < rawLimit, bytes[rawEnd] != 0 { rawEnd += 1 }
            if rawEnd < rawLimit { rawEnd += 1 }
            return TextValue(value: value, rawBytes: Data(bytes[target..<rawEnd]), diagnostic: nil)
        }
    }

    private static func relativeTarget(
        in bytes: UnsafeBufferPointer<UInt8>,
        pointerOffset: Int,
        minimumTargetBytes: Int
    ) -> PointerTarget {
        guard pointerOffset >= 0,
              pointerOffset <= bytes.count - 2,
              minimumTargetBytes > 0,
              let rawOffset = bigEndianUInt16(in: bytes, at: pointerOffset) else { return .invalid }
        guard rawOffset != 0 else { return .missing }

        let relativeOffset = Int(Int16(bitPattern: rawOffset))
        let (target, overflow) = pointerOffset.addingReportingOverflow(relativeOffset)
        guard !overflow,
              target >= 0,
              target <= bytes.count - minimumTargetBytes else { return .invalid }
        return .target(target)
    }

    private static func bigEndianUInt16(in bytes: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= bytes.count - 2 else { return nil }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func malformed(_ message: String, _ displayName: String) -> MetadataReadError {
        .malformedFile("\(message): \(displayName)")
    }

    private enum PointerTarget {
        case missing
        case invalid
        case target(Int)
    }

    private struct TextValue {
        let value: String
        let rawBytes: Data?
        let diagnostic: String?
    }
}
