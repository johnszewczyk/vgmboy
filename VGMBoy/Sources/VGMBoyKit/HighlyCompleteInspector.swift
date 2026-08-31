import Foundation

public struct VGMBoyHighlyCompleteInspection: Codable, Sendable {
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
}

public enum VGMBoyHighlyCompleteInspector {
    public static func inspect(path: String) throws -> VGMBoyHighlyCompleteInspection {
        let decoder = try HighlyCompleteDecoder(path: path)
        let metadata = try decoder.metadata(for: 0)
        return VGMBoyHighlyCompleteInspection(
            title: metadata.song,
            game: metadata.game,
            system: metadata.system,
            artist: metadata.author,
            comment: "",
            introLengthMs: metadata.introMs,
            loopLengthMs: metadata.loopMs,
            playLengthMs: metadata.playMs,
            fadeLengthMs: metadata.fadeMs,
            trackCount: decoder.trackCount
        )
    }
}
