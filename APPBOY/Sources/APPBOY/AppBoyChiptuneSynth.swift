import Foundation

/// Generates deterministic stereo 44.1 kHz 16-bit PCM WAV chiptune loops for built-in starter tracks
/// so real-time 10-band EQ (31 Hz–16 kHz), Mono downmix, seamless Long Play looping, and Playback Speed work out of the box.
enum AppBoyChiptuneSynth {
    static let sampleRate: Int = 44_100
    private static let channels: Int = 2

    static func resolvePlayableURL(for streamURI: String, trackId: String, naturalDurationSeconds: Double) throws -> URL {
        if streamURI.hasPrefix("synth://") {
            return try ensureSynthesizedWAV(uri: streamURI, trackId: trackId, naturalDurationSeconds: naturalDurationSeconds)
        }
        if streamURI.hasPrefix("file://"), let url = URL(string: streamURI) {
            return url
        }
        if let url = URL(string: streamURI), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return url
        }
        return URL(fileURLWithPath: streamURI)
    }

    private static func ensureSynthesizedWAV(uri: String, trackId: String, naturalDurationSeconds: Double) throws -> URL {
        let safeName = trackId.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("APPBOY-Synth-v2", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let durationTag = Int(min(max(naturalDurationSeconds, 12.0), 90.0).rounded())
        let targetURL = dir.appendingPathComponent("\(safeName)-\(durationTag)s.wav")
        if FileManager.default.fileExists(atPath: targetURL.path) {
            return targetURL
        }

        let seed = stableHash(uri + ":" + trackId)
        let clampedDuration = min(max(naturalDurationSeconds, 12.0), 90.0)
        let pcmData = renderLoopableStereoPCM(seed: seed, targetDurationSeconds: clampedDuration)
        let wavData = wrapWAV(pcmData: pcmData, sampleRate: sampleRate, channels: channels, bitsPerSample: 16)
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

    private static func renderLoopableStereoPCM(seed: UInt64, targetDurationSeconds: Double) -> Data {
        let scales: [[Double]] = [
            [0, 3, 5, 7, 10, 12, 15, 17],
            [0, 2, 4, 7, 9, 12, 14, 16],
            [0, 2, 3, 7, 8, 12, 14, 15],
            [0, 4, 7, 11, 12, 16, 19, 23]
        ]
        let scale = scales[Int(seed % UInt64(scales.count))]
        let baseMidi = 50 + Int((seed >> 8) % 10)
        let stepDuration = 0.135 + Double((seed >> 16) % 5) * 0.015
        let samplesPerStep = max(1, Int(stepDuration * Double(sampleRate)))
        let samplesPerBar = samplesPerStep * 16
        let barCount = max(2, Int((targetDurationSeconds * Double(sampleRate) / Double(samplesPerBar)).rounded()))
        let totalFrames = barCount * samplesPerBar
        let duty = [0.25, 0.5, 0.125, 0.375][Int((seed >> 24) % 4)]

        var leadPhase = 0.0
        var bassPhase = 0.0
        var subPhase = 0.0
        var arpPhase = 0.0
        var lfsr: UInt16 = UInt16(truncatingIfNeeded: (seed >> 32) | 1)

        var pcm = [Int16](repeating: 0, count: totalFrames * channels)
        let invSampleRate = 1.0 / Double(sampleRate)

        for i in 0..<totalFrames {
            let step = i / samplesPerStep
            let inStep = i % samplesPerStep
            let stepOffset = Double(inStep) / Double(samplesPerStep)

            // 16-step cyclic phrase so loop boundaries align seamlessly at barCount * 16 steps.
            let phraseStep = step % 16
            let patternIndex = Int((UInt64(phraseStep &* 5) &+ (seed >> 5)) % UInt64(scale.count))
            let bassIndex = Int((UInt64((phraseStep / 4) &* 3) &+ (seed >> 11)) % 4)
            let arpSub = (inStep / max(1, samplesPerStep / 3)) % 3

            let leadSemitone = Double(baseMidi + 12) + scale[patternIndex]
            let bassSemitone = Double(baseMidi - 12) + scale[bassIndex]
            let arpSemitone = leadSemitone + Double([0, 4, 7][arpSub])

            let leadFreq = 440.0 * pow(2.0, (leadSemitone - 69.0) / 12.0)
            let bassFreq = 440.0 * pow(2.0, (bassSemitone - 69.0) / 12.0)
            let subFreq = bassFreq * 0.5
            let arpFreq = 440.0 * pow(2.0, (arpSemitone - 69.0) / 12.0)

            leadPhase = fmod(leadPhase + leadFreq * invSampleRate, 1.0)
            bassPhase = fmod(bassPhase + bassFreq * invSampleRate, 1.0)
            subPhase = fmod(subPhase + subFreq * invSampleRate, 1.0)
            arpPhase = fmod(arpPhase + arpFreq * invSampleRate, 1.0)

            // Advance 15-bit noise LFSR at ~22 kHz for crisp hi-hat / snare transients up to 16 kHz.
            if (i & 1) == 0 {
                let bit = ((lfsr >> 0) ^ (lfsr >> 1)) & 1
                lfsr = (lfsr >> 1) | (bit << 14)
            }
            let noiseBit = (lfsr & 1) == 1 ? 1.0 : -1.0
            let hatEnv = (phraseStep % 2 == 1) ? max(0.0, 1.0 - stepOffset * 7.5) : max(0.0, 1.0 - stepOffset * 14.0) * 0.45
            let hatSample = noiseBit * hatEnv * 0.075

            let env = max(0.08, 1.0 - stepOffset * 0.72)
            let leadSample = (leadPhase < duty ? 1.0 : -1.0) * env * 0.21
            let triSample = (abs(bassPhase * 4.0 - 2.0) - 1.0) * 0.24
            let subSample = sin(subPhase * 2.0 * .pi) * 0.14
            let arpSample = (arpPhase < 0.5 ? 1.0 : -1.0) * (1.0 - stepOffset) * 0.11

            // Micro-crossfade first/last 64 samples to prevent boundary click on single-shot end.
            var edgeRamp = 1.0
            if i < 64 {
                edgeRamp = Double(i) / 64.0
            } else if i > totalFrames - 64 {
                edgeRamp = Double(totalFrames - i) / 64.0
            }

            let center = triSample + subSample + hatSample
            let left = max(-0.92, min(0.92, (center + leadSample * 1.18 + arpSample * 0.55) * edgeRamp))
            let right = max(-0.92, min(0.92, (center + leadSample * 0.62 + arpSample * 1.25) * edgeRamp))

            pcm[i * 2] = Int16(left * Double(Int16.max)).littleEndian
            pcm[i * 2 + 1] = Int16(right * Double(Int16.max)).littleEndian
        }

        return pcm.withUnsafeBufferPointer { Data(buffer: $0) }
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
