import Foundation
import VGMBoyCMDX

public struct VGMBoyMDXInspection: Codable, Sendable {
    public let title: String
    public let game: String
    public let system: String
    public let artist: String
    public let comment: String
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let fadeLengthMs: Int
    public let trackCount: Int

    public init(path: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = path.withCString({
            mdx_player_create($0, 44_100, &error)
        }) else {
            throw VGMBoyMDXInspectionError.open(Self.takeError(&error))
        }
        defer { mdx_player_destroy(handle) }

        var metadata = mdx_metadata_t()
        guard mdx_player_read_metadata(handle, &metadata, &error) == 0 else {
            throw VGMBoyMDXInspectionError.metadata(Self.takeError(&error))
        }
        defer { mdx_metadata_clear(&metadata) }

        let lengthMs = max(0, Int(metadata.play_length_ms))
        title = Self.decodeTitle(metadata.title)
        game = ""
        system = Self.string(metadata.system)
        artist = ""
        comment = ""
        introLengthMs = lengthMs
        loopLengthMs = 0
        playLengthMs = lengthMs
        fadeLengthMs = 0
        trackCount = 1
    }

    private static func string(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        pointer.map { String(cString: $0) } ?? ""
    }

    private static func decodeTitle(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else { return "" }
        let length = strlen(pointer)
        let data = Data(bytes: pointer, count: length)
        return String(data: data, encoding: .shiftJIS)
            ?? String(decoding: data, as: UTF8.self)
    }

    private static func takeError(_ error: inout UnsafeMutablePointer<CChar>?) -> String {
        let message = error.map { String(cString: $0) } ?? "Unknown error."
        if let pointer = error {
            mdx_error_message_free(pointer)
            error = nil
        }
        return message
    }
}

public enum VGMBoyMDXInspectionError: LocalizedError {
    case open(String)
    case metadata(String)

    public var errorDescription: String? {
        switch self {
        case .open(let message):
            "mdxmini could not open the MDX file. \(message)"
        case .metadata(let message):
            "mdxmini could not read MDX metadata. \(message)"
        }
    }
}
