import CatalogBrowserCore
import CatalogReader
import Foundation

/// One console represented in the artwork index. The game IDs use the same
/// stable root/game/system identity as the catalog Games projection.
public struct CatalogGalleryConsoleGroup: Identifiable, Codable, Equatable, Sendable {
    public let name: String
    public let gameIDs: [String]

    public var id: String { name }

    public init(name: String, gameIDs: [String]) {
        self.name = name
        self.gameIDs = gameIDs
    }
}

/// Shared, UI-neutral projection for the Title Snap Gallery. It defines the
/// console fallback, deterministic group order, search membership, and
/// selected-console filtering used by native and WebKit frontends.
public struct CatalogGalleryIndex: Sendable {
    private let games: [CatalogGalleryGame]
    private let catalogGameIDs: [String]
    private var searchIndex: CatalogSearchIndex

    public let consoleGroups: [CatalogGalleryConsoleGroup]

    public init(games: [CatalogGalleryGame]) {
        self.games = games

        let projectedGames = games.map { game in
            CatalogBrowserGame(
                bucket: CatalogGameBucket(
                    rootID: game.rootID,
                    rootPath: game.rootPath,
                    game: game.game,
                    system: game.system,
                    trackCount: 1
                ),
                displayName: game.game
            )
        }
        catalogGameIDs = projectedGames.map(\.id)
        consoleGroups = CatalogBrowserProjection.groups(from: projectedGames).map { group in
            CatalogGalleryConsoleGroup(
                name: group.name,
                gameIDs: group.games.map(\.id)
            )
        }

        searchIndex = CatalogSearchIndex(searchValues: games.map { game in
            let rootName = URL(fileURLWithPath: game.rootPath, isDirectory: true).lastPathComponent
            return CatalogBrowserSearchText.game(
                name: game.game,
                system: game.system,
                rootDisplayName: rootName,
                displayName: game.game
            )
        })
    }

    public static func consoleName(for game: CatalogGalleryGame) -> String {
        let name = game.system.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unknown Console" : name
    }

    /// Stable identity shared with `CatalogBrowserGame`, including its
    /// whitespace normalization. This keeps gallery records joinable to
    /// catalog sidebar rows without using display labels.
    public static func catalogGameID(for game: CatalogGalleryGame) -> String {
        CatalogBrowserGame(
            bucket: CatalogGameBucket(
                rootID: game.rootID,
                rootPath: game.rootPath,
                game: game.game,
                system: game.system,
                trackCount: 1
            ),
            displayName: game.game
        ).id
    }

    /// Returns only console groups with artwork titles matching the shared
    /// catalog search semantics (all normalized query terms must match).
    public mutating func consoleGroups(matching query: String) -> [CatalogGalleryConsoleGroup] {
        let matchingIndices = searchIndex.matchingIndices(query: query)
        let matchingIDs = Set(matchingIndices.compactMap { index in
            catalogGameIDs.indices.contains(index) ? catalogGameIDs[index] : nil
        })
        return consoleGroups.filter { group in
            group.gameIDs.contains(where: matchingIDs.contains)
        }
    }

    /// Returns every artwork title for a selected console. A nil selection
    /// means the full Gallery; an unknown console has no results.
    public func games(inConsole consoleName: String?) -> [CatalogGalleryGame] {
        guard let consoleName else { return games }
        guard let group = consoleGroups.first(where: { $0.name == consoleName }) else { return [] }
        let gameIDs = Set(group.gameIDs)
        return zip(games, catalogGameIDs).compactMap { game, id in
            gameIDs.contains(id) ? game : nil
        }
    }
}
