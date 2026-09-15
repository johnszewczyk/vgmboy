import CatalogPlaylistCore
import CatalogReader
import Foundation

/// Display text derived entirely from a published catalog row. It is a data
/// contract: frontends measure these strings with their own fonts and draw
/// them with their own toolkits.
public struct CatalogPlaylistDisplayFields: Equatable, Sendable {
    /// The playable leaf name before the subtrack suffix. It is suitable for
    /// filename-based format routing, unlike `fileText`.
    public let sourceFilename: String
    public let fileText: String
    public let displayName: String
    public let titleText: String
    public let gameText: String
    public let authorText: String
    public let systemText: String
    public let lengthText: String
}

/// One catalog-backed playlist row, retaining both source facts and the
/// shared display projection. This contains no selection, layout, font, or
/// playback state.
public struct CatalogPlaylistPresentationRow: Equatable, Sendable {
    public let metadataTrackID: Int64?
    public let rootID: Int64?
    public let sourcePath: String
    public let archivePath: String?
    public let archiveEntry: String?
    public let trackIndex: Int
    public let trackCount: Int
    public let title: String
    public let game: String
    public let author: String
    public let system: String
    public let comment: String
    public let introLengthMilliseconds: Int
    public let loopLengthMilliseconds: Int
    public let lengthMilliseconds: Int
    public let fadeLengthMilliseconds: Int
    public let display: CatalogPlaylistDisplayFields
}

/// Longest visible content for each data column. It deliberately supplies
/// strings, not pixels, so AppKit and WebKit remain responsible for local font
/// metrics and resize animation.
public struct CatalogPlaylistColumnContentHints: Equatable, Sendable {
    public let indexText: String
    public let fileText: String
    public let titleText: String
    public let gameText: String
    public let authorText: String
    public let systemText: String
    public let lengthText: String
}

/// The UI-neutral catalog playlist projection shared by native and WebKit
/// frontends. Input order is retained exactly; presentation never sorts rows.
public struct CatalogPlaylistPresentationProjection: Equatable, Sendable {
    public let rows: [CatalogPlaylistPresentationRow]
    public let columnContentHints: CatalogPlaylistColumnContentHints
}

/// The UI-neutral fields required for an explicitly sorted playlist. The
/// frontend supplies its stable row identity and natural playlist position;
/// this module owns the comparison policy, not selection or layout.
public struct CatalogPlaylistSortRecord: Codable, Equatable, Sendable {
    public let id: String
    public let naturalOrder: Int
    public let fileText: String
    public let titleText: String
    public let gameText: String
    public let authorText: String
    public let systemText: String
    public let pathText: String
    public let lengthMilliseconds: Int

    public init(
        id: String,
        naturalOrder: Int,
        fileText: String,
        titleText: String,
        gameText: String,
        authorText: String,
        systemText: String,
        pathText: String,
        lengthMilliseconds: Int
    ) {
        self.id = id
        self.naturalOrder = naturalOrder
        self.fileText = fileText
        self.titleText = titleText
        self.gameText = gameText
        self.authorText = authorText
        self.systemText = systemText
        self.pathText = pathText
        self.lengthMilliseconds = lengthMilliseconds
    }
}

public enum CatalogPlaylistSortColumn: String, CaseIterable, Codable, Sendable {
    case index
    case file
    case title
    case game
    case author
    case system
    case path
    case length

    /// Frontends retain their user-facing column identifiers, while the shared
    /// contract carries one canonical set. These aliases are intentionally at
    /// the boundary rather than duplicated in every renderer.
    public init?(frontendColumn: String) {
        switch frontendColumn {
        case "index": self = .index
        case "file", "filename": self = .file
        case "title": self = .title
        case "game": self = .game
        case "author", "artist": self = .author
        case "system": self = .system
        case "path": self = .path
        case "length", "lengthLabel": self = .length
        default: return nil
        }
    }
}

public enum CatalogPlaylistSortDirection: String, Codable, Sendable {
    case ascending
    case descending
}

/// A typed request for sorting a non-catalog playlist projection. Catalog
/// projections retain their data natively and use a session ID instead; this
/// DTO is for bounded local/mixed/favorites rows whose current visible values
/// exist only in a frontend projection.
public struct CatalogPlaylistSortRequest: Codable, Equatable, Sendable {
    public let records: [CatalogPlaylistSortRecord]
    public let frontendColumn: String
    public let direction: CatalogPlaylistSortDirection

