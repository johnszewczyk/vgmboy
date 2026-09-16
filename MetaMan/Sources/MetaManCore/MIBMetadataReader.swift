import Foundation

/// Reads the headerless PlayStation ADPCM layout that vgmstream admits as
/// `.mib`.  There is no stored sample-rate/channel header in this layout:
/// vgmstream uses the extension for 44.1 kHz and infers interleave, channels,
/// and optional loop markers from the PS-ADPCM frame stream.  Keep the probe
/// and arithmetic aligned with that reference so direct ScanSong rows do not
/// silently change the old catalog's behavior.
enum MIBMetadataReader {
    static let supportedExtensions: Set<String> = ["mib"]

    private static let frameSize = 0x10
    private static let probeSize = 0x2000
    private static let sampleRate = Int64(44_100)
    private static let maxChannels = 32
    private static let maxSamples = Int64(1_000_000_000)

    static func matches(_ data: Data) -> Bool {
        guard data.count >= frameSize else { return false }
        return psFramesAreValid(data)
    }

    static func supports(fileURL: URL) -> Bool {
        guard fileURL.pathExtension.caseInsensitiveCompare("mib") == .orderedSame,
              let file = try? FileHandle(forReadingFrom: fileURL) else {
            return false
        }
        defer { try? file.close() }
        guard let probe = try? file.read(upToCount: probeSize) else { return false }
        return matches(probe)
    }

    static func read(fileURL: URL) throws -> MetadataDocument {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return try read(data: data, displayName: fileURL.lastPathComponent)
    }

    static func read(data: Data, displayName: String?) throws -> MetadataDocument {
        guard data.count >= frameSize else {
            throw malformed("Headerless PS-ADPCM source is shorter than one frame.")
        }
        guard matches(data) else {
            throw MetadataReadError.unsupportedFormat("headerless PS-ADPCM frame probe")
        }

        let analysis = analyze(data)
        guard (1...maxChannels).contains(analysis.channels),
              analysis.interleave > 0,
              analysis.sampleCount > 0,
              analysis.sampleCount <= maxSamples else {
            throw malformed("Inferred channel, interleave, or sample-count facts are invalid.")
        }

        var loopStart = analysis.loopStartSample
        var loopEnd = analysis.loopEndSample
        let invalidLoop = analysis.hasLoop && (
            loopStart < 0 || loopEnd <= loopStart || loopEnd > analysis.sampleCount
        )
        var diagnostics: [String] = []
        if invalidLoop {
            diagnostics.append("Invalid inferred MIB loop bounds were retained as source facts but omitted from timing.")
            loopStart = 0
            loopEnd = 0
        }

        let looping = !invalidLoop && loopEnd > loopStart
        let loopLength = looping ? loopEnd - loopStart : 0
        let playSamples = looping
            ? loopStart + loopLength * 2 + sampleRate * 10
            : analysis.sampleCount
        let title = displayName.map {
            URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent
        }

        var facts: [String: String] = [
            "codecName": "PS-ADPCM",
            "layout": analysis.channels == 1 ? "none" : "interleave",
            "sampleRateHz": String(sampleRate),
            "channels": String(analysis.channels),
            "interleaveBlockSizeBytes": String(analysis.interleave),
            "decodedSampleCount": String(analysis.sampleCount),
            "loopEnabled": String(looping),
            "loopStartSample": String(loopStart),
            "loopEndSample": String(loopEnd),
            "rawLoopStartBytes": String(analysis.rawLoopStartBytes),
            "rawLoopEndBytesExclusive": String(analysis.rawLoopEndBytes),
            "loopToEnd": String(analysis.loopToEnd),
            "forceNoLoop": String(analysis.forceNoLoop),
            "channelCountInferred": String(analysis.channelsInferred),
            "interleaveInferred": String(analysis.interleaveInferred),
            "emptyFrameSeen": String(analysis.emptyFrameSeen),
            "metadataSource": "Headerless PS-ADPCM raw header"
        ]
        facts["sampleRateSource"] = "MIB extension default"

        return MetadataDocument(
            format: "mib",
            fields: MetadataFields(title: title, comment: "Headerless PS-ADPCM raw header"),
            rawMetadataBlocks: ["mibProbeHeader": Data(data.prefix(frameSize))],
            timing: MetadataTiming(
                introLengthMs: 0,
                loopLengthMs: milliseconds(loopLength),
                playLengthMs: milliseconds(playSamples),
                fadeLengthMs: 0
            ),
            technicalFacts: facts,
            diagnostics: diagnostics
        )
    }

