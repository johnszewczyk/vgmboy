import Foundation

public struct TrackInspection: Sendable, Codable {
    public var system: String
    public var trackCount: Int
    public var tracks: [TrackMetadata]

    public init(system: String, trackCount: Int, tracks: [TrackMetadata]) {
        self.system = system
        self.trackCount = trackCount
        self.tracks = tracks
    }
}

public enum AudioInspector {
    /// Reads routing, system identity, and per-track timing metadata without
    /// starting playback. The one public inspect entry point for the kit.
    public static func inspect(path: String) throws -> TrackInspection {
        let decoder = try GMEDecoder(path: path)
        let trackCount = decoder.trackCount
        var tracks: [TrackMetadata] = []
        tracks.reserveCapacity(trackCount)
        for index in 0..<trackCount {
            tracks.append(try decoder.metadata(for: index))
        }
        return TrackInspection(system: decoder.systemName, trackCount: trackCount, tracks: tracks)
    }
}