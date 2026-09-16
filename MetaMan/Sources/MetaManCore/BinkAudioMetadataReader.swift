import Foundation

/// Reads the Bink container's audio packet headers without decoding Bink
/// audio or video. ScanSong's `.bika` inputs are demuxed Bink containers, so
/// their extension is kept separate from `.bik` movie inputs.
enum BinkAudioMetadataReader {
    static let supportedExtensions = ["bika"]

    private static let mainHeaderSize = 0x2C
    private static let maximumFrames = 1_000_000
    private static let maximumTracks = 256

    private struct Header {
        let signature: String
        let revision: UInt8
        let fileSize: Int
        let frameCount: Int
        let largestFrameSize: UInt32
        let width: Int32
        let height: Int32
        let fpsDividend: UInt32
        let fpsDivisor: UInt32
        let videoFlags: UInt32
        let totalTracks: Int
        let sampleRates: [Int]
        let audioFlags: [UInt16]
        let streamIDs: [UInt32]
        let frameOffsets: [Int]
        let headerEnd: Int
    }

    private struct StreamFacts {
        let channels: Int
        let sampleRate: Int
        let audioFlags: UInt16
        let streamID: UInt32
        let streamSize: Int64
        let decodedSampleCount: Int64
    }

    /// Lightweight content recognition for callers that already have bytes.
    /// Full bounds and frame validation happen in `read`.
    static func matches(_ data: Data) -> Bool {
        guard data.count >= mainHeaderSize,
              let headID = uint32BE(data, at: 0x00) else {
            return false
        }
        return signature(for: headID) != nil
    }

    /// Bink's fixed header and declared file size are enough for route
    /// selection. The complete offset table and packet walk remain in read.
    static func supports(fileURL: URL) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let physicalSize = (attributes[.size] as? NSNumber)?.intValue,
              let file = try? FileHandle(forReadingFrom: fileURL) else {
            return false
        }
        defer { try? file.close() }
        guard let probe = try? file.read(upToCount: mainHeaderSize),
              probe.count >= mainHeaderSize,
              matches(probe),
              let declaredSize = uint32LE(probe, at: 0x04) else {
            return false
        }
        return Int64(declaredSize) + 8 == Int64(physicalSize)
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    static func readResult(fileURL: URL) throws -> MetadataReadResult {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try readResult(data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        let result = try readResult(data: data, displayName: displayName)
        guard result.tracks.count == 1, let track = result.tracks.first else {
            throw MetadataReadError.trackAwareResultRequired("Bink audio")
        }
        return track.document
    }

    static func readResult(data: Data, displayName: String?) throws -> MetadataReadResult {
        let header = try parseHeader(data)
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }
        let tracks = try header.sampleRates.indices.map { index in
            let facts = try streamFacts(data: data, header: header, streamIndex: index)
            let playLengthMs = Int(facts.decodedSampleCount * 1_000 / Int64(facts.sampleRate))
            var technicalFacts: [String: String] = [
                "metadataSource": "RAD Game Tools Bink header",
                "signature": header.signature,
                "revision": String(decoding: [header.revision], as: UTF8.self),
                "fileSizeBytes": String(header.fileSize),
                "headerEndOffset": String(header.headerEnd),
                "frameCount": String(header.frameCount),
                "videoWidth": String(header.width),
                "videoHeight": String(header.height),
                "fpsDividend": String(header.fpsDividend),
                "fpsDivisor": String(header.fpsDivisor),
                "videoFlags": "0x\(String(header.videoFlags, radix: 16, uppercase: true))",
                "largestFrameSizeBytes": String(header.largestFrameSize),
                "totalAudioTracks": String(header.totalTracks),
                "sourceTrackIndex": String(index + 1),
                "streamID": "0x\(String(facts.streamID, radix: 16, uppercase: true))",
                "audioFlags": "0x\(String(facts.audioFlags, radix: 16, uppercase: true))",
                "audioCodec": facts.audioFlags & 0x1000 != 0 ? "DCT" : "RDFT",
                "channels": String(facts.channels),
                "sampleRateHz": String(facts.sampleRate),
                "streamSizeBytes": String(facts.streamSize),
                "decodedSampleCount": String(facts.decodedSampleCount),
                "loopEnabled": "false"
            ]
            if header.totalTracks > 1 {
                technicalFacts["trackTitleSource"] = "filename-fallback"
            }
            let document = MetadataDocument(
                format: "bika",
                fields: MetadataFields(title: title, comment: "RAD Game Tools Bink header"),
                rawMetadataBlocks: ["binkHeader": Data(data.prefix(header.headerEnd))],
                timing: MetadataTiming(
                    introLengthMs: 0,
                    loopLengthMs: 0,
                    playLengthMs: playLengthMs,
                    fadeLengthMs: 0
                ),
                technicalFacts: technicalFacts
            )
            return MetadataTrack(sourceTrackIndex: index + 1, document: document)
        }
        return MetadataReadResult(tracks: tracks)
    }

