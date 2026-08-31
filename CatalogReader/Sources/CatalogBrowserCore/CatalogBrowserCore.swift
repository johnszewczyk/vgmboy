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

public enum SidebarRowKind: String, Codable, Sendable { case folder, leaf, group }
public enum SidebarRowGesture: String, Codable, Sendable { case primaryClick, disclosureClick, repeatedPrimaryClick, activate }
public enum SidebarRowIntent: String, Codable, Sendable { case select, preview, toggleExpansion, activate }

/// UI-neutral row policy. Renderers retain focus, geometry, and animation.
public enum SidebarRowInteraction {
    public static func intent(kind: SidebarRowKind, gesture: SidebarRowGesture, wasSelected: Bool = false) -> SidebarRowIntent {
        switch gesture {
        case .activate:
            return .activate
        case .disclosureClick:
            return kind == .leaf ? .select : .toggleExpansion
        case .repeatedPrimaryClick:
            return kind == .leaf ? .preview : .toggleExpansion
        case .primaryClick:
            if kind == .leaf { return .preview }
            return wasSelected ? .toggleExpansion : .select
        }
    }
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

/// UI-neutral incremental search index. Frontends provide one searchable
/// value per projected row and retain only the row-model adapter. Extending a
/// query reuses the previous candidate indices; a non-extension restarts from
/// the complete value set so results remain exact.
public struct CatalogSearchIndex: Sendable {
    private let normalizedValues: [String]
    private var previousTerms: [String] = []
    private var previousMatches: [Int]

    public init(searchValues: [String]) {
        normalizedValues = searchValues.map { $0.lowercased() }
        previousMatches = Array(searchValues.indices)
    }

    public mutating func matchingIndices(query: String) -> [Int] {
        let terms = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else {
            previousTerms = []
            previousMatches = Array(normalizedValues.indices)
            return previousMatches
        }

        let candidates = terms.starts(with: previousTerms)
            ? previousMatches
            : Array(normalizedValues.indices)
        let matches = candidates.filter { index in
            terms.allSatisfy { normalizedValues[index].contains($0) }
        }
        previousTerms = terms
        previousMatches = matches
        return matches
    }
}

/// UI-neutral source-file search index. It precomputes the same filename,
/// folder, and full-path search value used by the native Files sidebar and
/// supports cooperative cancellation for large catalogs.
public struct CatalogFileSearchIndex: Sendable {
    private struct Entry: Sendable {
        let file: CatalogFileBucket
        let searchableText: String
    }

    private let entries: [Entry]

    public init(files: [CatalogFileBucket]) {
        entries = files.map { file in
            Entry(
                file: file,
                searchableText: "\(Self.filename(in: file.path)) \(file.folderPath) \(file.path)".lowercased()
            )
        }
    }

    public func matchingFiles(
        query: String,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> [CatalogFileBucket]? {
        let terms = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return entries.map(\.file) }

        var matches: [CatalogFileBucket] = []
        matches.reserveCapacity(min(entries.count, 256))
        for (index, entry) in entries.enumerated() {
            if index.isMultiple(of: 256), isCancelled() { return nil }
            if terms.allSatisfy(entry.searchableText.contains) {
                matches.append(entry.file)
            }
        }
        return isCancelled() ? nil : matches
    }

    private static func filename(in path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

public struct CatalogFileTreeFolder: Equatable, Sendable {
    public let rootID: Int64
    public let rootPath: String
    public let folderPath: String

    public init(rootID: Int64, rootPath: String, folderPath: String) {
        self.rootID = rootID
        self.rootPath = rootPath
        self.folderPath = folderPath
    }
}

/// A complete database-only Files tree. This is a transportable projection of
/// the shared graph, not a DOM or native view node. Frontends may map its
/// `children` and source payloads into their local rendering shape.
public struct CatalogFileTreeNode: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case folder
        case file
    }

    public let kind: Kind
    public let id: String
    public let title: String
    public let folder: CatalogFileTreeFolder?
    public let file: CatalogFileBucket?
    public let children: [CatalogFileTreeNode]

