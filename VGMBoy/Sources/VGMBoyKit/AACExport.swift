import AudioToolbox
import Foundation

/// A finite, offline render request. The frontend supplies its already-known
/// display name and timing policy; VGMBoy never looks up catalog metadata.
public struct AACExportRequest: Sendable, Equatable {
    public var sourcePath: String
    public var archiveEntry: String?
    public var trackIndex: Int
    public var outputDirectory: URL
    public var filenameStem: String
    public var playMilliseconds: Int
    public var fadeMilliseconds: Int
    public var tempo: Double
    public var loop: PlaybackLoopMetadata?
    public var readEmbeddedLoopTags: Bool

    public init(
        sourcePath: String,
        archiveEntry: String? = nil,
        trackIndex: Int = 0,
        outputDirectory: URL,
        filenameStem: String,
        playMilliseconds: Int,
        fadeMilliseconds: Int,
        tempo: Double = 1,
        loop: PlaybackLoopMetadata? = nil,
        readEmbeddedLoopTags: Bool = true
    ) {
        self.sourcePath = sourcePath
        self.archiveEntry = archiveEntry
        self.trackIndex = trackIndex
        self.outputDirectory = outputDirectory
        self.filenameStem = filenameStem
        self.playMilliseconds = playMilliseconds
        self.fadeMilliseconds = fadeMilliseconds
        self.tempo = tempo
        self.loop = loop
        self.readEmbeddedLoopTags = readEmbeddedLoopTags
    }
}

public struct AACExportResult: Sendable, Equatable {
    public let outputURL: URL
    public let renderedFrames: Int64
    public let sampleRate: Int
}

/// A thread-safe cancellation token for an offline AAC render. Cancellation is
/// observed between decode blocks; the exporter never publishes a partial file
/// at the requested destination.
public final class AACExportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

/// Presentation-neutral progress for one finite offline render. A host can
/// use this to build a queue or conversion dialog without owning decoding.
public struct AACExportProgress: Sendable, Equatable {
    public let renderedFrames: Int64
    public let totalFrames: Int64
    public let sampleRate: Int

    public init(renderedFrames: Int64, totalFrames: Int64, sampleRate: Int) {
        self.renderedFrames = renderedFrames
        self.totalFrames = totalFrames
        self.sampleRate = sampleRate
    }

    public var fractionComplete: Double {
        guard totalFrames > 0 else { return 0 }
        return min(1, Double(renderedFrames) / Double(totalFrames))
    }
}

public enum AACExportError: LocalizedError, Equatable {
    case invalidRequest(String)
    case audioToolbox(OSStatus)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidRequest(let message): return message
        case .audioToolbox(let status): return "AAC export failed (AudioToolbox status \(status))."
        case .cancelled: return "AAC export cancelled."
        }
    }
}

/// Offline AAC/ADTS renderer. It builds a separate decoder and never touches
/// the live output device, transport buffer, queue, or frontend catalog.
public enum AACExporter {
    private static let sampleRate = 44_100
    private static let chunkFrames = 4_096
    /// Progress is a presentation channel, not a per-decode-block callback.
    /// Bound it so a slow realtime decoder cannot saturate the host's main
    /// actor with thousands of UI updates during a long export.
    private static let progressInterval: TimeInterval = 0.25

    public static func export(
        _ request: AACExportRequest,
        cancellation: AACExportCancellation? = nil,
        progress: (@Sendable (AACExportProgress) -> Void)? = nil
    ) throws -> AACExportResult {
        guard request.trackIndex >= 0 else {
            throw AACExportError.invalidRequest("AAC export requires a non-negative track index.")
        }
        guard request.playMilliseconds > 0, request.fadeMilliseconds >= 0 else {
            throw AACExportError.invalidRequest("AAC export requires a positive play length and a non-negative fade.")
        }
        guard request.tempo.isFinite, request.tempo > 0 else {
            throw AACExportError.invalidRequest("AAC export requires a positive finite tempo.")
        }
        let maximumMilliseconds = Int(Int32.max)
        guard request.playMilliseconds <= maximumMilliseconds,
              request.fadeMilliseconds <= maximumMilliseconds,
              request.playMilliseconds <= maximumMilliseconds - request.fadeMilliseconds else {
            throw AACExportError.invalidRequest("AAC export timing exceeds the supported millisecond range.")
        }
        guard let family = FormatRegistry.family(for: request.sourcePath) else {
            throw AACExportError.invalidRequest("AAC export requires a supported playable file.")
        }
        let directory = request.outputDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw AACExportError.invalidRequest("AAC export folder does not exist: \(directory.path)")
        }

