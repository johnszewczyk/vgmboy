import Foundation
import VGMBoyKit

/// Typed audio-output settings supplied by a presentation adapter. This keeps
/// the renderer's persistence shape at the edge while routing normalization and
/// command ordering through one shared transport operation.
public struct PlaybackTransportAudioConfigurationRequest: Codable, Equatable, Sendable {
    public let outputVolume: Float
    public let equalizerEnabled: Bool
    public let equalizerBandGains: [Float]
    public let monoEnabled: Bool

    public init(
        outputVolume: Float = PlaybackPreferences.defaultValue.outputVolume,
        equalizerEnabled: Bool = false,
        equalizerBandGains: [Float] = Array(repeating: 0, count: EqualizerConfiguration.bandCount),
        monoEnabled: Bool = false
    ) {
        let preferences = PlaybackPreferences(
            equalizerEnabled: equalizerEnabled,
            equalizerBandGains: equalizerBandGains,
            outputVolume: outputVolume,
            monoEnabled: monoEnabled
        )
        self.outputVolume = preferences.outputVolume
        self.equalizerEnabled = preferences.equalizer.enabled
        self.equalizerBandGains = preferences.equalizer.gainsDecibels
        self.monoEnabled = preferences.monoEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case outputVolume = "appVolume"
        case equalizerEnabled
        case equalizerBandGains
        case monoEnabled
    }

    public var preferences: PlaybackPreferences {
        PlaybackPreferences(
            equalizerEnabled: equalizerEnabled,
            equalizerBandGains: equalizerBandGains,
            outputVolume: outputVolume,
            monoEnabled: monoEnabled
        )
    }
}

/// Typed offline-export input. VGMBoy owns archive/member preparation and
/// finite rendering; the app adapter owns presentation events.
public struct PlaybackTransportAACExportRequest: Codable, Equatable, Sendable {
    public let sourcePath: String
    public let archivePath: String?
    public let archiveEntry: String?
    public let trackIndex: Int
    public let outputDirectory: String
    public let filenameStem: String
    public let playMilliseconds: Int
    public let fadeMilliseconds: Int
    public let tempo: PlaybackTempo?

    public init(
        sourcePath: String,
        archivePath: String? = nil,
        archiveEntry: String? = nil,
        trackIndex: Int = 0,
        outputDirectory: String,
        filenameStem: String,
        playMilliseconds: Int,
        fadeMilliseconds: Int = 0,
        tempo: PlaybackTempo? = nil
    ) {
        self.sourcePath = sourcePath
        self.archivePath = archivePath
        self.archiveEntry = archiveEntry
        self.trackIndex = max(0, trackIndex)
        self.outputDirectory = outputDirectory
        self.filenameStem = filenameStem
        self.playMilliseconds = max(0, playMilliseconds)
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.tempo = tempo
    }

    private enum CodingKeys: String, CodingKey {
        case sourcePath = "path"
        case archivePath
        case archiveEntry
        case trackIndex
        case outputDirectory
        case filenameStem
        case playMilliseconds
        case fadeMilliseconds
        case tempo
    }

    public func exportRequest() throws -> AACExportRequest {
        let inputPath = archivePath.flatMap { $0.isEmpty ? nil : $0 } ?? sourcePath
        let member = archiveEntry.flatMap { $0.isEmpty ? nil : $0 }
        guard !sourcePath.isEmpty, !inputPath.isEmpty,
              !outputDirectory.isEmpty, playMilliseconds > 0 else {
            throw PlaybackControlError.invalidPayload(
                "AAC export requires a playable path, output folder, filename, and positive play length."
            )
        }
        return .init(
            sourcePath: inputPath,
            archiveEntry: member,
            trackIndex: trackIndex,
            outputDirectory: URL(fileURLWithPath: outputDirectory),
            filenameStem: filenameStem,
            playMilliseconds: playMilliseconds,
            fadeMilliseconds: fadeMilliseconds,
            tempo: tempo?.multiplier ?? 1
        )
    }


}