    public init(
        kind: Kind,
        id: String,
        title: String,
        folder: CatalogFileTreeFolder? = nil,
        file: CatalogFileBucket? = nil,
        children: [CatalogFileTreeNode] = []
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.folder = folder
        self.file = file
        self.children = children
    }
}

/// A database-only Files-sidebar graph. It contains no rendering, selection,
/// persistence, filesystem enumeration, archive inspection, or playback
/// behavior. Frontends flatten the graph using their own disclosure state.
public struct CatalogFileTreeIndex: Sendable {
    public enum Row: Equatable, Sendable {
        case folder(id: String, title: String, depth: Int, isExpanded: Bool)
        case file(CatalogFileBucket, depth: Int)
    }

    private struct Folder: Sendable {
        let rootID: Int64
        let path: String
        let title: String
        let childFolderIDs: [String]
        let directFiles: [CatalogFileBucket]
    }

    private struct FolderBuilder {
        let rootID: Int64
        let path: String
        let title: String
        var childFolderIDs: Set<String> = []
        var directFiles: [CatalogFileBucket] = []
    }

    private let rootFolderIDs: [String]
    private let folders: [String: Folder]

    public var allFolderIDs: Set<String> { Set(folders.keys) }

    public init(files: [CatalogFileBucket]) {
        self.init(files: files, isCancelled: { false })!
    }

    public init?(
        files: [CatalogFileBucket],
        isCancelled: @Sendable () -> Bool
    ) {
        var builders: [String: FolderBuilder] = [:]
        var rootIDs: Set<String> = []

        func title(for path: String) -> String {
            let title = URL(fileURLWithPath: path, isDirectory: true).lastPathComponent
            return title.isEmpty ? path : title
        }

        func ensureFolder(rootID: Int64, path: String) {
            let id = Self.folderID(rootID: rootID, path: path)
            guard builders[id] == nil else { return }
            builders[id] = FolderBuilder(rootID: rootID, path: path, title: title(for: path))
        }

        for (index, file) in files.enumerated() {
            if index.isMultiple(of: 256), isCancelled() { return nil }
            let rootID = file.rootID
            ensureFolder(rootID: rootID, path: file.rootPath)
            rootIDs.insert(Self.folderID(rootID: rootID, path: file.rootPath))

            var folderPath = file.folderPath
            ensureFolder(rootID: rootID, path: folderPath)
            while folderPath != file.rootPath,
                  folderPath.hasPrefix(file.rootPath + "/") {
                let parentPath = URL(fileURLWithPath: folderPath, isDirectory: true)
                    .deletingLastPathComponent()
                    .path
                ensureFolder(rootID: rootID, path: parentPath)
                let parentID = Self.folderID(rootID: rootID, path: parentPath)
                let childID = Self.folderID(rootID: rootID, path: folderPath)
                builders[parentID]?.childFolderIDs.insert(childID)
                folderPath = parentPath
            }

            let folderID = Self.folderID(rootID: rootID, path: file.folderPath)
            builders[folderID]?.directFiles.append(file)
        }

        var folders: [String: Folder] = [:]
        folders.reserveCapacity(builders.count)
        for (index, entry) in builders.enumerated() {
            if index.isMultiple(of: 64), isCancelled() { return nil }
            let (id, builder) = entry
            let sortedFiles = builder.directFiles.sorted(by: Self.fileComesBefore)
            folders[id] = Folder(
                rootID: builder.rootID,
                path: builder.path,
                title: builder.title,
                childFolderIDs: builder.childFolderIDs.sorted { lhs, rhs in
                    let lhsTitle = builders[lhs]?.title ?? lhs
                    let rhsTitle = builders[rhs]?.title ?? rhs
                    return Self.localizedAscending(lhsTitle, rhsTitle, tieBreak: lhs, rhs)
                },
                directFiles: sortedFiles
            )
        }
        guard !isCancelled() else { return nil }
        self.folders = folders
        self.rootFolderIDs = rootIDs.sorted { lhs, rhs in
            let lhsPath = builders[lhs]?.path ?? lhs
            let rhsPath = builders[rhs]?.path ?? rhs
            return Self.localizedAscending(lhsPath, rhsPath, tieBreak: lhs, rhs)
        }
    }

    public func rows(expandedFolderIDs: Set<String>) -> [Row] {
        var rows: [Row] = []

        func appendFolder(_ id: String, depth: Int) {
            guard let folder = folders[id] else { return }
            let isExpanded = expandedFolderIDs.contains(id)
            rows.append(.folder(id: id, title: folder.title, depth: depth, isExpanded: isExpanded))
            guard isExpanded else { return }

            for childID in folder.childFolderIDs {
                appendFolder(childID, depth: depth + 1)
            }
            for file in folder.directFiles {
                rows.append(.file(file, depth: depth + 1))
            }
        }

        for rootID in rootFolderIDs {
            appendFolder(rootID, depth: 0)
        }
        return rows
    }

