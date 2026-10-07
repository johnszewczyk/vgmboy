import AppKit
import ArchiveCacheCore
import ArchiveMaterializationCore
import CatalogBrowserCore
import CatalogPlaylistCore
import CatalogReader
import FavoriteStoreCore
import FavoriteTrackCore
import Foundation
import PlaybackQueueCore
import PlaybackTransportCore
import VGMBoyFormatCore
import VGMBoyKit
import WebKit

private struct LineBoyCatalogGame: Sendable {
    let rootID: Int64
    let game: String
    let system: String
    let displayName: String
    let trackCount: Int
}

private struct LineBoyCatalogGroup: Sendable {
    let name: String
    let system: String
    let gameCount: Int
}

private struct LineBoyCatalogBootstrap: Sendable {
    let groups: [LineBoyCatalogGroup]
    let displayNames: [String: String]
    let gameCount: Int
    let trackCount: Int
    let favoriteIDs: [String]
}

private func readLineBoyCatalogBootstrap(at catalogURL: URL) throws -> LineBoyCatalogBootstrap {
    let catalog = try ReadOnlyCatalog(databaseURL: catalogURL)
    let games = CatalogBrowserProjection.games(from: try catalog.gameBuckets())
    let groups = CatalogBrowserProjection.groups(from: games).map { group in
        LineBoyCatalogGroup(
            name: group.name,
            system: group.games.first?.system ?? "",
            gameCount: group.games.count
        )
    }
    let favorites = Set(try FavoriteStore().snapshots().map(\.identity.id))
    let displayNames = Dictionary(uniqueKeysWithValues: games.compactMap { game in
        game.displayName == game.name ? nil : (game.id, game.displayName)
    })
    return LineBoyCatalogBootstrap(
        groups: groups,
        displayNames: displayNames,
        gameCount: games.count,
        trackCount: try catalog.activeTrackCount(),
        favoriteIDs: Array(favorites)
    )
}

private func readLineBoyCatalogGames(at catalogURL: URL, system: String) throws -> [LineBoyCatalogGame] {
    let catalog = try ReadOnlyCatalog(databaseURL: catalogURL)
    return CatalogBrowserProjection.games(from: try catalog.gameBuckets(system: system)).map { game in
        LineBoyCatalogGame(
            rootID: game.rootID,
            game: game.name,
            system: game.system,
            displayName: game.displayName,
            trackCount: game.trackCount
        )
    }
}

@MainActor
final class LineBoyAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var bridge: LineBoyNativeBridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let bridge = LineBoyNativeBridge()
        self.bridge = bridge

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "lineBoy")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .black
        bridge.attach(webView)

        guard let page = Bundle.module.url(forResource: "index", withExtension: "html") else {
            fatalError("LineBoy resources are missing index.html")
        }
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LineBoy"
        window.tabbingMode = .disallowed
        window.contentView = webView
        window.delegate = self
        window.center()
        bridge.attach(window: window)
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func windowWillClose(_ notification: Notification) {
        Task { await bridge?.shutdown() }
    }
}

@MainActor
final class LineBoyNativeBridge: NSObject, WKScriptMessageHandler {
    private struct LocalTrack {
        let id: String
        let path: String
        let title: String
    }

