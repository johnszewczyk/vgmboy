import Foundation

/// Uniform decode contract every bridge core satisfies. All calls happen on
/// the owning session's serial queue; the audio render thread never touches a
/// decoder directly.
protocol AudioDecoder: AnyObject {
    var sampleRate: Int { get }
    var trackCount: Int { get }
    var systemName: String { get }
    var absolutePlayedFrames: Int64 { get }
    var trackEnded: Bool { get }
    /// Whether the decoder applies its own fade-out (libgme/libvgm configure
    /// a native fade). Decoders that only stream real PCM (vgmstream, lazyusf,
    /// Play! PSF) report false so the session applies the fade DSP.
    var appliesFadeInternally: Bool { get }

    func startTrack(_ index: Int) throws
    func metadata(for index: Int) throws -> TrackMetadata
    func setTempo(_ tempo: Double)
    /// Applies a capped decode window (long play / timed): the shell stops the
    /// stream at the frame cap after this fade.
    func configureFade(playMs: Int, fadeMs: Int)
    /// Lets the decoder end at its own natural length and fade. A zero play
    /// window means "unbounded"; the session then caps as a backstop.
    func configureNativeEnding(playMs: Int, fadeMs: Int)
    func seek(milliseconds: Int)
    func readFrames(_ frameCount: Int) throws -> (left: [Float], right: [Float])
    /// Gives a decoder with non-ARC native lifetime requirements an explicit
    /// replacement boundary before the next decoder is constructed.
    func close()
}

extension AudioDecoder {
    func close() {}
}

enum DecoderFactoryError: LocalizedError {
    case unsupportedFamily(String)

    var errorDescription: String? {
        "No decoder is registered for family '\(self)'. This usually means the format is not admitted yet."
    }
}

/// Zero-based track indices must fit native decoder APIs, including bridges
/// that convert them to a one-based Int32 subsong number.
enum PlaybackTrackIndex {
    static func isRepresentable(_ index: Int) -> Bool { index >= 0 && index < Int(Int32.max) }
}

enum DecoderFactory {
    static func make(family: DecoderFamily, path: String, sampleRate: Int = 44_100) throws -> any AudioDecoder {
        switch family.id {
        case "libgme":
            return try GMEDecoder(path: path, sampleRate: sampleRate)
        case "asap":
            return try ASAPDecoder(path: path, sampleRate: sampleRate)
        case "sidplayfp":
            return try SIDDecoder(path: path, sampleRate: sampleRate)
        case "openmpt":
            return try OpenMPTDecoder(path: path, sampleRate: sampleRate)
        case "amiga-uade":
            return try AmigaDecoder(path: path, sampleRate: sampleRate)
        case "libvgm":
            return try VGMDecoder(path: path, sampleRate: sampleRate)
        case "psgplay":
            return try SNDHDecoder(path: path, sampleRate: sampleRate)
        case "mdx":
            return try MDXDecoder(path: path, sampleRate: sampleRate)
        case "standardaudio":
            return try StandardAudioDecoder(path: path, sampleRate: sampleRate)
        case "ffmpegaudio":
            return try FFmpegAudioDecoder(path: path, sampleRate: sampleRate)
        case "highlycomplete":
            return try HighlyCompleteDecoder(path: path, sampleRate: sampleRate)
        case "twosf":
            return try TwoSFDecoder(path: path, sampleRate: sampleRate)
        case "vgmstream":
            return try VgmstreamDecoder(path: path, sampleRate: sampleRate)
        case "lazyusf":
            return try LazyUSFDecoder(path: path, sampleRate: sampleRate)
        case "playpsf":
            return try PlayPSFDecoder(path: path, sampleRate: sampleRate)
        case "ares-snes":
            return try AresSNESDecoder(path: path, sampleRate: sampleRate)
        case "qsf":
            return try QSFDecoder(path: path, sampleRate: sampleRate)
        default:
            throw DecoderFactoryError.unsupportedFamily(family.id)
        }
    }

    /// Probe ordinary AVFoundation sources without touching the active
    /// playback session. The Nintendo DS overrides use different decoders.
    static func validateStandardAudioSource(path: String, sourceData: Data?, sampleRate: Int) throws {
        guard sourceData == nil, FormatRegistry.family(for: path)?.id == "standardaudio",
              !NDSWAVDetection.isSWAV(path), !NDSWAVDetection.isRawPCM22(path) else { return }
        _ = try StandardAudioDecoder(path: path, sampleRate: sampleRate)
    }

    /// SPC uses independent libgme instances, so its open and initial track
    /// setup can be checked without disturbing the current playback decoder.
    static func validateSPCSource(path: String, sourceData: Data?, trackIndex: Int, sampleRate: Int) throws {
        guard URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("spc") == .orderedSame,
              FormatRegistry.family(for: path)?.id == "libgme" else { return }
        // Disk SWAV signatures override extension routing in DecoderFactory.
        if sourceData == nil && NDSWAVDetection.isSWAV(path) { return }
        let decoder: GMEDecoder
        if let sourceData {
            decoder = try GMEDecoder(data: sourceData, sampleRate: sampleRate)
        } else {
            decoder = try GMEDecoder(path: path, sampleRate: sampleRate)
        }
        try decoder.startTrack(trackIndex)
        _ = try decoder.metadata(for: trackIndex)
    }

    /// Families whose decoder contract guarantees exactly one track. Keep
    /// variable-track decoders out of this list: their counts require opening
    /// the source. SWAV overrides extension routing and must be checked first.
    static func validateTrackIndex(_ index: Int, path: String, sourceData: Data?) throws {
        guard index > 0 else { return }
        if sourceData == nil && NDSWAVDetection.isSWAV(path) { return }
        guard let family = FormatRegistry.family(for: path) else { return }
        switch family.id {
        case "standardaudio", "ffmpegaudio", "mdx", "openmpt", "highlycomplete",
             "twosf", "lazyusf", "playpsf", "ares-snes", "qsf":
            throw PlaybackControlError.invalidPayload("Track index is not available for this single-track format.")
        default:
            return
        }
    }

    /// Validate the in-memory routing contract without creating a decoder or
    /// taking process-global decoder ownership.
    static func validateInMemorySource(path: String) throws {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let family = FormatRegistry.family(for: path)?.id
        guard (ext == "sap" && family == "asap") || (ext == "spc" && family == "libgme") else {
            throw DecoderFactoryError.unsupportedFamily("in-memory \(ext)")
        }
    }

    static func make(path: String, sourceData: Data? = nil, sampleRate: Int = 44_100) throws -> any AudioDecoder {
        if let sourceData {
            try validateInMemorySource(path: path)
            if URL(fileURLWithPath: path).pathExtension.caseInsensitiveCompare("sap") == .orderedSame {
                return try ASAPDecoder(data: sourceData, filename: URL(fileURLWithPath: path).lastPathComponent, sampleRate: sampleRate)
            }
            return try GMEDecoder(data: sourceData, sampleRate: sampleRate)
        }
        if NDSWAVDetection.isSWAV(path) {
            return try NDSSWAVDecoder(path: path, sampleRate: sampleRate)
        }
        if NDSWAVDetection.isRawPCM22(path) {
            return try NDSRawPCMDecoder(path: path, sampleRate: sampleRate)
        }
        guard let family = FormatRegistry.family(for: path) else {
            throw DecoderFactoryError.unsupportedFamily("unknown")
        }
        return try make(family: family, path: path, sampleRate: sampleRate)
    }
}
