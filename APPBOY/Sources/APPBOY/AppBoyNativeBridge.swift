import Foundation
import WebKit

/// Single JavaScript-to-native boundary for APPBOY, modeled on SB2's WKNativeBridge.
@MainActor
final class AppBoyNativeBridge: NSObject, WKScriptMessageHandler {
    private let store: AppBoyStore
    private let playback: AppBoyPlaybackCoordinator
    private weak var webView: WKWebView?
    private var hasBootstrapped = false
    private var queuedDeepLinks: [[String: Any]] = []

    init(store: AppBoyStore, playback: AppBoyPlaybackCoordinator) {
        self.store = store
        self.playback = playback
        super.init()
        playback.applyPreferences(store.preferences)

        playback.onStateChanged = { [weak self] snapshot in
            guard let self, let payload = Self.encodeJSONValue(snapshot) else { return }
            self.publishEvent(name: "nativePlaybackState", payload: payload)
        }
        playback.onNaturalEnd = { [weak self] generation, trackId in
            self?.publishEvent(name: "nativePlaybackEnded", payload: [
                "generation": generation,
                "trackId": trackId
            ])
        }
        playback.onRemoteCommand = { [weak self] command, positionTime in
            var payload: [String: Any] = ["command": command]
            if let positionTime {
                payload["positionTime"] = positionTime
            }
            self?.publishEvent(name: "remoteCommand", payload: payload)
        }
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
    }

    func emitDeepLink(url: URL) {
        guard url.scheme?.lowercased() == "appboy" else { return }
        let host = (url.host ?? "").lowercased()
        let pathPart = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let allowedViews: Set<String> = ["library", "playlist", "gallery", "favorites", "recent", "options"]
        let allowedOptionTabs: Set<String> = ["interface", "fonts", "gallery", "audio", "playback", "source"]
        let allowedTransports: Set<String> = ["pause", "stop", "next", "previous", "togglePlayPause", "newTab"]
        var eventPayload: [String: Any]?
        if host == "view", allowedViews.contains(pathPart.lowercased()) {
            eventPayload = ["action": "view", "target": pathPart.lowercased()]
        } else if host == "options" {
            let tab = pathPart.lowercased()
            eventPayload = [
                "action": "options",
                "target": allowedOptionTabs.contains(tab) ? tab : "interface"
            ]
        } else if host == "play" {
            var payload: [String: Any] = ["action": "play"]
            if !pathPart.isEmpty {
                payload["target"] = pathPart
            }
            eventPayload = payload
        } else if host == "transport", allowedTransports.contains(pathPart) {
            eventPayload = ["action": "transport", "target": pathPart]
        }
        guard let eventPayload else { return }
        if hasBootstrapped {
            publishEvent(name: "deepLink", payload: eventPayload)
        } else {
            queuedDeepLinks.append(eventPayload)
        }
    }

