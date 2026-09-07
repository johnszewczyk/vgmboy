import Foundation

public struct VGMBoyZXTuneInspection: Codable, Sendable {
    public let title: String
    public let system: String
    public let artist: String
    public let program: String
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let trackCount: Int

    public init(
        title: String,
        system: String,
        artist: String,
        program: String,
        introLengthMs: Int,
        loopLengthMs: Int,
        playLengthMs: Int,
        trackCount: Int
    ) {
        self.title = title
        self.system = system
        self.artist = artist
        self.program = program
        self.introLengthMs = introLengthMs
        self.loopLengthMs = loopLengthMs
        self.playLengthMs = playLengthMs
        self.trackCount = trackCount
    }
}

public enum VGMBoyZXTuneInspector {
    public static func inspect(path: String) throws -> VGMBoyZXTuneInspection {
        let decoder = try ZXTuneDecoder(path: path)
        let metadata = try decoder.metadata(for: 0)
        return VGMBoyZXTuneInspection(
            title: metadata.song,
            system: metadata.system,
            artist: metadata.author,
            program: decoder.systemName,
            introLengthMs: metadata.introMs,
            loopLengthMs: metadata.loopMs,
            playLengthMs: metadata.playMs,
            trackCount: decoder.trackCount
        )
    }
}
