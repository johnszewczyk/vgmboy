import Foundation

struct TrackMetadata: Sendable, Codable, Equatable {
    var index: Int
    var song: String
    var game: String
    var author: String
    var dumper: String
    var system: String
    var lengthMs: Int
    var introMs: Int
    var loopMs: Int
    var playMs: Int
    var fadeMs: Int

    init(
        index: Int,
        song: String,
        game: String,
        author: String,
        system: String,
        lengthMs: Int,
        introMs: Int,
        loopMs: Int,
        playMs: Int,
        fadeMs: Int,
        dumper: String = ""
    ) {
        self.index = index
        self.song = song
        self.game = game
        self.author = author
        self.dumper = dumper
        self.system = system
        self.lengthMs = lengthMs
        self.introMs = introMs
        self.loopMs = loopMs
        self.playMs = playMs
        self.fadeMs = fadeMs
    }

    var hasTiming: Bool {
        naturalPlayMs > 0
    }

    /// Best-known natural play length: the tagged play length, else
    /// intro + one loop (or the loop alone when no intro is tagged).
    var naturalPlayMs: Int {
        if playMs > 0 {
            return playMs
        }
        if introMs > 0 || loopMs > 0 {
            return max(introMs + loopMs, loopMs)
        }
        return 0
    }
}
