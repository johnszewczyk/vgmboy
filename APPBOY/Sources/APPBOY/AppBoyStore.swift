import CatalogBrowserCore
import CatalogGalleryCore
import CatalogPlaylistCore
import CatalogPlaylistPresentationCore
import CatalogReader
import FavoriteStoreCore
import FavoriteTrackCore
import Foundation
import FrontendPreferencesCore
import PlaybackHistoryCore
import PlaylistTabsPersistenceCore
import VGMBoyEmbeddedCore

struct AppBoyRemoteCatalogPayload: Codable, Sendable {
    let sourceLabel: String?
    let consoles: [AppBoyConsoleGroup]
    let tracks: [AppBoyTrack]
}

@MainActor
final class AppBoyStore {
    private static let sharedPrefsKeys = FrontendPreferencesKeySet(
        autoResizeEnabledKey: "appboy.autoResizeEnabled",
        selectionEnabledKey: "appboy.selectionAnimationEnabled",
        autoResizeMillisecondsKey: "appboy.autoResizeMilliseconds",
        selectionMillisecondsKey: "appboy.selectionAnimationMilliseconds",
        columnAutoSizeKey: "appboy.columnAutoSize",
        mainWindowAlwaysOnTopKey: "appboy.mainAlwaysOnTop",
        settingsWindowAlwaysOnTopKey: "appboy.settingsAlwaysOnTop"
    )

    private struct CatalogAlbumHydrationDescriptor {
        let selection: CatalogPlaylistGameSelection
        let storedRootPath: String
        let consoleId: String
        let consoleName: String
        let albumTitle: String
    }

    private let supportDirectory: URL
    private let documentsDirectory: URL
    private let sharedPrefsStore: FrontendPreferencesStore
    private let favoriteStore: FavoriteStore?
    private let historyStore: PlaybackHistoryStore?

    private(set) var preferences: AppBoyPreferencesSnapshot
    private(set) var workspace: AppBoyWorkspaceSnapshot
    private(set) var catalog: AppBoyCatalogSnapshot

    private var activeCatalogDatabaseURL: URL?
    private var activeDataPackRootURL: URL?
    private var albumsById: [String: AppBoyAlbum] = [:]
    private var tracksById: [String: AppBoyTrack] = [:]
    private var tracksByAlbumId: [String: [AppBoyTrack]] = [:]
    private var hydrationDescriptors: [String: CatalogAlbumHydrationDescriptor] = [:]
    private var artworkCache: [String: String] = [:]
    private var artworkCacheOrder: [String] = []
    private let maxCachedArtworks = 160

    init() {
        let fm = FileManager.default
        let appSupportBase = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let supportDir = appSupportBase.appendingPathComponent("APPBOY", isDirectory: true)
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.supportDirectory = supportDir
        self.documentsDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? supportDir

        let sharedStore = FrontendPreferencesStore(keys: Self.sharedPrefsKeys)
        self.sharedPrefsStore = sharedStore

        self.favoriteStore = try? FavoriteStore(
            databaseURL: supportDir.appendingPathComponent("UserData.sqlite")
        )
        self.historyStore = try? PlaybackHistoryStore(
            fileURL: supportDir.appendingPathComponent("PlaybackHistory.json")
        )

        var loadedPrefs: AppBoyPreferencesSnapshot = Self.readJSON(
            from: supportDir.appendingPathComponent("preferences.json")
        ) ?? AppBoyPreferencesSnapshot()
        loadedPrefs.normalize()
        self.preferences = loadedPrefs

        self.catalog = AppBoyCatalogSnapshot(
            sourceLabel: "Starter Catalog",
            databasePath: "",
            schemaVersion: 0,
            consoleCount: 0,
            albumCount: 0,
            trackCount: 0,
            artworkCount: 0,
            consoles: []
        )
        self.workspace = AppBoyWorkspaceSnapshot(activeTabId: "tab-1", tabs: [])

        self.syncSharedFrontendPreferences(from: loadedPrefs)
        self.loadLocalOrBundledCatalog()

        if let savedWorkspace: AppBoyWorkspaceSnapshot = Self.readJSON(
            from: supportDir.appendingPathComponent("playlist-tabs.json")
        ), !savedWorkspace.tabs.isEmpty {
            let validSaved = savedWorkspace.tabs.contains { tab in
                switch tab.sourceKind {
                case "favorites", "history":
                    return true
                case "album":
                    guard let albumId = tab.sourceId else { return false }
                    return self.albumsById[albumId] != nil
                default:
                    return !tab.trackIds.isEmpty
                }
            }
            if validSaved {
                self.workspace = savedWorkspace
            } else {
                self.workspace = self.makeDefaultWorkspace()
            }
        } else {
            self.workspace = self.makeDefaultWorkspace()
        }
    }

    private func makeDefaultWorkspace() -> AppBoyWorkspaceSnapshot {
        let firstAlbum = catalog.consoles.first?.albums.first
        let initialTracks = firstAlbum.map { tracks(forAlbumId: $0.id) } ?? []
        let tab = AppBoyPlaylistTab(
            id: "tab-1",
            title: firstAlbum?.title ?? "Playlist",
            consoleName: firstAlbum?.consoleName ?? "SNES",
            sourceKind: "album",
            sourceId: firstAlbum?.id,
            trackIds: initialTracks.map(\.id),
            selectedTrackId: initialTracks.first?.id
        )
        return AppBoyWorkspaceSnapshot(activeTabId: tab.id, tabs: [tab])
    }

    func album(for id: String) -> AppBoyAlbum? {
        albumsById[id]
    }

