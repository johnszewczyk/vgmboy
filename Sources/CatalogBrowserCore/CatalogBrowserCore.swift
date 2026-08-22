import CatalogReader
import Foundation

/// The browser modes are shared behavior, not a rendering concern. A skin may
/// present these as tabs, a menu, or a toolbar control.
public enum CatalogBrowserMode: String, CaseIterable, Codable, Sendable {
    case paths
    case consoles
    case diskPath
}

public enum CatalogBrowserView: String, Codable, Sendable {
    case paths
    case consoles
    case diskPath
    case search
}

public enum CatalogBrowserContentMode: String, Codable, Sendable {
    case database
    case tree
}

public enum CatalogBrowserResultSource: String, Codable, Sendable {
    case catalogPathIndex = "catalog-path-index"
    case diskPathTree = "disk-path-tree"
    case catalogConsoleIndex = "catalog-console-index"
}

/// Search is a temporary view. Clearing the query restores the selected mode.
public struct CatalogBrowserState: Codable, Equatable, Sendable {
    public private(set) var storedMode: CatalogBrowserMode
    public private(set) var query: String

    public init(mode: CatalogBrowserMode = .consoles, query: String = "") {
        self.storedMode = mode
        self.query = Self.normalizedQuery(query)
    }

    public var view: CatalogBrowserView {
        guard !query.isEmpty else {
            switch storedMode {
            case .paths: return .paths
            case .consoles: return .consoles
            case .diskPath: return .diskPath
            }
        }
        return .search
    }

    public var contentMode: CatalogBrowserContentMode {
        switch view {
        case .consoles, .search: return .database
        case .paths, .diskPath: return .tree
        }
    }

    public var resultSource: CatalogBrowserResultSource {
        switch view {
        case .paths: return .catalogPathIndex
        case .diskPath: return .diskPathTree
        case .consoles, .search: return .catalogConsoleIndex
        }
    }

    public mutating func setMode(_ mode: CatalogBrowserMode) {
        storedMode = mode
        query = ""
    }

    public mutating func setQuery(_ query: String) {
        self.query = Self.normalizedQuery(query)
    }

    private static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// UI-neutral game row. The native and WebKit skins should render this model,
/// rather than independently rebuilding it from CatalogGameBucket.
public struct CatalogBrowserGame: Identifiable, Codable, Equatable, Sendable {
    public let rootID: Int64
    public let rootPath: String
    public let name: String
    public let system: String
    public let trackCount: Int
    public let displayName: String

    public var id: String { "\(rootID)\u{1F}\(name)\u{1F}\(system)" }

    public var rootDisplayName: String {
        URL(fileURLWithPath: rootPath, isDirectory: true).lastPathComponent
    }

    public init(bucket: CatalogGameBucket, displayName: String? = nil) {
        let cleanName = bucket.game.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSystem = bucket.system.trimmingCharacters(in: .whitespacesAndNewlines)
        self.rootID = bucket.rootID
        self.rootPath = bucket.rootPath
        self.name = cleanName.isEmpty ? "Unknown Game" : cleanName
        self.system = cleanSystem
        self.trackCount = bucket.trackCount
        self.displayName = (displayName ?? (cleanName.isEmpty ? "Unknown Game" : cleanName))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct CatalogBrowserGameGroup: Identifiable, Codable, Equatable, Sendable {
    public let name: String
    public let games: [CatalogBrowserGame]

    public var id: String { name }
}

/// Deterministic grouping, disambiguation, sorting, and search shared by all
/// frontends. It consumes published catalog buckets and never opens SQLite.
public enum CatalogBrowserProjection {
    public static func games(from buckets: [CatalogGameBucket]) -> [CatalogBrowserGame] {
        let base = buckets.map { CatalogBrowserGame(bucket: $0) }
        let duplicateNames = Set(Dictionary(grouping: base, by: \.name).compactMap { key, values in
            values.count > 1 ? key : nil
        })
        let duplicateBuckets = Set(Dictionary(grouping: base, by: { "\($0.name)\u{1F}\($0.system)" }).compactMap { key, values in
            values.count > 1 ? key : nil
        })

        return base.map { game in
            guard duplicateNames.contains(game.name) else { return game }
            let system = game.system.isEmpty ? "Unknown System" : game.system
            let bucketKey = "\(game.name)\u{1F}\(game.system)"
            let source = duplicateBuckets.contains(bucketKey) ? " • \(game.rootDisplayName)" : ""
            return CatalogBrowserGame(bucket: CatalogGameBucket(
                rootID: game.rootID,
                rootPath: game.rootPath,
                game: game.name,
                system: game.system,
                trackCount: game.trackCount
            ), displayName: "\(game.name) (\(system)\(source))")
        }.sorted(by: gameComesBefore)
    }

    public static func groups(from games: [CatalogBrowserGame]) -> [CatalogBrowserGameGroup] {
        let grouped = Dictionary(grouping: games, by: { $0.system.isEmpty ? "Unknown Console" : $0.system })
        return grouped.keys.sorted(by: naturalAscending).map { name in
            CatalogBrowserGameGroup(
                name: name,
                games: (grouped[name] ?? []).sorted(by: gameComesBefore)
            )
        }
    }

    public static func search(_ games: [CatalogBrowserGame], query: String) -> [CatalogBrowserGame] {
        let terms = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return games }
        return games.filter { game in
            let haystack = "\(game.name) \(game.system) \(game.rootDisplayName) \(game.displayName)".lowercased()
            return terms.allSatisfy(haystack.contains)
        }
    }

    private static func gameComesBefore(_ left: CatalogBrowserGame, _ right: CatalogBrowserGame) -> Bool {
        let name = naturalCompare(left.name, right.name)
        if name != .orderedSame { return name == .orderedAscending }
        let system = naturalCompare(left.system, right.system)
        if system != .orderedSame { return system == .orderedAscending }
        let root = naturalCompare(left.rootPath, right.rootPath)
        if root != .orderedSame { return root == .orderedAscending }
        return left.id < right.id
    }

    private static func naturalAscending(_ left: String, _ right: String) -> Bool {
        naturalCompare(left, right) == .orderedAscending
    }

    private static func naturalCompare(_ left: String, _ right: String) -> ComparisonResult {
        left.compare(right, options: [.caseInsensitive, .numeric], range: nil, locale: Locale(identifier: "en_US_POSIX"))
    }
}