public struct PlaybackTransportAACExportResponse: Codable, Equatable, Sendable {
    public let path: String
    public let id: String

    public init(path: String, id: String) {
        self.path = path
        self.id = id
    }
}

public struct PlaybackTransportAACExportCancellationRequest: Codable, Equatable, Sendable {
    public let id: String?

    public init(id: String? = nil) {
        self.id = id
    }
}

public struct PlaybackTransportAACExportCancellationResponse: Codable, Equatable, Sendable {
    public let cancelled: Bool
    public let id: String?

    public init(cancelled: Bool, id: String? = nil) {
        self.cancelled = cancelled
        self.id = id
    }
}

/// Typed direct seek intent. The shared control surface remains responsible
/// for session validity; this boundary only prevents positional bridge values.
public struct PlaybackTransportSeekRequest: Codable, Equatable, Sendable {
    public let positionMilliseconds: Int
    public let expectedGeneration: Int?
    public let seekRevision: Int?

    public init(positionMilliseconds: Int, expectedGeneration: Int? = nil, seekRevision: Int? = nil) {
        self.positionMilliseconds = max(0, positionMilliseconds)
        self.expectedGeneration = expectedGeneration
        self.seekRevision = seekRevision
    }

    public var payload: PlaybackControlPayload {
        .init(positionMilliseconds: positionMilliseconds)
    }
}

public struct PlaybackTransportSessionRequest: Codable, Equatable, Sendable {
    public let expectedGeneration: Int?

    public init(expectedGeneration: Int? = nil) {
        self.expectedGeneration = expectedGeneration
    }
}

/// Typed output-envelope command used around a presentation transition. Gain
/// and duration are normalized before they reach the shared decoder session.
public struct PlaybackTransportRampGainRequest: Codable, Equatable, Sendable {
    public let outputGain: Float
    public let rampMilliseconds: Int
    public let expectedGeneration: Int?
    public let rampRevision: Int?

    public init(outputGain: Float, rampMilliseconds: Int, expectedGeneration: Int? = nil, rampRevision: Int? = nil) {
        self.outputGain = outputGain.isFinite ? outputGain : 0
        self.rampMilliseconds = max(1, rampMilliseconds)
        self.expectedGeneration = expectedGeneration
        self.rampRevision = rampRevision
    }

    public var payload: PlaybackControlPayload {
        .init(outputGain: outputGain, rampMilliseconds: rampMilliseconds)
    }
}

/// Typed renderer request for the timing preview displayed before a track is
/// loaded. The frontend supplies catalog facts and user intent; VGMBoyKit owns
/// format admission and the resulting duration policy.
public struct PlaybackTimingPreviewRequest: Codable, Equatable, Sendable {
    public let sourcePath: String
    public let playMilliseconds: Int
    public let manualPlayMilliseconds: Int
    public let fadeMilliseconds: Int
    public let unknownDurationMilliseconds: Int
    public let tempo: PlaybackTempo
    public let longPlayEnabled: Bool

    public init(
        sourcePath: String,
        playMilliseconds: Int = 0,
        manualPlayMilliseconds: Int = PlaybackTimingPreferences.defaultLongPlaySeconds * 1_000,
        fadeMilliseconds: Int = PlaybackTimingPreferences.defaultFadeSeconds * 1_000,
        unknownDurationMilliseconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000,
        tempo: PlaybackTempo = .defaultValue,
        longPlayEnabled: Bool = false
    ) {
        self.sourcePath = sourcePath
        self.playMilliseconds = max(0, playMilliseconds)
        self.manualPlayMilliseconds = max(0, manualPlayMilliseconds)
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.unknownDurationMilliseconds = max(1_000, unknownDurationMilliseconds)
        self.tempo = PlaybackTempo(numerator: tempo.numerator, denominator: tempo.denominator)
        self.longPlayEnabled = longPlayEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case sourcePath = "path"
        case playMilliseconds
        case manualPlayMilliseconds
        case fadeMilliseconds
        case unknownDurationMilliseconds
        case tempo
        case longPlayEnabled
    }