    private static func parseHeader(_ data: Data) throws -> Header {
        guard data.count >= mainHeaderSize,
              let headID = uint32BE(data, at: 0x00),
              let identity = signature(for: headID),
              let declaredSize = uint32LE(data, at: 0x04),
              Int64(declaredSize) + 8 == Int64(data.count),
              let rawFrameCount = uint32LE(data, at: 0x08),
              rawFrameCount > 0,
              rawFrameCount <= maximumFrames,
              let largestFrameSize = uint32LE(data, at: 0x0C),
              let width = int32LE(data, at: 0x14),
              let height = int32LE(data, at: 0x18),
              let fpsDividend = uint32LE(data, at: 0x1C),
              let fpsDivisor = uint32LE(data, at: 0x20),
              let videoFlags = uint32LE(data, at: 0x24),
              let rawTrackCount = int32LE(data, at: 0x28),
              rawTrackCount > 0,
              rawTrackCount <= maximumTracks else {
            throw malformed("Missing, truncated, or invalid Bink header.")
        }

        let frameCount = Int(rawFrameCount)
        let totalTracks = Int(rawTrackCount)
        var cursor = mainHeaderSize
        if (identity.signature == "BIK" && identity.revision >= Character("k").asciiValue!)
            || (identity.signature == "KB2" && identity.revision >= Character("i").asciiValue!) {
            cursor = try advanced(cursor, by: 4, limit: data.count)
        }
        if videoFlags & 0x000004 != 0 {
            cursor = try advanced(cursor, by: 0x0C, limit: data.count)
        }
        if videoFlags & 0x010000 != 0 {
            cursor = try advanced(cursor, by: 0x18, limit: data.count)
        }

        let maximumPacketEnd = try advanced(cursor, by: 4 * totalTracks, limit: data.count)
        let sampleRateOffset = maximumPacketEnd
        let streamInfoEnd = try advanced(sampleRateOffset, by: 4 * totalTracks, limit: data.count)
        let streamIDOffset = streamInfoEnd
        let frameTableOffset = try advanced(streamIDOffset, by: 4 * totalTracks, limit: data.count)

        var sampleRates: [Int] = []
        var audioFlags: [UInt16] = []
        var streamIDs: [UInt32] = []
        sampleRates.reserveCapacity(totalTracks)
        audioFlags.reserveCapacity(totalTracks)
        streamIDs.reserveCapacity(totalTracks)
        for index in 0..<totalTracks {
            let infoOffset = sampleRateOffset + index * 4
            guard let sampleRate = uint16LE(data, at: infoOffset), sampleRate > 0,
                  let flags = uint16LE(data, at: infoOffset + 2),
                  let streamID = uint32LE(data, at: streamIDOffset + index * 4) else {
                throw malformed("Bink audio stream information is truncated or invalid.")
            }
            sampleRates.append(Int(sampleRate))
            audioFlags.append(flags)
            streamIDs.append(streamID)
        }

        var frameOffsets: [Int] = []
        frameOffsets.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            guard let rawOffset = uint32LE(data, at: frameTableOffset + index * 4) else {
                throw malformed("Bink frame offset table is truncated.")
            }
            let frameOffset = Int(rawOffset & 0xFFFF_FFFE)
            guard frameOffset < data.count else {
                throw malformed("Bink frame offset is outside the file.")
            }
            frameOffsets.append(frameOffset)
        }
        let headerEnd = try advanced(frameTableOffset, by: 4 * frameCount + 4, limit: data.count)
        guard let trailingFileSize = uint32LE(data, at: headerEnd - 4),
              Int64(trailingFileSize) == Int64(declaredSize) + 8 else {
            throw malformed("Bink frame table has an invalid trailing file size.")
        }

