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

        switch match.storageScope {
        case "packageMetadata", "packageExtensions":
            guard var game = manifest["game"] as? [String: Any] else {
                throw UACTagAnalyzerEditorError.invalidManifest
            }
            let fieldsKey = match.storageScope == "packageMetadata" ? "metadata" : "extensions"
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
            let fieldsKey = match.storageScope == "memberMetadata" ? "metadata" : "extensions"
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
        case "playlistEntryExtraFields", "playlistEntryExtensions":
            try editPlaylistEntry(in: &manifest, match: match) { entry in
                let fieldsKey = match.storageScope == "playlistEntryExtraFields" ? "extraFields" : "extensions"
                try editField(
                    in: &entry,
                    fieldsKey: fieldsKey,
                    match: match,
                    expectedValue: expectedValue,
                    newName: newName,
                    newValue: newValue
                )
            }
        case "playlistEntryField":
            try editPlaylistEntry(in: &manifest, match: match) { entry in
                guard newName == match.storageKey else {
                    throw UACTagAnalyzerEditorError.unsupportedScope("renaming first-class playlist entry fields")
                }
                try editDirectField(
                    in: &entry,
                    key: match.storageKey,
                    expectedValue: expectedValue,
                    newValue: newValue
                )
            }
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

    /// Removes the requested track fields in one package with a single
    /// manifest rewrite while preserving the compressed payload byte-for-byte.
    public static func removeTrackFields(
        matches: [UACTagFieldMatch],
        compressManifestFrame: @escaping UACManifestFrameEncoder,
        decompressManifestFrame: @escaping UACManifestFrameDecoder
    ) throws {
        guard let first = matches.first else { return }
        let archiveURL = first.archiveURL.standardizedFileURL
        guard matches.allSatisfy({
            $0.isTrack
                && $0.archiveRelativePath == first.archiveRelativePath
                && $0.archiveURL.standardizedFileURL == archiveURL
                && $0.memberRelativePath != nil
                && ["memberMetadata", "memberExtensions", "playlistEntryExtraFields",
                    "playlistEntryExtensions", "playlistEntryField"].contains($0.storageScope)
        }) else {
            throw UACTagAnalyzerEditorError.unsupportedScope("bulk deletion requires track fields from one package")
        }

        let original = try UACContainerReader.read(
            from: archiveURL,
            decompressManifestFrame: decompressManifestFrame
        )
        let sourceStamp = try SourceStamp(url: archiveURL, manifestSHA256: original.manifestSHA256)
        guard var manifest = try JSONSerialization.jsonObject(with: original.manifestJSON) as? [String: Any],
              var members = manifest["members"] as? [[String: Any]] else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }

        var memberIndices: [String: Int] = [:]
        for (index, member) in members.enumerated() {
            if let path = member["path"] as? String { memberIndices[path] = index }
        }
        for match in matches {
            if ["memberMetadata", "memberExtensions"].contains(match.storageScope) {
                guard let memberPath = match.memberRelativePath,
                      let index = memberIndices[memberPath] else {
                    throw UACTagAnalyzerEditorError.missingMemberPath
                }
                var member = members[index]
                let fieldsKey = match.storageScope == "memberExtensions" ? "extensions" : "metadata"
                try removeField(in: &member, fieldsKey: fieldsKey, match: match)
                members[index] = member
            } else {
                try removePlaylistEntryField(in: &manifest, match: match)
            }
        }
        manifest["members"] = members

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
            throw UACTagAnalyzerEditorError.archiveChanged(first.archiveRelativePath)
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

    private static func editPlaylistEntry(
        in manifest: inout [String: Any],
        match: UACTagFieldMatch,
        edit: (inout [String: Any]) throws -> Void
    ) throws {
        guard let playlistID = match.playlistID,
              let entryIndex = match.playlistEntryIndex,
              var playlists = manifest["playlists"] as? [[String: Any]],
              let playlistIndex = playlists.firstIndex(where: { $0["id"] as? String == playlistID }),
              var entries = playlists[playlistIndex]["entries"] as? [[String: Any]],
              entries.indices.contains(entryIndex),
              entries[entryIndex]["targetMemberPath"] as? String == match.memberRelativePath else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }
        var entry = entries[entryIndex]
        try edit(&entry)
        entries[entryIndex] = entry
        playlists[playlistIndex]["entries"] = entries
        manifest["playlists"] = playlists
    }

    private static func editDirectField(
        in entry: inout [String: Any],
        key: String,
        expectedValue: UACJSONValue,
        newValue: UACJSONValue?
    ) throws {
        guard let currentRawValue = entry[key] else { throw UACTagAnalyzerEditorError.invalidManifest }
        let currentData = try JSONSerialization.data(withJSONObject: currentRawValue, options: [.fragmentsAllowed, .sortedKeys])
        let currentValue = try JSONDecoder().decode(UACJSONValue.self, from: currentData)
        guard currentValue == expectedValue else { throw UACTagAnalyzerEditorError.fieldChanged(key) }
        if let newValue {
            let encoded = try JSONEncoder().encode(newValue)
            entry[key] = try JSONSerialization.jsonObject(with: encoded, options: [.fragmentsAllowed])
        } else {
            entry.removeValue(forKey: key)
        }
    }

    private static func removeField(
        in parent: inout [String: Any],
        fieldsKey: String,
        match: UACTagFieldMatch
    ) throws {
        guard var fields = parent[fieldsKey] as? [String: Any],
              let currentRawValue = fields[match.storageKey],
              let expectedData = match.valueJSON.data(using: .utf8) else {
            throw UACTagAnalyzerEditorError.invalidManifest
        }
        let currentData = try JSONSerialization.data(withJSONObject: currentRawValue, options: [.fragmentsAllowed, .sortedKeys])
        let currentValue = try JSONDecoder().decode(UACJSONValue.self, from: currentData)
        let expectedValue = try JSONDecoder().decode(UACJSONValue.self, from: expectedData)
        guard currentValue == expectedValue else {
            throw UACTagAnalyzerEditorError.fieldChanged(match.storageKey)
        }
        fields.removeValue(forKey: match.storageKey)
        parent[fieldsKey] = fields
    }

    private static func removePlaylistEntryField(
        in manifest: inout [String: Any],
        match: UACTagFieldMatch
    ) throws {
        try editPlaylistEntry(in: &manifest, match: match) { entry in
            if match.storageScope == "playlistEntryField" {
                guard let expectedData = match.valueJSON.data(using: .utf8),
                      let currentRawValue = entry[match.storageKey] else {
                    throw UACTagAnalyzerEditorError.invalidManifest
                }
                let currentData = try JSONSerialization.data(withJSONObject: currentRawValue, options: [.fragmentsAllowed, .sortedKeys])
                let currentValue = try JSONDecoder().decode(UACJSONValue.self, from: currentData)
                let expectedValue = try JSONDecoder().decode(UACJSONValue.self, from: expectedData)
                guard currentValue == expectedValue else {
                    throw UACTagAnalyzerEditorError.fieldChanged(match.storageKey)
                }
                entry.removeValue(forKey: match.storageKey)
            } else {
                let fieldsKey = match.storageScope == "playlistEntryExtensions" ? "extensions" : "extraFields"
                try removeField(in: &entry, fieldsKey: fieldsKey, match: match)
            }
        }
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