    /// Resolves the shared timing policy and scales the visible pre-fade
    /// duration for native tempo without changing the decoder's policy.
    public func preview() throws -> PlaybackTimingPreview {
        // Native timing is bounded to signed 32-bit milliseconds. Validate
        // decoded bridge values too: synthesized Decodable bypasses init.
        let maximum = Int(Int32.max)
        guard (0...maximum).contains(playMilliseconds),
              (0...maximum).contains(manualPlayMilliseconds),
              (0...maximum).contains(fadeMilliseconds),
              (1...maximum).contains(unknownDurationMilliseconds) else {
            throw PlaybackControlError.invalidPayload("Playback timing is outside the supported range.")
        }
        guard let family = FormatRegistry.family(for: sourcePath) else {
            throw PlaybackControlError.invalidPayload("Playback timing requires a supported file path.")
        }
        let plan = PlaybackTimingPolicy.plan(
            metadata: .init(playMilliseconds: playMilliseconds),
            family: family,
            longPlayEnabled: longPlayEnabled,
            preferences: .init(
                longPlaySeconds: manualPlayMilliseconds / 1_000,
                unknownDurationSeconds: unknownDurationMilliseconds / 1_000,
                fadeSeconds: fadeMilliseconds / 1_000
            )
        )
        let effectiveTempo = FormatRegistry.effectiveTempo(tempo.multiplier, family: family)
        let scaledPreFadeSeconds = plan.preFadeSeconds <= 0
            ? 0
            : max(1, Int((Double(plan.preFadeSeconds) / effectiveTempo).rounded(.down)))
        let sourceMilliseconds = plan.isLongPlay
            ? manualPlayMilliseconds
            : (playMilliseconds > 0 ? playMilliseconds : unknownDurationMilliseconds)
        let outputMilliseconds = sourceMilliseconds == 0
            ? 0
            : max(1, Int((Double(sourceMilliseconds) / effectiveTempo).rounded()))
        return .init(
            preFadeSeconds: scaledPreFadeSeconds,
            fadeSeconds: plan.fadeSeconds,
            isLongPlay: plan.isLongPlay,
            usesNativeEnding: plan.usesNativeEnding,
            preFadeMilliseconds: outputMilliseconds,
            fadeMilliseconds: fadeMilliseconds
        )
    }
}

/// UI-neutral timing preview returned to renderers. Its coding keys preserve
/// the established WebKit wire shape while preventing bridge-local dictionary
/// construction.
public struct PlaybackTimingPreview: Codable, Equatable, Sendable {
    public let preFadeSeconds: Int
    public let fadeSeconds: Int
    public let totalSeconds: Int
    public let preFadeMilliseconds: Int
    public let fadeMilliseconds: Int
    public let totalMilliseconds: Int
    public let isLongPlay: Bool
    public let usesNativeEnding: Bool

    public init(
        preFadeSeconds: Int,
        fadeSeconds: Int,
        isLongPlay: Bool,
        usesNativeEnding: Bool,
        preFadeMilliseconds: Int? = nil,
        fadeMilliseconds: Int? = nil
    ) {
        self.preFadeSeconds = max(0, preFadeSeconds)
        self.fadeSeconds = max(0, fadeSeconds)
        self.totalSeconds = self.preFadeSeconds > 0 ? Self.saturatingAdd(self.preFadeSeconds, self.fadeSeconds) : 0
        self.preFadeMilliseconds = max(0, preFadeMilliseconds ?? Self.saturatingMilliseconds(self.preFadeSeconds))
        self.fadeMilliseconds = max(0, fadeMilliseconds ?? Self.saturatingMilliseconds(self.fadeSeconds))
        self.totalMilliseconds = self.preFadeMilliseconds > 0 ? Self.saturatingAdd(self.preFadeMilliseconds, self.fadeMilliseconds) : 0
        self.isLongPlay = isLongPlay
        self.usesNativeEnding = usesNativeEnding
    }

