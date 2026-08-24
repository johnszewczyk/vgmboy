import Foundation

/// The timing request shared by every frontend before it crosses into
/// `PlaybackController`. Ordinary playback is decoder-natural; only Long Play
/// supplies a manual duration. A timed request remains available for explicit
/// finite operations such as a deliberate faded skip.
public struct PlaybackTimingRequest: Equatable, Sendable {
    public let playbackMode: PlaybackMode
    public let playMilliseconds: Int?
    public let fadeMilliseconds: Int
    public let unknownDurationMilliseconds: Int

    public init(
        playbackMode: PlaybackMode,
        playMilliseconds: Int?,
        fadeMilliseconds: Int,
        unknownDurationMilliseconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000
    ) {
        self.playbackMode = playbackMode
        self.playMilliseconds = playMilliseconds
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.unknownDurationMilliseconds = max(1_000, unknownDurationMilliseconds)
    }

    /// Builds the standard request for a newly selected file.
    ///
    /// A finite format always uses `file_default` so VGMBoy can obtain its
    /// natural duration from the decoder. Formats without a natural duration
    /// retain VGMBoy's internal safety cap; that cap is not imposed here.
    public static func standard(
        path: String,
        longPlayEnabled: Bool,
        manualPlayMilliseconds: Int,
        fadeMilliseconds: Int,
        unknownDurationMilliseconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000
    ) throws -> Self {
        guard !path.isEmpty, let family = FormatRegistry.family(for: path) else {
            throw PlaybackControlError.invalidPayload("Playback timing requires a supported file path.")
        }
        if longPlayEnabled, family.supportsLongPlay {
            return Self(
                playbackMode: .longPlay,
                playMilliseconds: max(1, manualPlayMilliseconds),
                fadeMilliseconds: fadeMilliseconds,
                unknownDurationMilliseconds: unknownDurationMilliseconds
            )
        }
        return Self(
            playbackMode: .fileDefault,
            playMilliseconds: nil,
            fadeMilliseconds: fadeMilliseconds,
            unknownDurationMilliseconds: unknownDurationMilliseconds
        )
    }

    /// Builds an intentionally bounded request. Callers must supply the
    /// finite duration; this operation never invents a 150-second default.
    public static func timed(playMilliseconds: Int, fadeMilliseconds: Int) throws -> Self {
        guard playMilliseconds > 0 else {
            throw PlaybackControlError.invalidPayload("Timed playback requires a positive play length.")
        }
        return Self(
            playbackMode: .timed,
            playMilliseconds: playMilliseconds,
            fadeMilliseconds: fadeMilliseconds,
            unknownDurationMilliseconds: PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000
        )
    }
}