    func track(for id: String) -> AppBoyTrack? {
        if let cached = tracksById[id] {
            return cached
        }
        if let favSnap = (try? favoriteStore?.snapshots())?.first(where: { $0.identity.id == id }) {
            let hydrated = trackFromSnapshot(favSnap)
            tracksById[hydrated.id] = hydrated
            return hydrated
        }
        if let histRec = (try? historyStore?.records())?.first(where: { $0.snapshot.identity.id == id }) {
            let hydrated = trackFromSnapshot(histRec.snapshot)
            tracksById[hydrated.id] = hydrated
            return hydrated
        }
        return nil
    }

    func tracks(forAlbumId albumId: String) -> [AppBoyTrack] {
        if let cached = tracksByAlbumId[albumId] {
            return cached
        }
        guard let descriptor = hydrationDescriptors[albumId],
              let dbURL = activeCatalogDatabaseURL else {
            return []
        }
        do {
            let rawTracks = try CatalogPlaylistReader.tracksForGames(
                databaseURL: dbURL,
                selections: [descriptor.selection],
                preferFoldersOverMetadata: true
            )
            let projection = CatalogPlaylistPresentation.project(tracks: rawTracks)
            var hydrated: [AppBoyTrack] = []
            hydrated.reserveCapacity(projection.rows.count)

            for (idx, row) in projection.rows.enumerated() {
                let rawContainer = row.archivePath ?? row.sourcePath
                let relocatedContainer = relocateCatalogPath(
                    rawContainer,
                    storedRootPath: descriptor.storedRootPath
                )
                let canonicalSource = canonicalIdentityPath(
                    rawContainer,
                    storedRootPath: descriptor.storedRootPath
                )
                let favIdentity = FavoriteTrackIdentity(
                    sourcePath: canonicalSource,
                    archiveEntry: row.archiveEntry,
                    trackIndex: row.trackIndex,
                    trackCount: row.trackCount
                )
                let formatExt = URL(fileURLWithPath: row.display.sourceFilename).pathExtension.uppercased()
                let resolvedDuration: Double
                if row.lengthMilliseconds > 0 {
                    resolvedDuration = Double(row.lengthMilliseconds) / 1_000.0
                } else if row.loopLengthMilliseconds > 0 {
                    let safeIntro = max(0, row.introLengthMilliseconds)
                    resolvedDuration = Double(safeIntro + row.loopLengthMilliseconds * 2) / 1_000.0
                } else {
                    resolvedDuration = 150.0
                }

                let cleanArtist = row.display.authorText == "—" ? "" : row.display.authorText
                let cleanYear = row.display.yearText == "—" ? "" : row.display.yearText
                let cleanDumper = row.display.dumperText == "—" ? "" : row.display.dumperText
                let isUACArchive = URL(fileURLWithPath: relocatedContainer).pathExtension.lowercased() == "uac"
                    && row.archiveEntry != nil

                let track = AppBoyTrack(
                    id: favIdentity.id,
                    albumId: albumId,
                    consoleId: descriptor.consoleId,
                    consoleName: descriptor.consoleName,
                    albumTitle: descriptor.albumTitle,
                    trackNumber: row.trackNumber ?? (idx + 1),
                    title: row.display.titleText,
                    artist: cleanArtist,
                    year: cleanYear,
                    dumper: cleanDumper,
                    format: formatExt,
                    durationSeconds: resolvedDuration,
                    streamURI: URL(fileURLWithPath: relocatedContainer).absoluteString,
                    canonicalSourcePath: canonicalSource,
                    uacContainerPath: isUACArchive ? relocatedContainer : nil,
                    uacMemberPath: row.archiveEntry,
                    subsongIndex: row.trackIndex,
                    subsongCount: row.trackCount,
                    introSeconds: Double(max(0, row.introLengthMilliseconds)) / 1_000.0,
                    loopSeconds: Double(max(0, row.loopLengthMilliseconds)) / 1_000.0,
                    fadeSeconds: Double(max(0, row.fadeLengthMilliseconds)) / 1_000.0
                )
                hydrated.append(track)
                tracksById[track.id] = track
            }
            tracksByAlbumId[albumId] = hydrated
            return hydrated
        } catch {
            return []
        }
    }

    func tracks(forIds ids: [String]) -> [AppBoyTrack] {
        ids.compactMap { track(for: $0) }
    }

    func artworkDataURL(forAlbumId albumId: String) -> String? {
        if let cached = artworkCache[albumId] {
            return cached
        }
        guard let album = albumsById[albumId] else { return nil }
        if album.hasTitleSnap,
           let containerPath = album.titleSnapContainerPath,
           let memberPath = album.titleSnapMemberPath {
            let containerURL = URL(fileURLWithPath: containerPath)
            if FileManager.default.fileExists(atPath: containerURL.path),
               let dataURL = try? UACEmbeddedArchiveReader.readArtworkDataURL(
                   containerURL: containerURL,
                   memberPath: memberPath
               ) {
                cacheArtwork(dataURL, forAlbumId: albumId)
                return dataURL
            }
        }
        return album.artworkDataURL.isEmpty ? nil : album.artworkDataURL
    }

    private func cacheArtwork(_ dataURL: String, forAlbumId albumId: String) {
        if artworkCache[albumId] == nil {
            artworkCacheOrder.append(albumId)
            if artworkCacheOrder.count > maxCachedArtworks, let oldest = artworkCacheOrder.first {
                artworkCacheOrder.removeFirst()
                artworkCache.removeValue(forKey: oldest)
            }
        }
        artworkCache[albumId] = dataURL
    }

    // MARK: - Shared Favorites & History Bridges (FrontendCore)

    func allFavoriteIds() -> Set<String> {
        let snaps = (try? favoriteStore?.snapshots()) ?? []
        return Set(snaps.map(\.identity.id))
    }

