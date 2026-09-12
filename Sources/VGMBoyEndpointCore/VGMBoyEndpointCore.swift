import Foundation

/// Platform-neutral capability map for frontends embedding or bridging
/// VGMBoyKit. The map names the stable wire surface; implementations may
/// expose fewer routes and must advertise that fact instead of guessing.
public enum VGMBoyEndpoint: String, Codable, CaseIterable, Sendable {
    case playback
    case audio
    case diagnostics
    case export
}

public enum VGMBoyEndpointOperation: String, Codable, CaseIterable, Sendable {
    case load
    case play
    case pause
    case stop
    case unload
    case seek
    case setTempo = "set_tempo"
    case setPlaybackMode = "set_playback_mode"
    case setOutputVolume = "set_output_volume"
    case setEqualizer = "set_equalizer"
    case rampOutputGain = "ramp_output_gain"
    case setMonoEnabled = "set_mono_enabled"
    case status
    case subscribe
    case exportAAC = "export_aac"
}

public struct VGMBoyEndpointSurface: Codable, Equatable, Sendable {
    public static let version = 1

    public let version: Int
    public let endpoints: [VGMBoyEndpoint: [VGMBoyEndpointOperation]]

    public init(version: Int = Self.version, endpoints: [VGMBoyEndpoint: [VGMBoyEndpointOperation]]) {
        self.version = version
        self.endpoints = endpoints
    }

    public func supports(_ endpoint: VGMBoyEndpoint, _ operation: VGMBoyEndpointOperation) -> Bool {
        endpoints[endpoint]?.contains(operation) == true
    }

    /// The complete v1 surface. A host may publish a reduced map when a
    /// platform-specific implementation cannot provide an operation.
    public static let v1 = VGMBoyEndpointSurface(endpoints: [
        .playback: [.load, .play, .pause, .stop, .unload, .seek, .setTempo, .setPlaybackMode],
        .audio: [.setOutputVolume, .setEqualizer, .rampOutputGain, .setMonoEnabled],
        .diagnostics: [.status, .subscribe],
        .export: [.exportAAC]
    ])
}
