import AppKit
import ArchiveCacheCore
import ArchiveMaterializationCore
import CatalogBrowserCore
import CatalogPlaylistCore
import CatalogPlaylistPresentationCore
import CatalogReader
import FavoriteStoreCore
import FavoriteTrackCore
import FrontendPreferencesCore
import Foundation
import PlaylistTabsPersistenceCore
import PlaybackQueueCore
import PlaybackHistoryCore
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
    let searchText: String
}

private struct LineBoyCatalogSearchMatches: Sendable {
    let count: Int
    let games: [LineBoyCatalogGame]
}

private actor LineBoyCatalogSearch {
    private let games: [LineBoyCatalogGame]
    private var browserState = CatalogBrowserState(mode: .consoles)
    private var index: CatalogSearchIndex?

    init(games: [LineBoyCatalogGame]) {
        self.games = games
    }

    func search(_ query: String) -> LineBoyCatalogSearchMatches {
        browserState.setQuery(query)
        guard browserState.view == .search else {
            return LineBoyCatalogSearchMatches(count: 0, games: [])
        }
        if index == nil {
            index = CatalogSearchIndex(searchValues: games.map(\.searchText))
        }
        let matches = index?.matchingIndices(query: browserState.query) ?? []
        return LineBoyCatalogSearchMatches(
            count: matches.count,
            games: matches.prefix(250).map { games[$0] }
        )
    }
}

private struct LineBoyCatalogGroup: Sendable {
    let name: String
    let system: String
    let gameCount: Int
}

private struct LineBoyCatalogBootstrap: Sendable {
    let groups: [LineBoyCatalogGroup]
    let searchGames: [LineBoyCatalogGame]
    let gameCount: Int
    let trackCount: Int
    let favoriteIDs: [String]
}

private struct LineBoyCatalogPlaylistKey: Hashable, Sendable {
    let rootID: Int64
    let game: String
    let system: String
}

private struct LineBoyCatalogPlaylistRead: Sendable {
    let tracks: [CatalogPlaylistTrack]
    let favoriteIDs: Set<String>
}

private struct LineBoyPlaybackSettings: Codable, Equatable {
    static let defaultsKey = "LineBoy.playbackSettings.v1"

    var version = 1
    var longPlayEnabled = false
    var longPlaySeconds = PlaybackTimingPreferences.defaultLongPlaySeconds
    var unknownDurationSeconds = PlaybackTimingPreferences.defaultUnknownDurationSeconds
    var fadeEnabled = true
    var fadeSeconds = PlaybackTimingPreferences.defaultFadeSeconds
    var outputVolume: Float = 1
    var monoEnabled = false
    var equalizerEnabled = false
    var equalizerBandGains = Array(repeating: Float(0), count: EqualizerConfiguration.bandCount)
    var libGmeTempoEnabled = false
    var libGmeTempo = PlaybackTempo.defaultValue
    var libVgmTempoEnabled = false
    var libVgmTempo = PlaybackTempo.defaultValue

    var playbackPreferences: PlaybackPreferences {
        PlaybackPreferences(
            timing: PlaybackTimingPreferences(
                longPlaySeconds: longPlaySeconds,
                unknownDurationSeconds: unknownDurationSeconds,
                fadeSeconds: fadeSeconds
            ),
            fadeEnabled: fadeEnabled,
            equalizerEnabled: equalizerEnabled,
            equalizerBandGains: equalizerBandGains,
            outputVolume: outputVolume,
            monoEnabled: monoEnabled,
            libgmeTempo: libGmeTempo,
            libgmeTempoEnabled: libGmeTempoEnabled,
            libvgmTempo: libVgmTempo,
            libvgmTempoEnabled: libVgmTempoEnabled
        )
    }

    init() {}

    init(longPlayEnabled: Bool, preferences: PlaybackPreferences) {
        self.version = 1
        self.longPlayEnabled = longPlayEnabled
        self.longPlaySeconds = preferences.timing.longPlaySeconds
        self.unknownDurationSeconds = preferences.timing.unknownDurationSeconds
        self.fadeEnabled = preferences.fadeEnabled
        self.fadeSeconds = preferences.timing.fadeSeconds
        self.outputVolume = preferences.outputVolume
        self.monoEnabled = preferences.monoEnabled
        self.equalizerEnabled = preferences.equalizer.enabled
        self.equalizerBandGains = preferences.equalizer.gainsDecibels
        self.libGmeTempoEnabled = preferences.libgmeTempoEnabled
        self.libGmeTempo = preferences.libgmeTempo
        self.libVgmTempoEnabled = preferences.libvgmTempoEnabled
        self.libVgmTempo = preferences.libvgmTempo
    }