    func favoritesTracks() -> [[String: Any]] {
        let snaps = (try? favoriteStore?.snapshots()) ?? []
        let order: FavoriteSortOrder = preferences.favoriteSortOrder == "alphabetical"
            ? .alphabetical
            : .historical
        let ordered: [FavoriteTrackSnapshot]
        if order == .alphabetical {
            ordered = FavoriteListPresentation.ordered(snaps, by: .alphabetical)
        } else {
            ordered = snaps.reversed()
        }
        let iso = ISO8601DateFormatter()
        return ordered.map { snap in
            let resolved = tracksById[snap.identity.id] ?? trackFromSnapshot(snap)
            tracksById[resolved.id] = resolved
            let stamp = snap.addedAtMilliseconds.map {
                iso.string(from: Date(timeIntervalSince1970: Double($0) / 1_000.0))
            }
            return serializeTrack(resolved, timestamp: stamp)
        }
    }

    func historyTracks() -> [[String: Any]] {
        let records = (try? historyStore?.records()) ?? []
        let iso = ISO8601DateFormatter()
        return Array(records.prefix(150)).map { rec in
            let resolved = tracksById[rec.snapshot.identity.id] ?? trackFromSnapshot(rec.snapshot)
            tracksById[resolved.id] = resolved
            let stamp = iso.string(from: Date(timeIntervalSince1970: Double(rec.timestampMilliseconds) / 1_000.0))
            return serializeTrack(resolved, timestamp: stamp)
        }
    }

    func toggleFavorite(trackId: String) -> Bool {
        guard let favoriteStore else { return false }
        if let existing = (try? favoriteStore.snapshots())?.first(where: { $0.identity.id == trackId }) {
            let mutation = try? favoriteStore.toggle([existing])
            return mutation?.added ?? false
        }
        guard let targetTrack = track(for: trackId) else { return false }
        let snap = snapshot(from: targetTrack)
        let mutation = try? favoriteStore.toggle([snap])
        return mutation?.added ?? false
    }

    func toggleAlbumFavorites(albumId: String) -> [String] {
        guard let favoriteStore else { return [] }
        let albumTracks = tracks(forAlbumId: albumId)
        guard !albumTracks.isEmpty else { return Array(allFavoriteIds()) }
        let snapshots = albumTracks.map(snapshot(from:))
        _ = try? favoriteStore.toggle(snapshots)
        return Array(allFavoriteIds())
    }

    func recordHistory(trackId: String) {
        guard let historyStore, let targetTrack = track(for: trackId) else { return }
        _ = try? historyStore.record(snapshot(from: targetTrack))
    }

    func sortPlaylist(request: CatalogPlaylistSortRequest) -> [String] {
        guard let col = request.column else {
            return request.records.map(\.id)
        }
        return CatalogPlaylistSorting.orderedIDs(
            records: request.records,
            column: col,
            direction: request.direction
        )
    }

    func reduceTabOrder(request: PlaylistTabOrderTransitionRequest) -> PlaylistTabOrderState {
        PlaylistTabOrderReducer.reduce(state: request.state, action: request.action)
    }

    func saveWorkspace(_ next: AppBoyWorkspaceSnapshot) throws {
        workspace = next
        try Self.writeJSONThrowing(workspace, to: supportDirectory.appendingPathComponent("playlist-tabs.json"))
    }

    func applyPreferencesPatch(_ patch: [String: Any]) throws -> AppBoyPreferencesSnapshot {
        var next = preferences
        if let v = patch["accentColor"] as? String { next.accentColor = v }
        if let v = patch["uiChromePrimaryColor"] as? String { next.uiChromePrimaryColor = v }
        if let v = patch["uiChromeSecondaryColor"] as? String { next.uiChromeSecondaryColor = v }
        if let v = patch["uiChromePaneColor"] as? String { next.uiChromePaneColor = v }
        if let v = patch["sidebarTextColor"] as? String { next.sidebarTextColor = v }
        if let v = Self.doubleValue(patch["uiChromeFontSizePt"]) { next.uiChromeFontSizePt = v }
        if let v = Self.doubleValue(patch["contentFontSizePt"]) { next.contentFontSizePt = v }
        if let v = patch["uiChromeMonospace"] as? Bool { next.uiChromeMonospace = v }
        if let v = patch["contentMonospace"] as? Bool { next.contentMonospace = v }
        if let v = patch["selectionAnimationEnabled"] as? Bool { next.selectionAnimationEnabled = v }
        if let v = Self.intValue(patch["selectionAnimationMilliseconds"]) { next.selectionAnimationMilliseconds = v }
        if let v = patch["playlistLinkMode"] as? Bool { next.playlistLinkMode = v }
        if let v = patch["sidebarTrackCounts"] as? Bool { next.sidebarTrackCounts = v }
        if let v = patch["favoriteSortOrder"] as? String { next.favoriteSortOrder = v }
        if let v = patch["galleryFitMode"] as? String { next.galleryFitMode = v }
        if let v = Self.doubleValue(patch["galleryFrameScale"]) { next.galleryFrameScale = v }
        if let v = Self.doubleValue(patch["galleryGapRem"]) { next.galleryGapRem = v }
        if let v = Self.doubleValue(patch["galleryRadiusRem"]) { next.galleryRadiusRem = v }
        if let v = patch["repeatMode"] as? String { next.repeatMode = v }
        if let v = patch["equalizerEnabled"] as? Bool { next.equalizerEnabled = v }
        if let rawBands = patch["equalizerBandsDB"] as? [Any] {
            next.equalizerBandsDB = rawBands.map { Self.doubleValue($0) ?? 0.0 }
        }
        if let v = patch["monoEnabled"] as? Bool { next.monoEnabled = v }
        if let v = patch["fadeOutEnabled"] as? Bool { next.fadeOutEnabled = v }
        if let v = Self.doubleValue(patch["fadeOutSeconds"]) { next.fadeOutSeconds = v }
        if let v = patch["longPlayEnabled"] as? Bool { next.longPlayEnabled = v }
        if let v = Self.doubleValue(patch["manualPlayTimeSeconds"]) { next.manualPlayTimeSeconds = v }
        if let v = patch["playbackSpeedEnabled"] as? Bool { next.playbackSpeedEnabled = v }
        if let v = Self.doubleValue(patch["playbackSpeedRate"]) { next.playbackSpeedRate = v }
        if let v = Self.doubleValue(patch["appVolume"]) { next.appVolume = v }
        if let v = patch["remoteCatalogURL"] as? String { next.remoteCatalogURL = v }
        next.normalize()
        preferences = next
        syncSharedFrontendPreferences(from: next)
        try Self.writeJSONThrowing(preferences, to: supportDirectory.appendingPathComponent("preferences.json"))
        return preferences
    }

