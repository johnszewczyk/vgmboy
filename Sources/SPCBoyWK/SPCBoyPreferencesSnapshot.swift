import Foundation
import FrontendPreferencesCore

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
    var mainWindowAlwaysOnTop: Bool?
    var settingsWindowAlwaysOnTop: Bool?

    init(jsonObject: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        self = try JSONDecoder().decode(Self.self, from: data)
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.clamp(
            autoResizeAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
        selectionAnimationMilliseconds = FrontendAnimationTimings.clamp(
            selectionAnimationMilliseconds ?? FrontendAnimationTimings.defaultDurationMilliseconds
        )
    }

    init() {
        autoResizeAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
        selectionAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
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
}