    func userScript() -> WKUserScript {
        WKUserScript(
            source: """
            (() => {
              const pending = new Map();
              const listeners = new Map();
              let nextRequestID = 1;

              function request(method, args = []) {
                return new Promise((resolve, reject) => {
                  const id = String(nextRequestID++);
                  pending.set(id, { resolve, reject });
                  window.webkit.messageHandlers.appBoy.postMessage({ id, method, args });
                });
              }

              window.__appBoyReply = (id, ok, value) => {
                const entry = pending.get(String(id));
                if (!entry) return;
                pending.delete(String(id));
                if (ok) entry.resolve(value);
                else entry.reject(Object.assign(new Error(value?.message || "Native request failed."), value || {}));
              };

              window.__appBoyEvent = (name, value) => {
                for (const listener of listeners.get(name) || []) {
                  try { listener(value); } catch (err) { console.error("[APPBOY] event listener error", err); }
                }
              };

              const on = (name, listener) => {
                if (typeof listener !== "function") return () => {};
                const entries = listeners.get(name) || new Set();
                entries.add(listener);
                listeners.set(name, entries);
                return () => entries.delete(listener);
              };

              const api = {
                volumeDetentCount: 20,
                bootstrap: () => request("bootstrap"),
                albumTracks: (albumId) => request("albumTracks", [albumId]),
                favoritesList: () => request("favoritesList"),
                historyList: () => request("historyList"),
                favoritesToggle: (trackId) => request("favoritesToggle", [trackId]),
                favoritesAlbumToggle: (albumId) => request("favoritesAlbumToggle", [albumId]),
                workspaceSave: (workspace) => request("workspaceSave", [workspace]),
                settingsSave: (patch) => request("settingsSave", [patch]),
                reloadCatalog: () => request("reloadCatalog"),
                playbackStart: (payload) => request("playbackStart", [payload]),
                playbackPause: (generation) => request("playbackPause", [generation]),
                playbackResume: (generation) => request("playbackResume", [generation]),
                playbackStop: (generation) => request("playbackStop", [generation]),
                playbackSeek: (seconds, generation) => request("playbackSeek", [seconds, generation]),
                playbackSetRate: (rate) => request("playbackSetRate", [rate]),
                playbackSetVolume: (volume) => request("playbackSetVolume", [volume]),
                playbackSetEqualizer: (enabled, bandsDB) => request("playbackSetEqualizer", [enabled, bandsDB]),
                onNativePlaybackState: (listener) => on("nativePlaybackState", listener),
                onNativePlaybackEnded: (listener) => on("nativePlaybackEnded", listener),
                onRemoteCommand: (listener) => on("remoteCommand", listener),
                onSettingsChanged: (listener) => on("settingsChanged", listener),
                onDeepLink: (listener) => on("deepLink", listener)
              };

              window.appBoy = Object.freeze(api);
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "appBoy",
              message.frameInfo.isMainFrame,
              AppBoyWebContentPolicy.isTrustedDocument(message.frameInfo.request.url),
              AppBoyWebContentPolicy.isTrustedDocument(message.webView?.url),
              let body = message.body as? [String: Any],
              let id = body["id"] as? String,
              let method = body["method"] as? String else {
            return
        }
        let args = body["args"] as? [Any] ?? []
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let result = try await self.dispatch(method: method, args: args)
                self.reply(id: id, ok: true, value: result)
            } catch {
                self.reply(id: id, ok: false, value: ["message": error.localizedDescription])
            }
        }
    }

    private func dispatch(method: String, args: [Any]) async throws -> Any {
        switch method {
        case "bootstrap":
            let prefsValue = Self.encodeJSONValue(store.preferences) ?? [:]
            let catalogValue = Self.encodeJSONValue(store.catalog) ?? [:]
            let workspaceValue = Self.encodeJSONValue(store.workspace) ?? [:]
            var tabTracks: [String: [[String: Any]]] = [:]
            for tab in store.workspace.tabs {
                if tab.sourceKind == "favorites" {
                    tabTracks[tab.id] = store.favoritesTracks()
                } else if tab.sourceKind == "history" {
                    tabTracks[tab.id] = store.historyTracks()
                } else if let albumId = tab.sourceId, !albumId.isEmpty {
                    let tracks = store.tracks(forAlbumId: albumId)
                    tabTracks[tab.id] = tracks.map { store.serializeTrack($0) }
                } else {
                    let tracks = store.tracks(forIds: tab.trackIds)
                    tabTracks[tab.id] = tracks.map { store.serializeTrack($0) }
                }
            }
            hasBootstrapped = true
            let drainedLinks = queuedDeepLinks
            queuedDeepLinks.removeAll()
            return [
                "preferences": prefsValue,
                "catalog": catalogValue,
                "workspace": workspaceValue,
                "favoriteTrackIds": Array(store.allFavoriteIds()),
                "initialTabTracks": tabTracks,
                "initialDeepLinks": drainedLinks
            ]

        case "albumTracks":
            guard let albumId = args.first as? String else { return [] }
            return store.tracks(forAlbumId: albumId).map { store.serializeTrack($0) }

        case "favoritesList":
            return store.favoritesTracks()

        case "historyList":
            return store.historyTracks()

        case "favoritesToggle":
            guard let trackId = args.first as? String else {
                throw NSError(domain: "APPBOY.Bridge", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing trackId"])
            }
            let isFav = store.toggleFavorite(trackId: trackId)
            return [
                "trackId": trackId,
                "isFavorite": isFav,
                "favoriteTrackIds": Array(store.allFavoriteIds())
            ]

        case "favoritesAlbumToggle":
            guard let albumId = args.first as? String else {
                throw NSError(domain: "APPBOY.Bridge", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing albumId"])
            }
            let favIds = store.toggleAlbumFavorites(albumId: albumId)
            return [
                "albumId": albumId,
                "favoriteTrackIds": favIds
            ]

        case "workspaceSave":
            guard let raw = args.first,
                  let data = try? JSONSerialization.data(withJSONObject: raw),
                  let decoded = try? JSONDecoder().decode(AppBoyWorkspaceSnapshot.self, from: data) else {
                throw NSError(domain: "APPBOY.Bridge", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid workspace payload"])
            }
            try store.saveWorkspace(decoded)
            return ["ok": true]

        case "settingsSave":
            guard let patch = args.first as? [String: Any] else {
                throw NSError(domain: "APPBOY.Bridge", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid settings patch"])
            }
            let updated = try store.applyPreferencesPatch(patch)
            playback.applyPreferences(updated)
            let encoded = Self.encodeJSONValue(updated) ?? [:]
            publishEvent(name: "settingsChanged", payload: encoded)
            return encoded

        case "reloadCatalog":
            let reloaded = try await store.reloadCatalog()
            return [
                "catalog": Self.encodeJSONValue(reloaded) ?? [:],
                "favoriteTrackIds": Array(store.allFavoriteIds())
            ]

        case "playbackStart":
            guard let payload = args.first as? [String: Any],
                  let trackId = payload["trackId"] as? String,
                  let track = store.track(for: trackId) else {
                throw NSError(domain: "APPBOY.Bridge", code: 404, userInfo: [NSLocalizedDescriptionKey: "Track not found in catalog"])
            }
            store.recordHistory(trackId: track.id)
            let snap = playback.start(track: track, preferences: store.preferences)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackPause":
            let gen = Self.optionalInt(args.first)
            let snap = playback.pause(expectedGeneration: gen)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackResume":
            let gen = Self.optionalInt(args.first)
            let snap = playback.resume(expectedGeneration: gen)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackStop":
            let gen = Self.optionalInt(args.first)
            let snap = playback.stop(expectedGeneration: gen)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackSeek":
            let seconds = (args.first as? NSNumber)?.doubleValue ?? 0.0
            let gen = args.count > 1 ? Self.optionalInt(args[1]) : nil
            let snap = await playback.seek(to: seconds, expectedGeneration: gen)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackSetRate":
            let rate = (args.first as? NSNumber)?.doubleValue ?? 1.0
            let snap = playback.setRate(rate)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackSetVolume":
            let volume = (args.first as? NSNumber)?.doubleValue ?? 1.0
            let snap = playback.setVolume(volume)
            return Self.encodeJSONValue(snap) ?? [:]

        case "playbackSetEqualizer":
            let enabled = (args.first as? Bool) ?? false
            let rawBands = (args.count > 1 ? args[1] as? [Any] : nil) ?? []
            let bands = rawBands.map { ($0 as? NSNumber)?.doubleValue ?? 0.0 }
            let snap = playback.setEqualizer(enabled: enabled, bandsDB: bands)
            return Self.encodeJSONValue(snap) ?? [:]

        default:
            throw NSError(domain: "APPBOY.Bridge", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Unknown bridge method: \(method)"
            ])
        }
    }

    private func reply(id: String, ok: Bool, value: Any) {
        guard let webView,
              let idJSON = Self.jsonLiteral(id),
              let valJSON = Self.jsonLiteral(value) else { return }
        let okLiteral = ok ? "true" : "false"
        webView.evaluateJavaScript("window.__appBoyReply?.(\(idJSON), \(okLiteral), \(valJSON));", completionHandler: nil)
    }

    private func publishEvent(name: String, payload: Any) {
        guard let webView,
              let nameJSON = Self.jsonLiteral(name),
              let payloadJSON = Self.jsonLiteral(payload) else { return }
        webView.evaluateJavaScript("window.__appBoyEvent?.(\(nameJSON), \(payloadJSON));", completionHandler: nil)
    }

    private static func optionalInt(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let n = raw as? NSNumber { return n.intValue }
        return nil
    }

    private static func encodeJSONValue<T: Encodable>(_ value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func jsonLiteral(_ value: Any) -> String? {
        if let text = value as? String {
            guard let data = try? JSONEncoder().encode(text) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return "null"
        }
        return String(data: data, encoding: .utf8)
    }
}
