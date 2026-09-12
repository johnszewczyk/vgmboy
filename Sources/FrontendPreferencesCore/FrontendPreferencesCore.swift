import Foundation
import Observation

/// Shared interaction timings for the native and WebKit frontends.
public struct FrontendAnimationTimings: Codable, Equatable, Sendable {
    public static let defaultDurationMilliseconds = 200
    public static let allowedMilliseconds = 0...1_000

    public var autoResizeEnabled: Bool
    public var selectionEnabled: Bool
    public var autoResizeMilliseconds: Int
    public var selectionMilliseconds: Int

    public init(
        autoResizeEnabled: Bool = true,
        selectionEnabled: Bool = true,
        autoResizeMilliseconds: Int = Self.defaultDurationMilliseconds,
        selectionMilliseconds: Int = Self.defaultDurationMilliseconds
    ) {
        self.autoResizeEnabled = autoResizeEnabled
        self.selectionEnabled = selectionEnabled
        self.autoResizeMilliseconds = Self.clamp(autoResizeMilliseconds)
        self.selectionMilliseconds = Self.clamp(selectionMilliseconds)
    }

    private enum CodingKeys: String, CodingKey {
        case autoResizeEnabled
        case selectionEnabled
        case autoResizeMilliseconds
        case selectionMilliseconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            autoResizeEnabled: try container.decodeIfPresent(Bool.self, forKey: .autoResizeEnabled) ?? true,
            selectionEnabled: try container.decodeIfPresent(Bool.self, forKey: .selectionEnabled) ?? true,
            autoResizeMilliseconds: try container.decodeIfPresent(Int.self, forKey: .autoResizeMilliseconds) ?? Self.defaultDurationMilliseconds,
            selectionMilliseconds: try container.decodeIfPresent(Int.self, forKey: .selectionMilliseconds) ?? Self.defaultDurationMilliseconds
        )
    }

    public static func clamp(_ value: Int) -> Int {
        min(max(value, allowedMilliseconds.lowerBound), allowedMilliseconds.upperBound)
    }
}

public enum FrontendAppOptionSection: String, CaseIterable, Codable, Sendable {
    case database
    case interface
    case windows
    public var title: String { rawValue.capitalized }
}

public enum FrontendWindowRole: String, CaseIterable, Codable, Sendable {
    case main
    case settings
    case about
}

public struct FrontendWindowPreferences: Codable, Equatable, Sendable {
    public var mainAlwaysOnTop: Bool
    public var settingsAlwaysOnTop: Bool

    public init(mainAlwaysOnTop: Bool = false, settingsAlwaysOnTop: Bool = false) {
        self.mainAlwaysOnTop = mainAlwaysOnTop
        self.settingsAlwaysOnTop = settingsAlwaysOnTop
    }
}

public struct FrontendInterfacePreferences: Codable, Equatable, Sendable {
    public var animations: FrontendAnimationTimings
    public var windows: FrontendWindowPreferences
    public var columnAutoSize: Bool

    public init(
        animations: FrontendAnimationTimings = .init(),
        windows: FrontendWindowPreferences = .init(),
        columnAutoSize: Bool = true
    ) {
        self.animations = animations
        self.windows = windows
        self.columnAutoSize = columnAutoSize
    }

    private enum CodingKeys: String, CodingKey {
        case animations
        case windows
        case columnAutoSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            animations: try container.decodeIfPresent(FrontendAnimationTimings.self, forKey: .animations) ?? .init(),
            windows: try container.decodeIfPresent(FrontendWindowPreferences.self, forKey: .windows) ?? .init(),
            columnAutoSize: try container.decodeIfPresent(Bool.self, forKey: .columnAutoSize) ?? true
        )
    }
}

