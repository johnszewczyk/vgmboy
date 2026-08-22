import Foundation

/// Nintendo DS raw PCM dumps were historically called `.wav` despite having
/// neither a RIFF header nor a format descriptor. Keep the single documented
/// legacy shape in the engine, not in a frontend decoder fallback.
private let ndsRawPCMMinimumBytes: UInt64 = 64 * 1024
private let ndsRawPCMRate = 22_050

enum NDSWAVDetection {
    static func isSWAV(_ path: String) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) == Data("SWAV".utf8)
    }

    static func isRawPCM22(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension.lowercased() == "wav",
              url.deletingPathExtension().lastPathComponent.range(of: "_[0-9]{2}$", options: .regularExpression) != nil,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attributes[.size] as? NSNumber,
              size.uint64Value >= ndsRawPCMMinimumBytes,
              !isSWAV(path)
        else { return false }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: 4)) != Data("RIFF".utf8)
    }
}

final class NDSRawPCMDecoder: AudioDecoder, @unchecked Sendable {
    let sampleRate: Int
    let trackCount = 1
    let systemName = "Nintendo DS"
    let appliesFadeInternally = false
    private let file: FileHandle
    private let byteCount: Int64
    private(set) var absolutePlayedFrames: Int64 = 0
    private var outputPosition: Int64 = 0

    var trackEnded: Bool { outputPosition >= byteCount * 2 }

    init(path: String, sampleRate: Int) throws {
        file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        let values = try FileManager.default.attributesOfItem(atPath: path)
        byteCount = (values[.size] as? NSNumber)?.int64Value ?? 0
        self.sampleRate = sampleRate
    }

    deinit { try? file.close() }

    func startTrack(_ index: Int) throws {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        seek(milliseconds: 0)
    }

    func metadata(for index: Int) throws -> TrackMetadata {
        guard index == 0 else { throw PlaybackControlError.invalidPayload("Track index is not available for this file.") }
        let duration = Int((Double(byteCount) / Double(ndsRawPCMRate) * 1_000).rounded())
        return TrackMetadata(index: 0, song: "", game: "", author: "", system: systemName, lengthMs: duration, introMs: 0, loopMs: 0, playMs: duration, fadeMs: 0)
    }

    func setTempo(_ tempo: Double) {}
    func configureFade(playMs: Int, fadeMs: Int) {}
    func configureNativeEnding(playMs: Int, fadeMs: Int) {}

    func seek(milliseconds: Int) {
        outputPosition = min(byteCount * 2, max(0, Int64((Double(max(0, milliseconds)) / 1_000 * Double(sampleRate)).rounded(.down))))
        absolutePlayedFrames = outputPosition
    }

    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) {
        let available = max(0, byteCount * 2 - outputPosition)
        let count = min(Int64(max(0, frameCount)), available)
        guard count > 0 else { return ([], []) }
        let firstSource = outputPosition / 2
        let lastSource = (outputPosition + count - 1) / 2
        do {
            try file.seek(toOffset: UInt64(firstSource))
            guard let data = try file.read(upToCount: Int(lastSource - firstSource + 1)) else { return ([], []) }
            let bytes = [UInt8](data)
            var left = [Float]()
            left.reserveCapacity(Int(count))
            for offset in 0 ..< Int(count) {
                let sourceIndex = Int((outputPosition + Int64(offset)) / 2 - firstSource)
                left.append(Float(Int8(bitPattern: bytes[sourceIndex])) / 128)
            }
            outputPosition += count
            absolutePlayedFrames = outputPosition
            return (left, left)
        } catch {
            outputPosition = byteCount * 2
            return ([], [])
        }
    }
}

final class NDSSWAVDecoder: AudioDecoder, @unchecked Sendable {
    private let aliasURL: URL
    private let decoder: VgmstreamDecoder

    var sampleRate: Int { decoder.sampleRate }
    var trackCount: Int { decoder.trackCount }
    var systemName: String { "Nintendo DS" }
    var trackEnded: Bool { decoder.trackEnded }
    var appliesFadeInternally: Bool { decoder.appliesFadeInternally }
    var absolutePlayedFrames: Int64 { decoder.absolutePlayedFrames }

    init(path: String, sampleRate: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vgmboy-nds-swav-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        aliasURL = directory.appendingPathComponent("track.adpcm")
        do {
            try FileManager.default.linkItem(at: URL(fileURLWithPath: path), to: aliasURL)
        } catch {
            try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: aliasURL)
        }
        decoder = try VgmstreamDecoder(path: aliasURL.path, sampleRate: sampleRate)
    }

    deinit { try? FileManager.default.removeItem(at: aliasURL.deletingLastPathComponent()) }

    func startTrack(_ index: Int) throws { try decoder.startTrack(index) }
    func metadata(for index: Int) throws -> TrackMetadata {
        var metadata = try decoder.metadata(for: index)
        metadata.system = systemName
        return metadata
    }
    func setTempo(_ tempo: Double) { decoder.setTempo(tempo) }
    func configureFade(playMs: Int, fadeMs: Int) { decoder.configureFade(playMs: playMs, fadeMs: fadeMs) }
    func configureNativeEnding(playMs: Int, fadeMs: Int) { decoder.configureNativeEnding(playMs: playMs, fadeMs: fadeMs) }
    func seek(milliseconds: Int) { decoder.seek(milliseconds: milliseconds) }
    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float]) { decoder.readFrames(frameCount) }
}
