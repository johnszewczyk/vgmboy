import Foundation
import FrontendPreferencesCore
import VGMBoyKit

extension FrontendPreferencesKeySet {
    static let sb2 = FrontendPreferencesKeySet(
        autoResizeEnabledKey: "SB2.autoResizeAnimationEnabled",
        selectionEnabledKey: "SB2.selectionAnimationEnabled",
        autoResizeMillisecondsKey: "SB2.autoResizeAnimationMilliseconds",
        selectionMillisecondsKey: "SB2.selectionAnimationMilliseconds",
        columnAutoSizeKey: "SB2.columnAutoSize",
        mainWindowAlwaysOnTopKey: "SB2.mainWindowAlwaysOnTop",
        settingsWindowAlwaysOnTopKey: "SB2.settingsWindowAlwaysOnTop"
    )
}

/// The typed native persistence boundary for SPCBoy. JavaScript receives a JSON
/// projection, but it no longer owns or migrates the durable preference schema.
struct SB2PreferencesSnapshot: Codable, Sendable {
    enum SnapshotError: Error { case invalidJSON }
    struct PlaybackRate: Codable, Sendable { var numerator: Int?; var denominator: Int? }
    enum RepeatMode: String, Codable, Sendable { case off, all, one }
    enum SidebarMode: String, Codable, Sendable { case paths, consoles, diskPath, favorites }
    enum FavoriteOrder: String, Codable, Sendable { case historical, alphabetical }

    private static let playlistColumnSchema = FrontendPlaylistColumnSchema(columns: [
        .init(id: "favorite", isReorderable: false, isSortable: false),
        .init(id: "index", isSortable: false),
        .init(id: "filename"),
        .init(id: "title"),
        .init(id: "game"),
        .init(id: "artist"),
        .init(id: "system"),
        .init(id: "path"),
        .init(id: "lengthLabel")
    ])

    var manualPlayTimeSeconds: Int?
    var unknownDurationSeconds: Int?
    var longPlayEnabled: Bool?
    var repeatMode: RepeatMode?
    var queuedSkipsEnabled: Bool?
    var fadeEnabled: Bool?
    var equalizerEnabled: Bool?
    var equalizerBandGains: [Double]?
    var appVolume: Double?
    var monoEnabled: Bool?
    var spcFadeSeconds: Int?
    var playbackSpeed: PlaybackRate?
    var playbackSpeedEnabled: Bool?
    // Decoded once for migration from the old backend-specific SB2 controls.
    var libvgmPlaybackSpeed: PlaybackRate?
    var libvgmPlaybackSpeedEnabled: Bool?
    var uiItemSpacingRem: Double? // Legacy decode only.
    var uiItemSpacingPx: Int?
    var rootPath: String?
    var localBrowserEnabled: Bool?
    var selectedFolderPath: String?
    var selectedBrowserPath: String?
    var sidebarMode: SidebarMode?
    var favoriteSortOrder: FavoriteOrder?
    var selectedDatabaseGameKey: String?
    var collapsedConsoleNames: [String]?
    var gallerySizeScale: Double?
    var galleryGapRem: Double?
    var galleryRadiusRem: Double?
    var galleryFitMode: String?
    var uiFontSizePt: Double?
    var uiChromeFontSizePt: Double?
    var contentFontSizePt: Double?
    var sidebarFontSizePt: Double?
    var sidebarTextColor: String?
    var sidebarMonospace: Bool?
    var sidebarPathCounts: Bool?
    var playlistFontSizePt: Double?
    var playlistTextColor: String?
    var playlistHeaderTextColor: String?
    var playlistMonospace: Bool?
    var applicationMonospace: Bool?
    var uiChromeMonospace: Bool?
    var contentMonospace: Bool?
    var playlistHeaderBold: Bool?
    var titlebarTextColor: String?
    var titlebarBold: Bool?
    var sidebarWidthPercent: Double?
    var accentColor: String?
    var uiChromeColor: String?
    var uiChromePrimaryColor: String?
    var uiChromeSecondaryColor: String?
    var uiChromePaneColor: String?
    var uiChromeHoverColor: String?
    var uiChromeDividerColor: String?
    var aacExportDirectory: String?
    var routingPreferences: [String: String]?
    var archiveCacheEnabled: Bool?
    var archiveCacheLimitBytes: Int64?
    var columnOrder: [String]?
    var columnWidths: [String: Double]?
    var columnVisibility: [String: Bool]?
    var playlistColumnSizing: FrontendPlaylistColumnSizing?
    var columnAutoSize: Bool?
    var playlistLinkMode: Bool?
    var playlistSortEnabled: Bool?
    var sortColumn: String?
    var sortDirection: String?
    var autoResizeAnimationMilliseconds: Int?
    var selectionAnimationMilliseconds: Int?
    var autoResizeAnimationEnabled: Bool?
    var selectionAnimationEnabled: Bool?
    var mainWindowAlwaysOnTop: Bool?
    var settingsWindowAlwaysOnTop: Bool?

