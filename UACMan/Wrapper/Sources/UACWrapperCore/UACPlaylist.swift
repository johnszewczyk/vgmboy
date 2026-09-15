import Foundation

/// A UAC-native ordered playlist. The original playlist file, when present,
/// remains an ordinary member so its exact bytes can be restored on unpack.
public struct UACPlaylist: Codable, Equatable, Sendable {
    public let id: String
    public let title: String?
    public let variantID: String?
    public let originalMemberPath: String?
    public let entries: [UACPlaylistEntry]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        title: String? = nil,
        variantID: String? = nil,
        originalMemberPath: String? = nil,
        entries: [UACPlaylistEntry],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.title = title
        self.variantID = variantID
        self.originalMemberPath = originalMemberPath
        self.entries = entries
        self.metadata = metadata
        self.extensions = extensions
    }
}

/// One ordered pointer plus the parsed and raw playlist fields that apply to
/// it. Timing values remain raw text for now; this avoids imposing one
/// format's units or loop semantics on another format.
public struct UACPlaylistEntry: Codable, Equatable, Sendable {
    public let targetMemberPath: String
    public let targetMemberBlake3: String?
    public let entryKind: String
    public let rawLine: String?
    public let rawContext: String?
    public let formatTag: String?
    public let trackIndex: String?
    public let title: String?
    public let artist: String?
    public let lengthRaw: String?
    public let loopRaw: String?
    public let loopStartRaw: String?
    public let fadeRaw: String?
    public let repeatRaw: String?
    public let stopRaw: String?
    public let extraFields: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        targetMemberPath: String,
        targetMemberBlake3: String? = nil,
        entryKind: String = "file",
        rawLine: String? = nil,
        rawContext: String? = nil,
        formatTag: String? = nil,
        trackIndex: String? = nil,
        title: String? = nil,
        artist: String? = nil,
        lengthRaw: String? = nil,
        loopRaw: String? = nil,
        loopStartRaw: String? = nil,
        fadeRaw: String? = nil,
        repeatRaw: String? = nil,
        stopRaw: String? = nil,
        extraFields: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.targetMemberPath = targetMemberPath
        self.targetMemberBlake3 = targetMemberBlake3
        self.entryKind = entryKind
        self.rawLine = rawLine
        self.rawContext = rawContext
        self.formatTag = formatTag
        self.trackIndex = trackIndex
        self.title = title
        self.artist = artist
        self.lengthRaw = lengthRaw
        self.loopRaw = loopRaw
        self.loopStartRaw = loopStartRaw
        self.fadeRaw = fadeRaw
        self.repeatRaw = repeatRaw
        self.stopRaw = stopRaw
        self.extraFields = extraFields
        self.extensions = extensions
    }
}

/// An additional BLAKE3 observation with an explicit byte scope and method.
/// It supplements `UACMember.blake3` and the legacy `streamBlake3` shortcut.
public struct UACHashRecord: Codable, Equatable, Sendable {
    public let scope: String
    public let algorithm: String
    public let digest: String
    public let profile: String
    public let byteSize: UInt64?

    public init(
        scope: String,
        algorithm: String = "blake3-256",
        digest: String,
        profile: String,
        byteSize: UInt64? = nil
    ) {
        self.scope = scope
        self.algorithm = algorithm
        self.digest = digest
        self.profile = profile
        self.byteSize = byteSize
    }
}
