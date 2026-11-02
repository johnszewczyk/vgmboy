import Foundation
import VGMBoyCEmbeddedGME
import VGMBoyFormatCore

public enum EmbeddedGMEDecoderError: LocalizedError, Equatable, Sendable {
    case emptyInput
    case openFailed(String)
    case invalidTrackIndex(Int, count: Int)
    case startTrackFailed(String)
    case renderFailed(String)
    case seekFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Chip audio payload is empty."
        case .openFailed(let detail):
            return "libgme failed to open audio data: \(detail)"
        case .invalidTrackIndex(let index, let count):
            return "Subsong index \(index) is out of bounds (track count: \(count))."
        case .startTrackFailed(let detail):
            return "libgme failed to start track: \(detail)"
        case .renderFailed(let detail):
            return "libgme render error: \(detail)"
        case .seekFailed(let detail):
            return "libgme seek error: \(detail)"
        }
    }
}

public struct EmbeddedGMETrackTiming: Equatable, Sendable {
    public let lengthMilliseconds: Int?
    public let introMilliseconds: Int?
    public let loopMilliseconds: Int?
    public let defaultPlayMilliseconds: Int
    public let systemName: String
    public let gameTitle: String
    public let songTitle: String
    public let authorName: String

    public var resolvedDurationSeconds: Double? {
        if let lengthMilliseconds, lengthMilliseconds > 0 {
            return Double(lengthMilliseconds) / 1000.0
        }
        if let intro = introMilliseconds, let loop = loopMilliseconds, loop > 0 {
            let safeIntro = max(0, intro)
            return Double(safeIntro + loop * 2) / 1000.0
        }
        if defaultPlayMilliseconds > 0 {
            return Double(defaultPlayMilliseconds) / 1000.0
        }
        return nil
    }
}

/// Shared 10-band equalizer constants and automatic headroom math matching VGMBoyKit.
public struct EmbeddedEqualizerConfiguration: Codable, Equatable, Sendable {
    public static let bandCount = 10
    public static let bandFrequencies: [Float] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    public static let gainRange: ClosedRange<Float> = -12...12

    public var enabled: Bool
    public var gainsDecibels: [Float]

    public init(enabled: Bool = false, gainsDecibels: [Float] = Array(repeating: 0, count: bandCount)) {
        self.enabled = enabled
        self.gainsDecibels = Self.normalizedBands(gainsDecibels)
    }

    public static func normalizedBands(_ values: [Float]) -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(bandCount)
        for index in 0..<bandCount {
            let raw = index < values.count ? values[index] : 0
            let safe = raw.isFinite ? min(gainRange.upperBound, max(gainRange.lowerBound, raw)) : 0
            result.append((safe * 2).rounded() / 2)
        }
        return result
    }

    public var headroomCompensationDecibels: Float {
        guard enabled else { return 0 }
        let peakPositive = gainsDecibels.max() ?? 0
        return peakPositive > 0 ? -min(12, peakPositive * 0.72) : 0
    }
}

/// Musical 1/32-step tempo value matching VGMBoyKit.PlaybackTempo and SB2's playback-speed.js.
public struct EmbeddedPlaybackTempo: Codable, Equatable, Sendable {
    public static let defaultValue = EmbeddedPlaybackTempo(numerator: 1, denominator: 1)
    public static let minMultiplier: Double = 0.25
    public static let maxMultiplier: Double = 4.0

    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int, denominator: Int) {
        guard numerator >= 1, denominator >= 1 else {
            self = .defaultValue
            return
        }
        let divisor = Self.gcd(numerator, denominator)
        self.numerator = numerator / divisor
        self.denominator = denominator / divisor
    }

    public static func snapped(multiplier: Double) -> EmbeddedPlaybackTempo {
        let clamped = min(maxMultiplier, max(minMultiplier, multiplier.isFinite ? multiplier : 1.0))
        let steps = max(1, Int((clamped * 32.0).rounded()))
        return EmbeddedPlaybackTempo(numerator: steps, denominator: 32)
    }

    public var multiplier: Double {
        Double(numerator) / Double(denominator)
    }

    private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
        var a = abs(lhs)
        var b = abs(rhs)
        while b != 0 { (a, b) = (b, a % b) }
        return max(1, a)
    }
}

/// Embedded cycle-accurate Game_Music_Emu decoder backed by VGMBoy's vendored Higan/zxtune gme core.
public final class EmbeddedGMEDecoder {
    public static let supportedExtensions: Set<String> = [
        "spc", "sfm", "nsf", "nsfe", "gbs", "hes", "gym", "kss", "ay", "sap", "sgc"
    ]

    public static func supports(pathExtension: String) -> Bool {
        let normalized = pathExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        return supportedExtensions.contains(normalized)
    }

    public let sampleRate: Int
    public let trackCount: Int
    public let trackIndex: Int
    public let timing: EmbeddedGMETrackTiming

    private var handle: OpaquePointer?
    private var currentTempo: Double = 1.0

    public init(
        data: Data,
        sampleRate: Int = 44_100,
        subsongIndex: Int = 0,
        enableAccuracy: Bool = true
    ) throws {
        guard !data.isEmpty else {
            throw EmbeddedGMEDecoderError.emptyInput
        }
        var rawHandle: OpaquePointer?
        let openErr: String? = data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else {
                return "Invalid data buffer"
            }
            if let errPtr = vgmboy_embedded_gme_open_data(base, rawBuffer.count, &rawHandle, Int32(sampleRate)) {
                return String(cString: errPtr)
            }
            return nil
        }
        if let openErr {
            if let rawHandle { vgmboy_embedded_gme_delete(rawHandle) }
            throw EmbeddedGMEDecoderError.openFailed(openErr)
        }
        guard let opened = rawHandle else {
            throw EmbeddedGMEDecoderError.openFailed("Emulator handle is nil")
        }

