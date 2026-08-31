import Foundation

/// Scanner-facing metadata projection for ordinary audio handled by the
/// shared FFmpeg bridge. The result intentionally contains no decoder handle
/// or frontend state, so ScanSong can consume it through its process boundary.
public struct VGMBoyFFmpegInspection: Codable, Sendable {
    public let title: String
    public let game: String
    public let system: String
    public let artist: String
    public let comment: String
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let fadeLengthMs: Int
    public let trackCount: Int

    public init(path: String) throws {
        let decoder = try FFmpegAudioDecoder(path: path, sampleRate: 44_100)
        defer { decoder.close() }
        let metadata = try decoder.metadata(for: 0)
        title = metadata.song
        game = metadata.game
        system = metadata.system
        artist = metadata.author
        comment = decoder.metadataComment
        introLengthMs = metadata.introMs
        loopLengthMs = metadata.loopMs
        playLengthMs = metadata.playMs
        fadeLengthMs = metadata.fadeMs
        trackCount = decoder.trackCount
    }
}
