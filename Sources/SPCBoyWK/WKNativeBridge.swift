import AppKit
import CatalogReader
import CatalogBrowserCore
import Foundation
import LocalFileBrowserCore
import VGMBoyEndpointCore
import VGMBoyKit
import WebKit

/// The only JavaScript-to-native boundary in SPCBoy WK.
///
/// The web skin owns presentation and sends named requests. Swift owns the
/// read-only catalog and returns plain JSON records. This keeps the bridge
/// independent of the renderer's former host/runtime implementation.
final class WKNativeBridge: NSObject, WKScriptMessageHandler {
    private let catalogURL: URL
    private let isOptionsWindow: Bool

    var onOpenOptionsWindow: (() -> Void)?
    var onCloseOptionsWindow: (() -> Void)?
    var onChooseRootFolder: (() -> String?)?

    init(catalogURL: URL = WKNativeBridge.defaultCatalogURL, isOptionsWindow: Bool = false) {
        self.catalogURL = catalogURL
        self.isOptionsWindow = isOptionsWindow
        super.init()
    }

    static var defaultCatalogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CocoaSpice/Library.sqlite")
    }

    func userScript() -> WKUserScript {
        let optionsWindowFlag = isOptionsWindow ? "true" : "false"
        return WKUserScript(source: """
        (() => {
          const pending = new Map();
          const listeners = new Map();
          let nextRequestID = 1;

          function request(method, args = []) {
            return new Promise((resolve, reject) => {
              const id = String(nextRequestID++);
              pending.set(id, { resolve, reject });
              window.webkit.messageHandlers.spcBoyWK.postMessage({ id, method, args });
            });
          }

          window.__spcBoyWKReply = (id, ok, value) => {
            const entry = pending.get(String(id));
            if (!entry) return;
            pending.delete(String(id));
            if (ok) entry.resolve(value);
            else entry.reject(Object.assign(new Error(value?.message || "Native request failed."), value || {}));
          };

          window.__spcBoyWKEvent = (name, value) => {
            for (const listener of listeners.get(name) || []) listener(value);
          };

          const on = (name, listener) => {
            if (typeof listener !== "function") return () => {};
            const entries = listeners.get(name) || new Set();
            entries.add(listener);
            listeners.set(name, entries);
            return () => entries.delete(listener);
          };

          const api = {
            isOptionsWindow: \(optionsWindowFlag),
            playbackBackends: [],
            bootstrap: (...args) => request("bootstrap", args),
            refreshTree: (...args) => request("refreshTree", args),
            databaseLocation: (...args) => request("databaseLocation", args),
            databaseRoots: (...args) => request("databaseRoots", args),
            databaseGames: (...args) => request("databaseGames", args),
            databaseFiles: (...args) => request("databaseFiles", args),
            databaseSearchGames: (...args) => request("databaseSearchGames", args),
            databaseGameTracks: (...args) => request("databaseGameTracks", args),
            databaseFileTracks: (...args) => request("databaseFileTracks", args),
            databaseFolderTracks: (...args) => request("databaseFolderTracks", args),
            endpointSurface: (...args) => request("endpointSurface", args),
            reloadDatabaseLibrary: (...args) => request("reloadDatabaseLibrary", args),
            configureArchiveCache: (...args) => request("configureArchiveCache", args),
            archiveCacheSummary: (...args) => request("archiveCacheSummary", args),
            clearArchiveCache: (...args) => request("clearArchiveCache", args),
            setRoutingPreferences: (...args) => request("setRoutingPreferences", args),
            setPlaybackSettings: (...args) => request("setPlaybackSettings", args),
            setAppearanceSettings: (...args) => request("setAppearanceSettings", args),
            openOptionsWindow: () => request("openOptionsWindow"),
            closeOptionsWindow: () => request("closeOptionsWindow"),
            openPath: (...args) => request("openPath", args),
            chooseRootFolder: (...args) => request("chooseRootFolder", args),
            listFolder: (...args) => request("listFolder", args),
            selectFolder: (...args) => request("selectFolder", args),
            selectFile: (...args) => request("selectFile", args),
            showInFinder: (...args) => request("showInFinder", args),
            nativePlaybackInit: (...args) => request("nativePlaybackInit", args),
            nativePlaybackAudioConfig: (...args) => request("nativePlaybackAudioConfig", args),
            nativePlaybackLoad: (...args) => request("nativePlaybackLoad", args),
            nativePlaybackPlay: (...args) => request("nativePlaybackPlay", args),
            nativePlaybackPause: (...args) => request("nativePlaybackPause", args),
            nativePlaybackStop: (...args) => request("nativePlaybackStop", args),
            nativePlaybackClose: (...args) => request("nativePlaybackClose", args),
            nativePlaybackUnload: (...args) => request("nativePlaybackUnload", args),
            nativePlaybackSeek: (...args) => request("nativePlaybackSeek", args),
            nativePlaybackState: (...args) => request("nativePlaybackState", args),
            nativePlaybackRampGain: (...args) => request("nativePlaybackRampGain", args),
            setPlaybackPowerSaveBlocker: (...args) => request("setPlaybackPowerSaveBlocker", args),
            materializeTrack: (...args) => request("materializeTrack", args),
            releaseMaterializedTrack: (...args) => request("releaseMaterializedTrack", args),
            onCatalogReloaded: (listener) => on("catalogReloaded", listener),
            onLibrarySnapshot: (listener) => on("librarySnapshot", listener),
            onLibraryCommand: (listener) => on("libraryCommand", listener),
            onNativePlaybackState: (listener) => on("nativePlaybackState", listener),
            onPlaybackSettingsChanged: (listener) => on("playbackSettingsChanged", listener),
            onAppearanceSettingsChanged: (listener) => on("appearanceSettingsChanged", listener),
            onRoutingPreferencesChanged: (listener) => on("routingPreferencesChanged", listener),
            onTransportShortcut: (listener) => on("transportShortcut", listener),
            onScanLogData: (listener) => on("scanLogData", listener)
          };
          window.spcBoyWK = Object.freeze(api);
        })();
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "spcBoyWK",
              let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let method = body["method"] as? String,
              let args = body["args"] as? [Any] else { return }

        print("[SPCBoy WK] request \(method)")

        if method == "openOptionsWindow" || method == "closeOptionsWindow" {
            let handler = method == "openOptionsWindow" ? onOpenOptionsWindow : onCloseOptionsWindow
            Task { @MainActor in handler?() }
            Task {
                await Self.reply(to: message.webView, id: id, success: true, valueJSON: "null")
            }
            return
        }

        if method == "chooseRootFolder" {
            let chooser = onChooseRootFolder
            let catalogURL = self.catalogURL
            Task { @MainActor in
                guard let selectedPath = chooser?() else {
                    await Self.reply(to: message.webView, id: id, success: true, valueJSON: "null")
                    return
                }
                Task.detached(priority: .userInitiated) {
                    do {
                        let result = try Self.handle(method: "openPath", args: [selectedPath], catalogURL: catalogURL)
                        await Self.reply(to: message.webView, id: id, success: true, valueJSON: Self.json(result))
                    } catch {
                        await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": error.localizedDescription]))
                    }
                }
            }
            return
        }

        Task.detached(priority: .userInitiated) { [catalogURL] in
            do {
                let result = try Self.handle(method: method, args: args, catalogURL: catalogURL)
                await Self.reply(to: message.webView, id: id, success: true, valueJSON: Self.json(result))
            } catch {
                print("[SPCBoy WK] request \(method) failed: \(error.localizedDescription)")
                await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": error.localizedDescription]))
            }
        }
    }

    private static func reply(to webView: WKWebView?, id: String, success: Bool, valueJSON: String) async {
        guard let webView else { return }
        let idJSON = json(id)
        await MainActor.run {
            webView.evaluateJavaScript("window.__spcBoyWKReply(\(idJSON), \(success ? "true" : "false"), \(valueJSON));", completionHandler: nil)
        }
    }

    nonisolated private static func handle(method: String, args: [Any], catalogURL: URL) throws -> Any {
        switch method {
        case "bootstrap":
            return emptySnapshot()
        case "refreshTree":
            guard let rootPath = args.first as? String, !rootPath.isEmpty else { return emptySnapshot() }
            let selectedPath = args.dropFirst().first as? String
            return try localSnapshot(rootPath: rootPath, selectedPath: selectedPath)
        case "openPath":
            guard let inputPath = args.first as? String, !inputPath.isEmpty else { return emptySnapshot() }
            return try localSnapshotForInput(inputPath)
        case "listFolder":
            guard let folderPath = args.first as? String else { return [] }
            return try localChildren(folderPath)
        case "selectFolder":
            guard let folderPath = args.first as? String else { return emptySelection() }
            return try localSelection(folderPath, file: false)
        case "selectFile":
            guard let filePath = args.first as? String else { return emptySelection() }
            return try localSelection(filePath, file: true)
        case "showInFinder":
            guard let path = args.first as? String else { return false }
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path).standardizedFileURL])
            return true
        case "databaseLocation":
            return try location(catalogURL: catalogURL, reloaded: false)
        case "reloadDatabaseLibrary":
            return try location(catalogURL: catalogURL, reloaded: true)
        case "databaseRoots":
            return try roots(catalogURL: catalogURL)
        case "databaseGames":
            return try games(catalogURL: catalogURL)
        case "databaseFiles":
            return try files(catalogURL: catalogURL)
        case "databaseSearchGames":
            let query = (args.first as? String) ?? ""
            return try searchGames(query, catalogURL: catalogURL)
        case "databaseGameTracks":
            return try gameTracks(args.first, catalogURL: catalogURL)
        case "databaseFileTracks":
            return try fileTracks(args.first, catalogURL: catalogURL, folders: false)
        case "databaseFolderTracks":
            return try fileTracks(args.first, catalogURL: catalogURL, folders: true)
        case "endpointSurface":
            return try JSONSerialization.jsonObject(with: JSONEncoder().encode(VGMBoyEndpointSurface.v1))
        case "configureArchiveCache", "archiveCacheSummary", "clearArchiveCache",
             "setPlaybackSettings", "setAppearanceSettings",
             "setPlaybackPowerSaveBlocker":
            return NSNull()
        case "setRoutingPreferences":
            return args.first ?? [:]
        case "nativePlaybackInit", "nativePlaybackAudioConfig", "nativePlaybackLoad",
             "nativePlaybackPlay", "nativePlaybackPause", "nativePlaybackStop",
             "nativePlaybackClose", "nativePlaybackUnload", "nativePlaybackSeek",
             "nativePlaybackState", "nativePlaybackRampGain",
             "materializeTrack", "releaseMaterializedTrack":
            return try WKPlaybackBridge.shared.handle(method: method, args: args)
        default:
            throw BridgeError.unsupported(method)
        }
    }

    nonisolated private static func openCatalog(_ url: URL) throws -> ReadOnlyCatalog {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BridgeError.catalogMissing(url.path)
        }
        return try ReadOnlyCatalog(databaseURL: url)
    }

    nonisolated private static func location(catalogURL: URL, reloaded: Bool) throws -> [String: Any] {
        let catalog = try openCatalog(catalogURL)
        return [
            "path": catalogURL.path,
            "requiresRestart": false,
            "reloaded": reloaded,
            "catalog": [
                "schemaVersion": ReadOnlyCatalog.supportedSchemaVersion,
                "trackCount": try catalog.activeTrackCount()
            ]
        ]
    }

    nonisolated private static func roots(catalogURL: URL) throws -> [[String: Any]] {
        try openCatalog(catalogURL).roots().map {
            ["rootId": $0.id, "path": $0.path, "isEnabled": $0.isEnabled, "trackCount": $0.trackCount]
        }
    }

    nonisolated private static func games(catalogURL: URL) throws -> [[String: Any]] {
        let projected = CatalogBrowserProjection.games(from: try openCatalog(catalogURL).gameBuckets())
        return projected.map {
            [
                "rootId": $0.rootID,
                "rootPath": $0.rootPath,
                "rootName": URL(fileURLWithPath: $0.rootPath).lastPathComponent,
                "name": $0.name,
                "displayName": $0.displayName,
                "system": $0.system,
                "trackCount": $0.trackCount
            ]
        }
    }

    nonisolated private static func files(catalogURL: URL) throws -> [[String: Any]] {
        try openCatalog(catalogURL).fileBuckets().map {
            [
                "rootId": $0.rootID,
                "rootPath": $0.rootPath,
                "rootName": URL(fileURLWithPath: $0.rootPath).lastPathComponent,
                "folderPath": $0.folderPath,
                "path": $0.path,
                "isArchive": $0.isArchive,
                "trackCount": $0.trackCount
            ]
        }
    }

    nonisolated private static func searchGames(_ query: String, catalogURL: URL) throws -> [[String: Any]] {
        let projected = CatalogBrowserProjection.search(
            CatalogBrowserProjection.games(from: try openCatalog(catalogURL).gameBuckets()),
            query: query
        )
        return projected.map {
            ["rootId": $0.rootID, "rootPath": $0.rootPath, "rootName": URL(fileURLWithPath: $0.rootPath).lastPathComponent, "name": $0.name, "displayName": $0.displayName, "system": $0.system, "trackCount": $0.trackCount]
        }
    }

    nonisolated private static func gameTracks(_ value: Any?, catalogURL: URL) throws -> [[String: Any]] {
        guard let values = value as? [[String: Any]] else { return [] }
        let catalog = try openCatalog(catalogURL)
        var tracks: [CatalogTrack] = []
        for game in values {
            guard let rootID = int64(game["rootId"]), let name = game["name"] as? String else { continue }
            let system = (game["system"] as? String) ?? ""
            tracks += try catalog.tracks(rootID: rootID, game: name, system: system, preferFoldersOverMetadata: true)
        }
        let roots = Dictionary(uniqueKeysWithValues: try catalog.roots().map { ($0.id, $0.path) })
        return tracks.map { trackResponse($0, rootPath: roots[$0.rootID] ?? "") }
    }

    nonisolated private static func fileTracks(_ value: Any?, catalogURL: URL, folders: Bool) throws -> [[String: Any]] {
        guard let values = value as? [[String: Any]] else { return [] }
        let catalog = try openCatalog(catalogURL)
        var tracks: [CatalogTrack] = []
        for item in values {
            guard let rootID = int64(item["rootId"]) else { continue }
            if folders, let path = item["folderPath"] as? String {
                tracks += try catalog.tracks(rootID: rootID, folderPaths: [path])
            } else if !folders, let path = item["path"] as? String {
                tracks += try catalog.tracks(rootID: rootID, sourcePaths: [path])
            }
        }
        let roots = Dictionary(uniqueKeysWithValues: try catalog.roots().map { ($0.id, $0.path) })
        return tracks.map { trackResponse($0, rootPath: roots[$0.rootID] ?? "") }
    }

    nonisolated private static func trackResponse(_ track: CatalogTrack, rootPath: String) -> [String: Any] {
        let path = track.sourcePath
        let fileURL = URL(fileURLWithPath: path)
        let statURL = URL(fileURLWithPath: track.archivePath ?? path)
        let attributes = try? FileManager.default.attributesOfItem(atPath: statURL.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = ((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) * 1000
        return [
            "playlistId": "catalog-\(track.id)",
            "metadataTrackId": track.id,
            "rootPath": rootPath,
            "path": path,
            "filename": fileURL.lastPathComponent,
            "archivePath": track.archivePath ?? NSNull(),
            "archiveEntry": track.archiveEntry ?? NSNull(),
            "trackIndex": track.trackIndex,
            "trackCount": track.trackCount,
            "fileSize": fileSize,
            "modifiedAt": modifiedAt,
            "sourceSignature": NSNull(),
            "scanVersion": 0,
            "title": track.title,
            "game": track.game,
            "artist": track.author,
            "system": track.system,
            "playLengthMs": track.lengthMilliseconds
        ]
    }

    nonisolated private static func localSnapshotForInput(_ inputPath: String) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: inputPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
            throw LocalFileBrowserError.missingPath(inputURL.path)
        }
        let rootURL = isDirectory.boolValue ? inputURL : inputURL.deletingLastPathComponent()
        let selectedPath = isDirectory.boolValue ? inputURL.path : rootURL.path
        return try localSnapshot(rootPath: rootURL.path, selectedPath: selectedPath, playlistPath: isDirectory.boolValue ? nil : inputURL.path)
    }

    nonisolated private static func localSnapshot(rootPath: String, selectedPath: String?, playlistPath: String? = nil) throws -> [String: Any] {
        let session = try localSession(rootPath: rootPath)
        let root = try session.rootNode()
        let selected = selectedPath.flatMap { try? session.resolve(path: $0) }?.path ?? session.rootURL.path
        let playlist = playlistPath.flatMap { try? localTracks(for: $0, rootPath: session.rootURL.path) } ?? []
        return [
            "rootPath": session.rootURL.path,
            "tree": try jsonNodes([root]),
            "selectedFolderPath": selected,
            "selectedBrowserPath": playlistPath ?? selected,
            "playlist": playlist,
            "sidebarMode": "diskPath",
            "sidebarQuery": "",
            "selectedDatabaseGameKey": NSNull()
        ]
    }

    nonisolated private static func localChildren(_ folderPath: String) throws -> [[String: Any]] {
        let session = try localSession(rootPath: folderPath)
        return try jsonNodes(session.children(of: session.rootURL))
    }

    nonisolated private static func localSelection(_ path: String, file: Bool) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDirectory) else {
            throw LocalFileBrowserError.missingPath(inputURL.path)
        }
        if file && (isDirectory.boolValue || FormatRegistry.family(for: inputURL.path) == nil) {
            throw LocalFileBrowserError.unsupportedTarget(inputURL.path)
        }
        let folderURL = isDirectory.boolValue ? inputURL : inputURL.deletingLastPathComponent()
        let session = try localSession(rootPath: folderURL.path)
        let playlist = try localTracks(for: isDirectory.boolValue ? folderURL.path : inputURL.path, rootPath: session.rootURL.path)
        return [
            "selectedFolderPath": folderURL.path,
            "selectedBrowserPath": inputURL.path,
            "playlist": playlist
        ]
    }

    nonisolated private static func localSession(rootPath: String) throws -> LocalFileBrowserSession {
        try LocalFileBrowserSession(rootURL: URL(fileURLWithPath: rootPath)) { url in
            FormatRegistry.family(for: url.path) != nil
        }
    }

    nonisolated private static func localTracks(for path: String, rootPath: String) throws -> [[String: Any]] {
        let targetURL = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDirectory) else {
            throw LocalFileBrowserError.missingPath(targetURL.path)
        }
        let urls: [URL]
        if isDirectory.boolValue {
            urls = try FileManager.default.contentsOfDirectory(
                at: targetURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .filter { FormatRegistry.family(for: $0.path) != nil }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        } else {
            urls = [targetURL]
        }

        return try urls.flatMap { try localTrackRows(for: $0, rootPath: rootPath) }
    }

    nonisolated private static func localTrackRows(for url: URL, rootPath: String) throws -> [[String: Any]] {
        let structure = try? PlaybackStructureReader.read(path: url.path)
        let trackStructures = structure?.tracks ?? [.init(index: 0, naturalPlayMilliseconds: 0, fadeMilliseconds: 0)]
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = ((attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) * 1_000
        let filename = url.lastPathComponent
        let basename = url.deletingPathExtension().lastPathComponent
        let game = url.deletingLastPathComponent().lastPathComponent
        let system = FormatRegistry.family(for: url.path)?.id ?? ""
        return trackStructures.map { item in
            [
                "playlistId": "local-\(url.path)-\(item.index)",
                "metadataTrackId": 0,
                "rootPath": rootPath,
                "path": url.path,
                "filename": filename,
                "archivePath": NSNull(),
                "archiveEntry": NSNull(),
                "trackIndex": item.index,
                "trackCount": trackStructures.count,
                "fileSize": fileSize,
                "modifiedAt": modifiedAt,
                "sourceSignature": NSNull(),
                "scanVersion": 0,
                "title": basename,
                "game": game,
                "artist": "",
                "system": system,
                "playLengthMs": item.naturalPlayMilliseconds
            ]
        }
    }

    nonisolated private static func jsonNodes(_ nodes: [LocalFileBrowserNode]) throws -> [[String: Any]] {
        try nodes.map { node in
            [
                "id": node.id,
                "kind": node.kind.rawValue,
                "name": node.name,
                "path": node.path,
                "parentPath": node.parentPath ?? NSNull(),
                "children": try jsonNodes(node.children),
                "childrenLoaded": node.childrenLoaded,
                "alwaysExpanded": node.alwaysExpanded
            ]
        }
    }

    nonisolated private static func emptySnapshot() -> [String: Any] {
        ["rootPath": NSNull(), "tree": [], "selectedFolderPath": NSNull(), "selectedBrowserPath": NSNull(), "playlist": []]
    }

    nonisolated private static func emptySelection() -> [String: Any] {
        ["selectedFolderPath": NSNull(), "selectedBrowserPath": NSNull(), "playlist": []]
    }

    nonisolated private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    nonisolated private static func json(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            if let string = value as? String { return "\"\(string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" }
            return "null"
        }
        return String(decoding: data, as: UTF8.self)
    }
}

private enum BridgeError: LocalizedError {
    case unsupported(String)
    case catalogMissing(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let method): return "SPCBoy WK native bridge does not implement \(method) yet."
        case .catalogMissing(let path): return "The read-only catalog is not available at \(path)."
        }
    }
}
