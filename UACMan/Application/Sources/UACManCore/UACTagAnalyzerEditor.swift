import Darwin
import Foundation
import UACWrapperCore

public enum UACTagAnalyzerEditorError: Error, LocalizedError {
    case unsupportedScope(String)
    case missingMemberPath
    case missingTagName
    case extensionNamespaceRequired
    case archiveChanged(String)
    case fieldChanged(String)
    case duplicateField(String)
    case invalidManifest
    case rewriteFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedScope(let scope): "Unsupported tag storage scope: \(scope)"
        case .missingMemberPath: "The matched member path is missing."
        case .missingTagName: "A tag name cannot be empty."
        case .extensionNamespaceRequired: "Extension tag names must keep the extension. namespace."
        case .archiveChanged(let path): "The archive changed after analysis: \(path)"
        case .fieldChanged(let name): "The tag field changed after analysis: \(name)"
        case .duplicateField(let name): "The archive already contains the tag field: \(name)"
        case .invalidManifest: "The archive manifest does not contain the matched tag field."
        case .rewriteFailed(let message): "Could not rewrite the tag field: \(message)"
        }
    }
}

/// Rewrites one matched field in a single UAC manifest while preserving its
/// compressed TAR/Zstandard payload byte-for-byte.
public enum UACTagAnalyzerEditor {
    public static func rewrite(
        match: UACTagFieldMatch,
        expectedValueJSON: String,
        newName: String,
        newValue: UACJSONValue?,
        compressManifestFrame: @escaping UACManifestFrameEncoder,
        decompressManifestFrame: @escaping UACManifestFrameDecoder
    ) throws {
        let archiveURL = match.archiveURL.standardizedFileURL
        let original = try UACContainerReader.read(
            from: archiveURL,
            decompressManifestFrame: decompressManifestFrame
        )
        let sourceStamp = try SourceStamp(url: archiveURL, manifestSHA256: original.manifestSHA256)
        guard let expectedData = expectedValueJSON.data(using: .utf8) else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }
        let expectedValue = try JSONDecoder().decode(UACJSONValue.self, from: expectedData)
        guard var manifest = try JSONSerialization.jsonObject(with: original.manifestJSON) as? [String: Any] else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }

        let fieldsKey: String
        switch match.storageScope {
        case "packageMetadata", "packageExtensions":
            guard var game = manifest["game"] as? [String: Any] else {
                throw UACTagAnalyzerEditorError.invalidManifest
            }
            fieldsKey = match.storageScope == "packageMetadata" ? "metadata" : "extensions"
            try editField(
                in: &game,
                fieldsKey: fieldsKey,
                match: match,
                expectedValue: expectedValue,
                newName: newName,
                newValue: newValue
            )
            manifest["game"] = game
        case "memberMetadata", "memberExtensions":
            guard let memberPath = match.memberRelativePath,
                  var members = manifest["members"] as? [[String: Any]],
                  let index = members.firstIndex(where: { $0["path"] as? String == memberPath }) else {
                throw UACTagAnalyzerEditorError.missingMemberPath
            }
            var member = members[index]
            fieldsKey = match.storageScope == "memberMetadata" ? "metadata" : "extensions"
            try editField(
                in: &member,
                fieldsKey: fieldsKey,
                match: match,
                expectedValue: expectedValue,
                newName: newName,
                newValue: newValue
            )
            members[index] = member
            manifest["members"] = members
        default:
            throw UACTagAnalyzerEditorError.unsupportedScope(match.storageScope)
        }

        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys, .withoutEscapingSlashes])
        let temporaryURL = archiveURL.deletingLastPathComponent()
            .appendingPathComponent(".\(archiveURL.lastPathComponent).uacman-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let rewritten = try UACContainerWriter.rewriteManifest(
            manifestJSON: manifestData,
            in: archiveURL,
            to: temporaryURL,
            compressManifestFrame: compressManifestFrame,
            decompressManifestFrame: decompressManifestFrame
        )
        guard rewritten.manifestJSON == manifestData else {
            throw UACTagAnalyzerEditorError.rewriteFailed("the staged manifest did not match the requested edit")
        }
        let current = try UACContainerReader.read(from: archiveURL, decompressManifestFrame: decompressManifestFrame)
        guard try SourceStamp(url: archiveURL, manifestSHA256: current.manifestSHA256) == sourceStamp else {
            throw UACTagAnalyzerEditorError.archiveChanged(match.archiveRelativePath)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: archiveURL.path)
        if let permissions = attributes[.posixPermissions] as? NSNumber {
            try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: temporaryURL.path)
        }
        guard Darwin.rename(temporaryURL.path, archiveURL.path) == 0 else {
            throw UACTagAnalyzerEditorError.rewriteFailed(String(cString: strerror(errno)))
        }
    }

    private static func editField(
        in parent: inout [String: Any],
        fieldsKey: String,
        match: UACTagFieldMatch,
        expectedValue: UACJSONValue,
        newName: String,
        newValue: UACJSONValue?
    ) throws {
        guard var fields = parent[fieldsKey] as? [String: Any],
              let currentRawValue = fields[match.storageKey] else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }
        let currentData = try JSONSerialization.data(withJSONObject: currentRawValue, options: [.fragmentsAllowed, .sortedKeys])
        let currentValue = try JSONDecoder().decode(UACJSONValue.self, from: currentData)
        guard currentValue == expectedValue else {
            throw UACTagAnalyzerEditorError.fieldChanged(match.storageKey)
        }

        let normalizedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { throw UACTagAnalyzerEditorError.missingTagName }
        let isExtension = match.storageScope.hasSuffix("Extensions")
        let newStorageKey: String
        if isExtension {
            guard normalizedName.hasPrefix("extension.") else {
                throw UACTagAnalyzerEditorError.extensionNamespaceRequired
            }
            newStorageKey = String(normalizedName.dropFirst("extension.".count))
            guard !newStorageKey.isEmpty else { throw UACTagAnalyzerEditorError.missingTagName }
        } else {
            newStorageKey = normalizedName
        }
        if newStorageKey != match.storageKey, fields[newStorageKey] != nil {
            throw UACTagAnalyzerEditorError.duplicateField(normalizedName)
        }

        fields.removeValue(forKey: match.storageKey)
        if let newValue {
            let encodedValue = try JSONEncoder().encode(newValue)
            fields[newStorageKey] = try JSONSerialization.jsonObject(with: encodedValue, options: [.fragmentsAllowed])
        }
        parent[fieldsKey] = fields
    }

    private struct SourceStamp: Equatable {
        let size: UInt64
        let modificationDate: Date?
        let systemFileNumber: UInt64?
        let manifestSHA256: String

        init(url: URL, manifestSHA256: String) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber else {
                throw UACTagAnalyzerEditorError.archiveChanged(url.lastPathComponent)
            }
            self.size = size.uint64Value
            self.modificationDate = attributes[.modificationDate] as? Date
            self.systemFileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
            self.manifestSHA256 = manifestSHA256
        }
    }
}