    private func syncSharedFrontendPreferences(from prefs: AppBoyPreferencesSnapshot) {
        let shared = FrontendInterfacePreferences(
            animations: FrontendAnimationTimings(
                autoResizeEnabled: true,
                selectionEnabled: prefs.selectionAnimationEnabled,
                autoResizeMilliseconds: prefs.selectionAnimationMilliseconds,
                selectionMilliseconds: prefs.selectionAnimationMilliseconds
            ),
            windows: FrontendWindowPreferences(),
            columnAutoSize: true
        )
        sharedPrefsStore.save(shared)
    }

    func reloadCatalog() async throws -> AppBoyCatalogSnapshot {
        artworkCache.removeAll()
        artworkCacheOrder.removeAll()
        loadLocalOrBundledCatalog()

        let remoteText = preferences.remoteCatalogURL
        if !remoteText.isEmpty {
            guard let url = URL(string: remoteText),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme) else {
                throw NSError(domain: "APPBOY.Catalog", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Remote catalog URL must use http or https."
                ])
            }
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NSError(domain: "APPBOY.Catalog", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Remote catalog returned HTTP \(http.statusCode)."
                ])
            }
            let payload = try JSONDecoder().decode(AppBoyRemoteCatalogPayload.self, from: data)
            installPayload(payload, defaultLabel: url.host ?? "Remote SBO")
        }
        return catalog
    }

    func serializeTrack(_ track: AppBoyTrack, timestamp: String? = nil) -> [String: Any] {
        let favSet = allFavoriteIds()
        var dict: [String: Any] = [
            "id": track.id,
            "albumId": track.albumId,
            "consoleId": track.consoleId,
            "consoleName": track.consoleName,
            "albumTitle": track.albumTitle,
            "trackNumber": track.trackNumber,
            "title": track.title,
            "artist": track.artist,
            "year": track.year,
            "dumper": track.dumper,
            "format": track.format,
            "durationSeconds": track.durationSeconds,
            "isFavorite": favSet.contains(track.id)
        ]
        if let timestamp {
            dict["timestamp"] = timestamp
        }
        return dict
    }

    // MARK: - CatalogReader & Bundled DataPack Loading

    private func loadLocalOrBundledCatalog() {
        albumsById.removeAll()
        tracksById.removeAll()
        tracksByAlbumId.removeAll()
        hydrationDescriptors.removeAll()
        activeCatalogDatabaseURL = nil
        activeDataPackRootURL = nil

        if let dbBundle = discoverSQLiteDataPack(),
           loadSQLiteCatalog(databaseURL: dbBundle.databaseURL, dataPackRoot: dbBundle.rootURL, label: dbBundle.label) {
            mergeLooseDocumentsAudioImportsIfPresent()
            return
        }

        let starter = Self.buildStarterCatalog()
        self.catalog = starter.snapshot
        self.albumsById = starter.albumsById
        self.tracksById = starter.tracksById
        self.tracksByAlbumId = starter.tracksByAlbumId
        self.mergeLocalDocumentsCatalogIfPresent()
    }

    private func discoverSQLiteDataPack() -> (databaseURL: URL, rootURL: URL, label: String)? {
        let fm = FileManager.default
        let docsPack = documentsDirectory.appendingPathComponent("DataPack", isDirectory: true)
        let docsDB = docsPack.appendingPathComponent("catalog.sqlite")
        if fm.fileExists(atPath: docsDB.path) {
            return (docsDB, docsPack, "Documents DataPack")
        }

        let bundlePack = Bundle.main.bundleURL.appendingPathComponent("DataPack", isDirectory: true)
        let bundleDB = bundlePack.appendingPathComponent("catalog.sqlite")
        if fm.fileExists(atPath: bundleDB.path) {
            return (bundleDB, bundlePack, "Bundled DataPack (JohnS / SNES)")
        }

        let devPack = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("APPBOY/.build/DataPack", isDirectory: true)
        let devDB = devPack.appendingPathComponent("catalog.sqlite")
        if fm.fileExists(atPath: devDB.path) {
            return (devDB, devPack, "Staged DataPack (JohnS / SNES)")
        }
        return nil
    }

    private func loadSQLiteCatalog(databaseURL: URL, dataPackRoot: URL, label: String) -> Bool {
        do {
            let reader = try ReadOnlyCatalog(databaseURL: databaseURL)
            let summary = try reader.summary()
            let activeTracks = (try? reader.activeTrackCount()) ?? summary.trackCount
            let buckets = try reader.gameBuckets(preferFoldersOverMetadata: true, naturallySorted: true)
            guard !buckets.isEmpty else { return false }

            let browserGames = CatalogBrowserProjection.games(from: buckets)
            let browserGroups = CatalogBrowserProjection.groups(from: browserGames)

            let galleryGames = (try? reader.titleSnapGalleryGames(preferFoldersOverMetadata: true)) ?? []
            let galleryIndex = CatalogGalleryIndex(games: galleryGames)
            var galleryByGameID: [String: CatalogGalleryGame] = [:]
            galleryByGameID.reserveCapacity(galleryIndex.games(inConsole: nil).count)
            for g in galleryIndex.games(inConsole: nil) {
                galleryByGameID[CatalogGalleryIndex.catalogGameID(for: g)] = g
            }

            self.activeCatalogDatabaseURL = databaseURL
            self.activeDataPackRootURL = dataPackRoot

            var consoleGroups: [AppBoyConsoleGroup] = []
            var totalArtworkCount = 0

            for group in browserGroups {
                let consoleId = Self.slugify(group.name)
                let shortCode = Self.shortConsoleCode(for: group.name)
                var builtAlbums: [AppBoyAlbum] = []
                builtAlbums.reserveCapacity(group.games.count)

                for game in group.games {
                    let albumId = "cat-\(Self.stableHexHash(game.id))"
                    let galleryEntry = galleryByGameID[game.id]
                    let relocatedArtContainer = galleryEntry.map {
                        relocateCatalogPath($0.sourcePath, storedRootPath: $0.rootPath)
                    }
                    let hasArt = galleryEntry != nil && relocatedArtContainer != nil
                    if hasArt {
                        totalArtworkCount += 1
                    }

                    let fallbackSVG = Self.cartridgeSVGDataURL(
                        systemLabel: shortCode,
                        title: game.displayName.uppercased(),
                        subtitle: "\(game.trackCount) TRACKS",
                        accent: "#38aaff"
                    )

                    let album = AppBoyAlbum(
                        id: albumId,
                        consoleId: consoleId,
                        consoleName: group.name,
                        title: game.displayName,
                        artist: "",
                        year: "",
                        trackCount: game.trackCount,
                        totalDurationSeconds: 0.0,
                        artworkDataURL: fallbackSVG,
                        hasTitleSnap: hasArt,
                        titleSnapContainerPath: relocatedArtContainer,
                        titleSnapMemberPath: galleryEntry?.titleSnap
                    )
                    builtAlbums.append(album)
                    albumsById[albumId] = album
                    hydrationDescriptors[albumId] = CatalogAlbumHydrationDescriptor(
                        selection: CatalogPlaylistGameSelection(
                            rootID: game.rootID,
                            game: game.name,
                            system: game.system
                        ),
                        storedRootPath: game.rootPath,
                        consoleId: consoleId,
                        consoleName: group.name,
                        albumTitle: game.displayName
                    )
                }

                consoleGroups.append(AppBoyConsoleGroup(
                    id: consoleId,
                    name: group.name,
                    shortCode: shortCode,
                    albums: builtAlbums
                ))
            }

            let albumCount = consoleGroups.reduce(0) { $0 + $1.albums.count }
            self.catalog = AppBoyCatalogSnapshot(
                sourceLabel: label,
                databasePath: databaseURL.lastPathComponent,
                schemaVersion: summary.schemaVersion,
                consoleCount: consoleGroups.count,
                albumCount: albumCount,
                trackCount: activeTracks,
                artworkCount: totalArtworkCount,
                consoles: consoleGroups
            )
            return true
        } catch {
            return false
        }
    }

    private func relocateCatalogPath(_ storedPath: String, storedRootPath: String) -> String {
        guard let dataPackRoot = activeDataPackRootURL else { return storedPath }
        let cleanRoot = storedRootPath.hasSuffix("/")
            ? String(storedRootPath.dropLast())
            : storedRootPath
        if !cleanRoot.isEmpty, storedPath.hasPrefix(cleanRoot + "/") {
            let suffix = String(storedPath.dropFirst(cleanRoot.count + 1))
            let candidate = dataPackRoot.appendingPathComponent(suffix).path
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        if storedPath.hasPrefix("/DataPack/") {
            let suffix = String(storedPath.dropFirst("/DataPack/".count))
            let candidate = dataPackRoot.appendingPathComponent(suffix).path
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return storedPath
    }

    private func canonicalIdentityPath(_ storedPath: String, storedRootPath: String) -> String {
        let cleanRoot = storedRootPath.hasSuffix("/")
            ? String(storedRootPath.dropLast())
            : storedRootPath
        if !cleanRoot.isEmpty, storedPath.hasPrefix(cleanRoot + "/") {
            let suffix = String(storedPath.dropFirst(cleanRoot.count + 1))
            return "/DataPack/\(suffix)"
        }
        if let packRoot = activeDataPackRootURL?.path {
            let cleanPack = packRoot.hasSuffix("/") ? String(packRoot.dropLast()) : packRoot
            if storedPath.hasPrefix(cleanPack + "/") {
                let suffix = String(storedPath.dropFirst(cleanPack.count + 1))
                return "/DataPack/\(suffix)"
            }
        }
        return storedPath
    }

    private func snapshot(from track: AppBoyTrack) -> FavoriteTrackSnapshot {
        let identitySource = track.canonicalSourcePath
            ?? track.uacContainerPath
            ?? URL(string: track.streamURI)?.path
            ?? track.id
        let identity = FavoriteTrackIdentity(
            sourcePath: identitySource,
            archiveEntry: track.uacMemberPath,
            trackIndex: track.subsongIndex,
            trackCount: track.subsongCount
        )
        let filename = track.uacMemberPath
            ?? URL(fileURLWithPath: identitySource).lastPathComponent
        return FavoriteTrackSnapshot(
            identity: identity,
            filename: filename,
            title: track.title,
            game: track.albumTitle,
            author: track.artist,
            system: track.consoleName,
            playLengthMilliseconds: Int((max(0.0, track.durationSeconds) * 1_000.0).rounded())
        )
    }

    private func trackFromSnapshot(_ snap: FavoriteTrackSnapshot) -> AppBoyTrack {
        let physicalPath = relocateCatalogPath(snap.identity.sourcePath, storedRootPath: "")
        let isUAC = URL(fileURLWithPath: physicalPath).pathExtension.lowercased() == "uac"
            && snap.identity.archiveEntry != nil
        let isSynth = snap.identity.sourcePath.contains("APPBOY-Synth") || snap.identity.sourcePath.hasPrefix("/synth/")
        let streamURI: String
        if isSynth {
            streamURI = "synth://snes/\(snap.identity.id)"
        } else {
            streamURI = URL(fileURLWithPath: physicalPath).absoluteString
        }
        let ext = URL(fileURLWithPath: snap.filename).pathExtension.uppercased()
        let duration = snap.playLengthMilliseconds > 0
            ? Double(snap.playLengthMilliseconds) / 1_000.0
            : 150.0
        return AppBoyTrack(
            id: snap.identity.id,
            albumId: "fav-hydrated",
            consoleId: Self.slugify(snap.system),
            consoleName: snap.system.isEmpty ? "Library" : snap.system,
            albumTitle: snap.game.isEmpty ? "Playlist" : snap.game,
            trackNumber: snap.identity.trackIndex + 1,
            title: snap.title.isEmpty ? FavoriteListPresentation.displayName(for: snap) : snap.title,
            artist: snap.author,
            year: "",
            dumper: "",
            format: ext,
            durationSeconds: duration,
            streamURI: streamURI,
            canonicalSourcePath: snap.identity.sourcePath,
            uacContainerPath: isUAC ? physicalPath : nil,
            uacMemberPath: snap.identity.archiveEntry,
            subsongIndex: snap.identity.trackIndex,
            subsongCount: snap.identity.trackCount
        )
    }

    // MARK: - Remote & Loose File Fallbacks

    private func installPayload(_ payload: AppBoyRemoteCatalogPayload, defaultLabel: String) {
        var newAlbumsById: [String: AppBoyAlbum] = [:]
        var newTracksById: [String: AppBoyTrack] = [:]
        var newTracksByAlbum: [String: [AppBoyTrack]] = [:]
        for group in payload.consoles {
            for album in group.albums {
                newAlbumsById[album.id] = album
            }
        }
        for track in payload.tracks {
            newTracksById[track.id] = track
            newTracksByAlbum[track.albumId, default: []].append(track)
        }
        let albumCount = payload.consoles.reduce(0) { $0 + $1.albums.count }
        self.hydrationDescriptors.removeAll()
        self.albumsById = newAlbumsById
        self.tracksById = newTracksById
        self.tracksByAlbumId = newTracksByAlbum
        self.catalog = AppBoyCatalogSnapshot(
            sourceLabel: payload.sourceLabel ?? defaultLabel,
            databasePath: "",
            schemaVersion: 0,
            consoleCount: payload.consoles.count,
            albumCount: albumCount,
            trackCount: payload.tracks.count,
            artworkCount: albumCount,
            consoles: payload.consoles
        )
    }

    private func mergeLocalDocumentsCatalogIfPresent() {
        let jsonURL = documentsDirectory.appendingPathComponent("catalog.json")
        if let data = try? Data(contentsOf: jsonURL),
           let payload = try? JSONDecoder().decode(AppBoyRemoteCatalogPayload.self, from: data),
           !payload.consoles.isEmpty {
            installPayload(payload, defaultLabel: "Documents/catalog.json")
            return
        }
        mergeLooseDocumentsAudioImportsIfPresent()
    }

    private func mergeLooseDocumentsAudioImportsIfPresent() {
        var allowedExts: Set<String> = ["m4a", "aac", "mp3", "wav", "flac", "caf"]
        allowedExts.formUnion(EmbeddedGMEDecoder.supportedExtensions)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let audioFiles = entries.filter { allowedExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        guard !audioFiles.isEmpty else { return }

        let albumId = "local-documents-imports"
        var importedTracks: [AppBoyTrack] = []
        for (idx, fileURL) in audioFiles.enumerated() {
            let baseName = fileURL.deletingPathExtension().lastPathComponent
            let canonical = "/Documents/\(fileURL.lastPathComponent)"
            let favId = FavoriteTrackIdentity(sourcePath: canonical).id
            let track = AppBoyTrack(
                id: favId,
                albumId: albumId,
                consoleId: "local",
                consoleName: "Local Files",
                albumTitle: "Documents Imports",
                trackNumber: idx + 1,
                title: baseName,
                artist: "",
                year: "",
                format: fileURL.pathExtension.uppercased(),
                durationSeconds: 180.0,
                streamURI: fileURL.absoluteString,
                canonicalSourcePath: canonical
            )
            importedTracks.append(track)
            tracksById[track.id] = track
        }
        tracksByAlbumId[albumId] = importedTracks
        let localAlbum = AppBoyAlbum(
            id: albumId,
            consoleId: "local",
            consoleName: "Local Files",
            title: "Documents Imports",
            artist: "",
            year: "",
            trackCount: importedTracks.count,
            totalDurationSeconds: Double(importedTracks.count) * 180.0,
            artworkDataURL: Self.cartridgeSVGDataURL(
                systemLabel: "LOCAL",
                title: "DOCUMENTS",
                subtitle: "\(importedTracks.count) TRACKS",
                accent: "#38aaff"
            )
        )
        albumsById[albumId] = localAlbum
        let localGroup = AppBoyConsoleGroup(
            id: "local",
            name: "Local Files",
            shortCode: "LOCAL",
            albums: [localAlbum]
        )
        var consoles = [localGroup]
        consoles.append(contentsOf: catalog.consoles)
        catalog = AppBoyCatalogSnapshot(
            sourceLabel: catalog.sourceLabel,
            databasePath: catalog.databasePath,
            schemaVersion: catalog.schemaVersion,
            consoleCount: consoles.count,
            albumCount: consoles.reduce(0) { $0 + $1.albums.count },
            trackCount: catalog.trackCount + importedTracks.count,
            artworkCount: catalog.artworkCount,
            consoles: consoles
        )
    }

    // MARK: - Formatting & Serialization Utilities

    private static func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        let slug = lower.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "console" : slug
    }

    private static func shortConsoleCode(for name: String) -> String {
        let upper = name.uppercased()
        if upper.contains("SNES") || upper.contains("SUPER NINTENDO") { return "SNES" }
        if upper.contains("NES") || upper.contains("FAMICOM") { return "NES" }
        if upper.contains("GENESIS") || upper.contains("MEGA DRIVE") { return "GENESIS" }
        if upper.contains("GAME BOY") { return "GB" }
        if upper.contains("PC ENGINE") || upper.contains("TURBOGRAFX") { return "PCE" }
        if upper.contains("PLAYSTATION") { return "PSX" }
        return String(upper.prefix(12))
    }

    private static func stableHexHash(_ text: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }

    private static func doubleValue(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let i = raw as? Int { return Double(i) }
        if let n = raw as? NSNumber { return n.doubleValue }
        if let s = raw as? String { return Double(s) }
        return nil
    }

    private static func intValue(_ raw: Any?) -> Int? {
        if let i = raw as? Int { return i }
        if let d = raw as? Double { return Int(d.rounded()) }
        if let n = raw as? NSNumber { return n.intValue }
        if let s = raw as? String { return Int(s) }
        return nil
    }

    private static func readJSON<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func writeJSONThrowing<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func xmlEscape(_ text: String, maxLength: Int) -> String {
        String(text.prefix(maxLength))
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func cartridgeSVGDataURL(
        systemLabel: String,
        title: String,
        subtitle: String,
        accent: String
    ) -> String {
        let cleanSystem = xmlEscape(systemLabel, maxLength: 14)
        let shortTitle = xmlEscape(title, maxLength: 18)
        let shortSub = xmlEscape(subtitle, maxLength: 20)
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">
          <rect width="160" height="160" fill="#0b0d12"/>
          <rect x="10" y="10" width="140" height="140" fill="#121620" stroke="#29303a" stroke-width="2"/>
          <rect x="10" y="10" width="140" height="4" fill="\(accent)"/>
          <rect x="22" y="28" width="116" height="68" fill="#090b0f" stroke="#252c38" stroke-width="1"/>
          <path d="M22 76 L138 76 M22 84 L138 84" stroke="\(accent)" stroke-opacity="0.35" stroke-width="1"/>
          <text x="28" y="54" fill="\(accent)" font-family="ui-monospace,Menlo,monospace" font-size="13" font-weight="700" letter-spacing="1.6">\(cleanSystem)</text>
          <text x="22" y="118" fill="#e0e1eb" font-family="ui-monospace,Menlo,monospace" font-size="10" letter-spacing="0.4">\(shortTitle)</text>
          <text x="22" y="135" fill="#737a96" font-family="ui-monospace,Menlo,monospace" font-size="9" letter-spacing="0.4">\(shortSub)</text>
        </svg>
        """
        let base64 = Data(svg.utf8).base64EncodedString()
        return "data:image/svg+xml;base64,\(base64)"
    }

    private static func buildStarterCatalog() -> (
        snapshot: AppBoyCatalogSnapshot,
        albumsById: [String: AppBoyAlbum],
        tracksById: [String: AppBoyTrack],
        tracksByAlbumId: [String: [AppBoyTrack]]
    ) {
        struct SeedAlbum {
            let id: String
            let title: String
            let artist: String
            let year: String
            let format: String
            let accent: String
            let tracks: [(String, Double)]
        }
        struct SeedConsole {
            let id: String
            let name: String
            let code: String
            let albums: [SeedAlbum]
        }

        let seeds: [SeedConsole] = [
            SeedConsole(id: "snes", name: "Super Nintendo", code: "SNES", albums: [
                SeedAlbum(id: "snes-chrono-echoes", title: "Chrono Horizon", artist: "Yasunori Lab", year: "1995", format: "SPC", accent: "#38aaff", tracks: [
                    ("Premonition Clockwork", 24.0),
                    ("Millennial Fairgrounds", 28.0),
                    ("Corridors of Zeal", 32.0),
                    ("Wind Scene Overworld", 26.0),
                    ("World Revolution", 30.0)
                ]),
                SeedAlbum(id: "snes-zebes-depths", title: "Depths of Brinstar", artist: "Kenji Sound Team", year: "1994", format: "SPC", accent: "#38aaff", tracks: [
                    ("Title Atmospheric", 22.0),
                    ("Brinstar Overgrown Jungle", 29.0),
                    ("Maridia Drifting Sand", 34.0),
                    ("Lower Norfair Magma", 27.0)
                ])
            ]),
            SeedConsole(id: "genesis", name: "Sega Genesis", code: "GENESIS", albums: [
                SeedAlbum(id: "gen-bare-knuckle-neon", title: "Streets of Neon II", artist: "Yuzo FM Works", year: "1992", format: "VGZ", accent: "#ff7a45", tracks: [
                    ("Go Straight (FM Mix)", 28.0),
                    ("Dreamer Midnight Club", 31.0),
                    ("Spin on the Bridge", 25.0),
                    ("Expander Boss Rush", 27.0)
                ]),
                SeedAlbum(id: "gen-hydro-velocity", title: "Starlight Zone Act 3", artist: "Masato Studio", year: "1994", format: "VGZ", accent: "#ff7a45", tracks: [
                    ("Angel Island Dawn", 24.0),
                    ("Hydrocity Velocity", 26.0),
                    ("IceCap Snowboard", 30.0),
                    ("Sky Sanctuary Ruins", 29.0)
                ])
            ]),
            SeedConsole(id: "nes", name: "Nintendo (NES)", code: "NES", albums: [
                SeedAlbum(id: "nes-blue-bomber-2", title: "Titanium Fortress II", artist: "Takashi 2A03", year: "1988", format: "NSF", accent: "#5cdbd3", tracks: [
                    ("Opening Rooftop", 21.0),
                    ("Metal Blade Factory", 25.0),
                    ("Flash Stopper Cavern", 26.0),
                    ("Dr. Wily Stage 1", 31.0)
                ]),
                SeedAlbum(id: "nes-vampire-clocktower", title: "Clocktower Requiem III", artist: "Kinuyo VRC6", year: "1989", format: "NSF", accent: "#5cdbd3", tracks: [
                    ("Beginning Courtyard", 25.0),
                    ("Clockwork Gears", 28.0),
                    ("Aquarius Rising", 26.0)
                ])
            ]),
            SeedConsole(id: "gb", name: "Game Boy", code: "GB", albums: [
                SeedAlbum(id: "gb-koholint-dream", title: "Ballad of Koholint", artist: "Kazumi DMG", year: "1993", format: "GBS", accent: "#8bd450", tracks: [
                    ("Mabe Village Morning", 22.0),
                    ("Tal Tal Heights", 29.0),
                    ("Face Shrine Echo", 31.0),
                    ("Wind Fish Awakening", 27.0)
                ])
            ]),
            SeedConsole(id: "pce", name: "PC Engine", code: "PCE", albums: [
                SeedAlbum(id: "pce-blazing-star", title: "Soldier Blade Caravan", artist: "Takanori HuC6280", year: "1992", format: "HES", accent: "#ffc53d", tracks: [
                    ("Operation Silver", 26.0),
                    ("Orbital Interceptor", 28.0),
                    ("2-Minute Caravan Stage", 30.0)
                ])
            ]),
            SeedConsole(id: "psx", name: "PlayStation", code: "PSX", albums: [
                SeedAlbum(id: "psx-moonlight-nocturne", title: "Nocturne in the Library", artist: "Michiru SPU", year: "1997", format: "PSF", accent: "#bb9af7", tracks: [
                    ("Dracula's Castle", 30.0),
                    ("Wood Carving Partita", 33.0),
                    ("Marble Gallery", 26.0),
                    ("Requiem for the Gods", 32.0)
                ])
            ])
        ]

        var consoles: [AppBoyConsoleGroup] = []
        var albumsById: [String: AppBoyAlbum] = [:]
        var tracksById: [String: AppBoyTrack] = [:]
        var tracksByAlbumId: [String: [AppBoyTrack]] = [:]

        for seedConsole in seeds {
            var builtAlbums: [AppBoyAlbum] = []
            for seedAlbum in seedConsole.albums {
                var albumTracks: [AppBoyTrack] = []
                var totalDuration = 0.0
                for (index, item) in seedAlbum.tracks.enumerated() {
                    let canonical = "/synth/\(seedAlbum.id)/\(index + 1).spc"
                    let favId = FavoriteTrackIdentity(sourcePath: canonical).id
                    let track = AppBoyTrack(
                        id: favId,
                        albumId: seedAlbum.id,
                        consoleId: seedConsole.id,
                        consoleName: seedConsole.name,
                        albumTitle: seedAlbum.title,
                        trackNumber: index + 1,
                        title: item.0,
                        artist: seedAlbum.artist,
                        year: seedAlbum.year,
                        format: seedAlbum.format,
                        durationSeconds: item.1,
                        streamURI: "synth://\(seedConsole.id)/\(favId)",
                        canonicalSourcePath: canonical
                    )
                    albumTracks.append(track)
                    tracksById[favId] = track
                    totalDuration += item.1
                }
                tracksByAlbumId[seedAlbum.id] = albumTracks
                let album = AppBoyAlbum(
                    id: seedAlbum.id,
                    consoleId: seedConsole.id,
                    consoleName: seedConsole.name,
                    title: seedAlbum.title,
                    artist: seedAlbum.artist,
                    year: seedAlbum.year,
                    trackCount: albumTracks.count,
                    totalDurationSeconds: totalDuration,
                    artworkDataURL: cartridgeSVGDataURL(
                        systemLabel: seedConsole.code,
                        title: seedAlbum.title.uppercased(),
                        subtitle: "\(seedAlbum.artist) · \(seedAlbum.year)",
                        accent: seedAlbum.accent
                    )
                )
                albumsById[album.id] = album
                builtAlbums.append(album)
            }
            consoles.append(AppBoyConsoleGroup(
                id: seedConsole.id,
                name: seedConsole.name,
                shortCode: seedConsole.code,
                albums: builtAlbums
            ))
        }

        let albumCount = consoles.reduce(0) { $0 + $1.albums.count }
        let snapshot = AppBoyCatalogSnapshot(
            sourceLabel: "Starter Catalog",
            databasePath: "",
            schemaVersion: 0,
            consoleCount: consoles.count,
            albumCount: albumCount,
            trackCount: tracksById.count,
            artworkCount: albumCount,
            consoles: consoles
        )
        return (snapshot, albumsById, tracksById, tracksByAlbumId)
    }
}
