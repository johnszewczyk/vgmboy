import Foundation
import FrontendPreferencesCore
import VGMBoyKit

extension FrontendPreferencesKeySet {
    static let spcBoyWK = FrontendPreferencesKeySet(
        autoResizeEnabledKey: "SPCBoyWK.autoResizeAnimationEnabled",
        selectionEnabledKey: "SPCBoyWK.selectionAnimationEnabled",
        autoResizeMillisecondsKey: "SPCBoyWK.autoResizeAnimationMilliseconds",
        selectionMillisecondsKey: "SPCBoyWK.selectionAnimationMilliseconds",
        columnAutoSizeKey: "SPCBoyWK.columnAutoSize",
        mainWindowAlwaysOnTopKey: "SPCBoyWK.mainWindowAlwaysOnTop",
        settingsWindowAlwaysOnTopKey: "SPCBoyWK.settingsWindowAlwaysOnTop"
    )
}

/// The typed native persistence boundary for SPCBoy. JavaScript receives a JSON
/// projection, but it no longer owns or migrates the durable preference schema.
struct SPCBoyPreferencesSnapshot: Codable, Sendable {
    enum SnapshotError: Error { case invalidJSON }
    struct PlaybackRate: Codable, Sendable { var numerator: Int?; var denominator: Int? }
    enum RepeatMode: String, Codable, Sendable { case off, all, one }
    enum SidebarMode: String, Codable, Sendable { case paths, consoles, diskPath, favorites }
    enum FavoriteOrder: String, Codable, Sendable { case historical, alphabetical }
    enum PlaylistSortColumn: String, Codable, Sendable { case filename, title, game, artist, system, path, lengthLabel }
    enum SortDirection: String, Codable, Sendable { case ascending, descending }

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
    var libvgmPlaybackSpeed: PlaybackRate?
    var libvgmPlaybackSpeedEnabled: Bool?
    var uiItemSpacingRem: Double?
    var rootPath: String?
    var localBrowserEnabled: Bool?
    var selectedFolderPath: String?
    var selectedBrowserPath: String?
    var sidebarMode: SidebarMode?
    var favoriteSortOrder: FavoriteOrder?
    var selectedDatabaseGameKey: String?
    var collapsedConsoleNames: [String]?
    var lastSelectedTrackId: String?
    var uiFontSizePt: Double?
    var sidebarFontSizePt: Double?
    var sidebarTextColor: String?
    var sidebarMonospace: Bool?
    var sidebarPathCounts: Bool?
    var playlistFontSizePt: Double?
    var playlistTextColor: String?
    var playlistMonospace: Bool?
    var applicationMonospace: Bool?
    var playlistHeaderBold: Bool?
    var sidebarWidthPercent: Double?
    var accentColor: String?
    var aacExportDirectory: String?
    var routingPreferences: [String: String]?
    var archiveCacheEnabled: Bool?
    var archiveCacheLimitBytes: Int64?
    var columnOrder: [String]?
    var columnWidths: [String: Double]?
    var columnVisibility: [String: Bool]?
    var columnAutoSize: Bool?
    var sortColumn: PlaylistSortColumn?
    var sortDirection: SortDirection?
    var autoResizeAnimationMilliseconds: Int?
    var selectionAnimationMilliseconds: Int?
    var autoResizeAnimationEnabled: Bool?
    var selectionAnimationEnabled: Bool?
    var mainWindowAlwaysOnTop: Bool?
    var settingsWindowAlwaysOnTop: Bool?

    init(jsonObject: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        self = try JSONDecoder().decode(Self.self, from: data)
        normalizeSharedPlaybackPreferences()
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.clamp(
            autoResizeAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
        selectionAnimationMilliseconds = FrontendAnimationTimings.clamp(
            selectionAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
        autoResizeAnimationEnabled = autoResizeAnimationEnabled ?? true
        selectionAnimationEnabled = selectionAnimationEnabled ?? true
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
            numerator: shared.libgmeTempo.numerator,
            denominator: shared.libgmeTempo.denominator
        )
        playbackSpeedEnabled = shared.libgmeTempoEnabled
        libvgmPlaybackSpeed = .init(
            numerator: shared.libvgmTempo.numerator,
            denominator: shared.libvgmTempo.denominator
        )
        libvgmPlaybackSpeedEnabled = shared.libvgmTempoEnabled
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
        selectionAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
        autoResizeAnimationEnabled = true
        selectionAnimationEnabled = true
        mainWindowAlwaysOnTop = false
        settingsWindowAlwaysOnTop = false
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

    private mutating func normalizeSharedPlaybackPreferences() {
        func tempo(_ rate: PlaybackRate?) -> PlaybackTempo {
            PlaybackTempo(
                numerator: rate?.numerator ?? PlaybackTempo.defaultValue.numerator,
                denominator: rate?.denominator ?? PlaybackTempo.defaultValue.denominator
            )
        }

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
            libgmeTempo: tempo(playbackSpeed),
            libgmeTempoEnabled: playbackSpeedEnabled ?? false,
            libvgmTempo: tempo(libvgmPlaybackSpeed),
            libvgmTempoEnabled: libvgmPlaybackSpeedEnabled ?? false
        )
        manualPlayTimeSeconds = shared.timing.longPlaySeconds
        unknownDurationSeconds = shared.timing.unknownDurationSeconds
        fadeEnabled = shared.fadeEnabled
        spcFadeSeconds = shared.timing.fadeSeconds
        equalizerEnabled = shared.equalizer.enabled
        equalizerBandGains = shared.equalizer.gainsDecibels.map(Double.init)
        appVolume = Double(shared.outputVolume)
        monoEnabled = shared.monoEnabled
        playbackSpeed = PlaybackRate(
            numerator: shared.libgmeTempo.numerator,
            denominator: shared.libgmeTempo.denominator
        )
        playbackSpeedEnabled = shared.libgmeTempoEnabled
        libvgmPlaybackSpeed = PlaybackRate(
            numerator: shared.libvgmTempo.numerator,
            denominator: shared.libvgmTempo.denominator
        )
        libvgmPlaybackSpeedEnabled = shared.libvgmTempoEnabled
    }
}
