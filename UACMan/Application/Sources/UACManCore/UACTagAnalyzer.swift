import Foundation
import UACWrapperCore

public enum UACTagAnalysisPhase: String, Equatable, Sendable {
    case discovering
    case reading
}

public struct UACTagAnalysisProgress: Equatable, Sendable {
    public let phase: UACTagAnalysisPhase
    public let directoriesVisited: Int
    public let packagesFound: Int
    public let packagesProcessed: Int
    public let totalPackages: Int
    public let currentRelativePath: String
    public let uniqueTagCount: Int

    public init(
        phase: UACTagAnalysisPhase,
        directoriesVisited: Int,
        packagesFound: Int,
        packagesProcessed: Int,
        totalPackages: Int,
        currentRelativePath: String,
        uniqueTagCount: Int
    ) {
        self.phase = phase
        self.directoriesVisited = directoriesVisited
        self.packagesFound = packagesFound
        self.packagesProcessed = packagesProcessed
        self.totalPackages = totalPackages
        self.currentRelativePath = currentRelativePath
        self.uniqueTagCount = uniqueTagCount
    }
}

public struct UACTagNameUsage: Identifiable, Equatable, Sendable {
    public let name: String
    public let matchedPackCount: Int
    public let trackCount: Int
    public let matches: [UACTagFieldMatch]

    public init(name: String, matchedPackCount: Int, trackCount: Int, matches: [UACTagFieldMatch]) {
        self.name = name
        self.matchedPackCount = matchedPackCount
        self.trackCount = trackCount
        self.matches = matches
    }

    public var id: String { name }
}

public struct UACTagFieldMatch: Equatable, Sendable {
    public let archiveRelativePath: String
    public let archiveURL: URL
    public let archiveAlbum: String
    public let archiveTitle: String
    public let archiveConsole: String
    public let archiveTrackCount: Int
    public let memberRelativePath: String?
    public let scope: String
    public let storageScope: String
    public let storageKey: String
    public let isTrack: Bool
    public let value: String
    public let valueJSON: String
    public let valueIsJSON: Bool

    public init(
        archiveRelativePath: String,
        archiveURL: URL,
        archiveAlbum: String = "",
        archiveTitle: String = "",
        archiveConsole: String = "",
        archiveTrackCount: Int = 0,
        memberRelativePath: String?,
        scope: String,
        storageScope: String,
        storageKey: String,
        isTrack: Bool,
        value: String,
        valueJSON: String,
        valueIsJSON: Bool
    ) {
        self.archiveRelativePath = archiveRelativePath
        self.archiveURL = archiveURL
        self.archiveAlbum = archiveAlbum
        self.archiveTitle = archiveTitle
        self.archiveConsole = archiveConsole
        self.archiveTrackCount = archiveTrackCount
        self.memberRelativePath = memberRelativePath
        self.scope = scope
        self.storageScope = storageScope
        self.storageKey = storageKey
        self.isTrack = isTrack
        self.value = value
        self.valueJSON = valueJSON
        self.valueIsJSON = valueIsJSON
    }
}

public struct UACTagAnalysisResult: Equatable, Sendable {
    public let packageCount: Int
    public let packagesRead: Int
    public let tags: [UACTagNameUsage]
    public let issues: [UACCollectionIssue]
}

