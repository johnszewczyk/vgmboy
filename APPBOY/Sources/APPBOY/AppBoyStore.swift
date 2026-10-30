import Foundation

struct AppBoyRemoteCatalogPayload: Codable, Sendable {
    let sourceLabel: String?
    let consoles: [AppBoyConsoleGroup]
    let tracks: [AppBoyTrack]
}

@MainActor
final class AppBoyStore {
    private let supportDirectory: URL
    private let documentsDirectory: URL
    private(set) var preferences: AppBoyPreferencesSnapshot
    private var favorites: [AppBoyFavoriteEntry]
    private var history: [AppBoyHistoryEntry]
    private(set) var workspace: AppBoyWorkspaceSnapshot
    private(set) var catalog: AppBoyCatalogSnapshot
    private var tracksById: [String: AppBoyTrack] = [:]
    private var tracksByAlbumId: [String: [AppBoyTrack]] = [:]

    init() {
        let fm = FileManager.default
        let appSupportBase = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let supportDir = appSupportBase.appendingPathComponent("APPBOY", isDirectory: true)
        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.supportDirectory = supportDir
        self.documentsDirectory = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? supportDir

        var loadedPrefs: AppBoyPreferencesSnapshot = Self.readJSON(
            from: supportDir.appendingPathComponent("preferences.json")
        ) ?? AppBoyPreferencesSnapshot()
        loadedPrefs.normalize()
        self.preferences = loadedPrefs

        self.favorites = Self.readJSON(from: supportDir.appendingPathComponent("favorites.json")) ?? []
        self.history = Self.readJSON(from: supportDir.appendingPathComponent("history.json")) ?? []

        let starter = Self.buildStarterCatalog()
        self.catalog = starter.snapshot
        self.tracksById = starter.tracksById
        self.tracksByAlbumId = starter.tracksByAlbumId
        self.workspace = AppBoyWorkspaceSnapshot(activeTabId: "tab-1", tabs: [])
        self.mergeLocalDocumentsCatalogIfPresent()

        if let savedWorkspace: AppBoyWorkspaceSnapshot = Self.readJSON(
            from: supportDir.appendingPathComponent("playlist-tabs.json")
        ), !savedWorkspace.tabs.isEmpty {
            self.workspace = savedWorkspace
        } else {
            let firstAlbum = self.catalog.consoles.first?.albums.first
            let initialTracks = firstAlbum != nil ? (self.tracksByAlbumId[firstAlbum!.id] ?? []) : []
            let tab = AppBoyPlaylistTab(
                id: "tab-1",
                title: firstAlbum?.title ?? "Playlist",
                consoleName: firstAlbum?.consoleName ?? "SNES",
                sourceKind: "album",
                sourceId: firstAlbum?.id,
                trackIds: initialTracks.map(\.id),
                selectedTrackId: initialTracks.first?.id
            )
            self.workspace = AppBoyWorkspaceSnapshot(activeTabId: tab.id, tabs: [tab])
        }
    }

    func track(for id: String) -> AppBoyTrack? {
        tracksById[id]
    }

    func tracks(forAlbumId albumId: String) -> [AppBoyTrack] {
        tracksByAlbumId[albumId] ?? []
    }

    func tracks(forIds ids: [String]) -> [AppBoyTrack] {
        ids.compactMap { tracksById[$0] }
    }

    func allFavoriteIds() -> Set<String> {
        Set(favorites.map(\.trackId))
    }

    func favoritesTracks() -> [[String: Any]] {
        let ordered: [AppBoyFavoriteEntry]
        if preferences.favoriteSortOrder == "alphabetical" {
            ordered = favorites.sorted { lhs, rhs in
                let leftTitle = tracksById[lhs.trackId]?.title ?? lhs.trackId
                let rightTitle = tracksById[rhs.trackId]?.title ?? rhs.trackId
                return leftTitle.localizedCaseInsensitiveCompare(rightTitle) == .orderedAscending
            }
        } else {
            ordered = favorites.reversed()
        }
        return ordered.compactMap { entry in
            guard let track = tracksById[entry.trackId] else { return nil }
            return serializeTrack(track, timestamp: entry.addedAtISO8601)
        }
    }

    func historyTracks() -> [[String: Any]] {
        history.compactMap { entry in
            guard let track = tracksById[entry.trackId] else { return nil }
            return serializeTrack(track, timestamp: entry.playedAtISO8601)
        }
    }

    func toggleFavorite(trackId: String) -> Bool {
        if let idx = favorites.firstIndex(where: { $0.trackId == trackId }) {
            favorites.remove(at: idx)
            saveFavorites()
            return false
        }
        guard tracksById[trackId] != nil else { return false }
        let stamp = ISO8601DateFormatter().string(from: Date())
        favorites.append(AppBoyFavoriteEntry(trackId: trackId, addedAtISO8601: stamp))
        saveFavorites()
        return true
    }

