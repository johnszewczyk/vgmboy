import Foundation

public struct UACManifest: Codable, Equatable, Sendable {
    public let manifestVersion: Int
    public let packageID: String
    public let payload: UACPayload
    public let game: UACGame
    public let variants: [UACVariant]
    public let members: [UACMember]
    public let playlists: [UACPlaylist]
    public let sources: [UACSource]
    public let transformations: [UACTransformation]
    public let extensions: [String: UACJSONValue]

    public init(
        manifestVersion: Int = 2,
        packageID: String,
        payload: UACPayload,
        game: UACGame,
        variants: [UACVariant],
        members: [UACMember],
        playlists: [UACPlaylist] = [],
        sources: [UACSource] = [],
        transformations: [UACTransformation] = [],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.manifestVersion = manifestVersion
        self.packageID = packageID
        self.payload = payload
        self.game = game
        self.variants = variants
        self.members = members
        self.playlists = playlists
        self.sources = sources
        self.transformations = transformations
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case manifestVersion, packageID, payload, game, variants, members
        case playlists, sources, transformations, extensions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        manifestVersion = try values.decode(Int.self, forKey: .manifestVersion)
        packageID = try values.decode(String.self, forKey: .packageID)
        payload = try values.decode(UACPayload.self, forKey: .payload)
        game = try values.decode(UACGame.self, forKey: .game)
        variants = try values.decode([UACVariant].self, forKey: .variants)
        members = try values.decode([UACMember].self, forKey: .members)
        playlists = try values.decodeIfPresent([UACPlaylist].self, forKey: .playlists) ?? []
        sources = try values.decodeIfPresent([UACSource].self, forKey: .sources) ?? []
        transformations = try values.decodeIfPresent([UACTransformation].self, forKey: .transformations) ?? []
        extensions = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .extensions) ?? [:]
    }
}

public struct UACTransformation: Codable, Equatable, Sendable {
    public let id: String
    public let operation: String
    public let inputs: [UACTransformationInput]
    public let outputs: [UACTransformationOutput]
    public let tool: String
    public let toolVersion: String
    public let appliedAt: String
    public let reason: String?
    public let details: [String: UACJSONValue]

    public init(
        id: String,
        operation: String,
        inputs: [UACTransformationInput],
        outputs: [UACTransformationOutput] = [],
        tool: String,
        toolVersion: String,
        appliedAt: String,
        reason: String? = nil,
        details: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.operation = operation
        self.inputs = inputs
        self.outputs = outputs
        self.tool = tool
        self.toolVersion = toolVersion
        self.appliedAt = appliedAt
        self.reason = reason
        self.details = details
    }
}

public struct UACTransformationInput: Codable, Equatable, Sendable {
    public let sourceID: String
    public let sourcePath: String
    public let blake3: String
    public let streamBlake3: String?

    public init(sourceID: String, sourcePath: String, blake3: String, streamBlake3: String? = nil) {
        self.sourceID = sourceID
        self.sourcePath = sourcePath
        self.blake3 = blake3
        self.streamBlake3 = streamBlake3
    }
}

public struct UACTransformationOutput: Codable, Equatable, Sendable {
    public let memberPath: String
    public let blake3: String

    public init(memberPath: String, blake3: String) {
        self.memberPath = memberPath
        self.blake3 = blake3
    }
}

public struct UACPayload: Codable, Equatable, Sendable {
    public let format: String
    public let compressionProfile: String
    public let encoderVersion: String
    public let blake3: String

    public init(
        format: String = "tar+zstd-seekable",
        compressionProfile: String = "uac-zstd-seekable-level-3-frame-4194304-v1",
        encoderVersion: String,
        blake3: String
    ) {
        self.format = format
        self.compressionProfile = compressionProfile
        self.encoderVersion = encoderVersion
        self.blake3 = blake3
    }
}