    private static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : value
    }

    private static func saturatingMilliseconds(_ seconds: Int) -> Int {
        let (value, overflow) = seconds.multipliedReportingOverflow(by: 1_000)
        return overflow ? Int.max : value
    }

    private enum CodingKeys: String, CodingKey {
        case preFadeSeconds = "pre_fade_seconds"
        case fadeSeconds = "fade_seconds"
        case totalSeconds = "total_seconds"
        case preFadeMilliseconds = "pre_fade_milliseconds"
        case fadeMilliseconds = "fade_milliseconds"
        case totalMilliseconds = "total_milliseconds"
        case isLongPlay = "is_long_play"
        case usesNativeEnding = "uses_native_ending"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            preFadeSeconds: try values.decode(Int.self, forKey: .preFadeSeconds),
            fadeSeconds: try values.decode(Int.self, forKey: .fadeSeconds),
            isLongPlay: try values.decode(Bool.self, forKey: .isLongPlay),
            usesNativeEnding: try values.decode(Bool.self, forKey: .usesNativeEnding),
            preFadeMilliseconds: try values.decodeIfPresent(Int.self, forKey: .preFadeMilliseconds),
            fadeMilliseconds: try values.decodeIfPresent(Int.self, forKey: .fadeMilliseconds)
        )
    }
}

/// Typed update for an already-loaded transport. The shared contract creates
/// the VGMBoy control payload, so presentation adapters cannot choose an
/// alternate playback mode or silently invent timing fallbacks.
public struct PlaybackTransportReconfigurationRequest: Codable, Equatable, Sendable {
    public let longPlayEnabled: Bool
    public let manualPlayMilliseconds: Int
    public let fadeMilliseconds: Int
    public let unknownDurationMilliseconds: Int
    public let tempo: PlaybackTempo
    public let expectedGeneration: Int?
    public let settingsRevision: Int?

    public init(
        longPlayEnabled: Bool,
        manualPlayMilliseconds: Int = 0,
        fadeMilliseconds: Int = 0,
        unknownDurationMilliseconds: Int = PlaybackTimingPreferences.defaultUnknownDurationSeconds * 1_000,
        tempo: PlaybackTempo = .defaultValue,
        expectedGeneration: Int? = nil,
        settingsRevision: Int? = nil
    ) {
        self.longPlayEnabled = longPlayEnabled
        self.manualPlayMilliseconds = max(0, manualPlayMilliseconds)
        self.fadeMilliseconds = max(0, fadeMilliseconds)
        self.unknownDurationMilliseconds = max(1_000, unknownDurationMilliseconds)
        self.tempo = PlaybackTempo(numerator: tempo.numerator, denominator: tempo.denominator)
        self.expectedGeneration = expectedGeneration
        self.settingsRevision = settingsRevision
    }

    public var playbackModePayload: PlaybackControlPayload {
        .init(
            playbackMode: longPlayEnabled ? .longPlay : .fileDefault,
            playMilliseconds: longPlayEnabled ? manualPlayMilliseconds : nil,
            fadeMilliseconds: fadeMilliseconds,
            unknownDurationMilliseconds: unknownDurationMilliseconds
        )
    }
}

/// A narrow typed tempo update. A changed effective rate reloads the current
/// session while retaining its timing settings; an unchanged rate is a no-op.
public struct PlaybackTransportTempoRequest: Codable, Equatable, Sendable {
    public let tempo: PlaybackTempo

    public init(tempo: PlaybackTempo = .defaultValue) {
        self.tempo = PlaybackTempo(numerator: tempo.numerator, denominator: tempo.denominator)
    }
}