    private let catalogURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CocoaSpice/Library.sqlite")
    private let transport = PlaybackTransportCoordinator(label: "LineBoy.vgmboy-playback")
    private let materializer = ArchivePlaybackMaterializer(
        cacheRootURL: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LineBoy/ArchiveCache", isDirectory: true),
        preferenceKeys: ArchiveCachePreferenceKeys(
            modeKey: "LineBoy.archiveCacheMode",
            limitKey: "LineBoy.archiveCacheLimitBytes"
        )
    )
    private var catalogTracks: [String: CatalogTrack] = [:]
    private var localTracks: [String: LocalTrack] = [:]
    private weak var webView: WKWebView?
    private weak var window: NSWindow?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        transport.setStatusHandler { [weak self] status in
            Task { @MainActor [weak self] in self?.publishPlaybackStatus(status) }
        }
    }

    func attach(window: NSWindow) {
        self.window = window
    }

    func shutdown() async {
        await transport.stop()
        materializer.release()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any],
              let requestID = body["id"] as? String,
              let method = body["method"] as? String else { return }
        let arguments = body["args"] as? [String: Any] ?? [:]

        do {
            switch method {
            case "catalogBootstrap":
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        self.reply(requestID, success: try await self.catalogBootstrap())
                    } catch {
                        self.reply(requestID, failure: error.localizedDescription)
                    }
                }
            case "catalogGroup":
                guard let system = arguments["system"] as? String else {
                    throw LineBoyBridgeError.invalidArguments
                }
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        self.reply(requestID, success: try await self.catalogGroup(system: system))
                    } catch {
                        self.reply(requestID, failure: error.localizedDescription)
                    }
                }
            case "toggleFullScreen":
                guard let window else { throw LineBoyBridgeError.windowUnavailable }
                window.toggleFullScreen(nil)
                reply(requestID, success: ["requested": true])
            case "gameTracks":
                reply(requestID, success: try gameTracks(arguments))
            case "playTrack":
                reply(requestID, success: try startTrack(arguments["trackId"] as? String ?? ""))
            case "playPause":
                let wasPlaying = transport.statusSync().isPlaying
                Task { [weak self] in
                    guard let self else { return }
                    _ = await self.transport.setPlaying(!wasPlaying)
                    self.reply(requestID, success: self.playbackStatus())
                }
            case "adjacentTrack":
                reply(requestID, success: adjacentTrack(arguments))
            case "toggleFavorite":
                reply(requestID, success: try toggleFavorite(arguments["trackId"] as? String ?? ""))
            case "chooseFile":
                reply(requestID, success: try chooseFile())
            case "playbackStatus":
                reply(requestID, success: playbackStatus())
            default:
                throw LineBoyBridgeError.unsupportedMethod(method)
            }
        } catch {
            reply(requestID, failure: error.localizedDescription)
        }
    }

    private func catalogBootstrap() async throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: catalogURL.path) else {
            throw LineBoyBridgeError.catalogUnavailable(catalogURL.path)
        }
        let catalogURL = self.catalogURL
        let snapshot = try await Task.detached(priority: .userInitiated) {
            try readLineBoyCatalogBootstrap(at: catalogURL)
        }.value
        return [
            "groups": snapshot.groups.map { group in
                ["name": group.name, "system": group.system, "gameCount": group.gameCount] as [String: Any]
            },
            "displayNames": snapshot.displayNames,
            "gameCount": snapshot.gameCount,
            "trackCount": snapshot.trackCount,
            "favoriteIds": snapshot.favoriteIDs
        ]
    }

    private func catalogGroup(system: String) async throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: catalogURL.path) else {
            throw LineBoyBridgeError.catalogUnavailable(catalogURL.path)
        }
        let catalogURL = self.catalogURL
        let games = try await Task.detached(priority: .userInitiated) {
            try readLineBoyCatalogGames(at: catalogURL, system: system)
        }.value
        return [
            "games": games.map { game in
                [
                    "rootId": game.rootID,
                    "game": game.game,
                    "system": game.system,
                    "displayName": game.displayName,
                    "trackCount": game.trackCount
                ] as [String: Any]
            }
        ]
    }

    private func gameTracks(_ arguments: [String: Any]) throws -> [String: Any] {
        guard let rootID = (arguments["rootId"] as? NSNumber)?.int64Value,
              let game = arguments["game"] as? String,
              let system = arguments["system"] as? String else {
            throw LineBoyBridgeError.invalidArguments
        }
        let catalog = try ReadOnlyCatalog(databaseURL: catalogURL)
        let rows = try catalog.tracks(
            rootID: rootID,
            game: game,
            system: system,
            preferFoldersOverMetadata: true
        )
        let favoriteIDs = Set(try FavoriteStore().snapshots().map(\.identity.id))
        var nextTracks: [String: CatalogTrack] = [:]
        let response = rows.map { track -> [String: Any] in
            let identity = Self.favoriteIdentity(for: track)
            let id = identity.id
            nextTracks[id] = track
            let displayTitle = Self.displayName(for: track)
            let trackNumber = track.trackNumber.flatMap { $0 > 0 ? $0 : nil }
                ?? (track.trackCount > 1 ? track.trackIndex + 1 : 1)
            return [
                "id": id,
                "number": trackNumber,
                "title": displayTitle,
                "lengthMilliseconds": track.lengthMilliseconds,
                "favorite": favoriteIDs.contains(id),
                "displayPath": URL(fileURLWithPath: track.archiveEntry ?? track.sourcePath).lastPathComponent
            ]
        }
        catalogTracks.merge(nextTracks) { _, newest in newest }
        return ["tracks": response]
    }

    private func startTrack(_ id: String) throws -> [String: Any] {
        let requestID = transport.reservePlaybackRequest()
        let startRequest: PlaybackTransportStartRequest
        var resolvedPath: String
        if let track = catalogTracks[id] {
            startRequest = PlaybackTransportStartRequest(
                trackID: id,
                sourcePath: track.sourcePath,
                archivePath: track.archivePath,
                archiveEntry: track.archiveEntry,
                trackIndex: track.trackIndex,
                playMilliseconds: track.lengthMilliseconds,
                fadeMilliseconds: track.fadeLengthMilliseconds
            )
            resolvedPath = track.sourcePath
            if let archivePath = track.archivePath, let archiveEntry = track.archiveEntry {
                guard let requirement = FormatRegistry.archiveMaterializationRequirement(for: [archiveEntry]) else {
                    throw LineBoyBridgeError.unsupportedArchiveEntry(archiveEntry)
                }
                resolvedPath = try materializer.materialize(
                    archiveURL: URL(fileURLWithPath: archivePath),
                    entryPath: archiveEntry,
                    requirement: requirement
                ).path
            }
        } else if let local = localTracks[id] {
            startRequest = PlaybackTransportStartRequest(trackID: id, sourcePath: local.path)
            resolvedPath = local.path
        } else {
            throw LineBoyBridgeError.unknownTrack
        }
        guard transport.isCurrentPlaybackRequest(requestID) else { throw CancellationError() }
        let continuation = try startRequest.continuationStart(resolvedPath: resolvedPath, requestID: requestID)
        try transport.start(continuation)
        return playbackStatus()
    }

    private func adjacentTrack(_ arguments: [String: Any]) -> [String: Any] {
        let ids = arguments["trackIds"] as? [String] ?? []
        let selectedID = arguments["selectedTrackId"] as? String
        let direction = PlaybackQueueDirection(rawValue: arguments["direction"] as? String ?? "next") ?? .next
        let status = transport.statusSync()
        let state = PlaybackQueueState(
            currentTrackID: status.currentTrackID,
            selectedTrackID: selectedID,
            pendingTrackID: nil
        )
        let request = PlaybackQueueAdjacentRequest(
            state: state,
            playlistIDs: ids,
            direction: direction,
            wraps: true
        )
        return ["trackId": request.response.trackID as Any? ?? NSNull()]
    }

    private func toggleFavorite(_ id: String) throws -> [String: Any] {
        guard let track = catalogTracks[id] else { throw LineBoyBridgeError.unknownTrack }
        let identity = Self.favoriteIdentity(for: track)
        let snapshot = FavoriteTrackSnapshot(
            identity: identity,
            filename: URL(fileURLWithPath: track.archiveEntry ?? track.sourcePath).lastPathComponent,
            title: Self.displayName(for: track),
            game: track.game,
            author: track.author,
            system: track.system,
            playLengthMilliseconds: track.lengthMilliseconds
        )
        let result = try FavoriteStore().toggle([snapshot])
        return ["favorite": result.added, "revision": result.revision]
    }

    private func chooseFile() throws -> [String: Any] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Track"
        guard panel.runModal() == .OK, let url = panel.url else { return ["cancelled": true] }
        let path = url.standardizedFileURL.path
        guard FormatRegistry.family(for: path) != nil else {
            throw LineBoyBridgeError.unsupportedFile(url.lastPathComponent)
        }
        let id = "local:\(UUID().uuidString)"
        let title = url.deletingPathExtension().lastPathComponent
        localTracks[id] = LocalTrack(id: id, path: path, title: title)
        return [
            "id": id,
            "number": 1,
            "title": title,
            "lengthMilliseconds": 0,
            "favorite": false,
            "displayPath": url.lastPathComponent
        ]
    }

    private func playbackStatus() -> [String: Any] {
        let status = transport.statusSync()
        return Self.statusDictionary(status)
    }

    private func publishPlaybackStatus(_ status: PlaybackTransportStatus) {
        guard let webView else { return }
        let payload = Self.json(Self.statusDictionary(status))
        webView.evaluateJavaScript("window.__lineBoyNativeEvent('playbackStatus', \(payload));")
    }

    private func reply(_ id: String, success value: Any) {
        guard let webView else { return }
        webView.evaluateJavaScript("window.__lineBoyNativeReply(\(Self.json(id)), true, \(Self.json(value))); ")
    }

    private func reply(_ id: String, failure message: String) {
        guard let webView else { return }
        webView.evaluateJavaScript(
            "window.__lineBoyNativeReply(\(Self.json(id)), false, {message: \(Self.json(message))});"
        )
    }

    private static func favoriteIdentity(for track: CatalogTrack) -> FavoriteTrackIdentity {
        FavoriteTrackIdentity(
            sourcePath: track.sourcePath,
            archiveEntry: track.archiveEntry,
            trackIndex: track.trackIndex,
            trackCount: track.trackCount
        )
    }

    private static func displayName(for track: CatalogTrack) -> String {
        let title = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, title.count <= 120, !title.contains(track.sourcePath) {
            return title
        }
        return URL(fileURLWithPath: track.archiveEntry ?? track.sourcePath)
            .deletingPathExtension().lastPathComponent
    }

    private static func statusDictionary(_ status: PlaybackTransportStatus) -> [String: Any] {
        [
            "currentTrackId": status.currentTrackID as Any? ?? NSNull(),
            "isPlaying": status.isPlaying,
            "trackLoaded": status.trackLoaded,
            "elapsedSeconds": status.elapsedSeconds,
            "error": status.errorMessage as Any? ?? NSNull()
        ]
    }

    private static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let text = String(data: data, encoding: .utf8) else { return "null" }
        return text
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}

private enum LineBoyBridgeError: LocalizedError {
    case catalogUnavailable(String)
    case windowUnavailable
    case invalidArguments
    case unknownTrack
    case unsupportedArchiveEntry(String)
    case unsupportedFile(String)
    case unsupportedMethod(String)

    var errorDescription: String? {
        switch self {
        case .catalogUnavailable:
            return "The shared VGMMan catalog is unavailable. Use FILE to open a track."
        case .windowUnavailable:
            return "The LineBoy window is unavailable."
        case .invalidArguments:
            return "LineBoy received an incomplete request."
        case .unknownTrack:
            return "The selected track is no longer in the current catalog view."
        case .unsupportedArchiveEntry(let entry):
            return "VGMBoy cannot prepare archive member \(entry)."
        case .unsupportedFile(let name):
            return "VGMBoy does not support \(name)."
        case .unsupportedMethod(let method):
            return "LineBoy does not support the \(method) request."
        }
    }
}

let app = NSApplication.shared
let appDelegate = LineBoyAppDelegate()
app.setActivationPolicy(.regular)
app.delegate = appDelegate
app.run()