    init(jsonObject: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        self = try JSONDecoder().decode(Self.self, from: data)
        normalizeForPersistence()
    }

    init() {
        let shared = PlaybackPreferences.defaultValue
        manualPlayTimeSeconds = shared.timing.longPlaySeconds
        unknownDurationSeconds = shared.timing.unknownDurationSeconds
        longPlayEnabled = false
        fadeEnabled = shared.fadeEnabled
        spcFadeSeconds = shared.timing.fadeSeconds
        equalizerEnabled = shared.equalizer.enabled
        equalizerBandGains = shared.equalizer.gainsDecibels.map(Double.init)
        appVolume = Double(shared.outputVolume)
        monoEnabled = shared.monoEnabled
        playbackSpeed = .init(
            numerator: shared.playbackTempo.numerator,
            denominator: shared.playbackTempo.denominator
        )
        playbackSpeedEnabled = shared.playbackTempoEnabled
        libvgmPlaybackSpeed = nil
        libvgmPlaybackSpeedEnabled = nil
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
        selectionAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
        autoResizeAnimationEnabled = true
        selectionAnimationEnabled = true
        titlebarTextColor = "#e0e1eb"
        titlebarBold = false
        playlistColumnSizing = FrontendPlaylistColumnSizing()
        playlistLinkMode = false
        playlistSortEnabled = false
        mainWindowAlwaysOnTop = false
        settingsWindowAlwaysOnTop = false
        normalizeForPersistence()
    }

