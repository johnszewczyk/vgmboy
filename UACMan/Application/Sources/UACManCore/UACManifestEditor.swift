import Foundation
import UACWrapperCore

public enum UACManifestEditorError: Error, Equatable, LocalizedError {
    case invalidManifestJSON
    case invalidMetadataJSON(String)
    case invalidFieldKey
    case emptySearchText
    case gameRecordMissing
    case memberRecordMissing(String)

    public var errorDescription: String? {
        switch self {
        case .invalidManifestJSON:
            return "The manifest is not a valid UAC JSON document."
        case .invalidMetadataJSON(let field):
            return "\(field) must be a JSON object."
        case .invalidFieldKey:
            return "A metadata field name is required."
        case .emptySearchText:
            return "Find-and-replace needs non-empty search text."
        case .gameRecordMissing:
            return "The manifest has no editable game record."
        case .memberRecordMissing(let path):
            return "The manifest has no member at \(path)."
        }
    }
}

public enum UACBatchFieldOperation: String, CaseIterable, Identifiable, Sendable {
    case set
    case fillMissing
    case replaceText
    case remove

    public var id: Self { self }

    public var title: String {
        switch self {
        case .set: "Set value"
        case .fillMissing: "Fill empty values only"
        case .replaceText: "Find and replace"
        case .remove: "Remove field"
        }
    }
}

public struct UACManifestEditResult: Equatable, Sendable {
    public let manifestJSON: Data
    public let affectedCount: Int

    public init(manifestJSON: Data, affectedCount: Int) {
        self.manifestJSON = manifestJSON
        self.affectedCount = affectedCount
    }
}

/// Edits known metadata maps in the original JSON document so future or
/// otherwise unmodeled keys survive a read/edit/write cycle.
public enum UACManifestEditor {
    public static func decode(_ manifestJSON: Data) throws -> UACManifest {
        let manifest: UACManifest
        do {
            manifest = try JSONDecoder().decode(UACManifest.self, from: manifestJSON)
        } catch {
            throw UACManifestEditorError.invalidManifestJSON
        }
        try UACContainerReader.validate(manifest)
        return manifest
    }

    public static func prettyJSON(_ fields: [String: UACJSONValue]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(UACJSONValue.object(fields))
        guard let string = String(data: data, encoding: .utf8) else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        return string
    }

    public static func updateGameFields(
        in manifestJSON: Data,
        title: String,
        console: String,
        metadataJSON: String,
        extensionsJSON: String
    ) throws -> Data {
        var root = try jsonObject(manifestJSON)
        guard var game = root["game"] as? [String: Any] else {
            throw UACManifestEditorError.gameRecordMissing
        }
        game["title"] = title
        game["console"] = console
        game["metadata"] = try metadataObject(metadataJSON, field: "Game metadata")
        game["extensions"] = try metadataObject(extensionsJSON, field: "Game extensions")
        root["game"] = game
        return try validatedJSON(root)
    }

    public static func updateMemberFields(
        in manifestJSON: Data,
        memberPath: String,
        metadataJSON: String,
        extensionsJSON: String
    ) throws -> Data {
        var root = try jsonObject(manifestJSON)
        guard var members = root["members"] as? [[String: Any]],
              let index = members.firstIndex(where: { $0["path"] as? String == memberPath }) else {
            throw UACManifestEditorError.memberRecordMissing(memberPath)
        }
        members[index]["metadata"] = try metadataObject(metadataJSON, field: "Member metadata")
        members[index]["extensions"] = try metadataObject(extensionsJSON, field: "Member extensions")
        root["members"] = members
        return try validatedJSON(root)
    }

    /// Renames one metadata or extension key everywhere it is present while
    /// preserving unknown manifest fields. Metadata and extension namespaces
    /// cannot be crossed by one rename.
    public static func renameMetadataKey(
        in manifestJSON: Data,
        from oldKey: String,
        to newKey: String
    ) throws -> UACManifestEditResult {
        let oldParts = try metadataNamespace(oldKey)
        let newParts = try metadataNamespace(newKey)
        guard oldParts.bucket == newParts.bucket else {
            throw UACManifestEditorError.invalidMetadataJSON(
                "Metadata and extension namespaces cannot be mixed in one rename."
            )
        }

        var root = try jsonObject(manifestJSON)
        var affectedCount = 0
        func rename(in fields: inout [String: Any]) throws {
            guard fields[oldParts.key] != nil else { return }
            guard oldParts.key == newParts.key || fields[newParts.key] == nil else {
                throw UACManifestEditorError.invalidMetadataJSON(
                    "The destination tag already exists: \(newKey)"
                )
            }
            fields[newParts.key] = fields.removeValue(forKey: oldParts.key)
            affectedCount += 1
        }

        if var game = root["game"] as? [String: Any],
           var fields = game[oldParts.bucket] as? [String: Any] {
            try rename(in: &fields)
            game[oldParts.bucket] = fields
            root["game"] = game
        }
        if var members = root["members"] as? [[String: Any]] {
            for index in members.indices {
                guard var fields = members[index][oldParts.bucket] as? [String: Any] else { continue }
                try rename(in: &fields)
                members[index][oldParts.bucket] = fields
            }
            root["members"] = members
        }
        guard affectedCount > 0 else {
            throw UACManifestEditorError.invalidMetadataJSON("Tag not found in this package: \(oldKey)")
        }
        return UACManifestEditResult(
            manifestJSON: try validatedJSON(root),
            affectedCount: affectedCount
        )
    }

