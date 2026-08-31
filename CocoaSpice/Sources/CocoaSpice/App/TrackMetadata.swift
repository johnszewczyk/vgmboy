import Foundation
import VGMBoyKit

/// Metadata published in the selected catalog. CocoaSpice never decodes a
/// source or asks VGMBoyKit to populate these fields.
struct TrackMetadata: Codable, Equatable, Sendable {
    let game: String
    let song: String
    let system: String
    let author: String
    let dumper: String
    let comment: String
    let introLengthMs: Int
    let loopLengthMs: Int
    let playLengthMs: Int
    let fadeLengthMs: Int

    init(
        game: String,
        song: String,
        system: String,
        author: String,
        comment: String,
        introLengthMs: Int,
        loopLengthMs: Int,
        playLengthMs: Int,
        fadeLengthMs: Int,
        dumper: String = ""
    ) {
        self.game = game
        self.song = song
        self.system = system
        self.author = author
        self.dumper = dumper
        self.comment = comment
        self.introLengthMs = introLengthMs
        self.loopLengthMs = loopLengthMs
        self.playLengthMs = playLengthMs
        self.fadeLengthMs = fadeLengthMs
    }

    var playbackTimingMetadata: PlaybackTimingMetadata {
        PlaybackTimingMetadata(
            playMilliseconds: playLengthMs,
            introMilliseconds: introLengthMs,
            loopMilliseconds: loopLengthMs
        )
    }
}
