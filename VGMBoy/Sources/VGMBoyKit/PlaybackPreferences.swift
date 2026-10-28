import Foundation

/// Shared semantic playback preferences.
///
/// UserDefaults keys and JSON shapes remain frontend-owned. This value owns
/// shared meanings, defaults, numeric normalization, and the one migration
/// rule for collapsing legacy per-decoder tempo settings before values reach
/// `PlaybackController`.
public struct PlaybackPreferences: Codable, Equatable, Sendable {
    public static let defaultValue = PlaybackPreferences()
    public static let volumeRange: ClosedRange<Float> = 0...1

    public var timing: PlaybackTimingPreferences
    public var fadeEnabled: Bool
    public var equalizer: EqualizerConfiguration
    public var outputVolume: Float
    public var monoEnabled: Bool
    /// One native-tempo preference shared by every decoder that advertises
    /// tempo support. Frontends must gate application by decoder capability,
    /// not keep a separate value per plugin.
    public var playbackTempo: PlaybackTempo
    public var playbackTempoEnabled: Bool

    public init(
        timing: PlaybackTimingPreferences = .init(),
        fadeEnabled: Bool = true,
        equalizerEnabled: Bool = false,
        equalizerBandGains: [Float] = Array(repeating: 0, count: EqualizerConfiguration.bandCount),
        outputVolume: Float = 1,
        monoEnabled: Bool = false,
        playbackTempo: PlaybackTempo = .defaultValue,
        playbackTempoEnabled: Bool = false
    ) {
        self.timing = timing
        self.fadeEnabled = fadeEnabled
        self.equalizer = EqualizerConfiguration(
            enabled: equalizerEnabled,
            gainsDecibels: Self.normalizedEqualizerGains(equalizerBandGains)
        )
        self.outputVolume = Self.clampedVolume(outputVolume)
        self.monoEnabled = monoEnabled
        self.playbackTempo = Self.normalizedTempo(playbackTempo)
        self.playbackTempoEnabled = playbackTempoEnabled
    }

    public var fadeSeconds: Int {
        fadeEnabled ? timing.fadeSeconds : 0
    }

    public static func clampedVolume(_ value: Float) -> Float {
        guard value.isFinite else { return volumeRange.upperBound }
        return min(max(value, volumeRange.lowerBound), volumeRange.upperBound)
    }

    public static func clampedEqualizerGain(_ value: Float) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(value, EqualizerConfiguration.gainRange.lowerBound), EqualizerConfiguration.gainRange.upperBound)
    }

    /// Playback speed uses one shared 1/32-step range for all tempo-capable
    /// decoder plugins: 1/32× through 8×.
    public static func normalizedTempo(_ value: PlaybackTempo) -> PlaybackTempo {
        let steps = min(256, max(1, Int((value.multiplier * 32).rounded())))
        return PlaybackTempo(numerator: steps, denominator: 32)
    }

    /// Migrate the former per-decoder settings to the single shared control.
    /// When exactly one legacy plugin was enabled, preserve its rate. If both
    /// were enabled with different rates, libgme wins deterministically. If
    /// neither was enabled, keep a non-default saved rate for the next edit.
    public static func migrateBackendTempo(
        libgmeTempo: PlaybackTempo?,
        libgmeEnabled: Bool?,
        libvgmTempo: PlaybackTempo?,
        libvgmEnabled: Bool?
    ) -> (tempo: PlaybackTempo, enabled: Bool) {
        let gmeTempo = normalizedTempo(libgmeTempo ?? .defaultValue)
        let vgmTempo = normalizedTempo(libvgmTempo ?? .defaultValue)
        let gmeEnabled = libgmeEnabled ?? false
        let vgmEnabled = libvgmEnabled ?? false

        let tempo: PlaybackTempo
        if gmeEnabled != vgmEnabled {
            tempo = gmeEnabled ? gmeTempo : vgmTempo
        } else if !gmeEnabled, gmeTempo == .defaultValue, vgmTempo != .defaultValue {
            tempo = vgmTempo
        } else {
            tempo = gmeTempo
        }
        return (tempo, gmeEnabled || vgmEnabled)
    }

    private static func normalizedEqualizerGains(_ gains: [Float]) -> [Float] {
        Array(gains.prefix(EqualizerConfiguration.bandCount).map(clampedEqualizerGain))
            + Array(repeating: 0, count: max(0, EqualizerConfiguration.bandCount - gains.count))
    }
}
