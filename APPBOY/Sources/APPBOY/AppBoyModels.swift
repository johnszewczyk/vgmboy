import Foundation
import FrontendPreferencesCore
import VGMBoyEmbeddedCore

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
    let dumper: String
    let format: String
    let durationSeconds: Double
    let streamURI: String
    let canonicalSourcePath: String?
    let uacContainerPath: String?
    let uacMemberPath: String?
    let subsongIndex: Int
    let subsongCount: Int
    let introSeconds: Double
    let loopSeconds: Double
    let fadeSeconds: Double

    init(
        id: String,
        albumId: String,
        consoleId: String,
        consoleName: String,
        albumTitle: String,
        trackNumber: Int,
        title: String,
        artist: String,
        year: String,
        dumper: String = "",
        format: String,
        durationSeconds: Double,
        streamURI: String,
        canonicalSourcePath: String? = nil,
        uacContainerPath: String? = nil,
        uacMemberPath: String? = nil,
        subsongIndex: Int = 0,
        subsongCount: Int = 1,
        introSeconds: Double = 0.0,
        loopSeconds: Double = 0.0,
        fadeSeconds: Double = 0.0
    ) {
        self.id = id
        self.albumId = albumId
        self.consoleId = consoleId
        self.consoleName = consoleName
        self.albumTitle = albumTitle
        self.trackNumber = trackNumber
        self.title = title
        self.artist = artist
        self.year = year
        self.dumper = dumper
        self.format = format
        self.durationSeconds = durationSeconds
        self.streamURI = streamURI
        self.canonicalSourcePath = canonicalSourcePath
        self.uacContainerPath = uacContainerPath
        self.uacMemberPath = uacMemberPath
        self.subsongIndex = max(0, subsongIndex)
        self.subsongCount = max(1, subsongCount)
        self.introSeconds = max(0.0, introSeconds)
        self.loopSeconds = max(0.0, loopSeconds)
        self.fadeSeconds = max(0.0, fadeSeconds)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        albumId = try c.decode(String.self, forKey: .albumId)
        consoleId = try c.decode(String.self, forKey: .consoleId)
        consoleName = try c.decode(String.self, forKey: .consoleName)
        albumTitle = try c.decode(String.self, forKey: .albumTitle)
        trackNumber = try c.decodeIfPresent(Int.self, forKey: .trackNumber) ?? 1
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist) ?? ""
        year = try c.decodeIfPresent(String.self, forKey: .year) ?? ""
        dumper = try c.decodeIfPresent(String.self, forKey: .dumper) ?? ""
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        durationSeconds = try c.decodeIfPresent(Double.self, forKey: .durationSeconds) ?? 0.0
        streamURI = try c.decodeIfPresent(String.self, forKey: .streamURI) ?? ""
        canonicalSourcePath = try c.decodeIfPresent(String.self, forKey: .canonicalSourcePath)
        uacContainerPath = try c.decodeIfPresent(String.self, forKey: .uacContainerPath)
        uacMemberPath = try c.decodeIfPresent(String.self, forKey: .uacMemberPath)
        subsongIndex = max(0, try c.decodeIfPresent(Int.self, forKey: .subsongIndex) ?? 0)
        subsongCount = max(1, try c.decodeIfPresent(Int.self, forKey: .subsongCount) ?? 1)
        introSeconds = max(0.0, try c.decodeIfPresent(Double.self, forKey: .introSeconds) ?? 0.0)
        loopSeconds = max(0.0, try c.decodeIfPresent(Double.self, forKey: .loopSeconds) ?? 0.0)
        fadeSeconds = max(0.0, try c.decodeIfPresent(Double.self, forKey: .fadeSeconds) ?? 0.0)
    }
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
    let hasTitleSnap: Bool
    let titleSnapContainerPath: String?
    let titleSnapMemberPath: String?

    init(
        id: String,
        consoleId: String,
        consoleName: String,
        title: String,
        artist: String,
        year: String,
        trackCount: Int,
        totalDurationSeconds: Double,
        artworkDataURL: String,
        hasTitleSnap: Bool = false,
        titleSnapContainerPath: String? = nil,
        titleSnapMemberPath: String? = nil
    ) {
        self.id = id
        self.consoleId = consoleId
        self.consoleName = consoleName
        self.title = title
        self.artist = artist
        self.year = year
        self.trackCount = trackCount
        self.totalDurationSeconds = totalDurationSeconds
        self.artworkDataURL = artworkDataURL
        self.hasTitleSnap = hasTitleSnap
        self.titleSnapContainerPath = titleSnapContainerPath
        self.titleSnapMemberPath = titleSnapMemberPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        consoleId = try c.decode(String.self, forKey: .consoleId)
        consoleName = try c.decode(String.self, forKey: .consoleName)
        title = try c.decode(String.self, forKey: .title)
        artist = try c.decodeIfPresent(String.self, forKey: .artist) ?? ""
        year = try c.decodeIfPresent(String.self, forKey: .year) ?? ""
        trackCount = try c.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        totalDurationSeconds = try c.decodeIfPresent(Double.self, forKey: .totalDurationSeconds) ?? 0.0
        artworkDataURL = try c.decodeIfPresent(String.self, forKey: .artworkDataURL) ?? ""
        hasTitleSnap = try c.decodeIfPresent(Bool.self, forKey: .hasTitleSnap) ?? false
        titleSnapContainerPath = try c.decodeIfPresent(String.self, forKey: .titleSnapContainerPath)
        titleSnapMemberPath = try c.decodeIfPresent(String.self, forKey: .titleSnapMemberPath)
    }
}

