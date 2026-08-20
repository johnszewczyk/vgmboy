import Foundation

/// Versioned in-process control API for one VGMBoy playback session. A GUI,\n/// the CLI, and future frontends call the same typed commands and observe the\n/// same events; this is not a daemon or a transport protocol.
public enum PlaybackControlProtocol {
    public static let version = 1
}

public enum PlaybackControlCommand: String, Codable, Sendable {
    case load
    case play
    case pause
    case stop
    case seek
    case setTempo = "set_tempo"
    case setPlaybackMode = "set_playback_mode"
    case setEqualizer = "set_equalizer"
    case setOutputVolume = "set_output_volume"
    case setMonoEnabled = "set_mono_enabled"
    case status
    case subscribe
    case shutdown
}

/// Capability query for an embedded frontend. It is intentionally local and
/// typed: VGMBoyKit is linked into the host, never discovered as a daemon.
public struct PlaybackControlSurface: Sendable {
    public let version: Int = PlaybackControlProtocol.version

    public init() {}

    public func supports(_ command: PlaybackControlCommand) -> Bool {
        switch command {
        case .load, .play, .pause, .stop, .seek, .setTempo,
             .setPlaybackMode, .setEqualizer, .setOutputVolume, .setMonoEnabled,
             .status, .subscribe:
            true
        case .shutdown:
            false
        }
    }
}

public enum PlaybackMode: String, Codable, Sendable {
    /// Use tagged/native timing whenever the decoder supports it.
    case fileDefault = "file_default"
    /// Bound playback to `playMilliseconds + fadeMilliseconds`.
    case longPlay = "long_play"
    /// Bound playback to an explicit finite window without presenting it as
    /// the frontend's Long Play preference.
    case timed
}

public struct EqualizerConfiguration: Codable, Sendable, Equatable {
    public static let bandCount = 10
    /// CocoaSpice's established ten parametric-band centers, in Hz.
    public static let bandFrequencies: [Float] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    public static let gainRange: ClosedRange<Float> = -12...12
    public var enabled: Bool
    public var gainsDecibels: [Float]

    public init(enabled: Bool = true, gainsDecibels: [Float] = Array(repeating: 0, count: bandCount)) {
        self.enabled = enabled
        self.gainsDecibels = gainsDecibels
    }

    public var isValid: Bool {
        gainsDecibels.count == Self.bandCount
            && gainsDecibels.allSatisfy(\.isFinite)
            && gainsDecibels.allSatisfy { Self.gainRange.contains($0) }
    }
}

public enum PlaybackControlError: LocalizedError, Equatable {
    case invalidPayload(String)
    case unsupportedCommand(PlaybackControlCommand)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload(let message): return message
        case .unsupportedCommand(let command): return "Unsupported in-process command: \(command.rawValue)."
        }
    }
}

/// The finite parameters used by v1 commands. Fields not consumed by a command\n/// are rejected by the control boundary, rather than interpreted as playlist\n/// state or silently stored by the core.
public struct PlaybackControlPayload: Codable, Sendable, Equatable {
    public var path: String?
    public var trackIndex: Int?
    public var positionMilliseconds: Int?
    public var tempo: Double?
    public var playbackMode: PlaybackMode?
    public var playMilliseconds: Int?
    public var fadeMilliseconds: Int?
    public var equalizer: EqualizerConfiguration?
    public var outputVolume: Float?
    public var monoEnabled: Bool?

    public init(
        path: String? = nil,
        trackIndex: Int? = nil,
        positionMilliseconds: Int? = nil,
        tempo: Double? = nil,
        playbackMode: PlaybackMode? = nil,
        playMilliseconds: Int? = nil,
        fadeMilliseconds: Int? = nil,
        equalizer: EqualizerConfiguration? = nil,
        outputVolume: Float? = nil,
        monoEnabled: Bool? = nil
    ) {
        self.path = path
        self.trackIndex = trackIndex
        self.positionMilliseconds = positionMilliseconds
        self.tempo = tempo
        self.playbackMode = playbackMode
        self.playMilliseconds = playMilliseconds
        self.fadeMilliseconds = fadeMilliseconds
        self.equalizer = equalizer
        self.outputVolume = outputVolume
        self.monoEnabled = monoEnabled
    }
}

public struct PlaybackControlRequest: Codable, Sendable, Equatable {
    public var version: Int
    public var requestID: String
    public var command: PlaybackControlCommand
    public var payload: PlaybackControlPayload

    public init(
        requestID: String = UUID().uuidString,
        command: PlaybackControlCommand,
        payload: PlaybackControlPayload = .init()
    ) {
        version = PlaybackControlProtocol.version
        self.requestID = requestID
        self.command = command
        self.payload = payload
    }
}

public enum PlaybackControlEventKind: String, Codable, Sendable {
    case ready
    case response
    case status
    case ended
    case error
}

public struct PlaybackControlEvent: Codable, Sendable, Equatable {
    public var version: Int
    public var requestID: String?
    public var kind: PlaybackControlEventKind
    public var status: PlaybackStatus?
    public var message: String?

    public init(
        requestID: String? = nil,
        kind: PlaybackControlEventKind,
        status: PlaybackStatus? = nil,
        message: String? = nil
    ) {
        version = PlaybackControlProtocol.version
        self.requestID = requestID
        self.kind = kind
        self.status = status
        self.message = message
    }
}