    public func nodes() -> [CatalogFileTreeNode] {
        func makeFolderNode(_ id: String) -> CatalogFileTreeNode? {
            guard let folder = folders[id] else { return nil }
            let children = folder.childFolderIDs.compactMap(makeFolderNode)
                + folder.directFiles.map { file in
                    CatalogFileTreeNode(
                        kind: .file,
                        id: file.id,
                        title: Self.filename(in: file.path),
                        file: file
                    )
                }
            return CatalogFileTreeNode(
                kind: .folder,
                id: id,
                title: folder.title,
                folder: CatalogFileTreeFolder(
                    rootID: folder.rootID,
                    rootPath: rootPath(for: folder.rootID, fallback: folder.path),
                    folderPath: folder.path
                ),
                children: children
            )
        }

        return rootFolderIDs.compactMap(makeFolderNode)
    }

    public static func rootFolderIDs(for files: [CatalogFileBucket]) -> [String] {
        Array(Set(files.map { folderID(rootID: $0.rootID, path: $0.rootPath) }))
    }

    public static func folderID(rootID: Int64, path: String) -> String {
        "\(rootID)|\(path)"
    }

    private static func fileComesBefore(_ lhs: CatalogFileBucket, _ rhs: CatalogFileBucket) -> Bool {
        localizedAscending(filename(in: lhs.path), filename(in: rhs.path), tieBreak: lhs.path, rhs.path)
    }

    private static func filename(in path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private func rootPath(for rootID: Int64, fallback: String) -> String {
        guard let rootFolderID = rootFolderIDs.first(where: { $0.split(separator: "|", maxSplits: 1).first.map(String.init) == String(rootID) }),
              let rootFolder = folders[rootFolderID] else {
            return fallback
        }
        return rootFolder.path
    }

    private static func localizedAscending(
        _ lhs: String,
        _ rhs: String,
        tieBreak lhsTieBreak: String,
        _ rhsTieBreak: String
    ) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        return lhsTieBreak < rhsTieBreak
    }
}

/// UI-neutral state for Console → Game presentation. Frontends retain their
/// own rows, focus, scrolling, and persistence adapters, but the selection and
/// disclosure transitions are shared so a group click cannot accidentally
/// activate a game in only one skin.
public struct CatalogBrowserGroupState: Codable, Equatable, Sendable {
    public private(set) var expandedGroupNames: Set<String>
    public private(set) var selectedGroupName: String?
    public private(set) var selectedGameID: String?

    public init(
        expandedGroupNames: Set<String> = [],
        selectedGroupName: String? = nil,
        selectedGameID: String? = nil
    ) {
        self.expandedGroupNames = expandedGroupNames
        self.selectedGroupName = selectedGroupName
        self.selectedGameID = selectedGameID
    }

    public func applying(_ action: Action) -> Self {
        var next = self
        switch action {
        case .toggleGroup(let name):
            next.selectedGroupName = name
            next.selectedGameID = nil
            if next.expandedGroupNames.contains(name) {
                next.expandedGroupNames.remove(name)
            } else {
                next.expandedGroupNames.insert(name)
            }
        case .selectGroup(let name):
            next.selectedGroupName = name
            next.selectedGameID = nil
        case .selectGame(let groupName, let gameID):
            next.selectedGroupName = groupName
            next.selectedGameID = gameID
        case .setAllCollapsed(let collapsed, let knownGroupNames):
            if collapsed {
                next.expandedGroupNames.subtract(knownGroupNames)
            } else {
                next.expandedGroupNames.formUnion(knownGroupNames)
            }
        case .replaceExpandedGroups(let names):
            next.expandedGroupNames = names
        }
        return next
    }

    public enum Action: Equatable, Sendable {
        case toggleGroup(String)
        case selectGroup(String)
        case selectGame(groupName: String, gameID: String)
        case setAllCollapsed(Bool, knownGroupNames: Set<String>)
        case replaceExpandedGroups(Set<String>)
    }
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
        var index = CatalogSearchIndex(searchValues: games.map {
            "\($0.name) \($0.system) \($0.rootDisplayName) \($0.displayName)"
        })
        return index.matchingIndices(query: query).compactMap { position in
            games.indices.contains(position) ? games[position] : nil
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