    func normalized() -> Self {
        let boundedGME = Self.normalizedTempo(libGmeTempo)
        let boundedVGM = Self.normalizedTempo(libVgmTempo)
        let preferences = PlaybackPreferences(
            timing: PlaybackTimingPreferences(
                longPlaySeconds: min(max(longPlaySeconds, 0), 1_800),
                unknownDurationSeconds: min(max(unknownDurationSeconds, 30), 900),
                fadeSeconds: min(max(fadeSeconds, 0), 30)
            ),
            fadeEnabled: fadeEnabled,
            equalizerEnabled: equalizerEnabled,
            equalizerBandGains: equalizerBandGains,
            outputVolume: Float(FrontendPlaybackVolumeScale.normalized(Double(outputVolume))),
            monoEnabled: monoEnabled,
            libgmeTempo: boundedGME,
            libgmeTempoEnabled: libGmeTempoEnabled,
            libvgmTempo: boundedVGM,
            libvgmTempoEnabled: libVgmTempoEnabled
        )
        return Self(longPlayEnabled: longPlayEnabled, preferences: preferences)
    }

    func tempo(for family: DecoderFamily?) -> PlaybackTempo {
        switch family?.id {
        case FormatRegistry.libgmeFamily.id where libGmeTempoEnabled: libGmeTempo
        case FormatRegistry.libvgmFamily.id where libVgmTempoEnabled: libVgmTempo
        default: .defaultValue
        }
    }

    static func restore() -> Self {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(Self.self, from: data),
              value.version == 1 else { return Self() }
        return value.normalized()
    }

    var bridgeValue: [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }

    private static func normalizedTempo(_ value: PlaybackTempo) -> PlaybackTempo {
        let numerator = min(max(value.numerator, 1), PlaybackTempo.maxComponent)
        let denominator = min(max(value.denominator, 1), PlaybackTempo.maxComponent)
        return PlaybackTempo(numerator: numerator, denominator: denominator)
    }
}

private func readLineBoyCatalogBootstrap(at catalogURL: URL) throws -> LineBoyCatalogBootstrap {
    let catalog = try ReadOnlyCatalog(databaseURL: catalogURL)
    let projection = CatalogBrowserProjection.games(from: try catalog.gameBuckets())
    let searchGames = projection.map(lineBoyCatalogGame)
    let groups = CatalogBrowserProjection.groupSummaries(from: projection).map { group in
        LineBoyCatalogGroup(
            name: group.name,
            system: group.system,
            gameCount: group.gameCount
        )
    }
    let favorites = Set(try FavoriteStore().snapshots().map(\.identity.id))
    return LineBoyCatalogBootstrap(
        groups: groups,
        searchGames: searchGames,
        gameCount: projection.count,
        trackCount: projection.reduce(into: 0) { $0 += $1.trackCount },
        favoriteIDs: Array(favorites)
    )
}

private func lineBoyCatalogGame(_ game: CatalogBrowserGame) -> LineBoyCatalogGame {
    LineBoyCatalogGame(
        rootID: game.rootID,
        game: game.name,
        system: game.system,
        displayName: game.displayName,
        trackCount: game.trackCount,
        searchText: game.searchText
    )
}