    public init(
        records: [CatalogPlaylistSortRecord],
        frontendColumn: String,
        direction: CatalogPlaylistSortDirection
    ) {
        self.records = records
        self.frontendColumn = frontendColumn
        self.direction = direction
    }

    public var column: CatalogPlaylistSortColumn? {
        CatalogPlaylistSortColumn(frontendColumn: frontendColumn)
    }
}

/// Shared explicit-playlist sort policy. Natural catalog order remains the
/// deterministic tie breaker, so a re-sort never leaks an old visual order
/// into a newly selected sidebar item.
public enum CatalogPlaylistSorting {
    public static func orderedIDs(
        records: [CatalogPlaylistSortRecord],
        column: CatalogPlaylistSortColumn,
        direction: CatalogPlaylistSortDirection
    ) -> [String] {
        records.sorted { lhs, rhs in
            let comparison = compare(lhs, rhs, by: column)
            if comparison == .orderedSame {
                return lhs.naturalOrder < rhs.naturalOrder
            }
            return direction == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }.map(\.id)
    }

    public static func compare(
        _ lhs: CatalogPlaylistSortRecord,
        _ rhs: CatalogPlaylistSortRecord,
        by column: CatalogPlaylistSortColumn
    ) -> ComparisonResult {
        switch column {
        case .index:
            return compare(lhs.naturalOrder, rhs.naturalOrder)
        case .file:
            return lhs.fileText.localizedStandardCompare(rhs.fileText)
        case .title:
            return lhs.titleText.localizedStandardCompare(rhs.titleText)
        case .game:
            return lhs.gameText.localizedStandardCompare(rhs.gameText)
        case .author:
            return lhs.authorText.localizedStandardCompare(rhs.authorText)
        case .system:
            return lhs.systemText.localizedStandardCompare(rhs.systemText)
        case .path:
            return lhs.pathText.localizedStandardCompare(rhs.pathText)
        case .length:
            return compare(lhs.lengthMilliseconds, rhs.lengthMilliseconds)
        }
    }

    private static func compare(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }
}

public enum CatalogPlaylistPresentation {
    public static func project(
        tracks: [CatalogPlaylistTrack]
    ) -> CatalogPlaylistPresentationProjection {
        project(tracks.map {
            Input(
                metadataTrackID: nil,
                rootID: nil,
                sourcePath: $0.sourcePath,
                archivePath: $0.archivePath,
                archiveEntry: $0.archiveEntry,
                trackIndex: $0.trackIndex,
                trackCount: $0.trackCount,
                title: $0.title,
                game: $0.game,
                author: $0.author,
                system: $0.system,
                comment: $0.comment,
                introLengthMilliseconds: $0.introLengthMilliseconds,
                loopLengthMilliseconds: $0.loopLengthMilliseconds,
                lengthMilliseconds: $0.lengthMilliseconds,
                fadeLengthMilliseconds: $0.fadeLengthMilliseconds
            )
        })
    }

    public static func project(
        tracks: [CatalogTrack]
    ) -> CatalogPlaylistPresentationProjection {
        project(tracks.map {
            Input(
                metadataTrackID: $0.id,
                rootID: $0.rootID,
                sourcePath: $0.sourcePath,
                archivePath: $0.archivePath,
                archiveEntry: $0.archiveEntry,
                trackIndex: $0.trackIndex,
                trackCount: $0.trackCount,
                title: $0.title,
                game: $0.game,
                author: $0.author,
                system: $0.system,
                comment: $0.comment,
                introLengthMilliseconds: $0.introLengthMilliseconds,
                loopLengthMilliseconds: $0.loopLengthMilliseconds,
                lengthMilliseconds: $0.lengthMilliseconds,
                fadeLengthMilliseconds: $0.fadeLengthMilliseconds
            )
        })
    }

    private struct Input {
        let metadataTrackID: Int64?
        let rootID: Int64?
        let sourcePath: String
        let archivePath: String?
        let archiveEntry: String?
        let trackIndex: Int
        let trackCount: Int
        let title: String
        let game: String
        let author: String
        let system: String
        let comment: String
        let introLengthMilliseconds: Int
        let loopLengthMilliseconds: Int
        let lengthMilliseconds: Int
        let fadeLengthMilliseconds: Int
    }