/// UserDefaults names for the shared frontend preference subset. Each app owns
/// its namespace while the meaning and migration behavior stay shared.
public struct FrontendPreferencesKeySet: Equatable, Sendable {
    public let autoResizeEnabledKey: String
    public let selectionEnabledKey: String
    public let autoResizeMillisecondsKey: String
    public let selectionMillisecondsKey: String
    public let columnAutoSizeKey: String
    public let mainWindowAlwaysOnTopKey: String
    public let settingsWindowAlwaysOnTopKey: String

    public init(
        autoResizeEnabledKey: String,
        selectionEnabledKey: String,
        autoResizeMillisecondsKey: String,
        selectionMillisecondsKey: String,
        columnAutoSizeKey: String,
        mainWindowAlwaysOnTopKey: String,
        settingsWindowAlwaysOnTopKey: String
    ) {
        self.autoResizeEnabledKey = autoResizeEnabledKey
        self.selectionEnabledKey = selectionEnabledKey
        self.autoResizeMillisecondsKey = autoResizeMillisecondsKey
        self.selectionMillisecondsKey = selectionMillisecondsKey
        self.columnAutoSizeKey = columnAutoSizeKey
        self.mainWindowAlwaysOnTopKey = mainWindowAlwaysOnTopKey
        self.settingsWindowAlwaysOnTopKey = settingsWindowAlwaysOnTopKey
    }
}

/// Shared persistence mechanism for the native and WebKit frontend settings.
/// App-specific preference schemas remain outside this type.
public struct FrontendPreferencesStore {
    private let defaults: UserDefaults
    private let keys: FrontendPreferencesKeySet

    public init(defaults: UserDefaults = .standard, keys: FrontendPreferencesKeySet) {
        self.defaults = defaults
        self.keys = keys
    }

    public func load() -> FrontendInterfacePreferences {
        FrontendInterfacePreferences(
            animations: FrontendAnimationTimings(
                autoResizeEnabled: defaults.object(forKey: keys.autoResizeEnabledKey) as? Bool ?? true,
                selectionEnabled: defaults.object(forKey: keys.selectionEnabledKey) as? Bool ?? true,
                autoResizeMilliseconds: defaults.object(forKey: keys.autoResizeMillisecondsKey)
                    .flatMap { ($0 as? NSNumber)?.intValue } ?? FrontendAnimationTimings.defaultDurationMilliseconds,
                selectionMilliseconds: defaults.object(forKey: keys.selectionMillisecondsKey)
                    .flatMap { ($0 as? NSNumber)?.intValue } ?? FrontendAnimationTimings.defaultDurationMilliseconds
            ),
            windows: FrontendWindowPreferences(
                mainAlwaysOnTop: defaults.object(forKey: keys.mainWindowAlwaysOnTopKey) as? Bool ?? false,
                settingsAlwaysOnTop: defaults.object(forKey: keys.settingsWindowAlwaysOnTopKey) as? Bool ?? false
            ),
            columnAutoSize: defaults.object(forKey: keys.columnAutoSizeKey) as? Bool ?? true
        )
    }

    public func save(_ value: FrontendInterfacePreferences) {
        defaults.set(value.animations.autoResizeEnabled, forKey: keys.autoResizeEnabledKey)
        defaults.set(value.animations.selectionEnabled, forKey: keys.selectionEnabledKey)
        defaults.set(value.animations.autoResizeMilliseconds, forKey: keys.autoResizeMillisecondsKey)
        defaults.set(value.animations.selectionMilliseconds, forKey: keys.selectionMillisecondsKey)
        defaults.set(value.columnAutoSize, forKey: keys.columnAutoSizeKey)
        defaults.set(value.windows.mainAlwaysOnTop, forKey: keys.mainWindowAlwaysOnTopKey)
        defaults.set(value.windows.settingsAlwaysOnTop, forKey: keys.settingsWindowAlwaysOnTopKey)
    }
}

/// Observable coordinator extracted from CocoaSpice's working implementation.
/// Both frontends can bind to the same typed state while retaining their own
/// renderer and broader app preference schema.
@MainActor @Observable
public final class FrontendPreferencesCoordinator {
    public private(set) var value: FrontendInterfacePreferences
    private let store: FrontendPreferencesStore

