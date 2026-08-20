import AVFoundation
import Foundation

/// AVFoundation-backed PCM decoder for ordinary music files. It deliberately
/// provides playback facts only; catalog tags remain a frontend/database job.
final class StandardAudioDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    let trackCount = 1
    let systemName = "Standard audio"
    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let sourceSampleRate: Double
    private var sourceEnded = false
    private(set) var absolutePlayedFrames: Int64 = 0

    var trackEnded: Bool { sourceEnded }
    let appliesFadeInternally = false

    init(path: String, sampleRate: Int) throws {
        file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        sourceSampleRate = file.processingFormat.sampleRate
        self.sampleRate = sampleRate
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 2,
            interleaved: false
        ), let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat) else {
            throw DecoderFactoryError.unsupportedFamily("standard-audio conversion")
        }
        self.converter = converter
    }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        file.framePosition = 0
        sourceEnded = false
        absolutePlayedFrames = 0
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        let duration = sourceSampleRate > 0 ? Int((Double(file.length) / sourceSampleRate * 1_000).rounded()) : 0
        return TrackMetadata(index: 0, song: "", game: "", author: "", system: systemName, lengthMs: duration, introMs: 0, loopMs: 0, playMs: duration, fadeMs: 0)
    }

    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        let position = Int64((Double(max(0, milliseconds)) / 1_000 * sourceSampleRate).rounded(.down))
        file.framePosition = min(max(0, position), file.length)
        sourceEnded = file.framePosition >= file.length
        absolutePlayedFrames = Int64((Double(file.framePosition) / sourceSampleRate * Double(sampleRate)).rounded(.down))
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        guard frameCount > 0, !sourceEnded else { return ([], []) }
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            sourceEnded = true
            return ([], [])
        }
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { [weak self] _, outStatus in
            guard let self, !self.sourceEnded else {
                outStatus.pointee = .endOfStream
                return nil
            }
            guard let input = AVAudioPCMBuffer(pcmFormat: self.file.processingFormat, frameCapacity: 4_096) else {
                self.sourceEnded = true
                outStatus.pointee = .endOfStream
                return nil
            }
            do {
                try self.file.read(into: input)
            } catch {
                self.sourceEnded = true
                outStatus.pointee = .endOfStream
                return nil
            }
            if input.frameLength == 0 {
                self.sourceEnded = true
                outStatus.pointee = .endOfStream
                return nil
            }
            outStatus.pointee = .haveData
            return input
        }
        guard conversionError == nil, status != .error, output.frameLength > 0 else {
            sourceEnded = true
            return ([], [])
        }
        let count = Int(output.frameLength)
        let channels = output.floatChannelData!
        let left = Array(UnsafeBufferPointer(start: channels[0], count: count))
        let right: [Float]
        if output.format.channelCount > 1 {
            right = Array(UnsafeBufferPointer(start: channels[1], count: count))
        } else {
            right = left
        }
        absolutePlayedFrames += Int64(count)
        return (left, right)
    }
}
