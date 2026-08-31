import Foundation

/// User-controlled timing values shared by every frontend.
public struct PlaybackTimingPreferences: Codable, Equatable, Sendable {
    public static let defaultLongPlaySeconds = 180
    public static let defaultUnknownDurationSeconds = 150
    public static let defaultFadeSeconds = 6

    public var longPlaySeconds: Int
    public var unknownDurationSeconds: Int
    public var fadeSeconds: Int

    public init(
        longPlaySeconds: Int = Self.defaultLongPlaySeconds,
        unknownDurationSeconds: Int = Self.defaultUnknownDurationSeconds,
        fadeSeconds: Int = Self.defaultFadeSeconds
    ) {
        self.longPlaySeconds = max(0, longPlaySeconds)
        self.unknownDurationSeconds = max(1, unknownDurationSeconds)
        self.fadeSeconds = max(0, fadeSeconds)
    }
}

/// Decoder or catalog timing facts consumed by the shared frontend timing
/// policy. A zero value means that no natural duration is available.
public struct PlaybackTimingMetadata: Codable, Equatable, Sendable {
    public let playMilliseconds: Int
    public let introMilliseconds: Int
    public let loopMilliseconds: Int

    public init(
        playMilliseconds: Int = 0,
        introMilliseconds: Int = 0,
        loopMilliseconds: Int = 0
    ) {
        self.playMilliseconds = max(0, playMilliseconds)
        self.introMilliseconds = max(0, introMilliseconds)
        self.loopMilliseconds = max(0, loopMilliseconds)
    }

    public var naturalPlayMilliseconds: Int {
        if playMilliseconds > 0 { return playMilliseconds }
        if introMilliseconds > 0 || loopMilliseconds > 0 {
            return max(introMilliseconds + loopMilliseconds, loopMilliseconds)
        }
        return 0
    }
}

/// The effective timing preview shown by a frontend and carried into the
/// shared playback request. The decoder remains authoritative for final
/// natural-duration verification.
public struct PlaybackTimingPlan: Equatable, Sendable {
    public let preFadeSeconds: Int
    public let fadeSeconds: Int
    public let usesNativeEnding: Bool
    public let isLongPlay: Bool
    public let unknownDurationSeconds: Int

    public var totalSeconds: Int { preFadeSeconds > 0 ? preFadeSeconds + fadeSeconds : 0 }

    public init(
        preFadeSeconds: Int,
        fadeSeconds: Int,
        usesNativeEnding: Bool,
        isLongPlay: Bool,
        unknownDurationSeconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds
    ) {
        self.preFadeSeconds = max(0, preFadeSeconds)
        self.fadeSeconds = max(0, fadeSeconds)
        self.usesNativeEnding = usesNativeEnding
        self.isLongPlay = isLongPlay
        self.unknownDurationSeconds = max(1, unknownDurationSeconds)
    }
}

/// Shared timing policy extracted from CocoaSpice's native implementation.
public enum PlaybackTimingPolicy {
    public static func plan(
        metadata: PlaybackTimingMetadata?,
        family: DecoderFamily?,
        longPlayEnabled: Bool,
        preferences: PlaybackTimingPreferences
    ) -> PlaybackTimingPlan {
        let supportedLongPlay = family?.supportsLongPlay ?? false
        let fadeSeconds = max(0, preferences.fadeSeconds)

        if longPlayEnabled, supportedLongPlay {
            return PlaybackTimingPlan(
                preFadeSeconds: preferences.longPlaySeconds,
                fadeSeconds: fadeSeconds,
                usesNativeEnding: false,
                isLongPlay: true,
                unknownDurationSeconds: preferences.unknownDurationSeconds
            )
        }

        let naturalMilliseconds = metadata?.naturalPlayMilliseconds ?? 0
        if naturalMilliseconds > 0 {
            return PlaybackTimingPlan(
                preFadeSeconds: max(1, Int((Double(naturalMilliseconds) / 1_000.0).rounded())),
                fadeSeconds: fadeSeconds,
                usesNativeEnding: fadeSeconds == 0,
                isLongPlay: false,
                unknownDurationSeconds: preferences.unknownDurationSeconds
            )
        }

        return PlaybackTimingPlan(
            preFadeSeconds: preferences.unknownDurationSeconds,
            fadeSeconds: fadeSeconds,
            usesNativeEnding: true,
            isLongPlay: false,
            unknownDurationSeconds: preferences.unknownDurationSeconds
        )
    }
}