    public init(defaults: UserDefaults = .standard, keys: FrontendPreferencesKeySet) {
        store = FrontendPreferencesStore(defaults: defaults, keys: keys)
        value = store.load()
    }

    public func setAutoResizeEnabled(_ enabled: Bool) {
        value.animations.autoResizeEnabled = enabled
        store.save(value)
    }

    public func setSelectionEnabled(_ enabled: Bool) {
        value.animations.selectionEnabled = enabled
        store.save(value)
    }

    public func setAutoResizeMilliseconds(_ milliseconds: Int) {
        value.animations.autoResizeMilliseconds = FrontendAnimationTimings.clamp(milliseconds)
        store.save(value)
    }

    public func setSelectionMilliseconds(_ milliseconds: Int) {
        value.animations.selectionMilliseconds = FrontendAnimationTimings.clamp(milliseconds)
        store.save(value)
    }

    public func setColumnAutoSize(_ enabled: Bool) {
        value.columnAutoSize = enabled
        store.save(value)
    }

    public func setAlwaysOnTop(_ enabled: Bool, role: FrontendWindowRole) {
        switch role {
        case .main:
            value.windows.mainAlwaysOnTop = enabled
        case .settings:
            value.windows.settingsAlwaysOnTop = enabled
        case .about:
            return
        }
        store.save(value)
    }
}

/// Renderer-neutral spacing used when a playlist column is only as wide as
/// its displayed header. The renderers still measure fonts and convert this
/// value into their native width units.
public struct FrontendPlaylistColumnSizing: Codable, Equatable, Sendable {
    public static let defaultHorizontalPaddingPerSide = 8.0
    public static let allowedHorizontalPaddingPerSide = 0.0...16.0

    public let horizontalPaddingPerSide: Double

    public init(horizontalPaddingPerSide: Double = Self.defaultHorizontalPaddingPerSide) {
        self.horizontalPaddingPerSide = min(
            max(horizontalPaddingPerSide, Self.allowedHorizontalPaddingPerSide.lowerBound),
            Self.allowedHorizontalPaddingPerSide.upperBound
        )
    }

    public var horizontalPadding: Double {
        horizontalPaddingPerSide * 2
    }

    private enum CodingKeys: String, CodingKey {
        case horizontalPaddingPerSide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            horizontalPaddingPerSide: try container.decodeIfPresent(Double.self, forKey: .horizontalPaddingPerSide)
                ?? Self.defaultHorizontalPaddingPerSide
        )
    }
}

/// A renderer-neutral playlist column capability. Labels, widths, and the
/// mechanics of moving or hiding a column stay with the renderer; this only
/// describes the durable preference rules shared by every frontend.
public struct FrontendPlaylistColumnDefinition: Codable, Equatable, Sendable {
    public let id: String
    public let isReorderable: Bool
    public let isSortable: Bool
    public let isVisibleByDefault: Bool

    public init(
        id: String,
        isReorderable: Bool = true,
        isSortable: Bool = true,
        isVisibleByDefault: Bool = true
    ) {
        self.id = id
        self.isReorderable = isReorderable
        self.isSortable = isSortable
        self.isVisibleByDefault = isVisibleByDefault
    }
}

/// The validated, renderer-neutral part of a playlist's column preferences.
/// Width units intentionally remain local: CocoaSpice uses points while the
/// WebKit frontend uses percentage tracks.
public struct FrontendPlaylistColumnLayout: Codable, Equatable, Sendable {
    public let order: [String]
    public let visibility: [String: Bool]

    public init(order: [String], visibility: [String: Bool]) {
        self.order = order
        self.visibility = visibility
    }
}

public enum FrontendPlaylistSortDirection: String, Codable, Equatable, Sendable {
    case ascending
    case descending
}

