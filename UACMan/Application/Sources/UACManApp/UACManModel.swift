import AppKit
import Darwin
import Foundation
import Observation
import UniformTypeIdentifiers
import UACWrapperCore
import UACManCore

struct UACMemberRow: Identifiable {
    let path: String
    let name: String
    let variantID: String?
    let variantLabel: String?
    let role: String
    let format: String?
    let bytes: UInt64
    let rawHash: String
    let streamHash: String?
    let hashes: [UACHashRecord]
    let metadata: [String: UACJSONValue]
    let extensions: [String: UACJSONValue]
    let title: String?
    let artist: String?
    let album: String?
    let year: String?
    let genre: String?
    let playLengthMs: Int64?

    var id: String { path }
    var displayTitle: String { title ?? name }
    var titleSortValue: String { displayTitle.localizedLowercase }
    var artistSortValue: String { artist?.localizedLowercase ?? "" }
    var albumSortValue: String { album?.localizedLowercase ?? "" }
    var yearSortValue: String { year ?? "" }
    var genreSortValue: String { genre?.localizedLowercase ?? "" }
    var playLengthSortValue: Int64 { playLengthMs ?? -1 }
    var roleSortValue: String { role.localizedLowercase }
    var formatSortValue: String { format?.localizedLowercase ?? "" }

    var durationText: String {
        guard let playLengthMs, playLengthMs > 0 else { return "—" }
        let totalSeconds = playLengthMs / 1_000
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3_600
        return hours > 0
            ? "\(hours):\(String(format: "%02lld", minutes)):\(String(format: "%02lld", seconds))"
            : "\(totalSeconds / 60):\(String(format: "%02lld", seconds))"
    }

    init(member: UACMember, variantLabel: String?) {
        self.init(
            path: member.path,
            name: member.originalName,
            variantID: member.variantID,
            variantLabel: variantLabel,
            role: member.role,
            format: member.format ?? URL(fileURLWithPath: member.path).pathExtension,
            bytes: member.byteSize,
            rawHash: member.blake3,
            streamHash: member.streamBlake3,
            hashes: member.hashes,
            metadata: member.metadata,
            extensions: member.extensions
        )
    }

    func updatingMetadata(
        _ metadata: [String: UACJSONValue],
        extensions: [String: UACJSONValue]? = nil
    ) -> UACMemberRow {
        UACMemberRow(
            path: path,
            name: name,
            variantID: variantID,
            variantLabel: variantLabel,
            role: role,
            format: format,
            bytes: bytes,
            rawHash: rawHash,
            streamHash: streamHash,
            hashes: hashes,
            metadata: metadata,
            extensions: extensions ?? self.extensions
        )
    }

    func updatingName(_ name: String) -> UACMemberRow {
        UACMemberRow(
            path: path,
            name: name,
            variantID: variantID,
            variantLabel: variantLabel,
            role: role,
            format: format,
            bytes: bytes,
            rawHash: rawHash,
            streamHash: streamHash,
            hashes: hashes,
            metadata: metadata,
            extensions: extensions
        )
    }

    private init(
        path: String,
        name: String,
        variantID: String?,
        variantLabel: String?,
        role: String,
        format: String?,
        bytes: UInt64,
        rawHash: String,
        streamHash: String?,
        hashes: [UACHashRecord],
        metadata: [String: UACJSONValue],
        extensions: [String: UACJSONValue]
    ) {
        self.path = path
        self.name = name
        self.variantID = variantID
        self.variantLabel = variantLabel
        self.role = role
        self.format = format
        self.bytes = bytes
        self.rawHash = rawHash
        self.streamHash = streamHash
        self.hashes = hashes
        self.metadata = metadata
        self.extensions = extensions
        title = Self.text(metadata["title"])
        artist = Self.text(metadata["artist"])
        album = Self.text(metadata["album"])
        let date = Self.text(metadata["date"])
        year = Self.text(metadata["year"]) ?? date.map { String($0.prefix(4)) }
        genre = Self.text(metadata["genre"])
        playLengthMs = Self.integer(metadata["playLengthMs"])
            ?? Self.integer(metadata["durationMs"])
    }