public struct UACGame: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let console: String
    public let canonicalIDs: [String]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        title: String,
        console: String,
        canonicalIDs: [String] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.title = title
        self.console = console
        self.canonicalIDs = canonicalIDs
        self.metadata = metadata
        self.extensions = extensions
    }
}

public struct UACVariant: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let kind: String
    public let canonicalReleaseIDs: [String]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        label: String,
        kind: String,
        canonicalReleaseIDs: [String] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.canonicalReleaseIDs = canonicalReleaseIDs
        self.metadata = metadata
        self.extensions = extensions
    }
}

public struct UACMember: Codable, Equatable, Sendable {
    public let path: String
    public let originalName: String
    public let variantID: String?
    public let sourceIDs: [String]
    public let role: String
    public let format: String?
    public let byteSize: UInt64
    /// Offset of this member's file data within the decompressed TAR stream.
    /// Required for the seekable payload profile; absent for legacy streams.
    public let tarDataOffset: UInt64?
    public let blake3: String
    public let streamBlake3: String?
    public let hashes: [UACHashRecord]
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        path: String,
        originalName: String,
        variantID: String? = nil,
        sourceIDs: [String] = [],
        role: String,
        format: String? = nil,
        byteSize: UInt64,
        tarDataOffset: UInt64? = nil,
        blake3: String,
        streamBlake3: String? = nil,
        hashes: [UACHashRecord] = [],
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.path = path
        self.originalName = originalName
        self.variantID = variantID
        self.sourceIDs = sourceIDs
        self.role = role
        self.format = format
        self.byteSize = byteSize
        self.tarDataOffset = tarDataOffset
        self.blake3 = blake3
        self.streamBlake3 = streamBlake3
        self.hashes = hashes
        self.metadata = metadata
        self.extensions = extensions
    }

    private enum CodingKeys: String, CodingKey {
        case path, originalName, variantID, sourceIDs, role, format, byteSize
        case tarDataOffset, blake3, streamBlake3, hashes, metadata, extensions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        path = try values.decode(String.self, forKey: .path)
        originalName = try values.decode(String.self, forKey: .originalName)
        variantID = try values.decodeIfPresent(String.self, forKey: .variantID)
        sourceIDs = try values.decodeIfPresent([String].self, forKey: .sourceIDs) ?? []
        role = try values.decode(String.self, forKey: .role)
        format = try values.decodeIfPresent(String.self, forKey: .format)
        byteSize = try values.decode(UInt64.self, forKey: .byteSize)
        tarDataOffset = try values.decodeIfPresent(UInt64.self, forKey: .tarDataOffset)
        blake3 = try values.decode(String.self, forKey: .blake3)
        streamBlake3 = try values.decodeIfPresent(String.self, forKey: .streamBlake3)
        hashes = try values.decodeIfPresent([UACHashRecord].self, forKey: .hashes) ?? []
        metadata = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .metadata) ?? [:]
        extensions = try values.decodeIfPresent([String: UACJSONValue].self, forKey: .extensions) ?? [:]
    }
}

public struct UACSource: Codable, Equatable, Sendable {
    public let id: String
    public let collection: String
    public let setName: String
    public let sourceName: String
    public let sourceURL: String?
    public let packageBlake3: String?
    public let observedAt: String
    public let metadata: [String: UACJSONValue]
    public let extensions: [String: UACJSONValue]

    public init(
        id: String,
        collection: String,
        setName: String,
        sourceName: String,
        sourceURL: String? = nil,
        packageBlake3: String? = nil,
        observedAt: String,
        metadata: [String: UACJSONValue] = [:],
        extensions: [String: UACJSONValue] = [:]
    ) {
        self.id = id
        self.collection = collection
        self.setName = setName
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.packageBlake3 = packageBlake3
        self.observedAt = observedAt
        self.metadata = metadata
        self.extensions = extensions
    }
}

public indirect enum UACJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([UACJSONValue])
    case object([String: UACJSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int64.self) { self = .integer(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([UACJSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: UACJSONValue].self) { self = .object(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }
}