/// An explicit playlist sort request. A missing or invalid column is always
/// inactive, so legacy preferences cannot accidentally replace natural catalog
/// order when a frontend loads.
public struct FrontendPlaylistSortPreference: Codable, Equatable, Sendable {
    public let isEnabled: Bool
    public let columnID: String?
    public let direction: FrontendPlaylistSortDirection

    public init(
        isEnabled: Bool,
        columnID: String?,
        direction: FrontendPlaylistSortDirection
    ) {
        self.isEnabled = isEnabled
        self.columnID = columnID
        self.direction = direction
    }
}

/// Validates the shared meaning of playlist layout and sort preferences while
/// allowing each renderer to choose its own visible column identifiers.
///
/// A non-reorderable column remains at its schema position. Persisted order
/// only rearranges reorderable columns, and invalid or stale IDs are ignored.
/// The resulting layout always retains at least one visible column.
public struct FrontendPlaylistColumnSchema: Equatable, Sendable {
    public let columns: [FrontendPlaylistColumnDefinition]

    public init(columns: [FrontendPlaylistColumnDefinition]) {
        precondition(!columns.isEmpty, "A playlist column schema needs at least one column.")
        precondition(
            Set(columns.map(\.id)).count == columns.count && columns.allSatisfy { !$0.id.isEmpty },
            "Playlist column identifiers must be non-empty and unique."
        )
        self.columns = columns
    }

    public func normalizedLayout(
        order: [String]?,
        visibility: [String: Bool]?
    ) -> FrontendPlaylistColumnLayout {
        let knownIDs = Set(columns.map(\.id))
        var requestedReorderableIDs: [String] = []
        var seenIDs: Set<String> = []

        for id in order ?? [] where knownIDs.contains(id) && seenIDs.insert(id).inserted {
            guard columns.first(where: { $0.id == id })?.isReorderable == true else { continue }
            requestedReorderableIDs.append(id)
        }

        for column in columns where column.isReorderable && !seenIDs.contains(column.id) {
            requestedReorderableIDs.append(column.id)
        }

        var reorderableIterator = requestedReorderableIDs.makeIterator()
        let normalizedOrder = columns.map { column in
            column.isReorderable ? reorderableIterator.next()! : column.id
        }

        var normalizedVisibility = Dictionary(uniqueKeysWithValues: columns.map { column in
            (column.id, visibility?[column.id] ?? column.isVisibleByDefault)
        })
        if !normalizedVisibility.values.contains(true), let firstColumn = columns.first {
            normalizedVisibility[firstColumn.id] = true
        }

        return FrontendPlaylistColumnLayout(
            order: normalizedOrder,
            visibility: normalizedVisibility
        )
    }

    public func normalizedSort(
        isEnabled: Bool?,
        columnID: String?,
        direction: FrontendPlaylistSortDirection?
    ) -> FrontendPlaylistSortPreference {
        let validColumnID = columnID.flatMap { id in
            columns.first(where: { $0.id == id && $0.isSortable })?.id
        }
        let isActive = isEnabled == true && validColumnID != nil
        return FrontendPlaylistSortPreference(
            isEnabled: isActive,
            columnID: isActive ? validColumnID : nil,
            direction: direction ?? .ascending
        )
    }
}

public struct FrontendOptionsManifest: Codable, Equatable, Sendable {
    public let version: Int
    public let appSections: [FrontendAppOptionSection]
    public let animationRange: ClosedRange<Int>
    public let defaultAnimationMilliseconds: Int

    public init(version: Int = 1, appSections: [FrontendAppOptionSection] = FrontendAppOptionSection.allCases) {
        self.version = version
        self.appSections = appSections
        self.animationRange = FrontendAnimationTimings.allowedMilliseconds
        self.defaultAnimationMilliseconds = FrontendAnimationTimings.defaultDurationMilliseconds
    }

    public static let v1 = FrontendOptionsManifest()
}
