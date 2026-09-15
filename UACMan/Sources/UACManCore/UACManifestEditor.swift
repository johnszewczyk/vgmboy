import Foundation
import UACContainerCore

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
                metadata[fieldKey] = value
            case .fillMissing:
                let existing = metadata[fieldKey]
                let isEmptyString = (existing as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false
                if existing == nil || existing is NSNull || isEmptyString {
                    metadata[fieldKey] = value
                }
            case .replaceText:
                if let existing = metadata[fieldKey] as? String {
                    metadata[fieldKey] = existing.replacingOccurrences(of: searchText, with: value)
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
        return object
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
