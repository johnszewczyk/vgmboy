import Foundation
import MetaManCore
import UACWrapperCore

public struct SPCMetadataProjection: Equatable, Sendable {
    /// Normalized values useful for search, display, and ordinary editing.
    /// Track-specific values remain attached to the member even when equal
    /// values are also promoted to the soundtrack/game record.
    public let memberFields: [String: UACJSONValue]
    public let sharedCandidates: [String: UACJSONValue]
}

public struct SPCSharedMetadataProjection: Equatable, Sendable {
    public let fields: [String: UACJSONValue]
    public let conflicts: [String]
}

public struct SPCMetadataHarvestItem: Equatable, Sendable {
    public let memberPath: String
    public let projection: SPCMetadataProjection

    public init(memberPath: String, projection: SPCMetadataProjection) {
        self.memberPath = memberPath
        self.projection = projection
    }
}

public struct SPCMetadataMergeResult: Equatable, Sendable {
    public let manifestJSON: Data
    public let importedMemberCount: Int
    public let sharedFieldsApplied: [String]
    public let conflicts: [String]
}

public enum SPCMetadataProjector {
    public static func project(_ document: MetadataDocument) -> SPCMetadataProjection {
        let member = MetaManMetadataProjector.memberFields(from: document)

        var shared: [String: UACJSONValue] = [:]
        if let game = document.fields.game { shared["sourceGameTitle"] = .string(game) }
        if let system = document.fields.system { shared["sourceSystem"] = .string(system) }
        for key in ["album", "date", "year", "genre", "copyright"] {
            if let value = member[key] { shared[key] = value }
        }
        return SPCMetadataProjection(memberFields: member, sharedCandidates: shared)
    }

    /// A value is shared only when every inspected track has it and all tracks
    /// agree. Partial or differing values stay track-level and are reported.
    public static func sharedFields(from projections: [SPCMetadataProjection]) -> SPCSharedMetadataProjection {
        guard !projections.isEmpty else {
            return SPCSharedMetadataProjection(fields: [:], conflicts: [])
        }
        let keys = Set(projections.flatMap { $0.sharedCandidates.keys }).sorted()
        var fields: [String: UACJSONValue] = [:]
        var conflicts: [String] = []
        for key in keys {
            let values = projections.compactMap { $0.sharedCandidates[key] }
            guard values.count == projections.count,
                  let first = values.first,
                  values.allSatisfy({ $0 == first }) else {
                conflicts.append(key)
                continue
            }
            fields[key] = first
        }
        return SPCSharedMetadataProjection(fields: fields, conflicts: conflicts)
    }

    /// Adds normalized and lossless reader data to member metadata, and adds
    /// only unanimously shared facts to game metadata. Existing values are
    /// preserved unless the caller explicitly requests replacement.
    public static func merge(
        items: [SPCMetadataHarvestItem],
        into manifestJSON: Data,
        overwriteExisting: Bool = false
    ) throws -> SPCMetadataMergeResult {
        guard !items.isEmpty else {
            return SPCMetadataMergeResult(
                manifestJSON: manifestJSON,
                importedMemberCount: 0,
                sharedFieldsApplied: [],
                conflicts: []
            )
        }
        guard var root = try JSONSerialization.jsonObject(with: manifestJSON) as? [String: Any],
              var members = root["members"] as? [[String: Any]],
              var game = root["game"] as? [String: Any] else {
            throw UACManifestEditorError.invalidManifestJSON
        }

        let itemByPath = Dictionary(items.map { ($0.memberPath, $0) }, uniquingKeysWith: { first, _ in first })
        var foundPaths = Set<String>()
        for index in members.indices {
            guard let path = members[index]["path"] as? String,
                  let item = itemByPath[path] else { continue }
            foundPaths.insert(path)
            var metadata = members[index]["metadata"] as? [String: Any] ?? [:]
            for (key, value) in item.projection.memberFields {
                if overwriteExisting || isMissing(metadata[key]) {
                    metadata[key] = try jsonObjectValue(value)
                }
            }
            members[index]["metadata"] = metadata
        }
        guard foundPaths == Set(itemByPath.keys) else {
            throw UACManifestEditorError.memberRecordMissing(
                Set(itemByPath.keys).subtracting(foundPaths).sorted().joined(separator: ", ")
            )
        }

        let shared = sharedFields(from: items.map(\.projection))
        var gameMetadata = game["metadata"] as? [String: Any] ?? [:]
        var applied: [String] = []
        for (key, value) in shared.fields {
            if overwriteExisting || isMissing(gameMetadata[key]) {
                gameMetadata[key] = try jsonObjectValue(value)
                applied.append(key)
            }
        }
        game["metadata"] = gameMetadata
        root["members"] = members
        root["game"] = game
        guard JSONSerialization.isValidJSONObject(root) else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        let encoded = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .withoutEscapingSlashes])
        _ = try UACManifestEditor.decode(encoded)
        return SPCMetadataMergeResult(
            manifestJSON: encoded,
            importedMemberCount: foundPaths.count,
            sharedFieldsApplied: applied.sorted(),
            conflicts: shared.conflicts
        )
    }

    private static func isMissing(_ value: Any?) -> Bool {
        guard let value else { return true }
        if value is NSNull { return true }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false
    }

    private static func jsonObjectValue(_ value: UACJSONValue) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}
