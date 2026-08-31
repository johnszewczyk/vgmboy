import Foundation

/// Shared semantic playback preferences.
///
/// UserDefaults keys, JSON names, and migration rules remain frontend-owned.
/// This value owns the meanings, defaults, and numeric normalization used by
/// both CocoaSpice and SPCBoyWK before values reach `PlaybackController`.
public struct PlaybackPreferences: Codable, Equatable, Sendable {
    public static let defaultValue = PlaybackPreferences()
    public static let volumeRange: ClosedRange<Float> = 0...1

    public var timing: PlaybackTimingPreferences
    public var fadeEnabled: Bool
    public var equalizer: EqualizerConfiguration
    public var outputVolume: Float
    public var monoEnabled: Bool
    public var libgmeTempo: PlaybackTempo
    public var libgmeTempoEnabled: Bool
    public var libvgmTempo: PlaybackTempo
    public var libvgmTempoEnabled: Bool

    public init(
        timing: PlaybackTimingPreferences = .init(),
        fadeEnabled: Bool = true,
        equalizerEnabled: Bool = false,
        equalizerBandGains: [Float] = Array(repeating: 0, count: EqualizerConfiguration.bandCount),
        outputVolume: Float = 1,
        monoEnabled: Bool = false,
        libgmeTempo: PlaybackTempo = .defaultValue,
        libgmeTempoEnabled: Bool = false,
        libvgmTempo: PlaybackTempo = .defaultValue,
        libvgmTempoEnabled: Bool = false
    ) {
        self.timing = timing
        self.fadeEnabled = fadeEnabled
        self.equalizer = EqualizerConfiguration(
            enabled: equalizerEnabled,
            gainsDecibels: Self.normalizedEqualizerGains(equalizerBandGains)
        )
        self.outputVolume = Self.clampedVolume(outputVolume)
        self.monoEnabled = monoEnabled
        self.libgmeTempo = libgmeTempo
        self.libgmeTempoEnabled = libgmeTempoEnabled
        self.libvgmTempo = libvgmTempo
        self.libvgmTempoEnabled = libvgmTempoEnabled
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

    private static func normalizedEqualizerGains(_ gains: [Float]) -> [Float] {
        Array(gains.prefix(EqualizerConfiguration.bandCount).map(clampedEqualizerGain))
            + Array(repeating: 0, count: max(0, EqualizerConfiguration.bandCount - gains.count))
    }
}