        let outputURL = uniqueOutputURL(in: directory, filenameStem: request.filenameStem)
        let partialURL = directory.appendingPathComponent(".\(UUID().uuidString).partial.aac")
        var shouldRemovePartial = true
        defer {
            if shouldRemovePartial {
                try? FileManager.default.removeItem(at: partialURL)
            }
        }
        if cancellation?.isCancelled == true { throw AACExportError.cancelled }
        let decoder = try DecoderFactory.make(path: request.sourcePath, sampleRate: sampleRate)
        defer { decoder.close() }
        try decoder.startTrack(request.trackIndex)
        let effectiveTempo = FormatRegistry.effectiveTempo(request.tempo, family: family)
        decoder.setTempo(effectiveTempo)
        let capFrames = Int64(request.playMilliseconds + request.fadeMilliseconds) * Int64(sampleRate) / 1_000
        let fadeFrames = Int64(request.fadeMilliseconds) * Int64(sampleRate) / 1_000
        var loop = request.loop ?? (request.readEmbeddedLoopTags ? PlaybackLoopTagReader.read(path: request.sourcePath) : nil)
        if let loop, (!loop.isValid || PlaybackLoopReader.bounds(loop, sampleRate: sampleRate, tempo: effectiveTempo) == nil) {
            throw AACExportError.invalidRequest("AAC export loop boundaries are outside the supported frame range.")
        }
        if loop != nil && !decoder.appliesFadeInternally {
            // The shared reader, not a decoder-specific forced loop, owns
            // authored boundaries and repetition for the exported PCM.
            decoder.configureNativeEnding(playMs: 0, fadeMs: 0)
        } else {
            decoder.configureFade(playMs: request.playMilliseconds, fadeMs: request.fadeMilliseconds)
        }
        var remainingRepeats = loop?.repeatCount
        var writerRef: ExtAudioFileRef?
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: Double(sampleRate), mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: 1_024,
            mBytesPerFrame: 0, mChannelsPerFrame: 2, mBitsPerChannel: 0, mReserved: 0
        )
        try check(ExtAudioFileCreateWithURL(
            partialURL as CFURL, kAudioFileAAC_ADTSType, &fileFormat, nil,
            AudioFileFlags.eraseFile.rawValue, &writerRef
        ))
        guard let writer = writerRef else { throw AACExportError.invalidRequest("AAC export could not create its output file.") }
        defer {
            if let writerRef { ExtAudioFileDispose(writerRef) }
        }

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
        var lastProgressUptime: TimeInterval = 0
        func reportProgress(force: Bool = false) {
            guard let progress else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard force || now - lastProgressUptime >= progressInterval else { return }
            lastProgressUptime = now
            progress(AACExportProgress(renderedFrames: renderedFrames, totalFrames: capFrames, sampleRate: sampleRate))
        }
        reportProgress(force: true)
        while renderedFrames < capFrames {
            if cancellation?.isCancelled == true { throw AACExportError.cancelled }
            if decoder.trackEnded {
                guard let current = loop,
                      let bounds = PlaybackLoopReader.bounds(current, sampleRate: sampleRate, tempo: effectiveTempo),
                      decoder.absolutePlayedFrames >= bounds.end,
                      remainingRepeats.map({ $0 > 0 }) ?? true else { break }
            }
            let wanted = min(chunkFrames, Int(capFrames - renderedFrames))
            let frames = try PlaybackLoopReader.read(decoder: decoder, requested: wanted, sampleRate: sampleRate,
                                                     tempo: effectiveTempo, loop: &loop, remainingRepeats: &remainingRepeats)
            guard frames.left.count == frames.right.count, frames.left.count <= wanted else {
                throw AACExportError.invalidRequest("Decoder returned an invalid PCM frame count.")
            }
            let count = frames.left.count
            guard count > 0 else { break }
            var interleaved = [Float](repeating: 0, count: count * 2)
            for index in 0..<count {
                let gain = !decoder.appliesFadeInternally && fadeFrames > 0
                    ? PlaybackSession.fadeGain(position: renderedFrames + Int64(index), capFrames: capFrames, fadeFrames: fadeFrames)
                    : 1
                interleaved[index * 2] = frames.left[index] * gain
                interleaved[index * 2 + 1] = frames.right[index] * gain
            }
            try interleaved.withUnsafeMutableBytes { bytes in
                var bufferList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress)
                )
                try check(ExtAudioFileWrite(writer, UInt32(count), &bufferList))
            }
            renderedFrames += Int64(count)
            reportProgress()
        }
        if cancellation?.isCancelled == true { throw AACExportError.cancelled }
        reportProgress(force: true)
        let closeStatus = ExtAudioFileDispose(writer)
        writerRef = nil
        try check(closeStatus)
        try FileManager.default.moveItem(at: partialURL, to: outputURL)
        shouldRemovePartial = false
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