        return Header(
            signature: identity.signature,
            revision: identity.revision,
            fileSize: data.count,
            frameCount: frameCount,
            largestFrameSize: largestFrameSize,
            width: width,
            height: height,
            fpsDividend: fpsDividend,
            fpsDivisor: fpsDivisor,
            videoFlags: videoFlags,
            totalTracks: totalTracks,
            sampleRates: sampleRates,
            audioFlags: audioFlags,
            streamIDs: streamIDs,
            frameOffsets: frameOffsets,
            headerEnd: headerEnd
        )
    }

    private static func streamFacts(
        data: Data,
        header: Header,
        streamIndex: Int
    ) throws -> StreamFacts {
        let channels = header.audioFlags[streamIndex] & 0x2000 != 0 ? 2 : 1
        var streamSize: Int64 = 0
        var decodedBytes: Int64 = 0

        for frameOffset in header.frameOffsets {
            var cursor = frameOffset
            for candidate in 0...streamIndex {
                guard let rawPacketSize = uint32LE(data, at: cursor),
                      UInt64(rawPacketSize) <= UInt64(Int.max - 4) else {
                    throw malformed("Bink audio packet header is truncated or oversized.")
                }
                let packetSize = Int(rawPacketSize) + 4
                guard packetSize <= data.count - cursor else {
                    throw malformed("Bink audio packet extends beyond the file.")
                }
                if candidate == streamIndex {
                    streamSize += Int64(packetSize)
                    if rawPacketSize > 0 {
                        guard rawPacketSize >= 4,
                              let sampleBytes = uint32LE(data, at: cursor + 4) else {
                            throw malformed("Bink audio packet lacks its decoded-byte count.")
                        }
                        decodedBytes += Int64(sampleBytes)
                    }
                    break
                }
                cursor += packetSize
            }
        }

        let decodedSampleCount = decodedBytes / Int64(2 * channels)
        guard decodedSampleCount > 0 else {
            throw malformed("Bink audio stream contains no decoded samples.")
        }
        return StreamFacts(
            channels: channels,
            sampleRate: Int(header.sampleRates[streamIndex]),
            audioFlags: header.audioFlags[streamIndex],
            streamID: header.streamIDs[streamIndex],
            streamSize: streamSize,
            decodedSampleCount: decodedSampleCount
        )
    }

    private static func signature(for headID: UInt32) -> (signature: String, revision: UInt8)? {
        switch headID & 0xFFFF_FF00 {
        case 0x4249_4B00:
            return ("BIK", UInt8(headID & 0xFF))
        case 0x4B42_3200:
            return ("KB2", UInt8(headID & 0xFF))
        default:
            return nil
        }
    }

    private static func advanced(_ offset: Int, by amount: Int, limit: Int) throws -> Int {
        guard amount >= 0, offset <= limit - amount else {
            throw malformed("Bink header extends beyond the file.")
        }
        return offset + amount
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("Bink audio metadata reader: \(reason)")
    }

    private static func uint16LE(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, data.count - offset >= 2 else { return nil }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func uint32LE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func uint32BE(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, data.count - offset >= 4 else { return nil }
        return UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func int32LE(_ data: Data, at offset: Int) -> Int32? {
        uint32LE(data, at: offset).map(Int32.init(bitPattern:))
    }
}