    func toggleAlbumFavorites(albumId: String) -> [String] {
        let albumTracks = tracksByAlbumId[albumId] ?? []
        guard !albumTracks.isEmpty else { return Array(allFavoriteIds()) }
        let currentSet = allFavoriteIds()
        let allFavorited = albumTracks.allSatisfy { currentSet.contains($0.id) }
        if allFavorited {
            let removeIds = Set(albumTracks.map(\.id))
            favorites.removeAll { removeIds.contains($0.trackId) }
        } else {
            let stamp = ISO8601DateFormatter().string(from: Date())
            for track in albumTracks where !currentSet.contains(track.id) {
                favorites.append(AppBoyFavoriteEntry(trackId: track.id, addedAtISO8601: stamp))
            }
        }
        saveFavorites()
        return favorites.map(\.trackId)
    }

    func recordHistory(trackId: String) {
        guard tracksById[trackId] != nil else { return }
        history.removeAll { $0.trackId == trackId }
        let stamp = ISO8601DateFormatter().string(from: Date())
        history.insert(AppBoyHistoryEntry(trackId: trackId, playedAtISO8601: stamp), at: 0)
        if history.count > 150 {
            history = Array(history.prefix(150))
        }
        Self.writeJSON(history, to: supportDirectory.appendingPathComponent("history.json"))
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
        if let v = patch["longPlayEnabled"] as? Bool { next.longPlayEnabled = v }
        if let v = Self.doubleValue(patch["manualPlayTimeSeconds"]) { next.manualPlayTimeSeconds = v }
        if let v = patch["playbackSpeedEnabled"] as? Bool { next.playbackSpeedEnabled = v }
        if let v = Self.doubleValue(patch["playbackSpeedRate"]) { next.playbackSpeedRate = v }
        if let v = Self.doubleValue(patch["appVolume"]) { next.appVolume = v }
        if let v = patch["remoteCatalogURL"] as? String { next.remoteCatalogURL = v }
        next.normalize()
        preferences = next
        try Self.writeJSONThrowing(preferences, to: supportDirectory.appendingPathComponent("preferences.json"))
        return preferences
    }

