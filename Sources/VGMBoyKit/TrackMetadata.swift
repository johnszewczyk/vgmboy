import Foundation

public struct TrackMetadata: Sendable, Codable {
    public var index: Int
    public var song: String
    public var game: String
    public var author: String
    public var system: String
    public var lengthMs: Int
    public var introMs: Int
    public var loopMs: Int
    public var playMs: Int
    public var fadeMs: Int

    public init(
        index: Int,
        song: String,
        game: String,
        author: String,
        system: String,
        lengthMs: Int,
        introMs: Int,
        loopMs: Int,
        playMs: Int,
        fadeMs: Int
    ) {
        self.index = index
        self.song = song
        self.game = game
        self.author = author
        self.system = system
        self.lengthMs = lengthMs
        self.introMs = introMs
        self.loopMs = loopMs
        self.playMs = playMs
        self.fadeMs = fadeMs
    }

    public var hasTiming: Bool {
        lengthMs > 0 || introMs > 0 || loopMs > 0 || playMs > 0
    }
}