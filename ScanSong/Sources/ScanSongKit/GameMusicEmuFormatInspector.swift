import CGameMusicEmu
import Foundation

public struct GameMusicEmuFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        if route.formatExtension == "spc", let direct = try SPCMetadataReader.read(fileURL: fileURL) {
            return ScanInspection(
                route: route,
                tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: direct)]
            )
        }

        var emulator: OpaquePointer?
        try throwIfNeeded(gme_open_file(fileURL.path, &emulator, Int32(gme_info_only)))
        guard let emulator else {
            throw ScannerInspectionError.library("Game Music Emu did not return an inspector for \(fileURL.lastPathComponent).")
        }
        defer { gme_delete(emulator) }

        let companionPlaylistURL = route.formatExtension == "hes"
            ? companionHESPlaylistURL(for: fileURL)
            : nil
        if let playlistURL = companionPlaylistURL {
            try throwIfNeeded(playlistURL.path.withCString { gme_load_m3u(emulator, $0) })
        }

        let count = Int(gme_track_count(emulator))
        guard count > 0 else {
            throw ScannerInspectionError.malformedFile("Game Music Emu found no tracks in \(fileURL.lastPathComponent).")
        }
        let directHeader = try? GameMusicMetadataReader.read(fileURL: fileURL)
        let tracks = try (0..<count).map { index in
            var infoPointer: UnsafeMutablePointer<gme_info_t>?
            try throwIfNeeded(gme_track_info(emulator, &infoPointer, Int32(index)))
            guard let infoPointer else {
                throw ScannerInspectionError.library("Game Music Emu returned no metadata for track \(index + 1).")
            }
            defer { gme_free_info(infoPointer) }
            let info = infoPointer.pointee
            let suppressUnverifiedHESTiming = route.formatExtension == "hes" && companionPlaylistURL == nil
            let decoderMetadata = ScannerMetadata(
                game: string(info.game),
                song: string(info.song),
                system: string(info.system),
                author: string(info.author),
                comment: string(info.comment),
                introLengthMs: suppressUnverifiedHESTiming ? 0 : Int(info.intro_length),
                loopLengthMs: suppressUnverifiedHESTiming ? 0 : Int(info.loop_length),
                playLengthMs: suppressUnverifiedHESTiming ? 0 : Int(info.play_length),
                fadeLengthMs: suppressUnverifiedHESTiming ? 0 : Int(info.fade_length)
            )
            return ScanTrackMetadata(
                trackIndex: index,
                trackCount: count,
                metadata: directHeader?.merged(with: decoderMetadata) ?? decoderMetadata
            )
        }
        return ScanInspection(route: route, tracks: tracks)
    }

    private func throwIfNeeded(_ error: gme_err_t?) throws {
        if let error { throw ScannerInspectionError.library(String(cString: error)) }
    }

    private func string(_ pointer: UnsafePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        let value = String(cString: pointer)
        return value == "?" ? "" : value
    }

    private func companionHESPlaylistURL(for fileURL: URL) -> URL? {
        let baseURL = fileURL.deletingPathExtension()
        let candidates = [
            baseURL.appendingPathExtension("m3u"),
            baseURL.appendingPathExtension("M3U")
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}
