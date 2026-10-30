import Foundation

/// Generates deterministic 16-bit PCM WAV chiptune previews for built-in starter catalog tracks
/// so real AVPlayer streaming, scrubbing, background audio, and Lock Screen transport work out of the box.
enum AppBoyChiptuneSynth {
    private static let sampleRate: Int = 22_050

    static func resolvePlayableURL(for streamURI: String, trackId: String, durationSeconds: Double) throws -> URL {
        if streamURI.hasPrefix("synth://") {
            return try ensureSynthesizedWAV(uri: streamURI, trackId: trackId, durationSeconds: durationSeconds)
        }
        if streamURI.hasPrefix("file://"), let url = URL(string: streamURI) {
            return url
        }
        if let url = URL(string: streamURI), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return url
        }
        return URL(fileURLWithPath: streamURI)
    }

    private static func ensureSynthesizedWAV(uri: String, trackId: String, durationSeconds: Double) throws -> URL {
        let safeName = trackId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("APPBOY-Synth", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let targetURL = dir.appendingPathComponent("\(safeName).wav")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            return targetURL
        }

        let seed = stableHash(uri + ":" + trackId)
        let clampedDuration = min(max(durationSeconds, 12.0), 48.0)
        let totalSamples = Int(clampedDuration * Double(sampleRate))
        let pcmData = renderPCM(seed: seed, totalSamples: totalSamples)
        let wavData = wrapWAV(pcmData: pcmData, sampleRate: sampleRate, channels: 1, bitsPerSample: 16)
        try wavData.write(to: targetURL, options: .atomic)
        return targetURL
    }

    private static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func renderPCM(seed: UInt64, totalSamples: Int) -> Data {
        let scales: [[Double]] = [
            [0, 3, 5, 7, 10, 12, 15, 17],
            [0, 2, 4, 7, 9, 12, 14, 16],
            [0, 2, 3, 7, 8, 12, 14, 15],
            [0, 4, 7, 11, 12, 16, 19, 23]
        ]
        let scale = scales[Int(seed % UInt64(scales.count))]
        let baseMidi = 52 + Int((seed >> 8) % 10)
        let stepDuration = 0.14 + Double((seed >> 16) % 5) * 0.015
        let samplesPerStep = max(1, Int(stepDuration * Double(sampleRate)))
        let duty = [0.25, 0.5, 0.125, 0.375][Int((seed >> 24) % 4)]

        var leadPhase = 0.0
        var bassPhase = 0.0
        var arpPhase = 0.0
        var data = Data(capacity: totalSamples * 2)

        for i in 0..<totalSamples {
            let step = i / samplesPerStep
            let stepOffset = Double(i % samplesPerStep) / Double(samplesPerStep)
            let patternIndex = Int((UInt64(step &* 7) &+ (seed >> 5)) % UInt64(scale.count))
            let bassIndex = Int((UInt64((step / 4) &* 3) &+ (seed >> 11)) % 4)
            let arpSub = (i / max(1, samplesPerStep / 3)) % 3

            let leadSemitone = Double(baseMidi + 12) + scale[patternIndex]
            let bassSemitone = Double(baseMidi - 12) + scale[bassIndex]
            let arpSemitone = leadSemitone + Double([0, 4, 7][arpSub])

            let leadFreq = 440.0 * pow(2.0, (leadSemitone - 69.0) / 12.0)
            let bassFreq = 440.0 * pow(2.0, (bassSemitone - 69.0) / 12.0)
            let arpFreq = 440.0 * pow(2.0, (arpSemitone - 69.0) / 12.0)

            leadPhase = fmod(leadPhase + leadFreq / Double(sampleRate), 1.0)
            bassPhase = fmod(bassPhase + bassFreq / Double(sampleRate), 1.0)
            arpPhase = fmod(arpPhase + arpFreq / Double(sampleRate), 1.0)

            let env = max(0.08, 1.0 - stepOffset * 0.72)
            let leadSample = (leadPhase < duty ? 1.0 : -1.0) * env * 0.24
            let triSample = (abs(bassPhase * 4.0 - 2.0) - 1.0) * 0.28
            let arpSample = (arpPhase < 0.5 ? 1.0 : -1.0) * (1.0 - stepOffset) * 0.11

            var fadeGain = 1.0
            let fadeSamples = min(sampleRate * 2, totalSamples / 6)
            if fadeSamples > 0 && i > totalSamples - fadeSamples {
                fadeGain = Double(totalSamples - i) / Double(fadeSamples)
            }

            let mixed = max(-0.95, min(0.95, (leadSample + triSample + arpSample) * fadeGain))
            var sample16 = Int16(mixed * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &sample16) { data.append(contentsOf: $0) }
        }
        return data
    }

    private static func wrapWAV(pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        let byteRate = sampleRate * channels * (bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.appendLE(chunkSize)
        header.append(contentsOf: "WAVEfmt ".utf8)
        header.appendLE(UInt32(16))
        header.appendLE(UInt16(1))
        header.appendLE(UInt16(channels))
        header.appendLE(UInt32(sampleRate))
        header.appendLE(UInt32(byteRate))
        header.appendLE(UInt16(blockAlign))
        header.appendLE(UInt16(bitsPerSample))
        header.append(contentsOf: "data".utf8)
        header.appendLE(dataSize)
        header.append(pcmData)
        return header
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
