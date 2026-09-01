import Foundation
import VGMBoySNDH

public struct SNDHFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let source = try SNDHMetadataReader.read(fileURL: fileURL)
        let tracks = source.tracks.map { track in
            let song = track.subtuneName.isEmpty ? source.title : track.subtuneName
            let length = max(0, track.durationMilliseconds)
            let metadata = ScannerMetadata(
                game: "",
                song: song,
                system: "Atari ST",
                author: source.composer,
                comment: source.year,
                introLengthMs: 0,
                loopLengthMs: 0,
                playLengthMs: length,
                fadeLengthMs: 0
            )
            return ScanTrackMetadata(
                trackIndex: track.index,
                trackCount: source.tracks.count,
                metadata: metadata
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }
}