    private static func text(_ value: UACJSONValue?) -> String? {
        guard let value else { return nil }
        let text: String
        switch value {
        case .string(let value): text = value
        case .integer(let value): text = String(value)
        case .number(let value): text = String(value)
        case .bool(let value): text = value ? "true" : "false"
        case .null, .array, .object: return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func integer(_ value: UACJSONValue?) -> Int64? {
        switch value {
        case .integer(let value): return value
        case .number(let value)
            where value.isFinite && value >= Double(Int64.min) && value < Double(Int64.max):
            return Int64(value)
        case .string(let value): return Int64(value)
        default: return nil
        }
    }
}

@MainActor
@Observable
final class UACManModel {
    private enum PreferenceKey {
        static let lastDocumentPath = "UACMan.lastDocumentPath"
        static let lastCollectionPath = "UACMan.lastCollectionPath"
    }

    var documentURL: URL?
    var packageID = ""
    var packageTitle = ""
    var consoleName = ""
    var gameMetadataJSON = "{}"
    var gameExtensionsJSON = "{}"
    var memberMetadataJSON = "{}"
    var memberExtensionsJSON = "{}"
    var filePreviewPath: String?
    var filePreviewName = ""
    var filePreviewContent = ""
    var filePreviewTruncated = false
    var filePreviewError: String?
    var selectedMemberPath: String?
    var members: [UACMemberRow] = []
    var collectionRootURL: URL?
    var collectionEntries: [UACCollectionEntry] = []
    var collectionIssues: [UACCollectionIssue] = []
    var selectedCollectionPackagePath: String?
    var isScanningCollection = false
    var collectionStatusMessage = "Choose a folder to browse its UAC packages."
    var hasUnsavedChanges = false
    var isHarvestingMetadata = false
    var harvestProgressMessage = ""
    var statusMessage = "Open a .uac package to inspect its metadata."
    var errorMessage: String?

    @ObservationIgnored private let codec = ZstandardCLIManifestCodec()
    @ObservationIgnored private var loadedContainer: UACContainer?
    @ObservationIgnored private var originalManifestJSON = Data()
    @ObservationIgnored private var draftManifestJSON = Data()
    @ObservationIgnored private var openedSnapshot: OpenedFileSnapshot?
    @ObservationIgnored private var handledCommandLineFile = false
    @ObservationIgnored private var harvestTask: Task<Void, Never>?
    @ObservationIgnored private var collectionScanTask: Task<Void, Never>?
    @ObservationIgnored private var collectionScanID: UUID?

    var selectedMember: UACMember? {
        guard let selectedMemberPath else { return nil }
        return loadedContainer?.manifest.members.first { $0.path == selectedMemberPath }
    }

    var manifestEncodingDescription: String {
        guard let loadedContainer else { return "" }
        let encoding = loadedContainer.manifestEncoding == .zstandardJSON ? "Zstandard JSON" : "JSON"
        return "\(encoding) · \(ByteCountFormatter.string(fromByteCount: Int64(loadedContainer.storedManifestByteCount), countStyle: .file)) stored / \(ByteCountFormatter.string(fromByteCount: Int64(loadedContainer.manifestByteCount), countStyle: .file)) decoded"
    }

    var allMemberCount: Int { loadedContainer?.manifest.members.count ?? 0 }

    private static let textPreviewExtensions: Set<String> = [
        "cfg", "conf", "cue", "csv", "css", "h", "html", "ini", "js", "json",
        "log", "m3u", "m3u8", "markdown", "md", "nfo", "plist", "rs", "sh", "swift",
        "toml", "ts", "txt", "xml", "yaml", "yml"
    ]

    private static func isTextPreviewable(_ member: UACMemberRow) -> Bool {
        let format = member.format?.lowercased() ?? ""
        if format.hasPrefix("text/") || [
            "application/json", "application/javascript", "application/xml",
            "application/x-cue", "application/x-mpegurl", "text/x-cue"
        ].contains(format) {
            return true
        }
        let extensionName = URL(fileURLWithPath: member.name).pathExtension.lowercased()
        return textPreviewExtensions.contains(extensionName)
    }

    private static func webMemberSnapshot(_ member: UACMemberRow) -> [String: Any] {
        [
            "path": member.path,
            "name": member.name,
            "variantID": member.variantID ?? "",
            "variantLabel": member.variantLabel ?? "",
            "role": member.role,
            "format": member.format ?? "",
            "bytes": member.bytes,
            "rawHash": member.rawHash,
            "streamHash": member.streamHash ?? NSNull(),
            "hashes": member.hashes.map { hash in
                [
                    "scope": hash.scope,
                    "profile": hash.profile,
                    "digest": hash.digest,
                    "byteSize": hash.byteSize ?? NSNull()
                ] as [String: Any]
            },
            "title": member.title ?? "",
            "artist": member.artist ?? "",
            "album": member.album ?? "",
            "year": member.year ?? "",
            "genre": member.genre ?? "",
            "metadata": member.metadata.mapValues(Self.foundationValue),
            "extensions": member.extensions.mapValues(Self.foundationValue),
            "duration": member.durationText,
            "playLengthMs": member.playLengthMs ?? NSNull(),
            "previewable": Self.isTextPreviewable(member)
        ]
    }

    var webSnapshot: [String: Any] {
        [
            "documentName": documentURL?.lastPathComponent ?? "",
            "documentPath": documentURL?.path ?? "",
            "packageID": packageID,
            "packageTitle": packageTitle,
            "consoleName": consoleName,
            "gameMetadataJSON": gameMetadataJSON,
            "gameExtensionsJSON": gameExtensionsJSON,
            "memberMetadataJSON": memberMetadataJSON,
            "memberExtensionsJSON": memberExtensionsJSON,
            "memberHashes": selectedMember?.hashes.map { hash in
                [
                    "scope": hash.scope,
                    "profile": hash.profile,
                    "digest": hash.digest,
                    "byteSize": hash.byteSize ?? NSNull()
                ] as [String: Any]
            } ?? [],
            "selectedMemberPath": selectedMemberPath ?? NSNull(),
            "filePreviewPath": filePreviewPath ?? NSNull(),
            "filePreviewName": filePreviewName,
            "filePreviewContent": filePreviewContent,
            "filePreviewTruncated": filePreviewTruncated,
            "filePreviewError": filePreviewError ?? NSNull(),
            "variantCount": loadedContainer?.manifest.variants.count ?? 0,
            "members": members.map(Self.webMemberSnapshot),
            "collectionRoot": collectionRootURL?.path ?? "",
            "collectionStatus": collectionStatusMessage,
            "collectionEntries": collectionEntries.map { entry in
                [
                    "relativePath": entry.relativePath,
                    "packageID": entry.packageID,
                    "title": entry.title,
                    "console": entry.console,
                    "totalMemberCount": entry.totalMemberCount,
                    "playableMemberCount": entry.playableMemberCount,
                    "fileByteCount": entry.fileByteCount
                ] as [String: Any]
            },
            "collectionIssues": collectionIssues.map { ["relativePath": $0.relativePath, "message": $0.message] },
            "selectedCollectionPackagePath": selectedCollectionPackagePath ?? NSNull(),
            "isScanningCollection": isScanningCollection,
            "allMemberCount": allMemberCount,
            "manifestEncodingDescription": manifestEncodingDescription,
            "hasUnsavedChanges": hasUnsavedChanges,
            "isHarvestingMetadata": isHarvestingMetadata,
            "harvestProgressMessage": harvestProgressMessage,
            "canHarvestSPCMetadata": canHarvestSPCMetadata,
            "statusMessage": statusMessage,
            "errorMessage": errorMessage ?? NSNull()
        ]
    }

    private static func foundationValue(_ value: UACJSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .bool(let value): return value
        case .integer(let value): return value
        case .number(let value): return value
        case .string(let value): return value
        case .array(let values): return values.map(foundationValue)
        case .object(let values): return values.mapValues(foundationValue)
        }
    }

    var canHarvestSPCMetadata: Bool {
        loadedContainer?.manifest.payload.format == "tar+zstd-seekable"
            && loadedContainer?.seekTable != nil
            && !spcMemberPaths.isEmpty
    }

    private var spcMemberPaths: [String] {
        loadedContainer?.manifest.members.compactMap { member in
            let format = member.format?.lowercased()
                ?? URL(fileURLWithPath: member.originalName).pathExtension.lowercased()
            return format == "spc" ? member.path : nil
        } ?? []
    }

    func openCommandLineFileIfPresent() {
        guard !handledCommandLineFile else { return }
        handledCommandLineFile = true
        if let argument = ProcessInfo.processInfo.arguments.dropFirst().first,
           !argument.hasPrefix("-") {
            openDocument(URL(fileURLWithPath: argument))
            return
        }

        let defaults = UserDefaults.standard
        if let path = defaults.string(forKey: PreferenceKey.lastDocumentPath),
           FileManager.default.fileExists(atPath: path) {
            openDocument(URL(fileURLWithPath: path))
            return
        }
        if let path = defaults.string(forKey: PreferenceKey.lastCollectionPath),
           FileManager.default.fileExists(atPath: path) {
            openCollection(URL(fileURLWithPath: path))
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "uac") ?? .data]
        panel.allowsOtherFileTypes = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open UAC"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openDocument(url)
    }

