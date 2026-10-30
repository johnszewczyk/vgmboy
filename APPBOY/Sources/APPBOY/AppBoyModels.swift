import Foundation

struct AppBoyTrack: Codable, Equatable, Sendable {
    let id: String
    let albumId: String
    let consoleId: String
    let consoleName: String
    let albumTitle: String
    let trackNumber: Int
    let title: String
    let artist: String
    let year: String
    let format: String
    let durationSeconds: Double
    let streamURI: String
}

struct AppBoyAlbum: Codable, Equatable, Sendable {
    let id: String
    let consoleId: String
    let consoleName: String
    let title: String
    let artist: String
    let year: String
    let trackCount: Int
    let totalDurationSeconds: Double
    let artworkDataURL: String
}

struct AppBoyConsoleGroup: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let shortCode: String
    let albums: [AppBoyAlbum]
}

struct AppBoyCatalogSnapshot: Codable, Equatable, Sendable {
    let sourceLabel: String
    let consoleCount: Int
    let albumCount: Int
    let trackCount: Int
    let consoles: [AppBoyConsoleGroup]
}

struct AppBoyPlaylistTab: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var consoleName: String
    var sourceKind: String
    var sourceId: String?
    var trackIds: [String]
    var selectedTrackId: String?
}

struct AppBoyWorkspaceSnapshot: Codable, Equatable, Sendable {
    var activeTabId: String
    var tabs: [AppBoyPlaylistTab]
}

struct AppBoyFavoriteEntry: Codable, Equatable, Sendable {
    let trackId: String
    let addedAtISO8601: String
}

struct AppBoyHistoryEntry: Codable, Equatable, Sendable {
    let trackId: String
    let playedAtISO8601: String
}

