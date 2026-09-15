import Foundation

/// One tag exactly as it appears in the decoded tag block. Ordering and
/// duplicate names are retained; use `normalizedName` only for lookup.
public struct MetadataTag: Codable, Equatable, Sendable {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}

/// Common fields projected from format-specific tags. Raw tags remain
/// available on `MetadataDocument` so unknown and format-specific data is
/// never discarded by this convenience projection.
public struct MetadataFields: Codable, Equatable, Sendable {
    public let title: String?
    public let game: String?
    public let system: String?
    public let artist: String?
    public let album: String?
    public let date: String?
    public let year: String?
    public let genre: String?
    public let comment: String?
    public let copyright: String?
    public let encodedBy: String?

    public init(
        title: String? = nil,
        game: String? = nil,
        system: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        date: String? = nil,
        year: String? = nil,
        genre: String? = nil,
        comment: String? = nil,
        copyright: String? = nil,
        encodedBy: String? = nil
    ) {
        self.title = title
        self.game = game
        self.system = system
        self.artist = artist
        self.album = album
        self.date = date
        self.year = year
        self.genre = genre
        self.comment = comment
        self.copyright = copyright
        self.encodedBy = encodedBy
    }
}

/// Timings are read from file data or format metadata, not rendered through a
/// playback decoder.
public struct MetadataTiming: Codable, Equatable, Sendable {
    public let introLengthMs: Int
    public let loopLengthMs: Int
    public let playLengthMs: Int
    public let fadeLengthMs: Int

    public init(introLengthMs: Int, loopLengthMs: Int, playLengthMs: Int, fadeLengthMs: Int = 0) {
        self.introLengthMs = introLengthMs
        self.loopLengthMs = loopLengthMs
        self.playLengthMs = playLengthMs
        self.fadeLengthMs = fadeLengthMs
    }
}

/// Read-only result of inspecting one media file. `rawTagBlock` retains the
/// format-specific original tag bytes; its exact extent is defined by each
/// reader. `tags` provides a decoded, ordered view for applications and
/// editors.
public struct MetadataDocument: Codable, Equatable, Sendable {
    public let format: String
    public let fields: MetadataFields
    public let tags: [MetadataTag]
    public let rawTagBlock: Data?
    /// Original format-specific metadata blocks, keyed by block name when a
    /// format stores more than one independent block. Optional for backward-
    /// compatible decoding of documents written before this property existed.
    public let rawMetadataBlocks: [String: Data]?
    public let sourceEncoding: String?
    public let timing: MetadataTiming?
    public let technicalFacts: [String: String]
    public let diagnostics: [String]

    public init(
        format: String,
        fields: MetadataFields,
        tags: [MetadataTag] = [],
        rawTagBlock: Data? = nil,
        rawMetadataBlocks: [String: Data]? = nil,
        sourceEncoding: String? = nil,
        timing: MetadataTiming? = nil,
        technicalFacts: [String: String] = [:],
        diagnostics: [String] = []
    ) {
        self.format = format
        self.fields = fields
        self.tags = tags
        self.rawTagBlock = rawTagBlock
        self.rawMetadataBlocks = rawMetadataBlocks
        self.sourceEncoding = sourceEncoding
        self.timing = timing
        self.technicalFacts = technicalFacts
        self.diagnostics = diagnostics
    }

    /// Returns every value for a tag name, preserving original order.
    public func values(forTag name: String) -> [String] {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return tags.compactMap { $0.normalizedName == key ? $0.value : nil }
    }

    /// Returns the first non-empty value for a tag name after format-neutral
    /// trimming. Use `values(forTag:)` when exact decoded whitespace matters.
    public func value(forTag name: String) -> String? {
        values(forTag: name)
            .map(Self.trimASCIIWhitespace)
            .first(where: { !$0.isEmpty })
    }

    private static func trimASCIIWhitespace(_ value: String) -> String {
        let bytes = Array(value.utf8)
        var start = 0
        var end = bytes.count
        while start < end, bytes[start] <= 0x20 { start += 1 }
        while end > start, bytes[end - 1] <= 0x20 { end -= 1 }
        return String(decoding: bytes[start..<end], as: UTF8.self)
    }
}

public struct MetadataFormatDescriptor: Codable, Equatable, Sendable {
    public let identifier: String
    public let fileExtensions: [String]
    public let methodology: String

    public init(identifier: String, fileExtensions: [String], methodology: String) {
        self.identifier = identifier
        self.fileExtensions = fileExtensions
        self.methodology = methodology
    }
}

public enum MetadataReadError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case malformedFile(String)
    case trackAwareResultRequired(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format): "No MetaMan reader is registered for \(format)."
        case .malformedFile(let message): message
        case .trackAwareResultRequired(let format): "\(format) can contain multiple tracks; use MetaManCore.readResult instead."
        }
    }
}