    private static func project(_ inputs: [Input]) -> CatalogPlaylistPresentationProjection {
        let rows = inputs.map(row(from:))
        return CatalogPlaylistPresentationProjection(
            rows: rows,
            columnContentHints: columnContentHints(for: rows)
        )
    }

    private static func row(from input: Input) -> CatalogPlaylistPresentationRow {
        let archivePath = nonEmpty(input.archivePath)
        let archiveEntry = nonEmpty(input.archiveEntry)
        let playablePath = archiveEntry ?? input.sourcePath
        let playableURL = URL(fileURLWithPath: playablePath)
        let sourceFilename = playableURL.lastPathComponent.isEmpty
            ? input.sourcePath
            : playableURL.lastPathComponent
        let count = max(1, input.trackCount)
        let index = max(0, input.trackIndex)
        let suffix = count > 1 ? " [\(index + 1)]" : ""
        let displayName = displayedBaseName(sourceFilename) + suffix
        let groupName: String
        if archiveEntry != nil {
            let container = URL(fileURLWithPath: archivePath ?? input.sourcePath).lastPathComponent
            groupName = container.isEmpty ? sourceFilename : container
        } else {
            let parent = URL(fileURLWithPath: input.sourcePath).deletingLastPathComponent().lastPathComponent
            groupName = parent.isEmpty ? sourceFilename : parent
        }
        let display = CatalogPlaylistDisplayFields(
            sourceFilename: sourceFilename,
            fileText: sourceFilename + suffix,
            displayName: displayName,
            titleText: nonEmpty(input.title) ?? displayName,
            gameText: nonEmpty(input.game) ?? groupName,
            authorText: nonEmpty(input.author) ?? "—",
            systemText: nonEmpty(input.system) ?? "—",
            lengthText: formattedDuration(milliseconds: input.lengthMilliseconds)
        )
        return CatalogPlaylistPresentationRow(
            metadataTrackID: input.metadataTrackID,
            rootID: input.rootID,
            sourcePath: input.sourcePath,
            archivePath: archivePath,
            archiveEntry: archiveEntry,
            trackIndex: index,
            trackCount: count,
            title: input.title,
            game: input.game,
            author: input.author,
            system: input.system,
            comment: input.comment,
            introLengthMilliseconds: input.introLengthMilliseconds,
            loopLengthMilliseconds: input.loopLengthMilliseconds,
            lengthMilliseconds: input.lengthMilliseconds,
            fadeLengthMilliseconds: input.fadeLengthMilliseconds,
            display: display
        )
    }

    private static func columnContentHints(
        for rows: [CatalogPlaylistPresentationRow]
    ) -> CatalogPlaylistColumnContentHints {
        CatalogPlaylistColumnContentHints(
            indexText: String(max(1, rows.count)),
            fileText: longest(rows.map(\.display.fileText)),
            titleText: longest(rows.map(\.display.titleText)),
            gameText: longest(rows.map(\.display.gameText)),
            authorText: longest(rows.map(\.display.authorText)),
            systemText: longest(rows.map(\.display.systemText)),
            lengthText: longest(rows.map(\.display.lengthText), default: "—")
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func longest(_ strings: [String], default fallback: String = "") -> String {
        strings.reduce(fallback) { longest, candidate in
            candidate.count > longest.count ? candidate : longest
        }
    }

    private static func displayedBaseName(_ filename: String) -> String {
        let lowercaseFilename = filename.lowercased()
        let compoundArchiveSuffixes = [
            ".tar.zst", ".tar.zstd", ".tar.gz", ".tar.bz2", ".tar.xz", ".tar.lz", ".tar.lz4"
        ]
        if let suffix = compoundArchiveSuffixes.first(where: { lowercaseFilename.hasSuffix($0) }) {
            return String(filename.dropLast(suffix.count))
        }
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        return stem.isEmpty ? filename : stem
    }

    private static func formattedDuration(milliseconds: Int) -> String {
        let seconds = max(0, milliseconds > 0 ? milliseconds / 1_000 : 0)
        guard seconds > 0 else { return "—" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
