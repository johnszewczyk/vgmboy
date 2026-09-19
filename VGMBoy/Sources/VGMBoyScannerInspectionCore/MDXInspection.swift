import Foundation
import VGMBoyCMDX

public struct VGMBoyMDXInspection: Codable, Sendable {
    public let trackCount: Int

    public init(path: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard let handle = path.withCString({
            mdx_player_create($0, 44_100, &error)
        }) else {
            throw VGMBoyMDXInspectionError.open(Self.takeError(&error))
        }
        defer { mdx_player_destroy(handle) }
        trackCount = 1
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

    public var errorDescription: String? {
        switch self {
        case .open(let message):
            "mdxmini could not open the MDX file. \(message)"
        }
    }
}
