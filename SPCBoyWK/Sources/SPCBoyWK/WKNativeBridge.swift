import AppKit
import ArchiveCacheCore
import CatalogReader
import CatalogPlaylistCore
import CatalogBrowserCore
import CatalogSessionCore
import FavoriteStoreCore
import FavoriteTrackCore
import FrontendPreferencesCore
import Foundation
import LocalFileBrowserCore
import PlaybackQueueCore
import PlaybackTransportCore
import PlaylistIdentityCore
import VGMBoyEndpointCore
import VGMBoyKit
import WebKit

/// The only JavaScript-to-native boundary in SPCBoy WK.
///
/// The web skin owns presentation and sends named requests. Swift owns the
/// read-only catalog and returns plain JSON records. Transport completion
/// decisions are delegated to WKPlaybackBridge rather than owned by this
/// catalog bridge, keeping playback policy in the shared native boundary.
final class WKNativeBridge: NSObject, WKScriptMessageHandler {
    private let catalogURL: URL
    private let isOptionsWindow: Bool
    private let catalogSessions = CatalogSessionCoordinator()
    private weak var playbackEventWebView: WKWebView?

    var onOpenOptionsWindow: (() -> Void)?
    var onCloseOptionsWindow: (() -> Void)?
    var onChooseRootFolder: (() -> String?)?
    var onChoosePath: (() -> String?)?
    var onChooseAACExportDirectory: (() -> String?)?
    var onAppearanceSettingsChanged: (([String: Any]) -> Void)?
    var onFrontendSettingsChanged: ((SPCBoyPreferencesSnapshot) -> Void)?
    var onPlaybackEvent: (@MainActor (String, [String: Any]) -> Void)?

    init(catalogURL: URL = WKNativeBridge.defaultCatalogURL, isOptionsWindow: Bool = false) {
        self.catalogURL = catalogURL
        self.isOptionsWindow = isOptionsWindow
        super.init()
    }

    func attachPlaybackEvents(to webView: WKWebView) {
        playbackEventWebView = webView
        WKPlaybackBridge.shared.setStatusHandler { [weak self] status in
            Task { @MainActor [weak self] in
                self?.publishNativePlaybackState(status)
            }
        }
        WKPlaybackBridge.shared.setNaturalEndHandler { [weak self] status in
            Task { @MainActor [weak self] in
                self?.publishNativePlaybackEnded(status)
            }
        }
        WKPlaybackBridge.shared.setExportEventHandler { [weak self] event in
            Task { @MainActor [weak self] in
                self?.publishPlaybackEvent(name: "nativeAACExport", payload: [
                    "id": event.id,
                    "state": event.state,
                    "rendered_frames": event.renderedFrames,
                    "total_frames": event.totalFrames,
                    "message": event.message ?? NSNull()
                ])
            }
        }
    }

