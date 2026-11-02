import Foundation
import UACWrapperCore

public struct UACEmbeddedMemberSummary: Equatable, Sendable {
    public let containerURL: URL
    public let memberPath: String
    public let format: String?
    public let byteSize: UInt64
    public let gameTitle: String
    public let consoleName: String
    public let titleSnapMemberPath: String?

    public init(
        containerURL: URL,
        memberPath: String,
        format: String?,
        byteSize: UInt64,
        gameTitle: String,
        consoleName: String,
        titleSnapMemberPath: String?
    ) {
        self.containerURL = containerURL
        self.memberPath = memberPath
        self.format = format
        self.byteSize = byteSize
        self.gameTitle = gameTitle
        self.consoleName = consoleName
        self.titleSnapMemberPath = titleSnapMemberPath
    }
}

/// Embedded in-process reader for seekable UAC archives (playable members + Title Snap PNGs).
public enum UACEmbeddedArchiveReader {
    public static let defaultMaximumMemberBytes = 64 * 1024 * 1024
    public static let defaultMaximumArtworkBytes = 16 * 1024 * 1024

    public static func readContainer(at url: URL) throws -> UACContainer {
        try UACContainerReader.read(
            from: url,
            decompressManifestFrame: UACEmbeddedZstandardCodec.manifestFrameDecoder
        )
    }

    public static func readMemberData(
        containerURL: URL,
        memberPath: String,
        maximumByteCount: Int = defaultMaximumMemberBytes
    ) throws -> Data {
        let memberFile = try UACSeekableMemberFile(
            url: containerURL,
            memberPath: memberPath,
            maximumCachedFrames: 2,
            decompressManifestFrame: UACEmbeddedZstandardCodec.manifestFrameDecoder,
            decompressFrame: UACEmbeddedZstandardCodec.seekableFrameDecoder
        )
        guard memberFile.size <= UInt64(maximumByteCount) else {
            throw UACEmbeddedCodecError.exceedsMaximumMemory(Int(clamping: memberFile.size))
        }
        return try memberFile.read(at: 0, byteCount: Int(memberFile.size))
    }

    public static func readArtworkDataURL(
        containerURL: URL,
        memberPath: String = "art/title-snap.png"
    ) throws -> String {
        let normalizedPath: String
        if memberPath.hasPrefix("archive-member:") {
            normalizedPath = String(memberPath.dropFirst("archive-member:".count))
        } else {
            normalizedPath = memberPath
        }
        let data = try readMemberData(
            containerURL: containerURL,
            memberPath: normalizedPath,
            maximumByteCount: defaultMaximumArtworkBytes
        )
        let mimeType = Self.mimeType(forMemberPath: normalizedPath)
        return "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    private static func mimeType(forMemberPath path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        default:
            return "image/png"
        }
    }
}
