import Foundation

public struct VGMBoyMDXInspection: Codable, Sendable {
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
        let decoder = try MDXDecoder(path: path)
        let metadata = try decoder.metadata(for: 0)
        title = metadata.song
        game = ""
        system = metadata.system
        artist = ""
        comment = ""
        introLengthMs = metadata.introMs
        loopLengthMs = metadata.loopMs
        playLengthMs = metadata.playMs
        fadeLengthMs = metadata.fadeMs
        trackCount = decoder.trackCount
    }
}