    static var defaultCatalogURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CocoaSpice/Library.sqlite")
    }

    private static var playbackBackendManifest: [[String: Any]] {
        FormatRegistry.playbackDescriptors.map { descriptor in
            backend(
                descriptor.id,
                extensions: descriptor.extensions,
                supportsLongPlay: descriptor.supportsLongPlay,
                supportsTempo: descriptor.supportsTempo,
                hasNaturalEnding: descriptor.hasNaturalEnding
            )
        }
    }

    private static func backend(
        _ id: String,
        extensions: Set<String>,
        supportsLongPlay: Bool,
        supportsTempo: Bool,
        hasNaturalEnding: Bool
    ) -> [String: Any] {
        [
            "id": id,
            "extensions": extensions.sorted(),
            "supportsLongPlay": supportsLongPlay,
            "supportsTempo": supportsTempo,
            "hasNaturalEnding": hasNaturalEnding,
            "playbackSpeedMode": supportsTempo ? "native-tempo" : "none",
            "playbackSpeedExtensions": supportsTempo ? extensions.sorted() : []
        ]
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
            playbackBackends: \(Self.json(Self.playbackBackendManifest)),
            bootstrap: (...args) => request("bootstrap", args),
            refreshTree: (...args) => request("refreshTree", args),
            databaseLocation: (...args) => request("databaseLocation", args),
            databaseRoots: (...args) => request("databaseRoots", args),
            databaseGames: (...args) => request("databaseGames", args),
            databaseFiles: (...args) => request("databaseFiles", args),
            databaseFileTree: (...args) => request("databaseFileTree", args),
            databaseSearchGames: (...args) => request("databaseSearchGames", args),
            databaseGameTracks: (...args) => request("databaseGameTracks", args),
            databaseGroupState: (...args) => request("databaseGroupState", args),
            catalogSessionInvalidate: (...args) => request("catalogSessionInvalidate", args),
            playbackQueueTransition: (...args) => request("playbackQueueTransition", args),
            playbackCompletionRetire: (...args) => request("playbackCompletionRetire", args),
            playbackFadeDuration: (...args) => request("playbackFadeDuration", args),
            databaseFileTracks: (...args) => request("databaseFileTracks", args),
            databaseFolderTracks: (...args) => request("databaseFolderTracks", args),
            favoritesList: (...args) => request("favoritesList", args),
            favoritesToggle: (...args) => request("favoritesToggle", args),
            favoritesRevision: () => request("favoritesRevision"),
            resolveSidebarState: (...args) => request("resolveSidebarState", args),
            resolveSidebarRowIntent: (...args) => request("resolveSidebarRowIntent", args),
            frontendOptionsManifest: () => request("frontendOptionsManifest"),
            frontendSettingsLoad: (...args) => request("frontendSettingsLoad", args),
            frontendSettingsSave: (...args) => request("frontendSettingsSave", args),
            endpointSurface: (...args) => request("endpointSurface", args),
            reloadDatabaseLibrary: (...args) => request("reloadDatabaseLibrary", args),
            configureArchiveCache: (...args) => request("configureArchiveCache", args),
            archiveCacheSummary: (...args) => request("archiveCacheSummary", args),
            archiveCacheLocation: (...args) => request("archiveCacheLocation", args),
            clearArchiveCache: (...args) => request("clearArchiveCache", args),
            showArchiveCacheInFinder: () => request("showArchiveCacheInFinder"),
            setRoutingPreferences: (...args) => request("setRoutingPreferences", args),
            setAppearanceSettings: (...args) => request("setAppearanceSettings", args),
            chooseAACExportDirectory: () => request("chooseAACExportDirectory"),
            defaultAACExportDirectory: () => request("defaultAACExportDirectory"),
            openOptionsWindow: () => request("openOptionsWindow"),
            closeOptionsWindow: () => request("closeOptionsWindow"),
            openPath: (...args) => request("openPath", args),
            chooseRootFolder: (...args) => request("chooseRootFolder", args),
            choosePath: (...args) => request("choosePath", args),
            listFolder: (...args) => request("listFolder", args),
            selectFolder: (...args) => request("selectFolder", args),
            selectFile: (...args) => request("selectFile", args),
            showInFinder: (...args) => request("showInFinder", args),
            nativePlaybackInit: (...args) => request("nativePlaybackInit", args),
            nativePlaybackAudioConfig: (...args) => request("nativePlaybackAudioConfig", args),
            nativePlaybackTiming: (...args) => request("nativePlaybackTiming", args),
            nativePlaybackReconfigure: (...args) => request("nativePlaybackReconfigure", args),
            nativePlaybackStart: (...args) => request("nativePlaybackStart", args),
            nativePlaybackResume: (...args) => request("nativePlaybackResume", args),
            nativePlaybackPause: (...args) => request("nativePlaybackPause", args),
            nativePlaybackStop: (...args) => request("nativePlaybackStop", args),
            nativePlaybackClose: (...args) => request("nativePlaybackClose", args),
            nativePlaybackUnload: (...args) => request("nativePlaybackUnload", args),
            nativePlaybackSeek: (...args) => request("nativePlaybackSeek", args),
            nativePlaybackSetTempo: (...args) => request("nativePlaybackSetTempo", args),
            nativePlaybackState: (...args) => request("nativePlaybackState", args),
            nativePlaybackRampGain: (...args) => request("nativePlaybackRampGain", args),
            nativeExportAAC: (...args) => request("nativeExportAAC", args),
            nativeCancelAACExport: (...args) => request("nativeExportAACCancel", args),
            setPlaybackPowerSaveBlocker: (...args) => request("setPlaybackPowerSaveBlocker", args),
            onCatalogReloaded: (listener) => on("catalogReloaded", listener),
            onLibrarySnapshot: (listener) => on("librarySnapshot", listener),
            onLibraryCommand: (listener) => on("libraryCommand", listener),
            onNativePlaybackState: (listener) => on("nativePlaybackState", listener),
            onNativePlaybackEnded: (listener) => on("nativePlaybackEnded", listener),
            onNativeAACExport: (listener) => on("nativeAACExport", listener),
            onAppearanceSettingsChanged: (listener) => on("appearanceSettingsChanged", listener),
            onFrontendSettingsChanged: (listener) => on("frontendSettingsChanged", listener),
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

        if method == "setAppearanceSettings" {
            let settings = args.first as? [String: Any] ?? [:]
            let handler = onAppearanceSettingsChanged
            Task { @MainActor in handler?(settings) }
            Task {
                await Self.reply(to: message.webView, id: id, success: true, valueJSON: "null")
            }
            return
        }

        if method == "frontendSettingsSave" {
            guard let settings = args.first as? [String: Any] else {
                Task { await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": BridgeError.invalidSettings.localizedDescription])) }
                return
            }
            let handler = onFrontendSettingsChanged
            do {
                let savedSettings = try Self.frontendSettingsSave(settings)
                Task { @MainActor in
                    handler?(savedSettings)
                    await Self.reply(to: message.webView, id: id, success: true, valueJSON: "true")
                }
            } catch {
                Task { await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": error.localizedDescription])) }
            }
            return
        }

        if method == "catalogSessionInvalidate" {
            guard let rawScope = args.first as? String,
                  let scope = CatalogSessionScope(rawValue: rawScope) else {
                Task { await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": BridgeError.invalidArguments.localizedDescription])) }
                return
            }
            let generation = catalogSessions.begin(scope)
            Task { await Self.reply(to: message.webView, id: id, success: true, valueJSON: Self.json(generation)) }
            return
        }

        if method == "playbackCompletionRetire" {
            do {
                let result = try completionRetirementResponse(args)
                Task { await Self.reply(to: message.webView, id: id, success: true, valueJSON: Self.json(result)) }
            } catch {
                Task { await Self.reply(to: message.webView, id: id, success: false, valueJSON: Self.json(["message": error.localizedDescription])) }
            }
            return
        }

        if method == "chooseRootFolder" || method == "choosePath" || method == "chooseAACExportDirectory" {
            let chooser: (() -> String?)?
            switch method {
            case "chooseRootFolder": chooser = onChooseRootFolder
            case "choosePath": chooser = onChoosePath
            default: chooser = onChooseAACExportDirectory
            }
            let catalogURL = self.catalogURL
            let catalogGeneration = (method == "chooseRootFolder" || method == "choosePath")
                ? catalogSessions.begin(.playlist)
                : nil
            Task { @MainActor in
                guard let selectedPath = chooser?() else {
                    await Self.reply(to: message.webView, id: id, success: true, valueJSON: "null")
                    return
                }
                if method == "chooseAACExportDirectory" {
                    await Self.reply(to: message.webView, id: id, success: true, valueJSON: Self.json(selectedPath))
                    return
                }
                Task.detached(priority: .userInitiated) {
                    let response: (success: Bool, valueJSON: String)
                    do {
                        let result = try Self.handle(method: "openPath", args: [selectedPath], catalogURL: catalogURL)
                        response = (true, Self.json(result))
                    } catch {
                        response = (false, Self.json(["message": error.localizedDescription]))
                    }
                    await MainActor.run {
                        let stale = catalogGeneration.map {
                            !self.catalogSessions.isCurrent($0, for: .playlist)
                        } ?? false
                        if let catalogGeneration, !stale {
                            self.catalogSessions.finish(catalogGeneration, for: .playlist)
                        }
                        let valueJSON = stale ? Self.json(["stale": true]) : response.valueJSON
                        Task {
                            await Self.reply(
                                to: message.webView,
                                id: id,
                                success: stale || response.success,
                                valueJSON: valueJSON
                            )
                        }
                    }
                }
            }
            return
        }

        let catalogScope = CatalogSessionScope.scope(for: method)
        let catalogGeneration = catalogScope.map { catalogSessions.begin($0) }
        let requestMethod = method
        let requestArgumentsJSON = Self.json(args)
        let requestCatalogURL = catalogURL
        Task { [weak self, webView = message.webView] in
            let response: (success: Bool, valueJSON: String) = await Task.detached(priority: .userInitiated) {
                do {
                    guard let data = requestArgumentsJSON.data(using: .utf8),
                          let detachedArgs = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                        throw BridgeError.invalidArguments
                    }
                    let result = try Self.handle(method: requestMethod, args: detachedArgs, catalogURL: requestCatalogURL)
                    return (true, Self.json(result))
                } catch {
                    print("[SPCBoy WK] request \(requestMethod) failed: \(error.localizedDescription)")
                    return (false, Self.json(["message": error.localizedDescription]))
                }
            }.value

            guard let self else { return }
            var success = response.success
            var valueJSON = response.valueJSON
            if let catalogScope, let catalogGeneration {
                let isStale = !self.catalogSessions.isCurrent(catalogGeneration, for: catalogScope)
                if !isStale {
                    self.catalogSessions.finish(catalogGeneration, for: catalogScope)
                } else {
                    // Every request still receives a reply, but stale catalog
                    // work cannot publish data into the WebKit session.
                    success = true
                    valueJSON = Self.json(["stale": true])
                }
            }
            await Self.reply(to: webView, id: id, success: success, valueJSON: valueJSON)
        }
    }

    private static func reply(to webView: WKWebView?, id: String, success: Bool, valueJSON: String) async {
        guard let webView else { return }
        let idJSON = json(id)
        await MainActor.run {
            webView.evaluateJavaScript("window.__spcBoyWKReply(\(idJSON), \(success ? "true" : "false"), \(valueJSON));", completionHandler: nil)
        }
    }

    private func completionRetirementResponse(_ args: [Any]) throws -> Any {
        guard let request = args.first as? [String: Any],
              let statePayload = request["state"] as? [String: Any],
              let intent = request["intent"] as? [String: Any],
              let rawGeneration = request["generation"] as? NSNumber else {
            throw BridgeError.invalidArguments
        }
        let state = PlaybackQueueState(
            currentTrackID: statePayload["currentTrackId"] as? String,
            selectedTrackID: statePayload["selectedTrackId"] as? String,
            pendingTrackID: statePayload["pendingTrackId"] as? String
        )
        let repeatMode: PlaybackRepeatMode = switch intent["repeatMode"] as? String {
        case "one": .song
        case "all": .playlist
        default: .off
        }
        let lifecycleRequest = PlaybackContinuationRequest(
            generation: rawGeneration.intValue,
            state: state,
            playlistIDs: Self.stringArray(request["playlistIds"]),
            repeatMode: repeatMode
        )
        guard let decision = WKPlaybackBridge.shared.retireCompletedPlayback(lifecycleRequest) else {
            return NSNull()
        }
        SPCArchiveMaterialization.release()
        switch decision.action {
        case .stop:
            return ["action": "stop"]
        case .play(let trackID):
            return ["action": "play", "trackId": trackID]
        }
    }

    @MainActor
    private func publishNativePlaybackState(_ status: PlaybackTransportStatus) {
        publishPlaybackEvent(name: "nativePlaybackState", payload: playbackPayload(status))
    }

    @MainActor
    private func publishNativePlaybackEnded(_ status: PlaybackTransportStatus) {
        publishPlaybackEvent(
            name: "nativePlaybackEnded",
            payload: playbackPayload(status, transportState: "ended", reachedEnd: true)
        )
    }

    @MainActor
    private func playbackPayload(
        _ status: PlaybackTransportStatus,
        transportState forcedTransportState: String? = nil,
        reachedEnd forcedReachedEnd: Bool? = nil
    ) -> [String: Any] {
        PlaybackTransportStatusPayload(
            status: status,
            forcedTransportState: forcedTransportState,
            forcedReachedEnd: forcedReachedEnd
        ).jsonObject()
    }

    @MainActor
    private func publishPlaybackEvent(name: String, payload: [String: Any]) {
        if let onPlaybackEvent {
            onPlaybackEvent(name, payload)
            return
        }
        let valueJSON = Self.json(payload)
        guard let webView = playbackEventWebView else { return }
        Task { @MainActor in
            _ = try? await webView.evaluateJavaScript(
                "window.__spcBoyWKEvent(\(Self.json(name)), \(valueJSON));"
            )
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
        case "showArchiveCacheInFinder":
            let url = URL(fileURLWithPath: SPCArchiveMaterialization.cacheLocation())
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([url.standardizedFileURL])
            return true
        case "defaultAACExportDirectory":
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.standardizedFileURL.path
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true).path
        case "archiveCacheLocation":
            return SPCArchiveMaterialization.cacheLocation()
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
        case "databaseFileTree":
            return try fileTree(catalogURL: catalogURL)
        case "databaseSearchGames":
            let query = (args.first as? String) ?? ""
            return try searchGames(query, catalogURL: catalogURL)
        case "databaseGameTracks":
            return try gameTracks(args.first, catalogURL: catalogURL)
        case "databaseGroupState":
            guard let state = args.first as? [String: Any],
                  let action = args.dropFirst().first as? String else {
                throw BridgeError.invalidArguments
            }
            return try databaseGroupState(
                state: state,
                action: action,
                groupName: args.dropFirst(2).first as? String,
                gameID: args.dropFirst(3).first as? String
            )
        case "playbackQueueTransition":
            guard let request = args.first as? [String: Any],
                  let statePayload = request["state"] as? [String: Any],
                  let intent = request["intent"] as? [String: Any] else {
                throw BridgeError.invalidArguments
            }
            let state = PlaybackQueueState(
                currentTrackID: statePayload["currentTrackId"] as? String,
                selectedTrackID: statePayload["selectedTrackId"] as? String,
                pendingTrackID: statePayload["pendingTrackId"] as? String
            )
            let playlistIDs = stringArray(request["playlistIds"])
            switch intent["kind"] as? String {
            case "transportTarget":
                return state.transportTargetID(playlistIDs: playlistIDs) ?? NSNull()
            case "adjacent":
                guard let direction = PlaybackQueueDirection(rawValue: intent["direction"] as? String ?? ""),
                      let targetID = state.adjacentTargetID(
                          playlistIDs: playlistIDs,
                          direction: direction,
                          wraps: intent["wraps"] as? Bool ?? false
                      ) else {
                    return NSNull()
                }
                return targetID
            case "completion":
                let repeatMode: PlaybackRepeatMode = switch intent["repeatMode"] as? String {
                case "one": .song
                case "all": .playlist
                default: .off
                }
                return state.completionTargetID(
                    playlistIDs: playlistIDs,
                    repeatMode: repeatMode
                ) ?? NSNull()
            case "replace":
                let replacement = state.replacing(
                    playlistIDs: playlistIDs,
                    preservePlayback: intent["preservePlayback"] as? Bool ?? false
                )
                return [
                    "currentTrackId": replacement.currentTrackID.map { $0 as Any } ?? NSNull(),
                    "selectedTrackId": replacement.selectedTrackID.map { $0 as Any } ?? NSNull(),
                    "pendingTrackId": replacement.pendingTrackID.map { $0 as Any } ?? NSNull()
                ]
            default:
                throw BridgeError.invalidArguments
            }
        case "playbackFadeDuration":
            let duration = PlaybackFadePolicy.queuedSkipDuration(
                enabled: args.first as? Bool ?? false,
                isPlaying: args.dropFirst().first as? Bool ?? false,
                hasCurrentTrack: args.dropFirst(2).first as? Bool ?? false,
                elapsedSeconds: double(args.dropFirst(3).first) ?? 0,
                preFadeSeconds: double(args.dropFirst(4).first) ?? 0,
                fadeSeconds: double(args.dropFirst(5).first) ?? 0,
                totalSeconds: double(args.dropFirst(6).first) ?? 0
            )
            return duration.map { $0 * 1_000 } ?? NSNull()
        case "databaseFileTracks":
            return try fileTracks(args.first, catalogURL: catalogURL, folders: false)
        case "databaseFolderTracks":
            return try fileTracks(args.first, catalogURL: catalogURL, folders: true)
        case "favoritesList":
            return try favoriteResponses(FavoriteStore().snapshots(), order: favoriteSortOrder(args.first))
        case "favoritesToggle":
            let snapshots = favoriteSnapshots(args.first)
            let store = try FavoriteStore()
            _ = try store.toggle(snapshots)
            return try favoriteResponses(store.snapshots(), order: favoriteSortOrder(args.dropFirst().first))
        case "favoritesRevision":
            return try FavoriteStore().revision()
        case "resolveSidebarState":
            return sidebarState(mode: args.first as? String, query: args.dropFirst().first as? String)
        case "resolveSidebarRowIntent":
            guard let kindRaw = args.first as? String,
                  let gestureRaw = args.dropFirst().first as? String,
                  let kind = SidebarRowKind(rawValue: kindRaw),
                  let gesture = SidebarRowGesture(rawValue: gestureRaw) else {
                throw BridgeError.invalidArguments
            }
            let wasSelected = args.dropFirst(2).first as? Bool ?? false
            return SidebarRowInteraction.intent(kind: kind, gesture: gesture, wasSelected: wasSelected).rawValue
        case "frontendOptionsManifest":
            return try Self.object(FrontendOptionsManifest.v1)
        case "frontendSettingsLoad":
            return try Self.object(frontendSettingsLoad())
        case "frontendSettingsSave":
            guard let settings = args.first as? [String: Any] else { throw BridgeError.invalidSettings }
            _ = try frontendSettingsSave(settings)
            return true
        case "endpointSurface":
            return try JSONSerialization.jsonObject(with: JSONEncoder().encode(VGMBoyEndpointSurface.v1))
        case "configureArchiveCache":
            guard let settings = args.first as? [String: Any] else { throw BridgeError.invalidArguments }
            let enabled = settings["enabled"] as? Bool ?? true
            let limitBytes = int64(settings["limitBytes"]) ?? ArchiveCachePolicy.defaultLimitBytes
            let summary = SPCArchiveMaterialization.configure(enabled: enabled, limitBytes: limitBytes)
            return [
                "enabled": enabled,
                "limitBytes": summary["limitBytes"] ?? limitBytes,
                "summary": summary
            ]
        case "archiveCacheSummary":
            return SPCArchiveMaterialization.cacheSummary()
        case "clearArchiveCache":
            try SPCArchiveMaterialization.clearCache()
            return true
        case "setPlaybackPowerSaveBlocker":
            return NSNull()
        case "setRoutingPreferences":
            return args.first ?? [:]
        case "nativePlaybackInit", "nativePlaybackAudioConfig", "nativePlaybackTiming", "nativePlaybackReconfigure", "nativePlaybackSetTempo", "nativePlaybackStart",
             "nativePlaybackResume", "nativePlaybackPause", "nativePlaybackStop",
             "nativePlaybackClose", "nativePlaybackUnload", "nativePlaybackSeek",
             "nativePlaybackState", "nativePlaybackRampGain",
             "nativeExportAAC", "nativeExportAACCancel":
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

    nonisolated private static func stringArray(_ value: Any?) -> [String] {
        if let values = value as? [String] {
            return values
        }
        if let values = value as? [Any] {
            return values.compactMap { $0 as? String }
        }
        return []
    }

    nonisolated private static func databaseGroupState(
        state: [String: Any],
        action: String,
        groupName: String?,
        gameID: String?
    ) throws -> [String: Any] {
        let current = CatalogBrowserGroupState(
            expandedGroupNames: Set(stringArray(state["expandedGroupNames"])),
            selectedGroupName: state["selectedGroupName"] as? String,
            selectedGameID: state["selectedGameID"] as? String
        )
        let next: CatalogBrowserGroupState
        switch action {
        case "toggle":
            guard let groupName, !groupName.isEmpty else { throw BridgeError.invalidArguments }
            next = current.applying(.toggleGroup(groupName))
        case "select":
            guard let groupName, !groupName.isEmpty else { throw BridgeError.invalidArguments }
            next = current.applying(.selectGroup(groupName))
        case "selectGame":
            guard let groupName, !groupName.isEmpty, let gameID, !gameID.isEmpty else {
                throw BridgeError.invalidArguments
            }
            next = current.applying(.selectGame(groupName: groupName, gameID: gameID))
        case "allCollapsed":
            let collapsed = state["collapsed"] as? Bool ?? true
            next = current.applying(.setAllCollapsed(
                collapsed,
                knownGroupNames: Set(stringArray(state["knownGroupNames"]))
            ))
        default:
            throw BridgeError.invalidArguments
        }
        return [
            "expandedGroupNames": Array(next.expandedGroupNames).sorted(),
            "selectedGroupName": next.selectedGroupName ?? NSNull(),
            "selectedGameID": next.selectedGameID ?? NSNull()
        ]
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

    nonisolated private static func fileTree(catalogURL: URL) throws -> [[String: Any]] {
        let index = CatalogFileTreeIndex(files: try openCatalog(catalogURL).fileBuckets())

        func responseNode(_ node: CatalogFileTreeNode, isRoot: Bool = false) -> [String: Any] {
            switch node.kind {
            case .folder:
                let folder = node.folder
                let browserPath: String
                if let folder {
                    browserPath = isRoot
                        ? "catalog-root:\(folder.rootID)\u{0000}\(folder.rootPath)"
                        : "catalog-folder:\(folder.rootID):\(folder.folderPath)"
                } else {
                    browserPath = "catalog-folder:\(node.id)"
                }
                var response: [String: Any] = [
                    "kind": "folder",
                    "path": browserPath,
                    "name": node.title,
                    "childrenLoaded": true,
                    "children": node.children.map { responseNode($0) }
                ]
                if let folder {
                    response["catalogFolder"] = [
                        "rootId": folder.rootID,
                        "rootPath": folder.rootPath,
                        "folderPath": folder.folderPath
                    ]
                }
                return response
            case .file:
                guard let file = node.file else { return [:] }
                return [
                    "kind": "file",
                    "path": "catalog-file:\(file.rootID):\(file.path)",
                    "name": URL(fileURLWithPath: file.path).lastPathComponent,
                    "childrenLoaded": true,
                    "children": [],
                    "catalogFile": [
                        "rootId": file.rootID,
                        "rootPath": file.rootPath,
                        "rootName": URL(fileURLWithPath: file.rootPath).lastPathComponent,
                        "folderPath": file.folderPath,
                        "path": file.path,
                        "isArchive": file.isArchive,
                        "trackCount": file.trackCount
                    ]
                ]
            }
        }

        return index.nodes().map { node in
            responseNode(node, isRoot: true)
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
        var selections: [CatalogPlaylistGameSelection] = []
        var rootPaths: [Int64: String] = [:]
        for game in values {
            guard let rootID = int64(game["rootId"]), let name = game["name"] as? String else { continue }
            let system = (game["system"] as? String) ?? ""
            selections.append(CatalogPlaylistGameSelection(rootID: rootID, game: name, system: system))
            if let rootPath = game["rootPath"] as? String, !rootPath.isEmpty {
                rootPaths[rootID] = rootPath
            }
        }
        let tracks = try CatalogPlaylistReader.tracksForGames(
            databaseURL: catalogURL,
            selections: selections,
            preferFoldersOverMetadata: true
        )
        return tracks.map { playlistTrackResponse($0, rootPath: rootPath(for: $0, roots: rootPaths)) }
    }

    nonisolated private static func fileTracks(_ value: Any?, catalogURL: URL, folders: Bool) throws -> [[String: Any]] {
        guard let values = value as? [[String: Any]] else { return [] }
        let catalog = try openCatalog(catalogURL)
        let roots = Dictionary(uniqueKeysWithValues: try catalog.roots().map { ($0.id, $0.path) })
        var tracks: [CatalogTrack] = []
        if folders {
            for item in values {
                guard let rootID = int64(item["rootId"]),
                      let folderPath = item["folderPath"] as? String,
                      let rootPath = (item["rootPath"] as? String) ?? roots[rootID] else { continue }
                tracks += try catalog.tracks(rootPath: rootPath, folderPath: folderPath)
            }
        } else {
            let selections = values.compactMap { item -> CatalogSourceSelection? in
                guard let rootID = int64(item["rootId"]),
                      let path = item["path"] as? String else { return nil }
                return CatalogSourceSelection(rootID: rootID, path: path)
            }
            tracks = try catalog.tracks(sourceSelections: selections)
        }
        return tracks.map { trackResponse($0, rootPath: roots[$0.rootID] ?? "") }
    }

    nonisolated private static func trackResponse(_ track: CatalogTrack, rootPath: String) -> [String: Any] {
        let path = track.sourcePath
        let fileURL = URL(fileURLWithPath: path)
        let favoriteIdentity = FavoriteTrackIdentity(
            sourcePath: track.archivePath ?? path,
            archiveEntry: track.archiveEntry,
            trackIndex: track.trackIndex,
            trackCount: track.trackCount
        )
        return [
            "playlistId": PlaylistTrackIdentity.trackID(
                sourcePath: track.archivePath ?? path,
                archiveEntry: track.archiveEntry,
                trackIndex: track.trackIndex
            ),
            "favoriteId": favoriteIdentity.id,
            "metadataTrackId": track.id,
            "metadataLoaded": true,
            "rootPath": rootPath,
            "path": path,
            "filename": fileURL.lastPathComponent,
            "archivePath": track.archivePath ?? NSNull(),
            "archiveEntry": track.archiveEntry ?? NSNull(),
            "trackIndex": track.trackIndex,
            "trackCount": track.trackCount,
            // Catalog-backed rows already carry their metadata. Do not stat
            // every source path during playlist hydration; archives and
            // external roots can make that synchronous bridge work very slow.
            "fileSize": 0,
            "modifiedAt": 0,
            "sourceSignature": NSNull(),
            "scanVersion": 0,
            "title": track.title,
            "game": track.game,
            "artist": track.author,
            "dumper": track.dumper,
            "system": track.system,
            "playLengthMs": track.lengthMilliseconds
        ]
    }

    nonisolated private static func playlistTrackResponse(_ track: CatalogPlaylistTrack, rootPath: String) -> [String: Any] {
        let path = track.sourcePath
        let fileURL = URL(fileURLWithPath: path)
        let archivePath = track.archivePath?.isEmpty == false ? track.archivePath : nil
        let archiveEntry = track.archiveEntry?.isEmpty == false ? track.archiveEntry : nil
        let favoriteIdentity = FavoriteTrackIdentity(
            sourcePath: archivePath ?? path,
            archiveEntry: archiveEntry,
            trackIndex: track.trackIndex,
            trackCount: track.trackCount
        )
        return [
            "playlistId": PlaylistTrackIdentity.trackID(
                sourcePath: archivePath ?? path,
                archiveEntry: archiveEntry,
                trackIndex: track.trackIndex
            ),
            "favoriteId": favoriteIdentity.id,
            "metadataTrackId": 0,
            "metadataLoaded": true,
            "rootPath": rootPath,
            "path": path,
            "filename": fileURL.lastPathComponent,
            "archivePath": archivePath ?? NSNull(),
            "archiveEntry": archiveEntry ?? NSNull(),
            "trackIndex": track.trackIndex,
            "trackCount": track.trackCount,
            "fileSize": 0,
            "modifiedAt": 0,
            "sourceSignature": NSNull(),
            "scanVersion": 0,
            "title": track.title,
            "game": track.game,
            "artist": track.author,
            "dumper": track.dumper,
            "system": track.system,
            "playLengthMs": track.lengthMilliseconds
        ]
    }

    nonisolated private static func rootPath(for track: CatalogPlaylistTrack, roots: [Int64: String]) -> String {
        let archivePath = track.archivePath?.isEmpty == false ? track.archivePath : nil
        let sourcePath = URL(fileURLWithPath: archivePath ?? track.sourcePath).standardizedFileURL.path
        return roots.values
            .filter { root in
                let normalizedRoot = URL(fileURLWithPath: root, isDirectory: true).standardizedFileURL.path
                return sourcePath == normalizedRoot || sourcePath.hasPrefix(normalizedRoot + "/")
            }
            .max(by: { $0.count < $1.count }) ?? ""
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
            let favoriteIdentity = FavoriteTrackIdentity(
                sourcePath: url.path,
                trackIndex: item.index,
                trackCount: trackStructures.count
            )
            return [
                "playlistId": "local-\(url.path)-\(item.index)",
                "favoriteId": favoriteIdentity.id,
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
                "dumper": "",
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

    nonisolated private static func favoriteSnapshots(_ value: Any?) -> [FavoriteTrackSnapshot] {
        guard let rows = value as? [[String: Any]] else { return [] }
        return rows.compactMap { row in
            let sourcePath = ((row["archivePath"] as? String)?.isEmpty == false ? row["archivePath"] as? String : nil)
                ?? row["path"] as? String
            guard let sourcePath, !sourcePath.isEmpty else { return nil }
            let archiveEntry = (row["archiveEntry"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let trackIndex = Int((row["trackIndex"] as? NSNumber)?.intValue ?? 0)
            let trackCount = max(1, Int((row["trackCount"] as? NSNumber)?.intValue ?? 1))
            let lengthMilliseconds: Int
            if let value = row["playLengthMs"] as? NSNumber {
                lengthMilliseconds = value.intValue
            } else if let value = row["basePlaybackSeconds"] as? NSNumber {
                lengthMilliseconds = Int((value.doubleValue * 1_000).rounded())
            } else {
                lengthMilliseconds = 0
            }
            return FavoriteTrackSnapshot(
                identity: FavoriteTrackIdentity(
                    sourcePath: sourcePath,
                    archiveEntry: archiveEntry,
                    trackIndex: trackIndex,
                    trackCount: trackCount
                ),
                filename: (row["sourceFilename"] as? String) ?? (row["filename"] as? String) ?? URL(fileURLWithPath: sourcePath).lastPathComponent,
                title: (row["title"] as? String) ?? "",
                game: (row["game"] as? String) ?? "",
                author: (row["artist"] as? String) ?? (row["author"] as? String) ?? "",
                system: (row["system"] as? String) ?? "",
                playLengthMilliseconds: lengthMilliseconds
            )
        }
    }

    nonisolated private static func favoriteSortOrder(_ value: Any?) -> FavoriteSortOrder {
        FavoriteSortOrder(rawValue: value as? String ?? "historical") ?? .historical
    }

    nonisolated private static func favoriteResponses(
        _ snapshots: [FavoriteTrackSnapshot],
        order: FavoriteSortOrder
    ) -> [[String: Any]] {
        FavoriteListPresentation.ordered(snapshots, by: order).map { snapshot in
            let identity = snapshot.identity
            let sourceURL = URL(fileURLWithPath: identity.sourcePath)
            let filename = snapshot.filename.isEmpty
                ? (identity.archiveEntry.map { URL(fileURLWithPath: $0).lastPathComponent } ?? sourceURL.lastPathComponent)
                : snapshot.filename
            let seconds = Double(snapshot.playLengthMilliseconds) / 1_000
            return [
                "id": identity.id,
                "favoriteId": identity.id,
                "path": identity.sourcePath,
                "rootPath": sourceURL.deletingLastPathComponent().path,
                "sourceFilename": filename,
                "filename": identity.trackCount > 1 ? "\(filename) [\(identity.trackIndex + 1)]" : filename,
                "displayName": snapshot.title.isEmpty ? sourceURL.deletingPathExtension().lastPathComponent : snapshot.title,
                "sidebarLabel": FavoriteListPresentation.displayName(for: snapshot),
                "title": snapshot.title,
                "game": snapshot.game,
                "artist": snapshot.author,
                "dumper": "—",
                "system": snapshot.system,
                "trackIndex": identity.trackIndex,
                "trackCount": identity.trackCount,
                "archivePath": identity.archiveEntry == nil ? NSNull() : identity.sourcePath,
                "archiveEntry": identity.archiveEntry ?? NSNull(),
                "fileSize": 0,
                "modifiedAt": 0,
                "sourceSignature": NSNull(),
                "scanVersion": 0,
                "lengthLabel": formatDuration(seconds),
                "basePlaybackSeconds": seconds,
                "metadataLoaded": true
            ]
        }
    }

    nonisolated private static func sidebarState(mode: String?, query: String?) -> [String: Any] {
        let state = CatalogBrowserState(
            mode: CatalogBrowserMode(rawValue: mode ?? "") ?? .consoles,
            query: query ?? ""
        )
        return [
            "storedMode": state.storedMode.rawValue,
            "query": state.query,
            "view": state.view.rawValue,
            "contentMode": state.contentMode.rawValue,
            "resultSource": state.resultSource.rawValue,
            "isTemporary": state.view == .search
        ]
    }

    nonisolated private static func formatDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    nonisolated private static let frontendSettingsKey = "SPCBoyWK.frontendPreferencesV2"

    nonisolated private static func frontendSettingsLoad() throws -> SPCBoyPreferencesSnapshot {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: frontendSettingsKey) {
            var snapshot = try JSONDecoder().decode(SPCBoyPreferencesSnapshot.self, from: data)
            snapshot.apply(frontendInterface: FrontendPreferencesStore(defaults: defaults, keys: .spcBoyWK).load())
            return snapshot
        }
        var snapshot = SPCBoyPreferencesSnapshot()
        let frontendPreferences = FrontendPreferencesStore(defaults: defaults, keys: .spcBoyWK).load()
        snapshot.apply(frontendInterface: frontendPreferences)
        let data = try JSONEncoder().encode(snapshot)
        defaults.set(data, forKey: frontendSettingsKey)
        return snapshot
    }

    @discardableResult
    nonisolated private static func frontendSettingsSave(_ settings: [String: Any]) throws -> SPCBoyPreferencesSnapshot {
        let snapshot = try SPCBoyPreferencesSnapshot(jsonObject: settings)
        FrontendPreferencesStore(defaults: .standard, keys: .spcBoyWK).save(snapshot.frontendInterfacePreferences)
        UserDefaults.standard.set(try JSONEncoder().encode(snapshot), forKey: frontendSettingsKey)
        return snapshot
    }

    nonisolated private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    nonisolated private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    nonisolated private static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
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
    case invalidArguments
    case invalidSettings

    var errorDescription: String? {
        switch self {
        case .unsupported(let method): return "SPCBoy WK native bridge does not implement \(method) yet."
        case .catalogMissing(let path): return "The read-only catalog is not available at \(path)."
        case .invalidArguments: return "SPCBoy WK received invalid bridge arguments."
        case .invalidSettings: return "SPCBoy WK received an invalid frontend settings snapshot."
        }
    }
}