        let count = Int(vgmboy_embedded_gme_track_count(opened))
        let safeIndex = count > 0 ? min(max(0, subsongIndex), count - 1) : 0
        if count <= 0 {
            vgmboy_embedded_gme_delete(opened)
            throw EmbeddedGMEDecoderError.invalidTrackIndex(subsongIndex, count: count)
        }

        if enableAccuracy {
            vgmboy_embedded_gme_enable_accuracy(opened, 1)
        }

        var cTiming = vgmboy_gme_track_timing_t()
        _ = vgmboy_embedded_gme_track_timing(opened, Int32(safeIndex), &cTiming)

        if let startErr = vgmboy_embedded_gme_start_track(opened, Int32(safeIndex)) {
            let message = String(cString: startErr)
            vgmboy_embedded_gme_delete(opened)
            throw EmbeddedGMEDecoderError.startTrackFailed(message)
        }

        self.handle = opened
        self.sampleRate = sampleRate
        self.trackCount = count
        self.trackIndex = safeIndex
        self.timing = EmbeddedGMETrackTiming(
            lengthMilliseconds: cTiming.length_ms > 0 ? Int(cTiming.length_ms) : nil,
            introMilliseconds: cTiming.intro_length_ms >= 0 ? Int(cTiming.intro_length_ms) : nil,
            loopMilliseconds: cTiming.loop_length_ms > 0 ? Int(cTiming.loop_length_ms) : nil,
            defaultPlayMilliseconds: max(0, Int(cTiming.play_length_ms)),
            systemName: Self.readFixedCString(cTiming.system_name),
            gameTitle: Self.readFixedCString(cTiming.game_name),
            songTitle: Self.readFixedCString(cTiming.song_name),
            authorName: Self.readFixedCString(cTiming.author_name)
        )
    }

    deinit {
        if let handle {
            vgmboy_embedded_gme_delete(handle)
        }
    }

    public func setTempo(_ tempo: Double) {
        guard let handle else { return }
        let clamped = min(EmbeddedPlaybackTempo.maxMultiplier, max(EmbeddedPlaybackTempo.minMultiplier, tempo))
        currentTempo = clamped
        vgmboy_embedded_gme_set_tempo(handle, clamped)
    }

    public func setIgnoreSilence(_ ignore: Bool) {
        guard let handle else { return }
        vgmboy_embedded_gme_ignore_silence(handle, ignore ? 1 : 0)
    }

    /// Configures native libgme fade/horizon in track-time milliseconds, or disables
    /// automatic track termination when `horizonSeconds` is nil.
    public func configureFade(startSeconds: Double?, fadeDurationSeconds: Double) {
        guard let handle else { return }
        guard let startSeconds, startSeconds.isFinite, startSeconds > 0 else {
            // -1 disables gme's fade cutoff so looping chips run continuously.
            vgmboy_embedded_gme_set_fade(handle, -1, 0)
            return
        }
        let fadeMs = max(1, Int((max(0.05, fadeDurationSeconds) * 1000.0).rounded()))
        let startMs = max(0, Int((startSeconds * 1000.0).rounded()))
        vgmboy_embedded_gme_set_fade(handle, Int32(startMs), Int32(fadeMs))
    }

    public var currentPositionMilliseconds: Int {
        guard let handle else { return 0 }
        return max(0, Int(vgmboy_embedded_gme_tell(handle)))
    }

    public var isTrackEnded: Bool {
        guard let handle else { return true }
        return vgmboy_embedded_gme_track_ended(handle) != 0
    }

    public func seek(toMilliseconds milliseconds: Int) throws {
        guard let handle else { return }
        let clamped = max(0, milliseconds)
        if let errPtr = vgmboy_embedded_gme_seek(handle, Int32(clamped)) {
            throw EmbeddedGMEDecoderError.seekFailed(String(cString: errPtr))
        }
    }

    /// Renders `frameCount` stereo sample pairs into separate left/right Float32 channel buffers.
    public func renderStereoFloatFrames(
        frameCount: Int,
        scratchInt16: inout [Int16],
        leftChannel: UnsafeMutablePointer<Float>,
        rightChannel: UnsafeMutablePointer<Float>
    ) throws -> Int {
        guard let handle, frameCount > 0 else { return 0 }
        let sampleCount = frameCount * 2
        if scratchInt16.count < sampleCount {
            scratchInt16 = Array(repeating: 0, count: sampleCount)
        }
        let errMessage: String? = scratchInt16.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return "Empty scratch buffer" }
            if let errPtr = vgmboy_embedded_gme_play(handle, Int32(sampleCount), base) {
                return String(cString: errPtr)
            }
            return nil
        }
        if let errMessage {
            throw EmbeddedGMEDecoderError.renderFailed(errMessage)
        }

        let scale: Float = 1.0 / 32768.0
        for frame in 0..<frameCount {
            leftChannel[frame] = Float(scratchInt16[frame * 2]) * scale
            rightChannel[frame] = Float(scratchInt16[frame * 2 + 1]) * scale
        }
        return frameCount
    }

    private static func readFixedCString<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            let prefix = raw.prefix { $0 != 0 }
            return String(decoding: prefix, as: UTF8.self)
        }
    }
}
