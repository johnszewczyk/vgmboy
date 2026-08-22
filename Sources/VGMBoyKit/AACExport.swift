import AudioToolbox
import Foundation

/// A finite, offline render request. The frontend supplies its already-known
/// display name and timing policy; VGMBoy never looks up catalog metadata.
public struct AACExportRequest: Sendable, Equatable {
    public var sourcePath: String
    public var trackIndex: Int
    public var outputDirectory: URL
    public var filenameStem: String
    public var playMilliseconds: Int
    public var fadeMilliseconds: Int

    public init(
        sourcePath: String,
        trackIndex: Int = 0,
        outputDirectory: URL,
        filenameStem: String,
        playMilliseconds: Int,
        fadeMilliseconds: Int
    ) {
        self.sourcePath = sourcePath
        self.trackIndex = trackIndex
        self.outputDirectory = outputDirectory
        self.filenameStem = filenameStem
        self.playMilliseconds = playMilliseconds
        self.fadeMilliseconds = fadeMilliseconds
    }
}

public struct AACExportResult: Sendable, Equatable {
    public let outputURL: URL
    public let renderedFrames: Int64
    public let sampleRate: Int
}

public enum AACExportError: LocalizedError, Equatable {
    case invalidRequest(String)
    case audioToolbox(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message): return message
        case .audioToolbox(let status): return "AAC export failed (AudioToolbox status \(status))."
        }
    }
}

/// Offline AAC/ADTS renderer. It builds a separate decoder and never touches
/// the live output device, transport buffer, queue, or frontend catalog.
public enum AACExporter {
    private static let sampleRate = 44_100
    private static let chunkFrames = 4_096

    public static func export(_ request: AACExportRequest) throws -> AACExportResult {
        guard request.trackIndex >= 0 else {
            throw AACExportError.invalidRequest("AAC export requires a non-negative track index.")
        }
        guard request.playMilliseconds > 0, request.fadeMilliseconds >= 0 else {
            throw AACExportError.invalidRequest("AAC export requires a positive play length and a non-negative fade.")
        }
        guard FormatRegistry.family(for: request.sourcePath) != nil else {
            throw AACExportError.invalidRequest("AAC export requires a supported playable file.")
        }
        let directory = request.outputDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AACExportError.invalidRequest("AAC export folder does not exist: \(directory.path)")
        }

        let outputURL = uniqueOutputURL(in: directory, filenameStem: request.filenameStem)
        let decoder = try DecoderFactory.make(path: request.sourcePath, sampleRate: sampleRate)
        defer { decoder.close() }
        try decoder.startTrack(request.trackIndex)
        decoder.configureFade(playMs: request.playMilliseconds, fadeMs: request.fadeMilliseconds)

        let capFrames = Int64(request.playMilliseconds + request.fadeMilliseconds) * Int64(sampleRate) / 1_000
        var writer: ExtAudioFileRef?
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate), mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 1_024,
            mBytesPerFrame: 0, mChannelsPerFrame: 2, mBitsPerChannel: 0, mReserved: 0
        )
        try check(ExtAudioFileCreateWithURL(
            outputURL as CFURL, kAudioFileAAC_ADTSType, &fileFormat, nil,
            AudioFileFlags.eraseFile.rawValue, &writer
        ))
        guard let writer else { throw AACExportError.invalidRequest("AAC export could not create its output file.") }
        defer { ExtAudioFileDispose(writer) }

        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8,
            mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0
        )
        try check(ExtAudioFileSetProperty(
            writer, kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat
        ))

        var renderedFrames: Int64 = 0
        while renderedFrames < capFrames && !decoder.trackEnded {
            let wanted = min(chunkFrames, Int(capFrames - renderedFrames))
            let frames = decoder.readFrames(wanted)
            let count = min(wanted, min(frames.left.count, frames.right.count))
            guard count > 0 else { break }
            var interleaved = [Float](repeating: 0, count: count * 2)
            for index in 0..<count {
                interleaved[index * 2] = frames.left[index]
                interleaved[index * 2 + 1] = frames.right[index]
            }
            try interleaved.withUnsafeMutableBytes { bytes in
                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress)
                )
                try check(ExtAudioFileWrite(writer, UInt32(count), &bufferList))
            }
            renderedFrames += Int64(count)
        }
        return AACExportResult(outputURL: outputURL, renderedFrames: renderedFrames, sampleRate: sampleRate)
    }

    private static func uniqueOutputURL(in directory: URL, filenameStem: String) -> URL {
        let invalid = CharacterSet(charactersIn: "/:\\")
        let trimmed = filenameStem.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed.components(separatedBy: invalid).joined(separator: "-")
        let base = sanitized.isEmpty ? "Untitled Track" : sanitized
        var candidate = directory.appendingPathComponent(base).appendingPathExtension("aac")
        var ordinal = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(ordinal)").appendingPathExtension("aac")
            ordinal += 1
        }
        return candidate
    }

    private static func check(_ status: OSStatus) throws {
        guard status == noErr else { throw AACExportError.audioToolbox(status) }
    }
}