@MainActor
final class LineBoyAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var bridge: LineBoyNativeBridge?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        installMainMenu()
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

    private func installMainMenu() {
        let mainMenu = NSMenu(title: "LineBoy")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "LineBoy")
        appMenuItem.title = "LineBoy"
        appMenu.addItem(menuItem("About LineBoy", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Options…", action: #selector(showOptions(_:)), key: ",", target: self))
        appMenu.addItem(.separator())
        let servicesMenu = NSMenu(title: "Services")
        NSApp.servicesMenu = servicesMenu
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Hide LineBoy", action: #selector(NSApplication.hide(_:)), key: "h", target: NSApp))
        appMenu.addItem(menuItem(
            "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            key: "h",
            modifiers: [.command, .option],
            target: NSApp
        ))
        appMenu.addItem(menuItem("Show All", action: #selector(NSApplication.unhideAllApplications(_:)), target: NSApp))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Quit LineBoy", action: #selector(NSApplication.terminate(_:)), key: "q", target: NSApp))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.title = "File"
        fileMenu.addItem(menuItem("Open…", action: #selector(openFile(_:)), key: "o", target: self))
        fileMenu.addItem(menuItem("New Playlist Tab", action: #selector(newPlaylistTab(_:)), key: "t", target: self))
        let tabSelectionItem = NSMenuItem(title: "Select Playlist Tab", action: nil, keyEquivalent: "")
        let tabSelectionMenu = NSMenu(title: "Select Playlist Tab")
        for number in 1...9 {
            let item = menuItem("Tab \(number)", action: #selector(selectPlaylistTab(_:)), key: String(number), target: self)
            item.tag = number
            tabSelectionMenu.addItem(item)
        }
        tabSelectionItem.submenu = tabSelectionMenu
        fileMenu.addItem(tabSelectionItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem("Close Window", action: #selector(NSWindow.performClose(_:)), key: "w"))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.title = "Edit"
        editMenu.addItem(menuItem("Find in Library", action: #selector(findInLibrary(_:)), key: "f", target: self))
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem("Undo", action: NSSelectorFromString("undo:"), key: "z"))
        editMenu.addItem(menuItem("Redo", action: NSSelectorFromString("redo:"), key: "z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem("Cut", action: NSSelectorFromString("cut:"), key: "x"))
        editMenu.addItem(menuItem("Copy", action: NSSelectorFromString("copy:"), key: "c"))
        editMenu.addItem(menuItem("Paste", action: NSSelectorFromString("paste:"), key: "v"))
        editMenu.addItem(menuItem("Select All", action: NSSelectorFromString("selectAll:"), key: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.title = "View"
        viewMenu.addItem(menuItem(
            "Favorites Playlist",
            action: #selector(showFavoritesPlaylist(_:)),
            key: "f",
            modifiers: [.command, .shift],
            target: self
        ))
        viewMenu.addItem(menuItem(
            "Recent Playback",
            action: #selector(showRecentPlayback(_:)),
            key: "h",
            modifiers: [.command, .shift],
            target: self
        ))
        viewMenu.addItem(.separator())
        viewMenu.addItem(menuItem(
            "Toggle Full Screen",
            action: #selector(NSWindow.toggleFullScreen(_:)),
            key: "f",
            modifiers: [.command, .control]
        ))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.title = "Window"
        windowMenu.addItem(menuItem("Minimize", action: #selector(NSWindow.miniaturize(_:)), key: "m"))
        windowMenu.addItem(menuItem("Zoom", action: #selector(NSWindow.performZoom(_:))))
        windowMenu.addItem(.separator())
        windowMenu.addItem(menuItem("Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), target: NSApp))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = mainMenu
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        return item
    }

    @objc private func showOptions(_ sender: Any?) {
        clickToolbarAction("OPTIONS")
    }

    @objc private func showFavoritesPlaylist(_ sender: Any?) {
        clickToolbarAction("FAVORITES")
    }

    @objc private func showRecentPlayback(_ sender: Any?) {
        clickToolbarAction("RECENT")
    }

    @objc private func openFile(_ sender: Any?) {
        clickToolbarAction("OPEN")
    }

    @objc private func newPlaylistTab(_ sender: Any?) {
        guard let webView = window?.contentView as? WKWebView else { return }
        webView.evaluateJavaScript("window.__lineBoyCreatePlaylistTab?.();")
    }

    @objc private func selectPlaylistTab(_ sender: NSMenuItem) {
        guard let webView = window?.contentView as? WKWebView else { return }
        webView.evaluateJavaScript("window.__lineBoySelectPlaylistTab?.(\(sender.tag));")
    }

    @objc private func findInLibrary(_ sender: Any?) {
        guard let webView = window?.contentView as? WKWebView else { return }
        webView.evaluateJavaScript("window.__lineBoyFocusSearch?.();")
    }

    private func clickToolbarAction(_ action: String) {
        guard let webView = window?.contentView as? WKWebView,
              ["OPEN", "OPTIONS", "FAVORITES", "RECENT"].contains(action) else { return }
        webView.evaluateJavaScript("document.querySelector('[data-action=\"\(action)\"]')?.click();")
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
    private let playlistTabsStore = PlaylistTabsJSONFileStore(
        fileURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LineBoy", isDirectory: true)
            .appendingPathComponent("playlist-tabs-v1.json")
    )
    private var catalogTracks: [String: CatalogPlaylistTrack] = [:]
    private var localTracks: [String: LocalTrack] = [:]
    private var catalogPlaylists: [LineBoyCatalogPlaylistKey: [CatalogPlaylistTrack]] = [:]
    private var catalogPlaylistRecency: [LineBoyCatalogPlaylistKey] = []
    private var catalogSortSessions: [String: [String: CatalogPlaylistSortRecord]] = [:]
    private var catalogSortSessionOrder: [String] = []
    private var catalogGroups: [String: [LineBoyCatalogGame]] = [:]
    private var catalogSearch: LineBoyCatalogSearch?
    private let catalogPlaylistCacheLimit = 8
    private var playbackSettings = LineBoyPlaybackSettings.restore()
    private var activePlaybackMetadata: PlaybackTimingMetadata?
    private var activePlaybackFamily: DecoderFamily?
    private weak var webView: WKWebView?
    private weak var window: NSWindow?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        transport.setStatusHandler { [weak self] status in
            Task { @MainActor [weak self] in self?.publishPlaybackStatus(status) }
        }
        try? applyAudioSettings(playbackSettings)
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
            case "catalogSearch":
                guard let query = arguments["query"] as? String else {
                    throw LineBoyBridgeError.invalidArguments
                }
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        self.reply(requestID, success: try await self.searchCatalog(query: query))
                    } catch {
                        self.reply(requestID, failure: error.localizedDescription)
                    }
                }
            case "playlistTabsLoad":
                reply(requestID, success: try loadPlaylistTabs())
            case "playlistTabsSave":
                guard let snapshot = arguments["snapshot"] else {
                    throw LineBoyBridgeError.invalidArguments
                }
                try savePlaylistTabs(snapshot)
                reply(requestID, success: ["saved": true])
            case "toggleFullScreen":
                guard let window else { throw LineBoyBridgeError.windowUnavailable }
                window.toggleFullScreen(nil)
                reply(requestID, success: ["requested": true])
            case "gameTracks":
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        self.reply(requestID, success: try await self.gameTracks(arguments))
                    } catch {
                        self.reply(requestID, failure: error.localizedDescription)
                    }
                }
            case "databasePlaylistSort":
                reply(requestID, success: try sortCatalogPlaylist(arguments))
            case "playlistProjectionSort":
                reply(requestID, success: try sortPlaylistProjection(arguments))
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
            case "favoritesList":
                reply(requestID, success: try favoritesPlaylist())
            case "playbackHistoryList":
                reply(requestID, success: try recentPlaylist())
            case "chooseFile":
                reply(requestID, success: try chooseFile())
            case "playbackStatus":
                reply(requestID, success: playbackStatus())
            case "playbackSettingsLoad":
                reply(requestID, success: playbackSettings.bridgeValue)
            case "playbackAudioApply":
                let settings = try decodePlaybackSettings(arguments["settings"])
                try applyAudioSettings(settings)
                playbackSettings = settings
                reply(requestID, success: ["applied": true])
            case "playbackSettingsSave":
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        self.reply(requestID, success: try await self.savePlaybackSettings(arguments["settings"]))
                    } catch {
                        self.reply(requestID, failure: error.localizedDescription)
                    }
                }
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
        catalogGroups = Dictionary(grouping: snapshot.searchGames, by: \.system)
        catalogSearch = LineBoyCatalogSearch(games: snapshot.searchGames)
        return [
            "groups": snapshot.groups.map { group in
                ["name": group.name, "system": group.system, "gameCount": group.gameCount] as [String: Any]
            },
            "gameCount": snapshot.gameCount,
            "trackCount": snapshot.trackCount,
            "favoriteIds": snapshot.favoriteIDs
        ]
    }

    private func searchCatalog(query: String) async throws -> [String: Any] {
        guard let catalogSearch else { throw LineBoyBridgeError.catalogUnavailable(catalogURL.path) }
        let result = await catalogSearch.search(query)
        return [
            "count": result.count,
            "games": result.games.map { game in
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

    private func loadPlaylistTabs() throws -> Any {
        guard let data = try playlistTabsStore.load() else { return NSNull() }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func savePlaylistTabs(_ snapshot: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
        try playlistTabsStore.save(data)
    }

    private func catalogGroup(system: String) async throws -> [String: Any] {
        guard let games = catalogGroups[system] else {
            throw LineBoyBridgeError.catalogUnavailable(catalogURL.path)
        }
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

    private func gameTracks(_ arguments: [String: Any]) async throws -> [String: Any] {
        guard let rootID = (arguments["rootId"] as? NSNumber)?.int64Value,
              let game = arguments["game"] as? String,
              let system = arguments["system"] as? String else {
            throw LineBoyBridgeError.invalidArguments
        }
        let key = LineBoyCatalogPlaylistKey(rootID: rootID, game: game, system: system)
        let rows: [CatalogPlaylistTrack]
        let favoriteIDs: Set<String>
        if let cachedRows = catalogPlaylists[key] {
            rows = cachedRows
            favoriteIDs = try await Task.detached(priority: .utility) {
                Set(try FavoriteStore().snapshots().map(\.identity.id))
            }.value
            catalogPlaylistRecency.removeAll { $0 == key }
            catalogPlaylistRecency.append(key)
        } else {
            let catalogURL = self.catalogURL
            let result = try await Task.detached(priority: .userInitiated) {
                let tracks = try CatalogPlaylistReader.tracksForGames(
                    databaseURL: catalogURL,
                    selections: [CatalogPlaylistGameSelection(rootID: rootID, game: game, system: system)],
                    preferFoldersOverMetadata: true
                )
                let favoriteIDs = Set(try FavoriteStore().snapshots().map(\.identity.id))
                return LineBoyCatalogPlaylistRead(tracks: tracks, favoriteIDs: favoriteIDs)
            }.value
            rows = result.tracks
            favoriteIDs = result.favoriteIDs
            catalogPlaylists[key] = rows
            catalogPlaylistRecency.removeAll { $0 == key }
            catalogPlaylistRecency.append(key)
            while catalogPlaylistRecency.count > catalogPlaylistCacheLimit {
                let expired = catalogPlaylistRecency.removeFirst()
                catalogPlaylists.removeValue(forKey: expired)
            }
        }

        var nextTracks: [String: CatalogPlaylistTrack] = [:]
        rows.forEach { track in
            let identity = Self.favoriteIdentity(for: track)
            nextTracks[identity.id] = track
        }
        catalogTracks.removeAll(keepingCapacity: true)
        for expired in catalogPlaylistRecency {
            for track in catalogPlaylists[expired] ?? [] {
                let identity = Self.favoriteIdentity(for: track)
                catalogTracks[identity.id] = track
            }
        }
        catalogTracks.merge(nextTracks) { _, newest in newest }

        let projection = CatalogPlaylistPresentation.project(tracks: rows)
        let sortSessionID = UUID().uuidString
        catalogSortSessions[sortSessionID] = Dictionary(
            projection.rows.enumerated().map { offset, track in
                let identity = FavoriteTrackIdentity(
                    sourcePath: track.sourcePath,
                    archiveEntry: track.archiveEntry,
                    trackIndex: track.trackIndex,
                    trackCount: track.trackCount
                )
                return (identity.id, CatalogPlaylistSortRecord(
                    id: identity.id,
                    naturalOrder: offset,
                    fileText: track.display.fileText,
                    titleText: track.display.titleText,
                    gameText: track.display.gameText,
                    authorText: track.display.authorText,
                    systemText: track.display.systemText,
                    pathText: track.archiveEntry.map { "\(track.archivePath ?? track.sourcePath)#\($0)" }
                        ?? track.sourcePath,
                    lengthMilliseconds: track.lengthMilliseconds,
                    trackNumber: track.trackNumber
                ))
            }, uniquingKeysWith: { first, _ in first }
        )
        catalogSortSessionOrder.append(sortSessionID)
        while catalogSortSessionOrder.count > 8 {
            catalogSortSessions.removeValue(forKey: catalogSortSessionOrder.removeFirst())
        }
        let response = projection.rows.map { track -> [String: Any] in
            let identity = FavoriteTrackIdentity(
                sourcePath: track.sourcePath,
                archiveEntry: track.archiveEntry,
                trackIndex: track.trackIndex,
                trackCount: track.trackCount
            )
            let id = identity.id
            let trackNumber = track.trackNumber.flatMap { $0 > 0 ? $0 : nil }
                ?? (track.trackCount > 1 ? track.trackIndex + 1 : 1)
            let sourceURL = URL(fileURLWithPath: track.sourcePath)
            let path = track.archiveEntry.map { "\(track.archivePath ?? track.sourcePath)#\($0)" }
                ?? sourceURL.path
            return [
                "id": id,
                "number": trackNumber,
                "trackNumber": track.trackNumber as Any? ?? NSNull(),
                "fileText": track.display.fileText,
                "title": track.display.titleText,
                "game": track.display.gameText,
                "author": track.display.authorText,
                "system": track.display.systemText,
                "path": path,
                "lengthMilliseconds": track.lengthMilliseconds,
                "length": track.display.lengthText,
                "favorite": favoriteIDs.contains(id),
                "displayPath": track.display.sourceFilename
            ]
        }
        let hints = projection.columnContentHints
        return [
            "tracks": response,
            "sortSessionId": sortSessionID,
            "columnContentHints": [
                "index": hints.indexText,
                "filename": hints.fileText,
                "title": hints.titleText,
                "game": hints.gameText,
                "artist": hints.authorText,
                "system": hints.systemText,
                "path": hints.pathText,
                "lengthLabel": hints.lengthText
            ]
        ]
    }

    private func startTrack(_ id: String) throws -> [String: Any] {
        let requestID = transport.reservePlaybackRequest()
        var resolvedPath: String
        var metadata: PlaybackTimingMetadata?
        var family: DecoderFamily?
        let catalogTrack = catalogTracks[id]
        var historySnapshot: FavoriteTrackSnapshot?
        if let track = catalogTracks[id] {
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
            family = FormatRegistry.family(for: resolvedPath)
            metadata = PlaybackTimingMetadata(
                playMilliseconds: track.lengthMilliseconds,
                introMilliseconds: track.introLengthMilliseconds,
                loopMilliseconds: track.loopLengthMilliseconds
            )
            historySnapshot = Self.favoriteSnapshot(for: track)
        } else if let local = localTracks[id] {
            resolvedPath = local.path
            family = FormatRegistry.family(for: resolvedPath)
            historySnapshot = FavoriteTrackSnapshot(
                identity: FavoriteTrackIdentity(sourcePath: local.path),
                filename: URL(fileURLWithPath: local.path).lastPathComponent,
                title: local.title
            )
        } else if id.hasPrefix("local:") {
            let path = String(id.dropFirst("local:".count))
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.path == path,
                  FileManager.default.fileExists(atPath: path),
                  FormatRegistry.family(for: path) != nil else {
                throw LineBoyBridgeError.localFileUnavailable(url.lastPathComponent)
            }
            localTracks[id] = LocalTrack(id: id, path: path, title: url.deletingPathExtension().lastPathComponent)
            resolvedPath = path
            family = FormatRegistry.family(for: resolvedPath)
            historySnapshot = FavoriteTrackSnapshot(
                identity: FavoriteTrackIdentity(sourcePath: path),
                filename: url.lastPathComponent,
                title: url.deletingPathExtension().lastPathComponent
            )
        } else {
            throw LineBoyBridgeError.unknownTrack
        }
        guard transport.isCurrentPlaybackRequest(requestID) else { throw CancellationError() }
        let preferences = playbackSettings.playbackPreferences
        let plan = PlaybackTimingPolicy.plan(
            metadata: metadata,
            family: family,
            longPlayEnabled: playbackSettings.longPlayEnabled,
            preferences: Self.effectiveTimingPreferences(preferences)
        )
        let tempo = playbackSettings.tempo(for: family)
        let configuredRequest = PlaybackTransportStartRequest(
            trackID: id,
            sourcePath: catalogTrack?.sourcePath ?? resolvedPath,
            archivePath: catalogTrack?.archivePath,
            archiveEntry: catalogTrack?.archiveEntry,
            trackIndex: catalogTrack?.trackIndex ?? 0,
            playMilliseconds: plan.preFadeSeconds * 1_000,
            fadeMilliseconds: plan.fadeSeconds * 1_000,
            tempo: tempo,
            longPlayEnabled: plan.isLongPlay,
            unknownDurationMilliseconds: plan.unknownDurationSeconds * 1_000
        )
        let continuation = try configuredRequest.continuationStart(resolvedPath: resolvedPath, requestID: requestID)
        try transport.start(continuation)
        if let historySnapshot {
            Task.detached(priority: .utility) {
                _ = try? PlaybackHistoryStore().record(historySnapshot)
            }
        }
        activePlaybackMetadata = metadata
        activePlaybackFamily = family
        return playbackStatus()
    }

    private func decodePlaybackSettings(_ value: Any?) throws -> LineBoyPlaybackSettings {
        guard let value = value as? [String: Any], JSONSerialization.isValidJSONObject(value) else {
            throw LineBoyBridgeError.invalidArguments
        }
        let data = try JSONSerialization.data(withJSONObject: value)
        let settings = try JSONDecoder().decode(LineBoyPlaybackSettings.self, from: data)
        guard settings.version == 1 else { throw LineBoyBridgeError.invalidArguments }
        return settings.normalized()
    }

    private func applyAudioSettings(_ settings: LineBoyPlaybackSettings) throws {
        let preferences = settings.playbackPreferences
        _ = try transport.configureAudio(PlaybackTransportAudioConfigurationRequest(
            outputVolume: preferences.outputVolume,
            equalizerEnabled: preferences.equalizer.enabled,
            equalizerBandGains: preferences.equalizer.gainsDecibels,
            monoEnabled: preferences.monoEnabled
        ))
    }

    private static func effectiveTimingPreferences(_ preferences: PlaybackPreferences) -> PlaybackTimingPreferences {
        PlaybackTimingPreferences(
            longPlaySeconds: preferences.timing.longPlaySeconds,
            unknownDurationSeconds: preferences.timing.unknownDurationSeconds,
            fadeSeconds: preferences.fadeSeconds
        )
    }

    private func savePlaybackSettings(_ value: Any?) async throws -> [String: Any] {
        let next = try decodePlaybackSettings(value)
        let previous = playbackSettings
        try applyAudioSettings(next)
        playbackSettings = next
        UserDefaults.standard.set(try JSONEncoder().encode(next), forKey: LineBoyPlaybackSettings.defaultsKey)

        let timingChanged = previous.longPlayEnabled != next.longPlayEnabled
            || previous.longPlaySeconds != next.longPlaySeconds
            || previous.unknownDurationSeconds != next.unknownDurationSeconds
            || previous.fadeEnabled != next.fadeEnabled
            || previous.fadeSeconds != next.fadeSeconds
            || previous.libGmeTempoEnabled != next.libGmeTempoEnabled
            || previous.libGmeTempo != next.libGmeTempo
            || previous.libVgmTempoEnabled != next.libVgmTempoEnabled
            || previous.libVgmTempo != next.libVgmTempo
        if timingChanged, transport.statusSync().trackLoaded, let family = activePlaybackFamily {
            let preferences = next.playbackPreferences
            let plan = PlaybackTimingPolicy.plan(
                metadata: activePlaybackMetadata,
                family: family,
                longPlayEnabled: next.longPlayEnabled,
                preferences: Self.effectiveTimingPreferences(preferences)
            )
            let tempo = next.tempo(for: family)
            try await transport.reconfigureCurrentTrack(plan: plan, tempo: tempo)
        }
        return next.bridgeValue
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

    private func sortCatalogPlaylist(_ arguments: [String: Any]) throws -> [String] {
        guard let sessionID = arguments["sessionId"] as? String,
              let records = catalogSortSessions[sessionID],
              let ids = arguments["ids"] as? [String],
              ids.count == records.count,
              Set(ids).count == ids.count,
              Set(ids) == Set(records.keys),
              let columnName = arguments["column"] as? String,
              let column = CatalogPlaylistSortColumn(frontendColumn: columnName),
              let directionName = arguments["direction"] as? String,
              let direction = CatalogPlaylistSortDirection(rawValue: directionName) else {
            throw LineBoyBridgeError.invalidArguments
        }
        return CatalogPlaylistSorting.orderedIDs(
            records: ids.compactMap { records[$0] },
            column: column,
            direction: direction
        )
    }

    private func sortPlaylistProjection(_ arguments: [String: Any]) throws -> [String] {
        guard JSONSerialization.isValidJSONObject(arguments) else {
            throw LineBoyBridgeError.invalidArguments
        }
        let request = try JSONDecoder().decode(
            CatalogPlaylistSortRequest.self,
            from: JSONSerialization.data(withJSONObject: arguments)
        )
        guard let column = request.column,
              Set(request.records.map(\.id)).count == request.records.count else {
            throw LineBoyBridgeError.invalidArguments
        }
        return CatalogPlaylistSorting.orderedIDs(
            records: request.records,
            column: column,
            direction: request.direction
        )
    }

    private func toggleFavorite(_ id: String) throws -> [String: Any] {
        guard let track = catalogTracks[id] else { throw LineBoyBridgeError.unknownTrack }
        let snapshot = Self.favoriteSnapshot(for: track)
        let result = try FavoriteStore().toggle([snapshot])
        return ["favorite": result.added, "revision": result.revision]
    }

    private func favoritesPlaylist() throws -> [String: Any] {
        let snapshots = try FavoriteStore().snapshots()
        return ["tracks": snapshots.map { storedPlaylistTrack($0, id: $0.identity.id, isFavorite: true) }]
    }

    private func recentPlaylist() throws -> [String: Any] {
        let favoriteIDs = Set(try FavoriteStore().snapshots().map(\.identity.id))
        let records = try PlaybackHistoryStore().records()
        return ["tracks": records.map { record in
            storedPlaylistTrack(
                record.snapshot,
                id: record.id,
                isFavorite: favoriteIDs.contains(record.snapshot.identity.id),
                timestampMilliseconds: record.timestampMilliseconds
            )
        }]
    }

    private func storedPlaylistTrack(
        _ snapshot: FavoriteTrackSnapshot,
        id: String,
        isFavorite: Bool,
        timestampMilliseconds: Int64? = nil
    ) -> [String: Any] {
        let identity = snapshot.identity
        let track = CatalogPlaylistTrack(
            sourcePath: identity.sourcePath,
            archivePath: identity.archiveEntry == nil ? nil : identity.sourcePath,
            archiveEntry: identity.archiveEntry,
            trackIndex: identity.trackIndex,
            trackCount: identity.trackCount,
            trackNumber: identity.trackCount > 1 ? identity.trackIndex + 1 : nil,
            title: snapshot.title,
            game: snapshot.game,
            author: snapshot.author,
            system: snapshot.system,
            comment: "",
            introLengthMilliseconds: 0,
            loopLengthMilliseconds: 0,
            lengthMilliseconds: snapshot.playLengthMilliseconds,
            fadeLengthMilliseconds: 0
        )
        catalogTracks[id] = track
        let row = CatalogPlaylistPresentation.project(tracks: [track]).rows[0]
        let path = identity.archiveEntry.map { "\(identity.sourcePath)#\($0)" } ?? identity.sourcePath
        var response: [String: Any] = [
            "id": id,
            "number": track.trackNumber ?? 1,
            "trackNumber": track.trackNumber as Any? ?? NSNull(),
            "fileText": row.display.fileText,
            "title": row.display.titleText,
            "game": row.display.gameText,
            "author": row.display.authorText,
            "system": row.display.systemText,
            "path": path,
            "lengthMilliseconds": track.lengthMilliseconds,
            "length": row.display.lengthText,
            "favorite": isFavorite,
            "displayPath": row.display.sourceFilename,
            "native": true
        ]
        if let timestampMilliseconds {
            response["timestampMilliseconds"] = timestampMilliseconds
        }
        return response
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
        let id = "local:\(path)"
        let title = url.deletingPathExtension().lastPathComponent
        localTracks[id] = LocalTrack(id: id, path: path, title: title)
        return [
            "id": id,
            "number": 1,
            "fileText": url.lastPathComponent,
            "title": title,
            "game": title,
            "author": "—",
            "system": "—",
            "path": path,
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

    private static func favoriteIdentity(for track: CatalogPlaylistTrack) -> FavoriteTrackIdentity {
        FavoriteTrackIdentity(
            sourcePath: track.sourcePath,
            archiveEntry: track.archiveEntry,
            trackIndex: track.trackIndex,
            trackCount: track.trackCount
        )
    }

    private static func favoriteSnapshot(for track: CatalogPlaylistTrack) -> FavoriteTrackSnapshot {
        FavoriteTrackSnapshot(
            identity: favoriteIdentity(for: track),
            filename: URL(fileURLWithPath: track.archiveEntry ?? track.sourcePath).lastPathComponent,
            title: displayName(for: track),
            game: track.game,
            author: track.author,
            system: track.system,
            playLengthMilliseconds: track.lengthMilliseconds
        )
    }

    private static func displayName(for track: CatalogPlaylistTrack) -> String {
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
    case localFileUnavailable(String)
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
        case .localFileUnavailable(let name):
            return "The saved local track \(name) is unavailable or no longer supported."
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