    func reloadCatalog() async throws -> AppBoyCatalogSnapshot {
        let starter = Self.buildStarterCatalog()
        self.catalog = starter.snapshot
        self.tracksById = starter.tracksById
        self.tracksByAlbumId = starter.tracksByAlbumId
        self.mergeLocalDocumentsCatalogIfPresent()

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
            "format": track.format,
            "durationSeconds": track.durationSeconds,
            "isFavorite": favSet.contains(track.id)
        ]
        if let timestamp {
            dict["timestamp"] = timestamp
        }
        return dict
    }

    private func installPayload(_ payload: AppBoyRemoteCatalogPayload, defaultLabel: String) {
        var newTracksById: [String: AppBoyTrack] = [:]
        var newTracksByAlbum: [String: [AppBoyTrack]] = [:]
        for track in payload.tracks {
            newTracksById[track.id] = track
            newTracksByAlbum[track.albumId, default: []].append(track)
        }
        let albumCount = payload.consoles.reduce(0) { $0 + $1.albums.count }
        self.tracksById = newTracksById
        self.tracksByAlbumId = newTracksByAlbum
        self.catalog = AppBoyCatalogSnapshot(
            sourceLabel: payload.sourceLabel ?? defaultLabel,
            consoleCount: payload.consoles.count,
            albumCount: albumCount,
            trackCount: payload.tracks.count,
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

        // Also discover loose audio files dropped into Documents/ via Files app.
        let allowedExts: Set<String> = ["m4a", "aac", "mp3", "wav", "flac", "caf"]
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
            let track = AppBoyTrack(
                id: "local-doc-\(idx + 1)-\(baseName)",
                albumId: albumId,
                consoleId: "local",
                consoleName: "Local Files",
                albumTitle: "Documents Imports",
                trackNumber: idx + 1,
                title: baseName,
                artist: "Local Device",
                year: "2026",
                format: fileURL.pathExtension.uppercased(),
                durationSeconds: 180.0,
                streamURI: fileURL.absoluteString
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
            artist: "Local Device",
            year: "2026",
            trackCount: importedTracks.count,
            totalDurationSeconds: Double(importedTracks.count) * 180.0,
            artworkDataURL: Self.cartridgeSVGDataURL(code: "IOS", title: "DOCUMENTS", accent: "#38aaff")
        )
        let localGroup = AppBoyConsoleGroup(
            id: "local",
            name: "Local Files",
            shortCode: "IOS",
            albums: [localAlbum]
        )
        var consoles = [localGroup]
        consoles.append(contentsOf: catalog.consoles)
        catalog = AppBoyCatalogSnapshot(
            sourceLabel: "Local + Starter",
            consoleCount: consoles.count,
            albumCount: consoles.reduce(0) { $0 + $1.albums.count },
            trackCount: tracksById.count,
            consoles: consoles
        )
    }

    private func saveFavorites() {
        Self.writeJSON(favorites, to: supportDirectory.appendingPathComponent("favorites.json"))
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

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        try? writeJSONThrowing(value, to: url)
    }

    private static func writeJSONThrowing<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func cartridgeSVGDataURL(code: String, title: String, accent: String) -> String {
        let shortTitle = String(title.prefix(18))
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160">
          <rect width="160" height="160" fill="#0b0d12"/>
          <rect x="10" y="10" width="140" height="140" fill="#121620" stroke="#29303a" stroke-width="2"/>
          <rect x="10" y="10" width="140" height="4" fill="\(accent)"/>
          <rect x="22" y="28" width="116" height="68" fill="#090b0f" stroke="#252c38" stroke-width="1"/>
          <path d="M22 76 L138 76 M22 84 L138 84" stroke="\(accent)" stroke-opacity="0.35" stroke-width="1"/>
          <text x="28" y="52" fill="\(accent)" font-family="ui-monospace,Menlo,monospace" font-size="15" font-weight="700" letter-spacing="2">\(code)</text>
          <text x="22" y="118" fill="#e0e1eb" font-family="ui-monospace,Menlo,monospace" font-size="10" letter-spacing="0.5">\(shortTitle)</text>
          <text x="22" y="136" fill="#737a96" font-family="ui-monospace,Menlo,monospace" font-size="9" letter-spacing="1.2">SPCBOY // APPBOY</text>
        </svg>
        """
        let base64 = Data(svg.utf8).base64EncodedString()
        return "data:image/svg+xml;base64,\(base64)"
    }

    private static func buildStarterCatalog() -> (
        snapshot: AppBoyCatalogSnapshot,
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
            SeedConsole(id: "snes", name: "Super Nintendo", code: "SPC700", albums: [
                SeedAlbum(id: "snes-chrono-echoes", title: "Chrono Horizon", artist: "Yasunori Lab", year: "1995", format: "SPC", accent: "#38aaff", tracks: [
                    ("Premonition Clockwork", 24.0),
                    ("Millennial Fairgrounds", 28.0),
                    ("Corridors of Zeal", 32.0),
                    ("Wind Scene Overworld", 26.0),
                    ("World Revolution", 30.0)
                ]),
                SeedAlbum(id: "snes-zebes-depths", title: "Subterranean Zebes", artist: "Kenji Sound Team", year: "1994", format: "SPC", accent: "#50d890", tracks: [
                    ("Crateria Rainfall", 25.0),
                    ("Brinstar Overgrowth", 29.0),
                    ("Maridia Glass Tube", 27.0),
                    ("Lower Norfair Pulse", 31.0)
                ]),
                SeedAlbum(id: "snes-donkey-mist", title: "Aquatic Canopy", artist: " Eveline & Wise", year: "1995", format: "SPC", accent: "#67c7ff", tracks: [
                    ("Stickerbush Horizon", 34.0),
                    ("Mining Melancholy", 26.0),
                    ("Forest Interlude", 30.0)
                ])
            ]),
            SeedConsole(id: "genesis", name: "Sega Genesis", code: "YM2612", albums: [
                SeedAlbum(id: "md-bare-knuckle-neon", title: "Streets of Midnight", artist: "Yuzo FM Unit", year: "1992", format: "VGM", accent: "#ff79c6", tracks: [
                    ("Go Straight (FM Mix)", 28.0),
                    ("Dreamer in Shibuya", 26.0),
                    ("Slow Moon Harbor", 30.0),
                    ("Expander Boss Line", 24.0)
                ]),
                SeedAlbum(id: "md-starlight-zone", title: "Hydrocity & Starlight", artist: "Masato Sound", year: "1994", format: "VGM", accent: "#38aaff", tracks: [
                    ("Starlight Highway", 25.0),
                    ("IceCap Crystal", 29.0),
                    ("Flying Battery Act 1", 27.0)
                ])
            ]),
            SeedConsole(id: "nes", name: "Nintendo (NES / Famicom)", code: "2A03", albums: [
                SeedAlbum(id: "nes-wily-fortress", title: "Titanium Fortress II", artist: "Takashi 2A03", year: "1988", format: "NSF", accent: "#7dcfff", tracks: [
                    ("Rooftop Opening", 22.0),
                    ("Metal Blade Factory", 24.0),
                    ("Flash Stopper", 25.0),
                    ("Dr. Wily Stage 1", 30.0)
                ]),
                SeedAlbum(id: "nes-moonlight-castlevania", title: "Clocktower Nocturne", artist: "VRC6 Ensemble", year: "1989", format: "NSF", accent: "#bb9af7", tracks: [
                    ("Beginning (VRC6)", 26.0),
                    ("Aquarius Flowing", 24.0),
                    ("Stream of Shadows", 28.0)
                ])
            ]),
            SeedConsole(id: "gb", name: "Game Boy", code: "LR35902", albums: [
                SeedAlbum(id: "gb-koholint-waves", title: "Koholint Dreaming", artist: "Kazumi Wave", year: "1993", format: "GBS", accent: "#9ece6a", tracks: [
                    ("Mabe Village Morning", 22.0),
                    ("Tal Tal Heights", 28.0),
                    ("Ballad of the Wind Fish", 30.0)
                ]),
                SeedAlbum(id: "gb-brick-matrix", title: "Dot Matrix Pulse", artist: "DMG Chiptune", year: "1990", format: "GBS", accent: "#73daca", tracks: [
                    ("Type-A Korobeiniki", 23.0),
                    ("Rocket Launch Complete", 21.0),
                    ("High Score Telemetry", 24.0)
                ])
            ]),
            SeedConsole(id: "pce", name: "PC Engine / TurboGrafx", code: "HUC6280", albums: [
                SeedAlbum(id: "pce-star-soldier", title: "Blazing Lazers Orbit", artist: "Hudson PSG", year: "1989", format: "HES", accent: "#ff9e64", tracks: [
                    ("Area 01 Ion Drift", 25.0),
                    ("Subspace Interceptor", 27.0),
                    ("Final Core Approach", 29.0)
                ])
            ]),
            SeedConsole(id: "psx", name: "PlayStation", code: "SPU-XA", albums: [
                SeedAlbum(id: "psx-symphony-marble", title: "Inverted Cathedral", artist: "Michiru SPU", year: "1997", format: "PSF", accent: "#38aaff", tracks: [
                    ("Dracula's Castle", 31.0),
                    ("Marble Gallery", 26.0),
                    ("Wood Carving Partita", 29.0),
                    ("Requiem for the Gods", 33.0)
                ])
            ])
        ]

        var consoles: [AppBoyConsoleGroup] = []
        var tracksById: [String: AppBoyTrack] = [:]
        var tracksByAlbumId: [String: [AppBoyTrack]] = [:]

        for seedConsole in seeds {
            var builtAlbums: [AppBoyAlbum] = []
            for seedAlbum in seedConsole.albums {
                var albumTracks: [AppBoyTrack] = []
                var totalDuration = 0.0
                for (index, item) in seedAlbum.tracks.enumerated() {
                    let trackId = "\(seedAlbum.id)-t\(String(format: "%02d", index + 1))"
                    let track = AppBoyTrack(
                        id: trackId,
                        albumId: seedAlbum.id,
                        consoleId: seedConsole.id,
                        consoleName: seedConsole.name,
                        albumTitle: seedAlbum.title,
                        trackNumber: index + 1,
                        title: item.0,
                        artist: seedAlbum.artist.trimmingCharacters(in: .whitespaces),
                        year: seedAlbum.year,
                        format: seedAlbum.format,
                        durationSeconds: item.1,
                        streamURI: "synth://\(seedConsole.id)/\(trackId)"
                    )
                    albumTracks.append(track)
                    tracksById[trackId] = track
                    totalDuration += item.1
                }
                tracksByAlbumId[seedAlbum.id] = albumTracks
                builtAlbums.append(AppBoyAlbum(
                    id: seedAlbum.id,
                    consoleId: seedConsole.id,
                    consoleName: seedConsole.name,
                    title: seedAlbum.title,
                    artist: seedAlbum.artist.trimmingCharacters(in: .whitespaces),
                    year: seedAlbum.year,
                    trackCount: albumTracks.count,
                    totalDurationSeconds: totalDuration,
                    artworkDataURL: cartridgeSVGDataURL(
                        code: seedConsole.code,
                        title: seedAlbum.title.uppercased(),
                        accent: seedAlbum.accent
                    )
                ))
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
            sourceLabel: "Built-in VGM",
            consoleCount: consoles.count,
            albumCount: albumCount,
            trackCount: tracksById.count,
            consoles: consoles
        )
        return (snapshot, tracksById, tracksByAlbumId)
    }
}
