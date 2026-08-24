import Foundation

/// Decoder facts needed to form a local-file queue when no ScanSong
/// catalogue is loaded. It intentionally exposes neither tags nor a database
/// model: published catalog metadata remains a frontend concern.
public struct PlaybackTrackStructure: Codable, Equatable, Sendable {
    public let index: Int
    public let naturalPlayMilliseconds: Int
    public let fadeMilliseconds: Int

    public init(index: Int, naturalPlayMilliseconds: Int, fadeMilliseconds: Int) {
        self.index = index
        self.naturalPlayMilliseconds = naturalPlayMilliseconds
        self.fadeMilliseconds = fadeMilliseconds
    }
}

public struct PlaybackStructure: Codable, Equatable, Sendable {
    public let trackCount: Int
    public let tracks: [PlaybackTrackStructure]

    public init(trackCount: Int, tracks: [PlaybackTrackStructure]) {
        self.trackCount = trackCount
        self.tracks = tracks
    }
}

public enum PlaybackStructureReader {
    public static func read(path: String) throws -> PlaybackStructure {
        let decoder = try DecoderFactory.make(path: path)
        defer { decoder.close() }
        let count = max(1, decoder.trackCount)
        let tracks = try (0 ..< count).map { index -> PlaybackTrackStructure in
            let metadata = try decoder.metadata(for: index)
            return PlaybackTrackStructure(
                index: index,
                naturalPlayMilliseconds: metadata.naturalPlayMs,
                fadeMilliseconds: max(0, metadata.fadeMs)
            )
        }
        return PlaybackStructure(trackCount: count, tracks: tracks)
    }
}
