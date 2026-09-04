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
    public let usesDecoderNaturalDuration: Bool
    public let unknownDurationSeconds: Int

    public var totalSeconds: Int { preFadeSeconds > 0 ? preFadeSeconds + fadeSeconds : 0 }

    public init(
        preFadeSeconds: Int,
        fadeSeconds: Int,
        usesNativeEnding: Bool,
        isLongPlay: Bool,
        usesDecoderNaturalDuration: Bool = false,
        unknownDurationSeconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds
    ) {
        self.preFadeSeconds = max(0, preFadeSeconds)
        self.fadeSeconds = max(0, fadeSeconds)
        self.usesNativeEnding = usesNativeEnding
        self.isLongPlay = isLongPlay
        self.usesDecoderNaturalDuration = usesDecoderNaturalDuration
        self.unknownDurationSeconds = max(1, unknownDurationSeconds)
    }

    /// Source-compatible initializer for callers that used the original
    /// internal `PlaybackPlan` label order before this type became shared.
    public init(
        preFadeSeconds: Int,
        fadeSeconds: Int,
        isLongPlay: Bool,
        usesNativeEnding: Bool,
        usesDecoderNaturalDuration: Bool = false,
        unknownDurationSeconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds
    ) {
        self.init(
            preFadeSeconds: preFadeSeconds,
            fadeSeconds: fadeSeconds,
            usesNativeEnding: usesNativeEnding,
            isLongPlay: isLongPlay,
            usesDecoderNaturalDuration: usesDecoderNaturalDuration,
            unknownDurationSeconds: unknownDurationSeconds
        )
    }
}

/// Shared timing policy extracted from CocoaSpice's native implementation.
public enum PlaybackTimingPolicy {
    /// Resolves one typed request against catalog/decoder timing facts.
    ///
    /// A `fileDefault` request with no explicit play length asks the decoder
    /// for its natural duration. The unknown-duration value is only the
    /// bounded fallback when that request produces no timing metadata. A
    /// `timed` request is always explicit and never consults metadata.
    public static func plan(
        metadata: PlaybackTimingMetadata?,
        family: DecoderFamily?,
        request: PlaybackTimingRequest
    ) -> PlaybackTimingPlan {
        let fadeSeconds = max(0, request.fadeMilliseconds / 1_000)
        let unknownDurationSeconds = max(1, request.unknownDurationMilliseconds / 1_000)

        switch request.playbackMode {
        case .longPlay:
            guard family?.supportsLongPlay == true else {
                return fileDefaultPlan(
                    metadata: metadata,
                    family: family,
                    explicitPlaySeconds: nil,
                    fadeSeconds: fadeSeconds,
                    unknownDurationSeconds: unknownDurationSeconds
                )
            }
            let playSeconds = max(0, (request.playMilliseconds ?? 0) / 1_000)
            return PlaybackTimingPlan(
                preFadeSeconds: playSeconds,
                fadeSeconds: fadeSeconds,
                usesNativeEnding: false,
                isLongPlay: true,
                usesDecoderNaturalDuration: false,
                unknownDurationSeconds: unknownDurationSeconds
            )

        case .timed:
            let playSeconds = max(0, (request.playMilliseconds ?? 0) / 1_000)
            return PlaybackTimingPlan(
                preFadeSeconds: playSeconds,
                fadeSeconds: fadeSeconds,
                usesNativeEnding: false,
                isLongPlay: false,
                usesDecoderNaturalDuration: false,
                unknownDurationSeconds: unknownDurationSeconds
            )

        case .fileDefault:
            return fileDefaultPlan(
                metadata: metadata,
                family: family,
                explicitPlaySeconds: request.playMilliseconds.map { max(0, $0 / 1_000) },
                fadeSeconds: fadeSeconds,
                unknownDurationSeconds: unknownDurationSeconds
            )
        }
    }

    /// Compatibility convenience for frontend settings adapters. New callers
    /// should form a `PlaybackTimingRequest` and use the typed overload above.
    public static func plan(
        metadata: PlaybackTimingMetadata?,
        family: DecoderFamily?,
        longPlayEnabled: Bool,
        preferences: PlaybackTimingPreferences
    ) -> PlaybackTimingPlan {
        let useLongPlay = longPlayEnabled && family?.supportsLongPlay == true
        let request = PlaybackTimingRequest(
            playbackMode: useLongPlay ? .longPlay : .fileDefault,
            playMilliseconds: useLongPlay ? preferences.longPlaySeconds * 1_000 : nil,
            fadeMilliseconds: max(0, preferences.fadeSeconds) * 1_000,
            unknownDurationMilliseconds: max(1, preferences.unknownDurationSeconds) * 1_000
        )
        return plan(metadata: metadata, family: family, request: request)
    }

    private static func fileDefaultPlan(
        metadata: PlaybackTimingMetadata?,
        family: DecoderFamily?,
        explicitPlaySeconds: Int?,
        fadeSeconds: Int,
        unknownDurationSeconds: Int
    ) -> PlaybackTimingPlan {
        if let explicitPlaySeconds {
            return PlaybackTimingPlan(
                preFadeSeconds: explicitPlaySeconds,
                fadeSeconds: fadeSeconds,
                usesNativeEnding: family?.hasNaturalEnding == true && fadeSeconds == 0,
                isLongPlay: false,
                usesDecoderNaturalDuration: false,
                unknownDurationSeconds: unknownDurationSeconds
            )
        }

        let naturalMilliseconds = metadata?.naturalPlayMilliseconds ?? 0
        if naturalMilliseconds > 0 {
            return PlaybackTimingPlan(
                preFadeSeconds: max(1, Int((Double(naturalMilliseconds) / 1_000.0).rounded())),
                fadeSeconds: fadeSeconds,
                usesNativeEnding: family?.hasNaturalEnding == true && fadeSeconds == 0,
                isLongPlay: false,
                usesDecoderNaturalDuration: true,
                unknownDurationSeconds: unknownDurationSeconds
            )
        }

        return PlaybackTimingPlan(
            preFadeSeconds: unknownDurationSeconds,
            fadeSeconds: fadeSeconds,
            usesNativeEnding: false,
            isLongPlay: false,
            usesDecoderNaturalDuration: true,
            unknownDurationSeconds: unknownDurationSeconds
        )
    }
}

typealias PlaybackPlan = PlaybackTimingPlan