    func openCollectionPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsOtherFileTypes = false
        panel.prompt = "Browse Collection"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openCollection(url)
    }

    func openCollection(_ url: URL) {
        let root = url.standardizedFileURL
        UserDefaults.standard.set(root.path, forKey: PreferenceKey.lastCollectionPath)
        collectionScanTask?.cancel()
        let scanID = UUID()
        collectionScanID = scanID
        collectionRootURL = root
        collectionEntries = []
        collectionIssues = []
        selectedCollectionPackagePath = nil
        isScanningCollection = true
        collectionStatusMessage = "Reading UAC manifests…"
        errorMessage = nil

        let manifestDecoder = codec.decoder
        collectionScanTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try UACCollectionScanner.scan(root: root) { packageURL in
                    try UACContainerReader.read(
                        from: packageURL,
                        decompressManifestFrame: manifestDecoder
                    ).manifest
                }
                await self?.finishCollectionScan(result, scanID: scanID, root: root)
            } catch is CancellationError {
                await self?.cancelCollectionScan(scanID: scanID)
            } catch {
                await self?.failCollectionScan(error, scanID: scanID, root: root)
            }
        }
    }

    func cancelCurrentCollectionScan() {
        collectionScanTask?.cancel()
    }

    func selectCollectionPackage(_ relativePath: String) {
        guard let collectionRootURL,
              collectionEntries.contains(where: { $0.relativePath == relativePath }) else { return }
        guard relativePath != selectedCollectionPackagePath else { return }
        guard confirmDiscardIfNeeded() else { return }

        let previousSelection = selectedCollectionPackagePath
        let packageURL = collectionRootURL.appendingPathComponent(relativePath).standardizedFileURL
        selectedCollectionPackagePath = relativePath
        loadDocumentWithoutPrompt(packageURL)
        if documentURL != packageURL {
            selectedCollectionPackagePath = previousSelection
        }
    }

    func openDocument(_ url: URL) {
        guard confirmDiscardIfNeeded() else { return }
        let standardizedURL = url.standardizedFileURL
        let collectionRelativePath = collectionEntries.first {
            collectionRootURL?.appendingPathComponent($0.relativePath).standardizedFileURL == standardizedURL
        }?.relativePath
        loadDocumentWithoutPrompt(standardizedURL)
        guard documentURL == standardizedURL else { return }
        if let collectionRelativePath {
            selectedCollectionPackagePath = collectionRelativePath
        } else {
            collectionScanTask?.cancel()
            collectionRootURL = nil
            collectionEntries = []
            collectionIssues = []
            selectedCollectionPackagePath = nil
        }
    }

    private func loadDocumentWithoutPrompt(_ url: URL) {
        harvestTask?.cancel()
        harvestTask = nil
        isHarvestingMetadata = false
        filePreviewPath = nil
        filePreviewName = ""
        filePreviewContent = ""
        filePreviewTruncated = false
        filePreviewError = nil
        do {
            let standardizedURL = url.standardizedFileURL
            guard standardizedURL.pathExtension.lowercased() == "uac" else {
                throw UACManError.notUACFile
            }
            try codec.ensureAvailable()
            let container = try UACContainerReader.read(
                from: standardizedURL,
                decompressManifestFrame: codec.decoder
            )
            documentURL = standardizedURL
            UserDefaults.standard.set(standardizedURL.path, forKey: PreferenceKey.lastDocumentPath)
            loadedContainer = container
            originalManifestJSON = container.manifestJSON
            draftManifestJSON = container.manifestJSON
            openedSnapshot = try OpenedFileSnapshot(url: standardizedURL, manifestSHA256: container.manifestSHA256)
            packageID = container.manifest.packageID
            packageTitle = container.manifest.game.title
            consoleName = container.manifest.game.console
            gameMetadataJSON = try UACManifestEditor.prettyJSON(container.manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(container.manifest.game.extensions)
            let variantLabels = Dictionary(uniqueKeysWithValues: container.manifest.variants.map { ($0.id, $0.label) })
            members = container.manifest.members.map { member in
                UACMemberRow(member: member, variantLabel: member.variantID.flatMap { variantLabels[$0] })
            }
            selectedMemberPath = members.first?.path
            if let first = members.first {
                try loadMemberEditor(path: first.path, from: container.manifest)
            } else {
                memberMetadataJSON = "{}"
                memberExtensionsJSON = "{}"
            }
            hasUnsavedChanges = false
            errorMessage = nil
            let playableCount = container.manifest.members.filter { $0.role == "playable" || $0.role == "track" }.count
            statusMessage = "Loaded \(members.count) package member(s), including \(playableCount) playable member(s)."
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func selectMember(_ path: String) {
        guard path != selectedMemberPath else { return }
        do {
            if let current = selectedMemberPath {
                draftManifestJSON = try UACManifestEditor.updateMemberFields(
                    in: draftManifestJSON,
                    memberPath: current,
                    metadataJSON: memberMetadataJSON,
                    extensionsJSON: memberExtensionsJSON
                )
            }
            let currentManifest = try UACManifestEditor.decode(draftManifestJSON)
            try loadMemberEditor(path: path, from: currentManifest)
            selectedMemberPath = path
            hasUnsavedChanges = hasUnsavedChanges || draftManifestJSON != originalManifestJSON
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func previewMember(path: String) {
        guard let documentURL,
              let member = members.first(where: { $0.path == path }) else { return }

        filePreviewPath = path
        filePreviewName = member.name
        filePreviewContent = ""
        filePreviewTruncated = false
        filePreviewError = nil

        guard Self.isTextPreviewable(member) else {
            filePreviewError = "This member is not a supported text document."
            return
        }

        do {
            try codec.ensureAvailable()
            let virtualFile = try UACSeekableMemberFile(
                url: documentURL,
                memberPath: path,
                maximumCachedFrames: 4,
                decompressManifestFrame: codec.decoder,
                decompressFrame: codec.seekableFrameDecoder
            )
            let previewLimit = 4 * 1024 * 1024
            let byteCount = min(virtualFile.size, UInt64(previewLimit) + 1)
            let data = try virtualFile.read(at: 0, byteCount: Int(byteCount))
            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .utf16) else {
                filePreviewError = "This member is not valid UTF-8 or UTF-16 text."
                return
            }
            filePreviewContent = text
            filePreviewTruncated = virtualFile.size > UInt64(previewLimit)
        } catch {
            filePreviewError = "Could not read this bundled file: \(error)"
        }
    }

    func closeFilePreview() {
        filePreviewPath = nil
        filePreviewName = ""
        filePreviewContent = ""
        filePreviewTruncated = false
        filePreviewError = nil
    }

    func markEdited() {
        hasUnsavedChanges = true
    }

    func markMemberEdited() {
        hasUnsavedChanges = true
        guard let selectedMemberPath,
              let index = members.firstIndex(where: { $0.path == selectedMemberPath }),
              let data = memberMetadataJSON.data(using: .utf8),
              let metadata = try? JSONDecoder().decode([String: UACJSONValue].self, from: data) else {
            return
        }
        members[index] = members[index].updatingMetadata(metadata)
    }

    func renameMetadataKey(from oldKey: String, to newKey: String) {
        let oldKey = oldKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldKey.isEmpty, !newKey.isEmpty, oldKey != newKey else { return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else {
                throw UACManifestEditorError.invalidManifestJSON
            }
            let oldParts = oldKey.hasPrefix("extension.") ? ("extensions", String(oldKey.dropFirst("extension.".count))) : ("metadata", oldKey)
            let newParts = newKey.hasPrefix("extension.") ? ("extensions", String(newKey.dropFirst("extension.".count))) : ("metadata", newKey)
            guard oldParts.0 == newParts.0 else {
                throw UACManifestEditorError.invalidMetadataJSON("Metadata and extension namespaces cannot be mixed in one rename.")
            }
            var renamed = 0
            func rename(in object: inout [String: Any]) throws {
                guard object[oldParts.1] != nil else { return }
                guard object[newParts.1] == nil else {
                    throw UACManifestEditorError.invalidMetadataJSON("The destination tag already exists: \(newKey)")
                }
                object[newParts.1] = object.removeValue(forKey: oldParts.1)
                renamed += 1
            }
            if var game = root["game"] as? [String: Any], var fields = game[oldParts.0] as? [String: Any] {
                try rename(in: &fields)
                game[oldParts.0] = fields
                root["game"] = game
            }
            if var members = root["members"] as? [[String: Any]] {
                for index in members.indices {
                    guard var fields = members[index][oldParts.0] as? [String: Any] else { continue }
                    try rename(in: &fields)
                    members[index][oldParts.0] = fields
                }
                root["members"] = members
            }
            guard renamed > 0 else {
                throw UACManifestEditorError.invalidMetadataJSON("Tag not found in this package: \(oldKey)")
            }
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            statusMessage = "Renamed \(oldKey) to \(newKey) in \(renamed) location(s). Save to commit the package change."
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func addMetadataKey(key rawKey: String, scope: String, value rawValue: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { errorMessage = "Enter a tag name."; return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let targetAllTracks = scope == "tracks"
            let jsonValue: Any = value.isEmpty ? "" : value
            func insert(_ fields: inout [String: Any]) throws {
                guard fields[key] == nil else { throw UACManifestEditorError.invalidMetadataJSON("The tag already exists: \(key)") }
                fields[key] = jsonValue
            }
            var changed = 0
            if !targetAllTracks, var game = root["game"] as? [String: Any] {
                var fields = game["metadata"] as? [String: Any] ?? [:]
                try insert(&fields); game["metadata"] = fields; root["game"] = game; changed = 1
            } else if targetAllTracks, var members = root["members"] as? [[String: Any]] {
                for index in members.indices {
                    var fields = members[index]["metadata"] as? [String: Any] ?? [:]
                    if fields[key] == nil { fields[key] = jsonValue; members[index]["metadata"] = fields; changed += 1 }
                }
                root["members"] = members
            }
            guard changed > 0 else { throw UACManifestEditorError.invalidMetadataJSON("No tracks are available for this tag.") }
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            statusMessage = "Added \(key) to \(targetAllTracks ? "all tracks" : "the package"). Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func deleteMetadataKey(key rawKey: String, scope: String = "") {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let parts = metadataNamespace(for: key)
            let targets = metadataScopeTargets(scope)
            var removed = 0
            func remove(_ fields: inout [String: Any]) { if fields.removeValue(forKey: parts.storageKey) != nil { removed += 1 } }
            if targets.game, var game = root["game"] as? [String: Any], var fields = game[parts.bucket] as? [String: Any] { remove(&fields); game[parts.bucket] = fields; root["game"] = game }
            if targets.members, var members = root["members"] as? [[String: Any]] { for index in members.indices { if var fields = members[index][parts.bucket] as? [String: Any] { remove(&fields); members[index][parts.bucket] = fields } }; root["members"] = members }
            guard removed > 0 else { throw UACManifestEditorError.invalidMetadataJSON("Tag not found in this package: \(key)") }
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            statusMessage = "Deleted \(key) from \(removed) location(s). Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func updateMetadataValue(key rawKey: String, scope: String = "", value rawValue: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let parts = metadataNamespace(for: key)
            let targets = metadataScopeTargets(scope)
            var changed = 0
            func update(_ fields: inout [String: Any]) { if fields[parts.storageKey] != nil { fields[parts.storageKey] = rawValue; changed += 1 } }
            if targets.game, var game = root["game"] as? [String: Any], var fields = game[parts.bucket] as? [String: Any] { update(&fields); game[parts.bucket] = fields; root["game"] = game }
            if targets.members, var members = root["members"] as? [[String: Any]] { for index in members.indices { if var fields = members[index][parts.bucket] as? [String: Any] { update(&fields); members[index][parts.bucket] = fields } }; root["members"] = members }
            guard changed > 0 else { throw UACManifestEditorError.invalidMetadataJSON("Tag not found in this package: \(key)") }
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON; statusMessage = "Updated \(key) in \(changed) location(s). Save to commit the package change."; errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func commitMetadataRow(key rawKey: String, newKey rawNewKey: String, scope: String = "", value: String?, structuredValueJSON: String? = nil) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines), newKey = rawNewKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !newKey.isEmpty else { errorMessage = "Tag name cannot be empty."; return }
        do {
            let structuredValue = try decodedStructuredValue(from: structuredValueJSON)
            try flushEditorBuffers(); guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let oldParts = metadataNamespace(for: key)
            let newParts = metadataNamespace(for: newKey)
            let targets = metadataScopeTargets(scope)
            guard oldParts.bucket == newParts.bucket else {
                throw UACManifestEditorError.invalidMetadataJSON("Metadata and extension namespaces cannot be mixed in one edit.")
            }
            var changed = 0
            if targets.game, var game = root["game"] as? [String: Any], var fields = game[oldParts.bucket] as? [String: Any], let old = fields[oldParts.storageKey] {
                if oldParts.storageKey != newParts.storageKey, fields[newParts.storageKey] != nil {
                    throw UACManifestEditorError.invalidMetadataJSON("The destination tag already exists: \(newKey)")
                }
                fields.removeValue(forKey: oldParts.storageKey)
                if let structuredValue { fields[newParts.storageKey] = structuredValue }
                else if let value { fields[newParts.storageKey] = value }
                else { fields[newParts.storageKey] = old }
                game[oldParts.bucket] = fields
                root["game"] = game
                changed += 1
            }
            if targets.members, var members = root["members"] as? [[String: Any]] {
                for index in members.indices where members[index][oldParts.bucket] is [String: Any] {
                    var fields = members[index][oldParts.bucket] as! [String: Any]
                    guard let old = fields[oldParts.storageKey] else { continue }
                    if oldParts.storageKey != newParts.storageKey, fields[newParts.storageKey] != nil {
                        throw UACManifestEditorError.invalidMetadataJSON("The destination tag already exists: \(newKey)")
                    }
                    fields.removeValue(forKey: oldParts.storageKey)
                    if let structuredValue { fields[newParts.storageKey] = structuredValue }
                    else if let value { fields[newParts.storageKey] = value }
                    else { fields[newParts.storageKey] = old }
                    changed += 1
                    members[index][oldParts.bucket] = fields
                }
                root["members"] = members
            }
            guard changed > 0 else { throw UACManifestEditorError.invalidMetadataJSON("Tag not found in this package: \(key)") }
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted]); let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON; statusMessage = "Updated \(key) in \(changed) location(s). Save to commit the package change."; errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func renameMember(path rawPath: String, name rawName: String) {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !name.isEmpty, !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
            errorMessage = "Enter a simple filename without path separators."
            return
        }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any], var members = root["members"] as? [[String: Any]], let index = members.firstIndex(where: { ($0["path"] as? String) == path }) else {
                throw UACManifestEditorError.memberRecordMissing(path)
            }
            members[index]["originalName"] = name
            root["members"] = members
            try acceptDraftManifest(root)
            if let rowIndex = self.members.firstIndex(where: { $0.path == path }) {
                self.members[rowIndex] = self.members[rowIndex].updatingName(name)
            }
            statusMessage = "Renamed the displayed filename. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func addMemberTag(path rawPath: String, scope: String, key rawKey: String, value rawValue: String) {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !key.isEmpty else { errorMessage = "Enter a tag name."; return }
        do {
            try flushEditorBuffers()
            let bucket = try memberMetadataBucket(scope)
            let storageKey = bucket == "extensions" && key.hasPrefix("extension.") ? String(key.dropFirst("extension.".count)) : key
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any], var members = root["members"] as? [[String: Any]], let index = members.firstIndex(where: { ($0["path"] as? String) == path }) else {
                throw UACManifestEditorError.memberRecordMissing(path)
            }
            var fields = members[index][bucket] as? [String: Any] ?? [:]
            guard fields[storageKey] == nil else { throw UACManifestEditorError.invalidMetadataJSON("The tag already exists: \(key)") }
            fields[storageKey] = rawValue
            members[index][bucket] = fields
            root["members"] = members
            try acceptDraftManifest(root)
            statusMessage = "Added \(key) to the selected file. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func commitMemberTag(path rawPath: String, scope: String, key rawKey: String, newKey rawNewKey: String, value: String, structuredValueJSON: String? = nil) {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let newKey = rawNewKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !key.isEmpty, !newKey.isEmpty else { errorMessage = "Tag name cannot be empty."; return }
        do {
            let structuredValue = try decodedStructuredValue(from: structuredValueJSON)
            try flushEditorBuffers()
            let bucket = try memberMetadataBucket(scope)
            let oldStorageKey = bucket == "extensions" && key.hasPrefix("extension.") ? String(key.dropFirst("extension.".count)) : key
            let newStorageKey = bucket == "extensions" && newKey.hasPrefix("extension.") ? String(newKey.dropFirst("extension.".count)) : newKey
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any], var members = root["members"] as? [[String: Any]], let index = members.firstIndex(where: { ($0["path"] as? String) == path }) else {
                throw UACManifestEditorError.memberRecordMissing(path)
            }
            var fields = members[index][bucket] as? [String: Any] ?? [:]
            guard let currentValue = fields[oldStorageKey] else { throw UACManifestEditorError.invalidMetadataJSON("Tag not found in the selected file: \(key)") }
            guard !(currentValue is [Any] || currentValue is [String: Any]) || structuredValue != nil else { throw UACManifestEditorError.invalidMetadataJSON("Structured tags require a Multiple Values editor: \(key)") }
            if oldStorageKey != newStorageKey, fields[newStorageKey] != nil { throw UACManifestEditorError.invalidMetadataJSON("The destination tag already exists: \(newKey)") }
            fields.removeValue(forKey: oldStorageKey)
            fields[newStorageKey] = structuredValue ?? value
            members[index][bucket] = fields
            root["members"] = members
            try acceptDraftManifest(root)
            statusMessage = "Updated \(key) on the selected file. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func deleteMemberTag(path rawPath: String, scope: String, key rawKey: String) {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty, !key.isEmpty else { return }
        do {
            try flushEditorBuffers()
            let bucket = try memberMetadataBucket(scope)
            let storageKey = bucket == "extensions" && key.hasPrefix("extension.") ? String(key.dropFirst("extension.".count)) : key
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any], var members = root["members"] as? [[String: Any]], let index = members.firstIndex(where: { ($0["path"] as? String) == path }) else {
                throw UACManifestEditorError.memberRecordMissing(path)
            }
            var fields = members[index][bucket] as? [String: Any] ?? [:]
            guard fields.removeValue(forKey: storageKey) != nil else { throw UACManifestEditorError.invalidMetadataJSON("Tag not found in the selected file: \(key)") }
            members[index][bucket] = fields
            root["members"] = members
            try acceptDraftManifest(root)
            statusMessage = "Deleted \(key) from the selected file. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    private func memberMetadataBucket(_ scope: String) throws -> String {
        switch scope {
        case "memberMetadata": return "metadata"
        case "memberExtensions": return "extensions"
        default: throw UACManifestEditorError.invalidMetadataJSON("Unknown member tag namespace: \(scope)")
        }
    }

    private func decodedStructuredValue(from raw: String?) throws -> Any? {
        guard let raw else { return nil }
        guard let data = raw.data(using: .utf8) else {
            throw UACManifestEditorError.invalidMetadataJSON("The structured value is not valid UTF-8 JSON.")
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw UACManifestEditorError.invalidMetadataJSON("The structured value is not valid JSON.")
        }
    }

    private func acceptDraftManifest(_ root: [String: Any]) throws {
        draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
        let manifest = try UACManifestEditor.decode(draftManifestJSON)
        gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
        gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
        refreshMemberSummaries(from: manifest)
        if let selectedMemberPath { try loadMemberEditor(path: selectedMemberPath, from: manifest) }
        hasUnsavedChanges = draftManifestJSON != originalManifestJSON
    }

    func commitTechnicalRow(scope: String, key: String, newKey: String, value: String) {
        guard !key.isEmpty, !newKey.isEmpty else { errorMessage = "Technical field names cannot be empty."; return }
        guard scope.hasPrefix("Package") else { errorMessage = "Only package technical fields can be edited."; return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            guard var game = root["game"] as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let bucket = scope.contains("Extension") ? "extensions" : "metadata"
            let oldStorageKey = key.hasPrefix("extension.") ? String(key.dropFirst("extension.".count)) : key
            let newStorageKey = newKey.hasPrefix("extension.") ? String(newKey.dropFirst("extension.".count)) : newKey
            guard var fields = game[bucket] as? [String: Any], let currentValue = fields[oldStorageKey] else {
                throw UACManifestEditorError.invalidMetadataJSON("Technical field cannot be edited: \(key)")
            }
            if currentValue is [Any] || currentValue is [String: Any] {
                throw UACManifestEditorError.invalidMetadataJSON("Technical field contains structured values and is read-only: \(key)")
            }
            if oldStorageKey != newStorageKey, fields[newStorageKey] != nil {
                throw UACManifestEditorError.invalidMetadataJSON("The destination tag already exists: \(newKey)")
            }
            fields.removeValue(forKey: oldStorageKey)
            fields[newStorageKey] = value
            game[bucket] = fields
            root["game"] = game
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            statusMessage = "Updated package technical field. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func deleteTechnicalRow(scope: String, key: String) {
        guard scope.hasPrefix("Package") else { errorMessage = "Only package technical fields can be deleted."; return }
        do {
            try flushEditorBuffers()
            guard var root = try JSONSerialization.jsonObject(with: draftManifestJSON) as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            guard var game = root["game"] as? [String: Any] else { throw UACManifestEditorError.invalidManifestJSON }
            let bucket = scope.contains("Extension") ? "extensions" : "metadata"
            let storageKey = key.hasPrefix("extension.") ? String(key.dropFirst("extension.".count)) : key
            guard var fields = game[bucket] as? [String: Any], fields.removeValue(forKey: storageKey) != nil else {
                throw UACManifestEditorError.invalidMetadataJSON("Technical field cannot be deleted: \(key)")
            }
            game[bucket] = fields
            root["game"] = game
            draftManifestJSON = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys, .prettyPrinted])
            let manifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(manifest.game.extensions)
            refreshMemberSummaries(from: manifest)
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            statusMessage = "Deleted package technical field. Save to commit the package change."
            errorMessage = nil
        } catch { errorMessage = String(describing: error) }
    }

    func harvestSPCMetadata(replaceExisting: Bool = false) {
        guard !isHarvestingMetadata else { return }
        guard let documentURL else { return }
        guard canHarvestSPCMetadata else {
            errorMessage = "Native SPC tag harvest requires SPC members in a seekable tar+zstd-seekable UAC payload."
            return
        }
        guard !spcMemberPaths.isEmpty else {
            errorMessage = "This UAC has no SPC members to harvest."
            return
        }
        do {
            try flushEditorBuffers()
        } catch {
            errorMessage = String(describing: error)
            return
        }

        isHarvestingMetadata = true
        harvestProgressMessage = "Preparing SPC metadata reader…"
        statusMessage = "Reading embedded SPC headers through the UAC seek table."
        let memberPaths = spcMemberPaths
        let manifestDecoder = codec.decoder
        let frameDecoder = codec.seekableFrameDecoder
        let packageURL = documentURL
        let progressRelay = SPCMetadataProgressRelay(model: self)
        harvestTask = Task.detached(priority: .utility) { [weak self] in
            do {
                let outcome = try SPCMetadataHarvester.harvest(
                    packageURL: packageURL,
                    memberPaths: memberPaths,
                    decompressManifestFrame: manifestDecoder,
                    decompressFrame: frameDecoder,
                    progress: { completed, total, path in
                        Task { @MainActor in
                            progressRelay.report(completed: completed, total: total, path: path)
                        }
                    }
                )
                await self?.finishSPCMetadataHarvest(outcome, replaceExisting: replaceExisting, packageURL: packageURL)
            } catch {
                await self?.failSPCMetadataHarvest(error, packageURL: packageURL)
            }
        }
    }

    func cancelSPCMetadataHarvest() {
        harvestTask?.cancel()
        harvestTask = nil
        isHarvestingMetadata = false
        harvestProgressMessage = ""
        statusMessage = "SPC metadata harvest cancelled; no partial import was applied."
    }

    func revert() {
        cancelSPCMetadataHarvest()
        guard let loadedContainer else { return }
        do {
            draftManifestJSON = originalManifestJSON
            packageTitle = loadedContainer.manifest.game.title
            consoleName = loadedContainer.manifest.game.console
            gameMetadataJSON = try UACManifestEditor.prettyJSON(loadedContainer.manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(loadedContainer.manifest.game.extensions)
            refreshMemberSummaries(from: loadedContainer.manifest)
            if let selectedMemberPath {
                try loadMemberEditor(path: selectedMemberPath, from: loadedContainer.manifest)
            }
            hasUnsavedChanges = false
            errorMessage = nil
            statusMessage = "Reverted unsaved metadata edits."
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func save() {
        guard let documentURL, let openedSnapshot else { return }
        let temporaryURL = documentURL.deletingLastPathComponent()
            .appendingPathComponent(".\(documentURL.lastPathComponent).uacman-\(UUID().uuidString).tmp")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        do {
            try flushEditorBuffers()
            let finalJSON = draftManifestJSON
            guard finalJSON != originalManifestJSON else {
                hasUnsavedChanges = false
                statusMessage = "No metadata changes to save."
                errorMessage = nil
                return
            }

            try codec.ensureAvailable()
            let current = try UACContainerReader.read(from: documentURL, decompressManifestFrame: codec.decoder)
            let currentSnapshot = try OpenedFileSnapshot(url: documentURL, manifestSHA256: current.manifestSHA256)
            guard currentSnapshot == openedSnapshot else { throw UACManError.fileChangedExternally }

            let rewritten = try UACContainerWriter.rewriteManifest(
                manifestJSON: finalJSON,
                in: documentURL,
                to: temporaryURL,
                compressManifestFrame: codec.encoder,
                decompressManifestFrame: codec.decoder
            )
            guard rewritten.manifestJSON == finalJSON else { throw UACManError.rewriteVerificationFailed }
            let unchangedSource = try UACContainerReader.read(from: documentURL, decompressManifestFrame: codec.decoder)
            let unchangedSnapshot = try OpenedFileSnapshot(url: documentURL, manifestSHA256: unchangedSource.manifestSHA256)
            guard unchangedSnapshot == openedSnapshot else { throw UACManError.fileChangedExternally }
            let originalAttributes = try FileManager.default.attributesOfItem(atPath: documentURL.path)
            if let permissions = originalAttributes[.posixPermissions] as? NSNumber {
                try FileManager.default.setAttributes(
                    [.posixPermissions: permissions],
                    ofItemAtPath: temporaryURL.path
                )
            }
            guard Darwin.rename(temporaryURL.path, documentURL.path) == 0 else {
                throw UACManError.atomicReplaceFailed(String(cString: strerror(errno)))
            }
            loadDocumentWithoutPrompt(documentURL)
            statusMessage = "Saved metadata; the compressed payload was preserved byte-for-byte."
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func loadMemberEditor(path: String, from manifest: UACManifest) throws {
        guard let member = manifest.members.first(where: { $0.path == path }) else {
            throw UACManifestEditorError.memberRecordMissing(path)
        }
        memberMetadataJSON = try UACManifestEditor.prettyJSON(member.metadata)
        memberExtensionsJSON = try UACManifestEditor.prettyJSON(member.extensions)
        if let index = members.firstIndex(where: { $0.path == path }) {
            members[index] = members[index].updatingMetadata(member.metadata, extensions: member.extensions)
        }
    }

    private func refreshMemberSummaries(from manifest: UACManifest) {
        let metadataByPath = Dictionary(
            manifest.members.map { ($0.path, $0.metadata) },
            uniquingKeysWith: { first, _ in first }
        )
        let extensionsByPath = Dictionary(
            manifest.members.map { ($0.path, $0.extensions) },
            uniquingKeysWith: { first, _ in first }
        )
        members = members.map { row in
            guard let metadata = metadataByPath[row.path] else { return row }
            return row.updatingMetadata(metadata, extensions: extensionsByPath[row.path])
        }
    }

    private func metadataNamespace(for key: String) -> (bucket: String, storageKey: String) {
        key.hasPrefix("extension.")
            ? ("extensions", String(key.dropFirst("extension.".count)))
            : ("metadata", key)
    }

    private func metadataScopeTargets(_ scope: String) -> (game: Bool, members: Bool) {
        switch scope.lowercased() {
        case "package", "packagetags", "package tags": return (true, false)
        case "tracks", "track", "tracktags", "track tags": return (false, true)
        default: return (true, true)
        }
    }

    private func flushEditorBuffers() throws {
        var updated = draftManifestJSON
        if let selectedMemberPath {
            updated = try UACManifestEditor.updateMemberFields(
                in: updated,
                memberPath: selectedMemberPath,
                metadataJSON: memberMetadataJSON,
                extensionsJSON: memberExtensionsJSON
            )
        }
        updated = try UACManifestEditor.updateGameFields(
            in: updated,
            title: packageTitle,
            console: consoleName,
            metadataJSON: gameMetadataJSON,
            extensionsJSON: gameExtensionsJSON
        )
        draftManifestJSON = updated
        hasUnsavedChanges = draftManifestJSON != originalManifestJSON
    }

    private func finishSPCMetadataHarvest(
        _ outcome: SPCMetadataHarvestOutcome,
        replaceExisting: Bool,
        packageURL: URL
    ) {
        guard documentURL == packageURL else { return }
        isHarvestingMetadata = false
        harvestTask = nil
        harvestProgressMessage = ""
        if outcome.wasCancelled {
            statusMessage = "SPC metadata harvest cancelled; no partial import was applied."
            return
        }
        guard !outcome.items.isEmpty else {
            statusMessage = "No SPC metadata could be imported."
            errorMessage = outcome.failures.prefix(4).joined(separator: "\n")
            return
        }
        do {
            let result = try SPCMetadataProjector.merge(
                items: outcome.items,
                into: draftManifestJSON,
                overwriteExisting: replaceExisting
            )
            draftManifestJSON = result.manifestJSON
            let mergedManifest = try UACManifestEditor.decode(draftManifestJSON)
            gameMetadataJSON = try UACManifestEditor.prettyJSON(mergedManifest.game.metadata)
            refreshMemberSummaries(from: mergedManifest)
            if let selectedMemberPath {
                try loadMemberEditor(path: selectedMemberPath, from: mergedManifest)
            }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            let mode = replaceExisting ? "replaced" : "filled missing"
            var summary = "Harvested native SPC metadata for \(result.importedMemberCount) track(s); \(mode) UAC fields."
            if !result.sharedFieldsApplied.isEmpty {
                summary += " Shared soundtrack fields: \(result.sharedFieldsApplied.joined(separator: ", "))."
            }
            if !result.conflicts.isEmpty {
                summary += " Kept differing or incomplete fields track-level: \(result.conflicts.joined(separator: ", "))."
            }
            if outcome.diagnosticCount > 0 {
                summary += " MetaMan reported \(outcome.diagnosticCount) parser diagnostic(s)."
            }
            if !outcome.failures.isEmpty {
                summary += " \(outcome.failures.count) track(s) could not be read."
            }
            statusMessage = summary
            errorMessage = outcome.failures.isEmpty ? nil : outcome.failures.prefix(6).joined(separator: "\n")
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func finishCollectionScan(
        _ result: UACCollectionScanResult,
        scanID: UUID,
        root: URL
    ) {
        guard collectionScanID == scanID, collectionRootURL == root else { return }
        collectionScanTask = nil
        isScanningCollection = false
        collectionEntries = result.entries
        collectionIssues = result.issues
        if result.entries.isEmpty && result.issues.isEmpty {
            collectionStatusMessage = "No .uac packages found in this folder."
        } else {
            collectionStatusMessage = "\(result.entries.count) package(s) · \(result.issues.count) unreadable item(s)"
        }
    }

    private func cancelCollectionScan(scanID: UUID) {
        guard collectionScanID == scanID else { return }
        collectionScanTask = nil
        isScanningCollection = false
        collectionStatusMessage = "Collection scan cancelled."
    }

    private func failCollectionScan(_ error: Error, scanID: UUID, root: URL) {
        guard collectionScanID == scanID, collectionRootURL == root else { return }
        collectionScanTask = nil
        isScanningCollection = false
        collectionStatusMessage = "Could not read this collection folder."
        errorMessage = String(describing: error)
    }

    private func failSPCMetadataHarvest(_ error: Error, packageURL: URL) {
        guard documentURL == packageURL else { return }
        isHarvestingMetadata = false
        harvestTask = nil
        harvestProgressMessage = ""
        errorMessage = String(describing: error)
    }

    private func confirmDiscardIfNeeded() -> Bool {
        guard hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Discard unsaved metadata changes?"
        alert.informativeText = "Your edits have not been written to the UAC package."
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}

@MainActor
private final class SPCMetadataProgressRelay {
    weak var model: UACManModel?

    init(model: UACManModel) {
        self.model = model
    }

    func report(completed: Int, total: Int, path: String) {
        model?.harvestProgressMessage = "Read \(completed) of \(total): \(URL(fileURLWithPath: path).lastPathComponent)"
    }
}

private struct OpenedFileSnapshot: Equatable {
    let size: UInt64
    let modificationDate: Date?
    let systemFileNumber: UInt64?
    let manifestSHA256: String

    init(url: URL, manifestSHA256: String) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.standardizedFileURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber else {
            throw UACManError.notUACFile
        }
        self.size = size.uint64Value
        self.modificationDate = attributes[.modificationDate] as? Date
        self.systemFileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        self.manifestSHA256 = manifestSHA256
    }
}

private enum UACManError: Error, LocalizedError {
    case notUACFile
    case fileChangedExternally
    case rewriteVerificationFailed
    case atomicReplaceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notUACFile:
            return "Choose a regular .uac file."
        case .fileChangedExternally:
            return "The UAC changed on disk after it was opened. Reopen it before saving."
        case .rewriteVerificationFailed:
            return "The rewritten manifest did not match the metadata being saved."
        case .atomicReplaceFailed(let message):
            return "Could not atomically replace the UAC: \(message)"
        }
    }
}