    /// Adds one string metadata field to explicitly selected playable members.
    /// All targets and conflicts are validated before any mutation is returned.
    public static func addStringMetadataField(
        in manifestJSON: Data,
        memberPaths: Set<String>,
        key: String,
        value: String
    ) throws -> UACManifestEditResult {
        let fieldKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fieldKey.isEmpty else { throw UACManifestEditorError.invalidFieldKey }
        guard !memberPaths.isEmpty else { return UACManifestEditResult(manifestJSON: manifestJSON, affectedCount: 0) }

        var root = try jsonObject(manifestJSON)
        guard var members = root["members"] as? [[String: Any]] else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        var indicesByPath: [String: Int] = [:]
        for index in members.indices {
            guard let path = members[index]["path"] as? String,
                  indicesByPath.updateValue(index, forKey: path) == nil else {
                throw UACManifestEditorError.invalidManifestJSON
            }
        }
        let missingPaths = memberPaths.filter { indicesByPath[$0] == nil }.sorted()
        guard missingPaths.isEmpty else {
            throw UACManifestEditorError.memberRecordMissing(missingPaths.joined(separator: ", "))
        }
        let indices = memberPaths.compactMap { indicesByPath[$0] }
        guard indices.allSatisfy({
            let role = members[$0]["role"] as? String
            return role == "playable" || role == "track"
        }) else {
            throw UACManifestEditorError.invalidMetadataJSON(
                "New tags can only be applied to playable tracks."
            )
        }
        guard indices.allSatisfy({
            let fields = members[$0]["metadata"] as? [String: Any] ?? [:]
            return fields[fieldKey] == nil
        }) else {
            throw UACManifestEditorError.invalidMetadataJSON(
                "The tag already exists on one or more selected tracks: \(fieldKey)"
            )
        }
        for index in indices {
            var fields = members[index]["metadata"] as? [String: Any] ?? [:]
            fields[fieldKey] = value
            members[index]["metadata"] = fields
        }
        root["members"] = members
        return UACManifestEditResult(
            manifestJSON: try validatedJSON(root),
            affectedCount: indices.count
        )
    }

    /// Applies one field operation to only the requested member paths. Other
    /// member fields and unmodeled manifest JSON remain untouched.
    public static func applyBatchMetadataEdit(
        in manifestJSON: Data,
        memberPaths: Set<String>,
        key: String,
        operation: UACBatchFieldOperation,
        value: String = "",
        searchText: String = ""
    ) throws -> Data {
        let fieldKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fieldKey.isEmpty else { throw UACManifestEditorError.invalidFieldKey }
        if operation == .replaceText, searchText.isEmpty {
            throw UACManifestEditorError.emptySearchText
        }
        guard !memberPaths.isEmpty else { return manifestJSON }

        var root = try jsonObject(manifestJSON)
        guard var members = root["members"] as? [[String: Any]] else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        var foundPaths = Set<String>()
        for index in members.indices {
            guard let path = members[index]["path"] as? String,
                  memberPaths.contains(path) else { continue }
            foundPaths.insert(path)
            var metadata = members[index]["metadata"] as? [String: Any] ?? [:]
            switch operation {
            case .set:
                if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    metadata.removeValue(forKey: fieldKey)
                } else {
                    metadata[fieldKey] = value
                }
            case .fillMissing:
                let existing = metadata[fieldKey]
                let isEmptyString = (existing as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false
                if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   existing == nil || existing is NSNull || isEmptyString {
                    metadata[fieldKey] = value
                }
            case .replaceText:
                if let existing = metadata[fieldKey] as? String {
                    let replacement = existing.replacingOccurrences(of: searchText, with: value)
                    if replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        metadata.removeValue(forKey: fieldKey)
                    } else {
                        metadata[fieldKey] = replacement
                    }
                }
            case .remove:
                metadata.removeValue(forKey: fieldKey)
            }
            members[index]["metadata"] = metadata
        }
        guard foundPaths == memberPaths else {
            throw UACManifestEditorError.memberRecordMissing(memberPaths.subtracting(foundPaths).sorted().joined(separator: ", "))
        }
        root["members"] = members
        return try validatedJSON(root)
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        return object
    }

    private static func metadataObject(_ text: String, field: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data),
              let object = value as? [String: Any] else {
            throw UACManifestEditorError.invalidMetadataJSON(field)
        }
        guard field.localizedCaseInsensitiveContains("metadata") else { return object }
        return object.filter { _, value in
            if value is NSNull { return false }
            if let text = value as? String {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
    }

    private static func metadataNamespace(_ rawKey: String) throws -> (bucket: String, key: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw UACManifestEditorError.invalidFieldKey }
        if key.hasPrefix("extension.") {
            let storageKey = String(key.dropFirst("extension.".count))
            guard !storageKey.isEmpty else { throw UACManifestEditorError.invalidFieldKey }
            return ("extensions", storageKey)
        }
        return ("metadata", key)
    }

    private static func validatedJSON(_ object: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys, .withoutEscapingSlashes]
              ) else {
            throw UACManifestEditorError.invalidManifestJSON
        }
        _ = try decode(data)
        return data
    }
}