    private struct Analysis {
        let channels: Int
        let channelsInferred: Bool
        let interleave: Int64
        let interleaveInferred: Bool
        let sampleCount: Int64
        let rawLoopStartBytes: Int64
        let rawLoopEndBytes: Int64
        let loopStartSample: Int64
        let loopEndSample: Int64
        let loopToEnd: Bool
        let forceNoLoop: Bool
        let emptyFrameSeen: Bool

        var hasLoop: Bool { rawLoopEndBytes != 0 }
    }

    private static func analyze(_ data: Data) -> Analysis {
        data.withUnsafeBytes { rawBuffer in
            analyze(rawBuffer.bindMemory(to: UInt8.self))
        }
    }

    private static func analyze(_ data: UnsafeBufferPointer<UInt8>) -> Analysis {
        let fileLength = Int64(data.count)
        var mibFrame = Array(data.prefix(frameSize))
        mibFrame[0] = 0

        var loopStartPoints: [Int64] = []
        var loopEndPoints: [Int64] = []
        var loopToEnd = false
        var forceNoLoop = false
        var emptyFrameSeen = false
        var channelCount = 0
        var interleave: Int64 = 0
        var didUpdateChannel = true
        var didUpdateInterleave = true
        var readOffset: Int64 = 0
        var lastFrameFirst: UInt8 = 0
        var lastFrameFlags: UInt8 = 0
        var lastFrameByte3: UInt8 = 0

        while readOffset < fileLength {
            lastFrameFirst = byte(data, at: readOffset)
            lastFrameFlags = byte(data, at: readOffset + 1)
            lastFrameByte3 = byte(data, at: readOffset + 3)
            readOffset += Int64(min(frameSize, max(0, Int(fileLength - readOffset))))
            if readOffset < fileLength / 2 {
                if !frameMatches(data, at: readOffset - Int64(frameSize), reference: mibFrame, startingAt: 2) {
                    if didUpdateChannel {
                        didUpdateChannel = false
                        channelCount += 1
                    }
                    if channelCount < 2 {
                        didUpdateInterleave = true
                    }
                }

                if frameMatches(data, at: readOffset - Int64(frameSize), reference: mibFrame, startingAt: 1) {
                    emptyFrameSeen = true
                    if didUpdateInterleave {
                        didUpdateInterleave = false
                        interleave = readOffset - Int64(frameSize)
                    }
                    if readOffset - Int64(frameSize) == Int64(channelCount) * interleave {
                        didUpdateChannel = true
                    }
                }
            }

            if lastFrameFlags == 0x06, loopStartPoints.count < 0x10 {
                loopStartPoints.append(readOffset - Int64(frameSize))
            }
            if lastFrameFlags == 0x03, lastFrameByte3 != 0x77, loopEndPoints.count < 0x10 {
                loopEndPoints.append(readOffset)
            }
            if lastFrameFlags == 0x04, loopStartPoints.count < 0x10 {
                loopStartPoints.append(readOffset - Int64(frameSize))
                loopToEnd = true
            }
        }

        if lastFrameFirst == 0x0C, lastFrameFlags == 0 {
            forceNoLoop = true
        }

        if channelCount == 0 {
            channelCount = 1
        }

        if loopStartPoints.count >= 2 {
            if loopStartPoints.count <= 0x0F {
                interleave = loopStartPoints[1] - loopStartPoints[0]
                if interleave > 0, channelCount == 1 {
                    channelCount = 2
                }
            }
        }
        var rawLoopStartBytes: Int64 = 0
        if loopStartPoints.count >= 2, loopStartPoints.count <= 0x0F {
            rawLoopStartBytes = loopStartPoints[1]
        }

        var rawLoopEndBytes: Int64 = 0
        if loopEndPoints.count >= 2, loopEndPoints.count <= 0x0F {
            rawLoopEndBytes = loopEndPoints[loopEndPoints.count - 1]
            if channelCount == 1 {
                channelCount = 2
            }
        } else if loopEndPoints.count >= 0x10 {
            loopToEnd = false
        }

        if loopToEnd {
            rawLoopEndBytes = fileLength
        }
        if forceNoLoop {
            rawLoopEndBytes = 0
        }

        if interleave > Int64(frameSize), channelCount == 1 {
            channelCount = 2
        }
        if interleave == 0 {
            interleave = Int64(frameSize)
        }

        if emptyFrameSeen {
            var newChannelCount = 0
            var emptyOffset: Int64 = 0
            while true {
                guard emptyOffset < fileLength else { break }
                newChannelCount += 1
                if !frameMatches(data, at: emptyOffset, reference: mibFrame, startingAt: 1) { break }
                emptyOffset += interleave
            }
            newChannelCount -= 1
            if newChannelCount > channelCount {
                channelCount = newChannelCount
            }
        }

        let sampleCount = fileLength / Int64(frameSize) / Int64(channelCount) * 28
        let loopSamples = loopSamples(
            loopStartBytes: rawLoopStartBytes,
            loopEndBytes: rawLoopEndBytes,
            fileLength: fileLength,
            interleave: interleave,
            channels: channelCount,
            loopToEnd: loopToEnd
        )
        return Analysis(
            channels: channelCount,
            channelsInferred: true,
            interleave: interleave,
            interleaveInferred: interleave != Int64(frameSize),
            sampleCount: sampleCount,
            rawLoopStartBytes: rawLoopStartBytes,
            rawLoopEndBytes: rawLoopEndBytes,
            loopStartSample: loopSamples.start,
            loopEndSample: loopSamples.end,
            loopToEnd: loopToEnd,
            forceNoLoop: forceNoLoop,
            emptyFrameSeen: emptyFrameSeen
        )
    }