/// Inventories field names and their manifest occurrences. It reads package
/// manifests only; it never materializes or modifies compressed members.
public enum UACTagAnalyzer {
    public static func analyze(
        root: URL,
        manifestReader: UACCollectionManifestReader,
        progress: (@Sendable (UACTagAnalysisProgress) -> Void)? = nil
    ) throws -> UACTagAnalysisResult {
        let discovery = try UACCollectionScanner.discover(root: root) { update in
            progress?(UACTagAnalysisProgress(
                phase: .discovering,
                directoriesVisited: update.directoriesVisited,
                packagesFound: update.packagesFound,
                packagesProcessed: 0,
                totalPackages: 0,
                currentRelativePath: update.currentRelativePath,
                uniqueTagCount: 0
            ))
        }

        var tagCounts: [String: MutableTagNameUsage] = [:]
        var issues = discovery.issues
        var packagesRead = 0
        let totalPackages = discovery.packages.count
        progress?(UACTagAnalysisProgress(
            phase: .reading,
            directoriesVisited: discovery.directoriesVisited,
            packagesFound: totalPackages,
            packagesProcessed: 0,
            totalPackages: totalPackages,
            currentRelativePath: "",
            uniqueTagCount: 0
        ))

        for (offset, package) in discovery.packages.enumerated() {
            if Task<Never, Never>.isCancelled { throw CancellationError() }
            do {
                let manifest = try manifestReader(package.url)
                packagesRead += 1
                let archiveAlbum = Self.archiveAlbum(in: manifest)
                let archiveTrackCount = manifest.members.filter {
                    $0.role == "playable" || $0.role == "track"
                }.count
                var packageTagNames = Set(manifest.game.metadata.keys)
                for (name, value) in manifest.game.metadata {
                    addMatch(name, value: value, package: package, member: nil, scope: "Package Tags", storageScope: "packageMetadata", storageKey: name, isTrack: false, archiveAlbum: archiveAlbum, archiveTrackCount: archiveTrackCount, archiveTitle: manifest.game.title, archiveConsole: manifest.game.console, to: &tagCounts)
                }
                for (name, value) in manifest.game.extensions {
                    let fieldName = "extension.\(name)"
                    packageTagNames.insert(fieldName)
                    addMatch(fieldName, value: value, package: package, member: nil, scope: "Package Extensions", storageScope: "packageExtensions", storageKey: name, isTrack: false, archiveAlbum: archiveAlbum, archiveTrackCount: archiveTrackCount, archiveTitle: manifest.game.title, archiveConsole: manifest.game.console, to: &tagCounts)
                }
                for member in manifest.members {
                    var memberTagNames = Set(member.metadata.keys)
                    for (name, value) in member.metadata {
                        let isTrack = member.role == "playable" || member.role == "track"
                        addMatch(name, value: value, package: package, member: member.path, scope: "\(member.role) Tags", storageScope: "memberMetadata", storageKey: name, isTrack: isTrack, archiveAlbum: archiveAlbum, archiveTrackCount: archiveTrackCount, archiveTitle: manifest.game.title, archiveConsole: manifest.game.console, to: &tagCounts)
                    }
                    for (name, value) in member.extensions {
                        let fieldName = "extension.\(name)"
                        memberTagNames.insert(fieldName)
                        let isTrack = member.role == "playable" || member.role == "track"
                        addMatch(fieldName, value: value, package: package, member: member.path, scope: "\(member.role) Extensions", storageScope: "memberExtensions", storageKey: name, isTrack: isTrack, archiveAlbum: archiveAlbum, archiveTrackCount: archiveTrackCount, archiveTitle: manifest.game.title, archiveConsole: manifest.game.console, to: &tagCounts)
                    }
                    packageTagNames.formUnion(memberTagNames)
                }
                for name in packageTagNames {
                    tagCounts[name, default: MutableTagNameUsage()].matchedPackCount += 1
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                issues.append(UACCollectionIssue(
                    relativePath: package.relativePath,
                    message: error.localizedDescription
                ))
            }

            progress?(UACTagAnalysisProgress(
                phase: .reading,
                directoriesVisited: discovery.directoriesVisited,
                packagesFound: totalPackages,
                packagesProcessed: offset + 1,
                totalPackages: totalPackages,
                currentRelativePath: package.relativePath,
                uniqueTagCount: tagCounts.count
            ))
        }
        if Task<Never, Never>.isCancelled { throw CancellationError() }

        let tags = tagCounts.map { name, usage in
            UACTagNameUsage(
                name: name,
                matchedPackCount: usage.matchedPackCount,
                trackCount: usage.trackCount,
                matches: usage.matches.sorted { lhs, rhs in
                    let archiveOrder = lhs.archiveRelativePath.localizedStandardCompare(rhs.archiveRelativePath)
                    if archiveOrder != .orderedSame { return archiveOrder == .orderedAscending }
                    let lhsSource = lhs.memberRelativePath ?? ""
                    let rhsSource = rhs.memberRelativePath ?? ""
                    let sourceOrder = lhsSource.localizedStandardCompare(rhsSource)
                    if sourceOrder != .orderedSame { return sourceOrder == .orderedAscending }
                    return lhs.scope.localizedStandardCompare(rhs.scope) == .orderedAscending
                }
            )
        }.sorted { lhs, rhs in
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? lhs.name < rhs.name : order == .orderedAscending
        }
        issues.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return UACTagAnalysisResult(
            packageCount: totalPackages,
            packagesRead: packagesRead,
            tags: tags,
            issues: issues
        )
    }

    private struct MutableTagNameUsage {
        var matchedPackCount = 0
        var trackCount = 0
        var matches: [UACTagFieldMatch] = []
    }

    private static func addMatch(
        _ name: String,
        value: UACJSONValue,
        package: UACCollectionPackageFile,
        member: String?,
        scope: String,
        storageScope: String,
        storageKey: String,
        isTrack: Bool,
        archiveAlbum: String,
        archiveTrackCount: Int,
        archiveTitle: String,
        archiveConsole: String,
        to counts: inout [String: MutableTagNameUsage]
    ) {
        var usage = counts[name, default: MutableTagNameUsage()]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let valueJSON = (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "null"
        usage.matches.append(UACTagFieldMatch(
            archiveRelativePath: package.relativePath,
            archiveURL: package.url,
            archiveAlbum: archiveAlbum,
            archiveTitle: archiveTitle,
            archiveConsole: archiveConsole,
            archiveTrackCount: archiveTrackCount,
            memberRelativePath: member,
            scope: scope,
            storageScope: storageScope,
            storageKey: storageKey,
            isTrack: isTrack,
            value: displayValue(value),
            valueJSON: valueJSON,
            valueIsJSON: requiresJSONEditor(value)
        ))
        if isTrack { usage.trackCount += 1 }
        counts[name] = usage
    }

    private static func displayValue(_ value: UACJSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let value): return value ? "true" : "false"
        case .integer(let value): return String(value)
        case .number(let value): return String(value)
        case .string(let value): return value
        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(value), let string = String(data: data, encoding: .utf8) else {
                return ""
            }
            return string
        }
    }

    private static func archiveAlbum(in manifest: UACManifest) -> String {
        func album(_ metadata: [String: UACJSONValue]) -> String? {
            guard let value = metadata.first(where: { $0.key.caseInsensitiveCompare("album") == .orderedSame })?.value,
                  case .string(let album) = value else { return nil }
            let trimmed = album.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let packageAlbum = album(manifest.game.metadata) { return packageAlbum }
        let albumCounts = manifest.members
            .filter { $0.role == "playable" || $0.role == "track" }
            .compactMap { album($0.metadata) }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return albumCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
        }.first?.key ?? ""
    }

    private static func requiresJSONEditor(_ value: UACJSONValue) -> Bool {
        return switch value {
        case .string: false
        case .null, .bool, .integer, .number, .array, .object: true
        }
    }
}
