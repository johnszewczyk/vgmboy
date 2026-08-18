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
    func readFrames(_ frameCount: Int) -> (left: [Float], right: [Float])
}

enum DecoderFactoryError: LocalizedError {
    case unsupportedFamily(String)

    var errorDescription: String? {
        "No decoder is registered for family '\(self)'. This usually means the format is not admitted yet."
    }
}

enum DecoderFactory {
    static func make(family: DecoderFamily, path: String, sampleRate: Int = 44_100) throws -> any AudioDecoder {
        switch family.id {
        case "libgme":
            return try GMEDecoder(path: path, sampleRate: sampleRate)
        case "libvgm":
            return try VGMDecoder(path: path, sampleRate: sampleRate)
        case "vgmstream":
            return try VgmstreamDecoder(path: path, sampleRate: sampleRate)
        default:
            throw DecoderFactoryError.unsupportedFamily(family.id)
        }
    }

    static func make(path: String, sampleRate: Int = 44_100) throws -> any AudioDecoder {
        guard let family = FormatRegistry.family(for: path) else {
            throw DecoderFactoryError.unsupportedFamily("unknown")
        }
        return try make(family: family, path: path, sampleRate: sampleRate)
    }
}