    @inline(__always)
    private static func byte(_ data: UnsafeBufferPointer<UInt8>, at offset: Int64) -> UInt8 {
        guard offset >= 0, offset < Int64(data.count) else { return 0 }
        return data[Int(offset)]
    }

    @inline(__always)
    private static func frameMatches(
        _ data: UnsafeBufferPointer<UInt8>,
        at offset: Int64,
        reference: [UInt8],
        startingAt start: Int
    ) -> Bool {
        for index in start..<frameSize {
            if byte(data, at: offset + Int64(index)) != reference[index] { return false }
        }
        return true
    }

    private static func loopSamples(
        loopStartBytes: Int64,
        loopEndBytes: Int64,
        fileLength: Int64,
        interleave: Int64,
        channels: Int,
        loopToEnd: Bool
    ) -> (start: Int64, end: Int64) {
        guard loopEndBytes != 0 else { return (0, 0) }
        let channelCount = Int64(channels)
        if channels == 1 {
            return (
                loopStartBytes / Int64(frameSize) * 18,
                loopEndBytes / Int64(frameSize) * 28
            )
        }

        func interleavedSamples(_ bytes: Int64) -> Int64 {
            var samples = ((bytes / interleave - 1) * interleave) / Int64(frameSize) * 14
            if bytes % interleave != 0 {
                samples += ((bytes % interleave - 1) / Int64(frameSize) * 14 * channelCount)
            }
            return samples
        }

        let start = interleavedSamples(loopStartBytes)
        let end = loopToEnd && loopEndBytes == fileLength
            ? (loopEndBytes / Int64(frameSize) * 28) / channelCount
            : interleavedSamples(loopEndBytes)
        return (start, end)
    }

    private static func psFramesAreValid(_ data: Data) -> Bool {
        data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let end = min(bytes.count, probeSize)
            var offset = 0
            while offset < end {
                guard offset + 1 < bytes.count else { return false }
                let predictor = (bytes[offset] >> 4) & 0x0F
                let flags = bytes[offset + 1]
                guard predictor <= 5, flags <= 7 else { return false }
                offset += frameSize
            }
            return true
        }
    }

    private static func milliseconds(_ samples: Int64) -> Int {
        guard samples > 0 else { return 0 }
        return Int(samples * 1_000 / sampleRate)
    }

    private static func malformed(_ reason: String) -> MetadataReadError {
        .malformedFile("MIB metadata reader: \(reason)")
    }
}