struct AppBoyPreferencesSnapshot: Codable, Equatable, Sendable {
    var accentColor: String = "#38aaff"
    var uiChromePrimaryColor: String = "#111419"
    var uiChromeSecondaryColor: String = "#141820"
    var uiChromePaneColor: String = "#090b0f"
    var sidebarTextColor: String = "#b6b7dc"
    var uiChromeFontSizePt: Double = 11.0
    var contentFontSizePt: Double = 11.5
    var uiChromeMonospace: Bool = true
    var contentMonospace: Bool = true
    var selectionAnimationEnabled: Bool = true
    var selectionAnimationMilliseconds: Int = 180
    var playlistLinkMode: Bool = true
    var sidebarTrackCounts: Bool = true
    var favoriteSortOrder: String = "historical"
    var galleryFitMode: String = "crop"
    var galleryFrameScale: Double = 1.0
    var galleryGapRem: Double = 0.35
    var galleryRadiusRem: Double = 0.2
    var repeatMode: String = "off"
    var equalizerEnabled: Bool = false
    var equalizerBandsDB: [Double] = Array(repeating: 0.0, count: 10)
    var monoEnabled: Bool = false
    var fadeOutEnabled: Bool = true
    var fadeOutSeconds: Double = 5.0
    var longPlayEnabled: Bool = false
    var manualPlayTimeSeconds: Double = 180.0
    var playbackSpeedEnabled: Bool = false
    var playbackSpeedRate: Double = 1.25
    var appVolume: Double = 1.0
    var remoteCatalogURL: String = ""

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppBoyPreferencesSnapshot()
        accentColor = try c.decodeIfPresent(String.self, forKey: .accentColor) ?? d.accentColor
        uiChromePrimaryColor = try c.decodeIfPresent(String.self, forKey: .uiChromePrimaryColor) ?? d.uiChromePrimaryColor
        uiChromeSecondaryColor = try c.decodeIfPresent(String.self, forKey: .uiChromeSecondaryColor) ?? d.uiChromeSecondaryColor
        uiChromePaneColor = try c.decodeIfPresent(String.self, forKey: .uiChromePaneColor) ?? d.uiChromePaneColor
        sidebarTextColor = try c.decodeIfPresent(String.self, forKey: .sidebarTextColor) ?? d.sidebarTextColor
        uiChromeFontSizePt = try c.decodeIfPresent(Double.self, forKey: .uiChromeFontSizePt) ?? d.uiChromeFontSizePt
        contentFontSizePt = try c.decodeIfPresent(Double.self, forKey: .contentFontSizePt) ?? d.contentFontSizePt
        uiChromeMonospace = try c.decodeIfPresent(Bool.self, forKey: .uiChromeMonospace) ?? d.uiChromeMonospace
        contentMonospace = try c.decodeIfPresent(Bool.self, forKey: .contentMonospace) ?? d.contentMonospace
        selectionAnimationEnabled = try c.decodeIfPresent(Bool.self, forKey: .selectionAnimationEnabled) ?? d.selectionAnimationEnabled
        selectionAnimationMilliseconds = try c.decodeIfPresent(Int.self, forKey: .selectionAnimationMilliseconds) ?? d.selectionAnimationMilliseconds
        playlistLinkMode = try c.decodeIfPresent(Bool.self, forKey: .playlistLinkMode) ?? d.playlistLinkMode
        sidebarTrackCounts = try c.decodeIfPresent(Bool.self, forKey: .sidebarTrackCounts) ?? d.sidebarTrackCounts
        favoriteSortOrder = try c.decodeIfPresent(String.self, forKey: .favoriteSortOrder) ?? d.favoriteSortOrder
        galleryFitMode = try c.decodeIfPresent(String.self, forKey: .galleryFitMode) ?? d.galleryFitMode
        galleryFrameScale = try c.decodeIfPresent(Double.self, forKey: .galleryFrameScale) ?? d.galleryFrameScale
        galleryGapRem = try c.decodeIfPresent(Double.self, forKey: .galleryGapRem) ?? d.galleryGapRem
        galleryRadiusRem = try c.decodeIfPresent(Double.self, forKey: .galleryRadiusRem) ?? d.galleryRadiusRem
        repeatMode = try c.decodeIfPresent(String.self, forKey: .repeatMode) ?? d.repeatMode
        equalizerEnabled = try c.decodeIfPresent(Bool.self, forKey: .equalizerEnabled) ?? d.equalizerEnabled
        equalizerBandsDB = try c.decodeIfPresent([Double].self, forKey: .equalizerBandsDB) ?? d.equalizerBandsDB
        monoEnabled = try c.decodeIfPresent(Bool.self, forKey: .monoEnabled) ?? d.monoEnabled
        fadeOutEnabled = try c.decodeIfPresent(Bool.self, forKey: .fadeOutEnabled) ?? d.fadeOutEnabled
        fadeOutSeconds = try c.decodeIfPresent(Double.self, forKey: .fadeOutSeconds) ?? d.fadeOutSeconds
        longPlayEnabled = try c.decodeIfPresent(Bool.self, forKey: .longPlayEnabled) ?? d.longPlayEnabled
        manualPlayTimeSeconds = try c.decodeIfPresent(Double.self, forKey: .manualPlayTimeSeconds) ?? d.manualPlayTimeSeconds
        playbackSpeedEnabled = try c.decodeIfPresent(Bool.self, forKey: .playbackSpeedEnabled) ?? d.playbackSpeedEnabled
        playbackSpeedRate = try c.decodeIfPresent(Double.self, forKey: .playbackSpeedRate) ?? d.playbackSpeedRate
        appVolume = try c.decodeIfPresent(Double.self, forKey: .appVolume) ?? d.appVolume
        remoteCatalogURL = try c.decodeIfPresent(String.self, forKey: .remoteCatalogURL) ?? d.remoteCatalogURL
    }

    mutating func normalize() {
        uiChromeFontSizePt = min(max(uiChromeFontSizePt, 9.0), 16.0)
        contentFontSizePt = min(max(contentFontSizePt, 9.5), 18.0)
        selectionAnimationMilliseconds = min(max(selectionAnimationMilliseconds, 0), 600)
        galleryFrameScale = min(max(galleryFrameScale, 0.65), 1.6)
        galleryGapRem = min(max(galleryGapRem, 0.0), 1.0)
        galleryRadiusRem = min(max(galleryRadiusRem, 0.0), 1.0)
        if equalizerBandsDB.count < 10 {
            equalizerBandsDB.append(contentsOf: Array(repeating: 0.0, count: 10 - equalizerBandsDB.count))
        } else if equalizerBandsDB.count > 10 {
            equalizerBandsDB = Array(equalizerBandsDB.prefix(10))
        }
        equalizerBandsDB = equalizerBandsDB.map { val in
            guard val.isFinite else { return 0.0 }
            let clamped = min(max(val, -12.0), 12.0)
            return (clamped * 2.0).rounded() / 2.0
        }
        fadeOutSeconds = min(max(fadeOutSeconds, 0.0), 30.0)
        manualPlayTimeSeconds = min(max(manualPlayTimeSeconds, 15.0), 3600.0)
        playbackSpeedRate = min(max(playbackSpeedRate, 0.5), 2.0)
        appVolume = (min(max(appVolume, 0.0), 1.0) * 20.0).rounded() / 20.0
        if !["historical", "alphabetical"].contains(favoriteSortOrder) {
            favoriteSortOrder = "historical"
        }
        if !["crop", "pad"].contains(galleryFitMode) {
            galleryFitMode = "crop"
        }
        if !["off", "all", "one"].contains(repeatMode) {
            repeatMode = "off"
        }
        accentColor = Self.cleanColor(accentColor, fallback: "#38aaff")
        uiChromePrimaryColor = Self.cleanColor(uiChromePrimaryColor, fallback: "#111419")
        uiChromeSecondaryColor = Self.cleanColor(uiChromeSecondaryColor, fallback: "#141820")
        uiChromePaneColor = Self.cleanColor(uiChromePaneColor, fallback: "#090b0f")
        sidebarTextColor = Self.cleanColor(sidebarTextColor, fallback: "#b6b7dc")
        remoteCatalogURL = remoteCatalogURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanColor(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64, !trimmed.contains(";"), !trimmed.contains("{") else {
            return fallback
        }
        return trimmed
    }
}

struct AppBoyPlaybackStateSnapshot: Codable, Equatable, Sendable {
    let generation: Int
    let trackId: String?
    let transportState: String
    let elapsedSeconds: Double
    let durationSeconds: Double
    let playbackRate: Double
    let errorMessage: String?
}
