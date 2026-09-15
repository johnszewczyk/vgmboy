import AppKit
import Darwin
import Foundation
import Observation
import UniformTypeIdentifiers
import UACContainerCore
import UACManCore

struct SPCMemberRow: Identifiable, Hashable {
    let path: String
    let name: String
    let bytes: UInt64
    let rawHash: String
    let streamHash: String?
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

    init(member: UACMember) {
        self.init(
            path: member.path,
            name: member.originalName,
            bytes: member.byteSize,
            rawHash: member.blake3,
            streamHash: member.streamBlake3,
            metadata: member.metadata
        )
    }

    func updatingMetadata(_ metadata: [String: UACJSONValue]) -> SPCMemberRow {
        SPCMemberRow(
            path: path,
            name: name,
            bytes: bytes,
            rawHash: rawHash,
            streamHash: streamHash,
            metadata: metadata
        )
    }

    private init(
        path: String,
        name: String,
        bytes: UInt64,
        rawHash: String,
        streamHash: String?,
        metadata: [String: UACJSONValue]
    ) {
        self.path = path
        self.name = name
        self.bytes = bytes
        self.rawHash = rawHash
        self.streamHash = streamHash
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
    var documentURL: URL?
    var packageID = ""
    var packageTitle = ""
    var consoleName = ""
    var gameMetadataJSON = "{}"
    var gameExtensionsJSON = "{}"
    var memberMetadataJSON = "{}"
    var memberExtensionsJSON = "{}"
    var selectedMemberPath: String?
    var selectedMemberPaths: Set<String> = []
    var members: [SPCMemberRow] = []
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

    var canHarvestSPCMetadata: Bool {
        loadedContainer?.manifest.payload.format == "tar+zstd-seekable"
            && loadedContainer?.seekTable != nil
    }

    func openCommandLineFileIfPresent() {
        guard !handledCommandLineFile else { return }
        handledCommandLineFile = true
        guard let argument = ProcessInfo.processInfo.arguments.dropFirst().first,
              !argument.hasPrefix("-") else { return }
        openDocument(URL(fileURLWithPath: argument))
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

    func openDocument(_ url: URL) {
        guard confirmDiscardIfNeeded() else { return }
        loadDocumentWithoutPrompt(url)
    }

    private func loadDocumentWithoutPrompt(_ url: URL) {
        harvestTask?.cancel()
        harvestTask = nil
        isHarvestingMetadata = false
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
            let spcMembers = container.manifest.members.filter { member in
                member.format?.lowercased() == "spc"
                    || URL(fileURLWithPath: member.originalName).pathExtension.lowercased() == "spc"
            }

            documentURL = standardizedURL
            loadedContainer = container
            originalManifestJSON = container.manifestJSON
            draftManifestJSON = container.manifestJSON
            openedSnapshot = try OpenedFileSnapshot(url: standardizedURL, manifestSHA256: container.manifestSHA256)
            packageID = container.manifest.packageID
            packageTitle = container.manifest.game.title
            consoleName = container.manifest.game.console
            gameMetadataJSON = try UACManifestEditor.prettyJSON(container.manifest.game.metadata)
            gameExtensionsJSON = try UACManifestEditor.prettyJSON(container.manifest.game.extensions)
            members = spcMembers.map { SPCMemberRow(member: $0) }
            selectedMemberPath = members.first?.path
            selectedMemberPaths = []
            if let first = members.first {
                try loadMemberEditor(path: first.path, from: container.manifest)
            } else {
                memberMetadataJSON = "{}"
                memberExtensionsJSON = "{}"
            }
            hasUnsavedChanges = false
            errorMessage = nil
            statusMessage = "Loaded \(members.count) SPC member(s) · \(allMemberCount) total package member(s)."
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

    func setSelectedMembers(_ paths: Set<String>) {
        selectedMemberPaths = paths.intersection(Set(members.map(\.path)))
    }

    func setMemberSelected(_ path: String, isSelected: Bool) {
        if isSelected {
            selectedMemberPaths.insert(path)
        } else {
            selectedMemberPaths.remove(path)
        }
    }

    func applyBatchFieldEdit(
        key: String,
        operation: UACBatchFieldOperation,
        value: String,
        searchText: String
    ) {
        guard !selectedMemberPaths.isEmpty else {
            errorMessage = "Select one or more tracks before applying a batch edit."
            return
        }
        do {
            try flushEditorBuffers()
            draftManifestJSON = try UACManifestEditor.applyBatchMetadataEdit(
                in: draftManifestJSON,
                memberPaths: selectedMemberPaths,
                key: key,
                operation: operation,
                value: value,
                searchText: searchText
            )
            let updatedManifest = try UACManifestEditor.decode(draftManifestJSON)
            refreshMemberSummaries(from: updatedManifest)
            if let selectedMemberPath {
                try loadMemberEditor(path: selectedMemberPath, from: updatedManifest)
            }
            hasUnsavedChanges = draftManifestJSON != originalManifestJSON
            errorMessage = nil
            statusMessage = "Applied \(operation.title.lowercased()) to \(selectedMemberPaths.count) selected track(s). Revert is available until saved."
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func harvestSPCMetadata(replaceExisting: Bool = false) {
        guard !isHarvestingMetadata else { return }
        guard let documentURL else { return }
        guard canHarvestSPCMetadata else {
            errorMessage = "Native SPC tag harvest currently requires a seekable tar+zstd-seekable UAC payload."
            return
        }
        guard !members.isEmpty else {
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
        let memberPaths = members.map(\.path)
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
            members[index] = members[index].updatingMetadata(member.metadata)
        }
    }

    private func refreshMemberSummaries(from manifest: UACManifest) {
        let metadataByPath = Dictionary(
            manifest.members.map { ($0.path, $0.metadata) },
            uniquingKeysWith: { first, _ in first }
        )
        members = members.map { row in
            guard let metadata = metadataByPath[row.path] else { return row }
            return row.updatingMetadata(metadata)
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