    func jsonObject() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SnapshotError.invalidJSON
        }
        return object
    }

    var frontendInterfacePreferences: FrontendInterfacePreferences {
        FrontendInterfacePreferences(
            animations: FrontendAnimationTimings(
                autoResizeEnabled: autoResizeAnimationEnabled ?? true,
                selectionEnabled: selectionAnimationEnabled ?? true,
                autoResizeMilliseconds: autoResizeAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds,
                selectionMilliseconds: selectionAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
            ),
            windows: FrontendWindowPreferences(
                mainAlwaysOnTop: mainWindowAlwaysOnTop ?? false,
                settingsAlwaysOnTop: settingsWindowAlwaysOnTop ?? false
            ),
            columnAutoSize: columnAutoSize ?? true
        )
    }

    mutating func apply(frontendInterface preferences: FrontendInterfacePreferences) {
        autoResizeAnimationEnabled = preferences.animations.autoResizeEnabled
        selectionAnimationEnabled = preferences.animations.selectionEnabled
        autoResizeAnimationMilliseconds = preferences.animations.autoResizeMilliseconds
        selectionAnimationMilliseconds = preferences.animations.selectionMilliseconds
        columnAutoSize = preferences.columnAutoSize
        mainWindowAlwaysOnTop = preferences.windows.mainAlwaysOnTop
        settingsWindowAlwaysOnTop = preferences.windows.settingsAlwaysOnTop
    }

    /// Repairs the durable, renderer-neutral preference subset before it is
    /// exposed to WebKit or written back to the app-specific JSON container.
    mutating func normalizeForPersistence() {
        if uiItemSpacingPx == nil {
            let legacy = uiItemSpacingRem ?? 0
            let pixels = legacy * Double(uiChromeFontSizePt ?? 10) * 8 / 3
            uiItemSpacingPx = legacy > 0 && pixels.isFinite ? Int(min(32, max(0, pixels.rounded()))) : 0
        }
        uiItemSpacingPx = min(32, max(0, uiItemSpacingPx ?? 0))
        uiItemSpacingRem = nil
        // SB2 is intentionally database-only. Clear legacy local-browser
        // values whenever preferences cross the native persistence boundary.
        rootPath = nil
        localBrowserEnabled = false
        selectedFolderPath = nil
        selectedBrowserPath = nil
        sidebarMode = sidebarMode == .paths ? .paths : .consoles
        gallerySizeScale = min(1.6, max(0.65, gallerySizeScale ?? 1))
        galleryGapRem = min(1, max(0, galleryGapRem ?? 0))
        galleryRadiusRem = min(1, max(0, galleryRadiusRem ?? 0))
        galleryFitMode = galleryFitMode == "pad" ? "pad" : "crop"
        normalizeSharedPlaybackPreferences()
        normalizePlaylistColumnPreferences()
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.clamp(
            autoResizeAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
        selectionAnimationMilliseconds = FrontendAnimationTimings.clamp(
            selectionAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
        autoResizeAnimationEnabled = autoResizeAnimationEnabled ?? true
        selectionAnimationEnabled = selectionAnimationEnabled ?? true
        titlebarTextColor = titlebarTextColor ?? "#e0e1eb"
        titlebarBold = titlebarBold ?? false
        playlistLinkMode = playlistLinkMode ?? false
        playlistColumnSizing = FrontendPlaylistColumnSizing(
            horizontalPaddingPerSide: playlistColumnSizing?.horizontalPaddingPerSide
                ?? FrontendPlaylistColumnSizing.defaultHorizontalPaddingPerSide
        )
    }

    private mutating func normalizeSharedPlaybackPreferences() {
        func tempo(_ rate: PlaybackRate?) -> PlaybackTempo {
            PlaybackTempo(
                numerator: rate?.numerator ?? PlaybackTempo.defaultValue.numerator,
                denominator: rate?.denominator ?? PlaybackTempo.defaultValue.denominator
            )
        }

        let migratedTempo = PlaybackPreferences.migrateBackendTempo(
            libgmeTempo: tempo(playbackSpeed),
            libgmeEnabled: playbackSpeedEnabled,
            libvgmTempo: tempo(libvgmPlaybackSpeed),
            libvgmEnabled: libvgmPlaybackSpeedEnabled
        )

        let shared = PlaybackPreferences(
            timing: PlaybackTimingPreferences(
                longPlaySeconds: manualPlayTimeSeconds ?? PlaybackTimingPreferences.defaultLongPlaySeconds,
                unknownDurationSeconds: unknownDurationSeconds ?? PlaybackTimingPreferences.defaultUnknownDurationSeconds,
                fadeSeconds: spcFadeSeconds ?? PlaybackTimingPreferences.defaultFadeSeconds
            ),
            fadeEnabled: fadeEnabled ?? true,
            equalizerEnabled: equalizerEnabled ?? false,
            equalizerBandGains: equalizerBandGains?.map(Float.init) ?? [],
            outputVolume: Float(appVolume ?? 1),
            monoEnabled: monoEnabled ?? false,
            playbackTempo: migratedTempo.tempo,
            playbackTempoEnabled: migratedTempo.enabled
        )
        manualPlayTimeSeconds = shared.timing.longPlaySeconds
        unknownDurationSeconds = shared.timing.unknownDurationSeconds
        fadeEnabled = shared.fadeEnabled
        spcFadeSeconds = shared.timing.fadeSeconds
        equalizerEnabled = shared.equalizer.enabled
        equalizerBandGains = shared.equalizer.gainsDecibels.map(Double.init)
        appVolume = Double(shared.outputVolume)
        monoEnabled = shared.monoEnabled
        playbackSpeed = PlaybackRate(numerator: shared.playbackTempo.numerator, denominator: shared.playbackTempo.denominator)
        playbackSpeedEnabled = shared.playbackTempoEnabled
        libvgmPlaybackSpeed = nil
        libvgmPlaybackSpeedEnabled = nil
    }

    private mutating func normalizePlaylistColumnPreferences() {
        let layout = Self.playlistColumnSchema.normalizedLayout(
            order: columnOrder,
            visibility: columnVisibility
        )
        let sort = Self.playlistColumnSchema.normalizedSort(
            isEnabled: playlistSortEnabled,
            columnID: sortColumn,
            direction: sortDirection.flatMap(FrontendPlaylistSortDirection.init(rawValue:))
        )
        columnOrder = layout.order
        columnVisibility = layout.visibility
        playlistSortEnabled = sort.isEnabled
        sortColumn = sort.columnID
        sortDirection = sort.direction.rawValue
    }
}
