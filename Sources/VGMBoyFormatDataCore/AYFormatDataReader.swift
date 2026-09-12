import Foundation

public struct AYTrackFacts: Codable, Equatable, Sendable {
    public let sourceTrackIndex: Int
    public let title: String
    /// AY stores this duration in 50 Hz frames. A missing pointer yields nil.
    public let lengthFrames: UInt16?
    public let metadata: FormatMetadata

    public init(sourceTrackIndex: Int, title: String, lengthFrames: UInt16?, metadata: FormatMetadata) {
        self.sourceTrackIndex = sourceTrackIndex
        self.title = title
        self.lengthFrames = lengthFrames
        self.metadata = metadata
    }
}

public struct AYFormatFacts: Codable, Equatable, Sendable {
    public let version: UInt8
    public let playerID: UInt8
    public let firstTrack: UInt8
    public let trackCount: Int
    public let author: String
    public let comment: String
    public let tracks: [AYTrackFacts]

    public init(
        version: UInt8,
        playerID: UInt8,
        firstTrack: UInt8,
        trackCount: Int,
        author: String,
        comment: String,
        tracks: [AYTrackFacts]
    ) {
        self.version = version
        self.playerID = playerID
        self.firstTrack = firstTrack
        self.trackCount = trackCount
        self.author = author
        self.comment = comment
        self.tracks = tracks
    }
}

/// Reads the ZXAYEMUL metadata and per-subsong length table without executing
/// its embedded Z80 player. Relative pointers are signed and file-bounded.
public enum AYFormatDataReader {
    private static let signature = Array("ZXAYEMUL".utf8)
    private static let headerSize = 0x14
    private static let maxTextBytes = 255
    private static let defaultPlayLengthMs = 150_000

    public static func read(data: Data, displayName: String) throws -> AYFormatFacts {
        try data.withUnsafeBytes { rawBytes in
            let bytes = rawBytes.bindMemory(to: UInt8.self)
            guard bytes.count >= headerSize,
                  bytes[..<signature.count].elementsEqual(signature) else {
                throw malformed("Not a ZXAYEMUL file with a complete header", displayName)
            }

            let version = bytes[8]
            let playerID = bytes[9]
            let maximumTrack = Int(bytes[16])
            let firstTrack = bytes[17]
            let trackCount = maximumTrack + 1
            let trackTableOffset = relativeTarget(
                in: bytes,
                pointerOffset: 18,
                minimumTargetBytes: trackCount * 4
            )
            guard let trackTableOffset else {
                throw malformed("AY track pointer table is missing or truncated", displayName)
            }

            let author = text(in: bytes, pointerOffset: 12)
            let comment = text(in: bytes, pointerOffset: 14)
            var tracks: [AYTrackFacts] = []
            tracks.reserveCapacity(trackCount)

            for sourceTrackIndex in 0..<trackCount {
                let rowOffset = trackTableOffset + sourceTrackIndex * 4
                let title = text(in: bytes, pointerOffset: rowOffset)
                let infoOffset = relativeTarget(in: bytes, pointerOffset: rowOffset + 2, minimumTargetBytes: 6)
                let lengthFrames = infoOffset.flatMap { bigEndianUInt16(in: bytes, at: $0 + 4) }
                let authoredLengthMs = lengthFrames.map { Int($0) * 20 } ?? -1
                let playLengthMs = authoredLengthMs > 0 ? authoredLengthMs : defaultPlayLengthMs
                let metadata = FormatMetadata(
                    game: "",
                    song: title,
                    system: "ZX Spectrum",
                    author: author,
                    comment: comment,
                    introLengthMs: -1,
                    loopLengthMs: -1,
                    playLengthMs: playLengthMs,
                    fadeLengthMs: -1
                )
                tracks.append(AYTrackFacts(
                    sourceTrackIndex: sourceTrackIndex,
                    title: title,
                    lengthFrames: lengthFrames,
                    metadata: metadata
                ))
            }

            return AYFormatFacts(
                version: version,
                playerID: playerID,
                firstTrack: firstTrack,
                trackCount: trackCount,
                author: author,
                comment: comment,
                tracks: tracks
            )
        }
    }

    private static func text(in bytes: UnsafeBufferPointer<UInt8>, pointerOffset: Int) -> String {
        guard let target = relativeTarget(in: bytes, pointerOffset: pointerOffset, minimumTargetBytes: 1) else {
            return ""
        }

        var start = target
        while start < bytes.count, bytes[start] != 0, bytes[start] <= 0x20 { start += 1 }
        let limit = start + min(bytes.count - start, maxTextBytes)
        var end = start
        while end < limit, bytes[end] != 0 { end += 1 }
        while end > start, bytes[end - 1] <= 0x20 { end -= 1 }
        let decoded = String(decoding: bytes[start..<end], as: UTF8.self)
        return ["?", "<?>", "< ? >"].contains(decoded) ? "" : decoded
    }

    private static func relativeTarget(
        in bytes: UnsafeBufferPointer<UInt8>,
        pointerOffset: Int,
        minimumTargetBytes: Int
    ) -> Int? {
        guard pointerOffset >= 0,
              pointerOffset <= bytes.count - 2,
              minimumTargetBytes > 0,
              let rawOffset = bigEndianUInt16(in: bytes, at: pointerOffset),
              rawOffset != 0 else { return nil }

        let relativeOffset = Int(Int16(bitPattern: rawOffset))
        let (target, overflow) = pointerOffset.addingReportingOverflow(relativeOffset)
        guard !overflow,
              target >= 0,
              target <= bytes.count - minimumTargetBytes else { return nil }
        return target
    }

    private static func bigEndianUInt16(in bytes: UnsafeBufferPointer<UInt8>, at offset: Int) -> UInt16? {
        guard offset >= 0, offset <= bytes.count - 2 else { return nil }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func malformed(_ message: String, _ displayName: String) -> FormatDataError {
        .malformed("\(message): \(displayName)")
    }
}