struct AppBoyConsoleGroup: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let shortCode: String
    let albums: [AppBoyAlbum]
}

struct AppBoyCatalogSnapshot: Codable, Equatable, Sendable {
    let sourceLabel: String
    let databasePath: String
    let schemaVersion: Int
    let consoleCount: Int
    let albumCount: Int
    let trackCount: Int
    let artworkCount: Int
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
    var equalizerBandsDB: [Double] = Array(repeating: 0.0, count: EmbeddedEqualizerConfiguration.bandCount)
    var monoEnabled: Bool = false
    var fadeOutEnabled: Bool = true
    var fadeOutSeconds: Double = 5.0
    var longPlayEnabled: Bool = false
    var manualPlayTimeSeconds: Double = 180.0
    var playbackSpeedEnabled: Bool = false
    var playbackSpeedRate: Double = 1.25
    var playbackSpeedNumerator: Int = 5
    var playbackSpeedDenominator: Int = 4
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
        playbackSpeedNumerator = try c.decodeIfPresent(Int.self, forKey: .playbackSpeedNumerator) ?? d.playbackSpeedNumerator
        playbackSpeedDenominator = try c.decodeIfPresent(Int.self, forKey: .playbackSpeedDenominator) ?? d.playbackSpeedDenominator
        appVolume = try c.decodeIfPresent(Double.self, forKey: .appVolume) ?? d.appVolume
        remoteCatalogURL = try c.decodeIfPresent(String.self, forKey: .remoteCatalogURL) ?? d.remoteCatalogURL
    }

    mutating func normalize() {
        uiChromeFontSizePt = min(max(uiChromeFontSizePt, 9.0), 16.0)
        contentFontSizePt = min(max(contentFontSizePt, 9.5), 18.0)
        selectionAnimationMilliseconds = min(FrontendAnimationTimings.clamp(selectionAnimationMilliseconds), 600)
        galleryFrameScale = min(max(galleryFrameScale, 0.65), 1.6)
        galleryGapRem = min(max(galleryGapRem, 0.0), 1.0)
        galleryRadiusRem = min(max(galleryRadiusRem, 0.0), 1.0)

        let floatBands = EmbeddedEqualizerConfiguration.normalizedBands(equalizerBandsDB.map(Float.init))
        equalizerBandsDB = floatBands.map(Double.init)

        fadeOutSeconds = min(max(fadeOutSeconds, 0.0), 30.0)
        manualPlayTimeSeconds = min(max(manualPlayTimeSeconds, 15.0), 3600.0)

        let tempo = EmbeddedPlaybackTempo.snapped(multiplier: playbackSpeedRate)
        playbackSpeedRate = tempo.multiplier
        playbackSpeedNumerator = tempo.numerator
        playbackSpeedDenominator = tempo.denominator

        appVolume = FrontendPlaybackVolumeScale.normalized(appVolume)
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

struct AppBoyAudioDiagnostics: Codable, Equatable, Sendable {
    let backendName: String
    let transportState: String
    let sampleRateHz: Int
    let queuedBuffers: Int
    let targetBuffers: Int
    let framesScheduled: Int64
    let equalizerEnabled: Bool
    let headroomCompensationDB: Double
    let tempoDisplay: String
    let trackTitle: String
    let containerSummary: String
    let positionSeconds: Double
    let durationSeconds: Double
}
