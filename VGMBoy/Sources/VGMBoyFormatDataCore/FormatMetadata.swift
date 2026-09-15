import Foundation

/// Metadata facts that can be read from a source without starting a player
/// or linking a playback decoder.
public struct FormatMetadata: Codable, Equatable, Sendable {
    public let game: String
    public let song: String
    public let system: String
    public let author: String
    public let comment: String
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let fadeLengthMs: Int

    public init(
        game: String,
        song: String,
        system: String,
        author: String,
        comment: String,
        introLengthMs: Int,
        loopLengthMs: Int,
        playLengthMs: Int,
        fadeLengthMs: Int
    ) {
        self.game = game
        self.song = song
        self.system = system
        self.author = author
        self.comment = comment
        self.introLengthMs = introLengthMs
        self.loopLengthMs = loopLengthMs
        self.playLengthMs = playLengthMs
        self.fadeLengthMs = fadeLengthMs
    }
}

public enum FormatDataError: LocalizedError, Equatable, Sendable {
    case malformed(String)

    public var message: String {
        switch self {
        case .malformed(let message): message
        }
    }

    public var errorDescription: String? { message }
}
