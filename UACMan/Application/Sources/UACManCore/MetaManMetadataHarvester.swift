import Foundation
import MetaManCore
import UACWrapperCore

public struct MetaManMetadataHarvestOutcome: Sendable {
    public let memberMetadata: [String: [String: UACJSONValue]]
    public let trackMetadata: [String: [MetaManMetadataTrackProjection]]
    public let gameMetadata: [String: UACJSONValue]
    public let sharedFieldConflicts: [String]
    public let failures: [String]
    public let diagnosticCount: Int

    public init(
        memberMetadata: [String: [String: UACJSONValue]],
        trackMetadata: [String: [MetaManMetadataTrackProjection]] = [:],
        gameMetadata: [String: UACJSONValue] = [:],
        sharedFieldConflicts: [String] = [],
        failures: [String],
        diagnosticCount: Int
    ) {
        self.memberMetadata = memberMetadata
        self.trackMetadata = trackMetadata
        self.gameMetadata = gameMetadata
        self.sharedFieldConflicts = sharedFieldConflicts
        self.failures = failures
        self.diagnosticCount = diagnosticCount
    }
}

public struct MetaManMetadataTrackProjection: Encodable, Sendable {
    /// The native decoder/subsong index. UAC stores this as a decimal string
    /// in playlist entries because the manifest keeps playlist fields open.
    public let sourceTrackIndex: Int?
    /// Zero-based row position in the source M3U queue, when one applies.
    public let sourcePlaylistOrder: Int?
    public let metadata: [String: UACJSONValue]
    public let sourcePlaylistPath: String?
    public let rawLine: String?
    public let lengthRaw: String?
    public let loopRaw: String?
    public let loopStartRaw: String?
    public let fadeRaw: String?
    public let repeatRaw: String?

    public init(
        sourceTrackIndex: Int?,
        sourcePlaylistOrder: Int? = nil,
        metadata: [String: UACJSONValue],
        sourcePlaylistPath: String? = nil,
        rawLine: String? = nil,
        lengthRaw: String? = nil,
        loopRaw: String? = nil,
        loopStartRaw: String? = nil,
        fadeRaw: String? = nil,
        repeatRaw: String? = nil
    ) {
        self.sourceTrackIndex = sourceTrackIndex
        self.sourcePlaylistOrder = sourcePlaylistOrder
        self.metadata = metadata
        self.sourcePlaylistPath = sourcePlaylistPath
        self.rawLine = rawLine
        self.lengthRaw = lengthRaw
        self.loopRaw = loopRaw
        self.loopStartRaw = loopStartRaw
        self.fadeRaw = fadeRaw
        self.repeatRaw = repeatRaw
    }
}

public enum MetaManMetadataHarvester {
    private static let maximumMemberSize: UInt64 = 64 * 1024 * 1024
    private static let maximumCompanionPlaylistSize: UInt64 = 4 * 1024 * 1024
    private static let maximumCompanionPlaylistCount = 4_096
    private static let maximumCompanionPlaylistSetSize: UInt64 = 32 * 1024 * 1024
    // Audio tracks can exceed the general cap. These readers use file APIs or
    // memory mapping instead of copying the encoded audio into a working buffer.
    private static let maximumAudioMemberSize: UInt64 = 1024 * 1024 * 1024
    private static let largeAudioExtensions: Set<String> = [
        "aif", "aiff", "ape", "flac", "m4a", "mp3", "ogg", "wav"
    ]

    /// Harvests a directory of native source files for one format extension.
    /// UAC packages are read through the wrapper API, not this native-source
    /// directory harvester. Track-aware results remain separate projections.
    public static func harvest(
        directoryURL: URL,
        formatExtension: String
    ) throws -> MetaManMetadataHarvestOutcome {
        let ext = formatExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        guard ext != "uac" else {
            throw MetaManMetadataHarvesterError.containerFormat(ext)
        }
        guard !ext.isEmpty,
              MetaManCore.supportedFormats.contains(where: { $0.fileExtensions.contains(ext) }) else {
            throw MetaManMetadataHarvesterError.unsupportedFormat(ext)
        }

        let root = directoryURL.standardizedFileURL
        let rootValues = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw MetaManMetadataHarvesterError.notDirectory(root.path)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw MetaManMetadataHarvesterError.cannotEnumerate(root.path)
        }

        var files: [(url: URL, path: String)] = []
        var playlistsByDirectory: [String: [URL]] = [:]
        var nsfFilesByDirectory: [String: [URL]] = [:]
        for case let url as URL in enumerator {
            let fileExtension = url.pathExtension.lowercased()
            let isTarget = fileExtension == ext
            let isFormatPlaylist = ["gbs", "nsf"].contains(ext) && fileExtension == "m3u"
            guard isTarget || isFormatPlaylist else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true else {
                throw MetaManMetadataHarvesterError.notRegularFile(url.path)
            }
            let path = String(url.standardizedFileURL.path.dropFirst(root.path.count + 1))
            guard !path.isEmpty, !path.hasPrefix("../"), !path.contains("\\") else {
                throw MetaManMetadataHarvesterError.unsafeRelativePath(path)
            }
            if isTarget {
                files.append((url, path))
                if ext == "nsf" {
                    nsfFilesByDirectory[url.deletingLastPathComponent().standardizedFileURL.path, default: []]
                        .append(url)
                }
            } else {
                playlistsByDirectory[url.deletingLastPathComponent().standardizedFileURL.path, default: []]
                    .append(url)
            }
        }
        files.sort { $0.path < $1.path }

        var memberMetadata: [String: [String: UACJSONValue]] = [:]
        var trackMetadata: [String: [MetaManMetadataTrackProjection]] = [:]
        var failures: [String] = []
        var diagnosticCount = 0
        var nsfProjectionConflicts: [String] = []
        var gbsProjectionConflicts: [String] = []
        var gbsSourceDocuments: [MetadataDocument] = []
        for file in files {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
                let maximumSize = largeAudioExtensions.contains(ext)
                    ? maximumAudioMemberSize
                    : maximumMemberSize
                guard let size = attributes[.size] as? NSNumber,
                      size.uint64Value <= maximumSize else {
                    throw MetaManMetadataHarvesterError.memberTooLarge(file.path)
                }
                let context: MetadataReadContext
                if ext == "gbs" || ext == "nsf" {
                    let directory = file.url.deletingLastPathComponent().standardizedFileURL.path
                    let siblings = playlistsByDirectory[directory] ?? []
                    let playlistURLs: [URL]
                    if ext == "nsf", (nsfFilesByDirectory[directory] ?? []).count > 1 {
                        let stem = file.url.deletingPathExtension().lastPathComponent
                        playlistURLs = siblings.filter {
                            $0.deletingPathExtension().lastPathComponent
                                .compare(stem, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                        }
                    } else {
                        playlistURLs = siblings
                    }
                    let orderedPlaylists = playlistURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }
                    guard orderedPlaylists.count <= maximumCompanionPlaylistCount else {
                        throw MetaManMetadataHarvesterError.tooManyCompanionPlaylists(ext, file.path)
                    }
                    var playlistSetBytes: UInt64 = 0
                    let companions = try orderedPlaylists.map { playlistURL in
                        let playlistAttributes = try FileManager.default.attributesOfItem(atPath: playlistURL.path)
                        guard let playlistSize = playlistAttributes[.size] as? NSNumber,
                              playlistSize.uint64Value <= maximumCompanionPlaylistSize else {
                            throw MetaManMetadataHarvesterError.companionPlaylistTooLarge(ext, playlistURL.lastPathComponent)
                        }
                        playlistSetBytes += playlistSize.uint64Value
                        guard playlistSetBytes <= maximumCompanionPlaylistSetSize else {
                            throw MetaManMetadataHarvesterError.companionPlaylistSetTooLarge(ext, file.path)
                        }
                        let companionPath: String
                        if ext == "nsf" {
                            companionPath = String(playlistURL.standardizedFileURL.path.dropFirst(root.path.count + 1))
                        } else {
                            companionPath = playlistURL.lastPathComponent
                        }
                        return MetadataCompanionFile(
                            relativePath: companionPath,
                            data: try Data(contentsOf: playlistURL, options: [.mappedIfSafe])
                        )
                    }
                    context = MetadataReadContext(
                        companionFiles: companions,
                        sourceRelativePath: ext == "nsf" ? file.path : nil
                    )
                } else {
                    context = MetadataReadContext()
                }
                let result = try MetaManCore.readResult(fileURL: file.url, context: context)
                guard !result.tracks.isEmpty else {
                    throw MetaManMetadataHarvesterError.noTracks(file.path)
                }
                if ext == "gbs" {
                    diagnosticCount += Set(result.tracks.flatMap { $0.document.diagnostics }).count
                } else {
                    diagnosticCount += result.tracks.reduce(0) { $0 + $1.document.diagnostics.count }
                }
                if ext == "nsf" || ext == "gbs" {
                    let readerDiagnostics = Set(result.tracks.flatMap { $0.document.diagnostics })
                    let prefixed = readerDiagnostics.sorted().map { "\(file.path): \($0)" }
                    if ext == "nsf" {
                        nsfProjectionConflicts.append(contentsOf: prefixed)
                    } else {
                        gbsProjectionConflicts.append(contentsOf: prefixed)
                        gbsSourceDocuments.append(contentsOf: result.tracks.map(\.document))
                    }
                }
                trackMetadata[file.path] = result.tracks.map { track in
                    let facts = track.document.technicalFacts
                    return MetaManMetadataTrackProjection(
                        sourceTrackIndex: track.sourceTrackIndex,
                        sourcePlaylistOrder: facts["m3uSourceOrder"].flatMap(Int.init),
                        metadata: MetaManMetadataProjector.memberFields(from: track.document),
                        sourcePlaylistPath: facts["m3uSourcePath"],
                        rawLine: facts["m3uRawLine"],
                        lengthRaw: facts["m3uTimeRaw"],
                        loopRaw: facts["m3uLoopRaw"],
                        loopStartRaw: facts["m3uLoopStartRaw"],
                        fadeRaw: facts["m3uFadeRaw"],
                        repeatRaw: facts["m3uRepeatRaw"]
                    )
                }
                if ext == "nsf" {
                    let shared = MetaManMetadataProjector.sharedNSFFields(from: result.tracks.map(\.document))
                    memberMetadata[file.path] = shared.fields
                    nsfProjectionConflicts.append(contentsOf: shared.conflicts.map { "\(file.path): \($0)" })
                } else if ext == "gbs" {
                    // GBS header identity belongs on the package; per-track
                    // entries carry Title, Format, and M3U playback data.
                    memberMetadata[file.path] = [:]
                } else if result.tracks.count == 1, let track = result.tracks.first {
                    memberMetadata[file.path] = MetaManMetadataProjector.memberFields(from: track.document)
                } else {
                    let indexes = result.tracks.compactMap(\.sourceTrackIndex)
                    guard indexes.count == result.tracks.count,
                          indexes.allSatisfy({ $0 >= 0 }),
                          (ext == "nsfe" || Set(indexes).count == indexes.count) else {
                        throw MetaManMetadataHarvesterError.unrepresentableTrackMap(file.path)
                    }
                    memberMetadata[file.path] = MetaManMetadataProjector.sharedMemberFields(
                        from: result.tracks.map(\.document)
                    )
                }
            } catch {
                memberMetadata.removeValue(forKey: file.path)
                trackMetadata.removeValue(forKey: file.path)
                failures.append("\(file.path): \(error.localizedDescription)")
            }
        }

        let shared: (fields: [String: UACJSONValue], conflicts: [String])
        if ext == "nsf" {
            shared = sharedNSFPackageMetadata(memberMetadata)
        } else if ext == "gbs" {
            shared = sharedGBSPackageMetadata(gbsSourceDocuments)
        } else {
            shared = ([:], [])
        }
        return MetaManMetadataHarvestOutcome(
            memberMetadata: memberMetadata,
            trackMetadata: trackMetadata,
            gameMetadata: shared.fields,
            sharedFieldConflicts: nsfProjectionConflicts + gbsProjectionConflicts + shared.conflicts,
            failures: failures,
            diagnosticCount: diagnosticCount
        )
    }

    private static func sharedNSFPackageMetadata(
        _ members: [String: [String: UACJSONValue]]
    ) -> (fields: [String: UACJSONValue], conflicts: [String]) {
        let keys = Set(members.values.flatMap(\.keys)).sorted()
        var fields: [String: UACJSONValue] = [:]
        var conflicts: [String] = []
        for key in keys {
            let values = members.values.compactMap { $0[key] }
            guard let first = values.first else { continue }
            if values.allSatisfy({ $0 == first }), values.count == members.count {
                fields[key] = first
            } else if values.dropFirst().contains(where: { $0 != first }) {
                conflicts.append("NSF package field \(key) differs across source members; it was not promoted to game metadata.")
            }
        }
        return (fields, conflicts)
    }

    private static func sharedGBSPackageMetadata(
        _ documents: [MetadataDocument]
    ) -> (fields: [String: UACJSONValue], conflicts: [String]) {
        guard !documents.isEmpty else { return ([:], []) }
        var fields: [String: UACJSONValue] = [:]
        var conflicts: [String] = []

        func sharedHeaderValue(
            _ keyPath: KeyPath<MetadataFields, String?>,
            name: String
        ) -> String? {
            let values = documents.map { normalizedSourceValue($0.fields[keyPath: keyPath]) }
            let distinct = Set(values.compactMap { $0 })
            guard distinct.count <= 1,
                  distinct.isEmpty || values.allSatisfy({ $0 != nil }) else {
                conflicts.append("GBS header \(name) differs across source members; it was not promoted.")
                return nil
            }
            return distinct.first
        }

        func sharedM3UValue(_ sourceName: String, tagName: String) -> String? {
            let factKey = "m3uSharedTag.\(sourceName)"
            let values = documents.map { normalized($0.technicalFacts[factKey]) }
            let distinct = Set(values.compactMap { $0 })
            guard distinct.count == 1, values.allSatisfy({ $0 != nil }) else {
                if !distinct.isEmpty {
                    conflicts.append("GBS M3U # @\(tagName) differs across source members; it was not promoted.")
                }
                return nil
            }
            return distinct.first
        }

        let headerAlbum = sharedHeaderValue(\.game, name: "game")
        let headerArtist = sharedHeaderValue(\.artist, name: "artist")
        let headerCopyright = sharedHeaderValue(\.comment, name: "comment")
        let headerYear = sharedHeaderValue(\.year, name: "year")
        let m3uAlbum = sharedM3UValue("TITLE", tagName: "TITLE")
        let m3uArtist = sharedM3UValue("ARTIST", tagName: "ARTIST")
        let m3uDate = sharedM3UValue("DATE", tagName: "DATE")
        let m3uYear = sharedM3UValue("YEAR", tagName: "YEAR")
        let m3uComposer = sharedM3UValue("COMPOSER", tagName: "COMPOSER")
        let m3uDumper = sharedM3UValue("RIPPER", tagName: "RIPPER")
        let m3uTagger = sharedM3UValue("TAGGER", tagName: "TAGGER")
        let m3uDeveloper = sharedM3UValue("DEVELOPER", tagName: "DEVELOPER")
        let m3uPublisher = sharedM3UValue("PUBLISHER", tagName: "PUBLISHER")
        let m3uCopyright = sharedM3UValue("COPYRIGHT", tagName: "COPYRIGHT")
        let m3uGenre = sharedM3UValue("GENRE", tagName: "GENRE")

        func choose(_ header: String?, _ m3u: String?, field: String) -> String? {
            guard let m3u else { return header }
            guard let header else { return m3u }
            guard header == m3u else {
                conflicts.append("GBS header and M3U values disagree for \(field); the header value was retained.")
                return header
            }
            return header
        }
        if let album = choose(headerAlbum, m3uAlbum, field: "Album") {
            fields["Album"] = .string(album)
        }
        if let artist = choose(headerArtist, m3uArtist, field: "Album Artist") {
            fields["Album Artist"] = .string(artist)
        }
        if let copyright = choose(headerCopyright, m3uCopyright, field: "Copyright") {
            fields["Copyright"] = .string(copyright)
        }
        if let year = choose(headerYear, m3uYear, field: "Year") {
            fields["Year"] = .string(year)
        }
        if let m3uDate { fields["Date"] = .string(m3uDate) }
        if let m3uComposer { fields["Composer"] = .string(m3uComposer) }
        if let m3uDumper { fields["Dumper"] = .string(m3uDumper) }
        if let m3uTagger { fields["Tagger"] = .string(m3uTagger) }
        if let m3uDeveloper { fields["Developer"] = .string(m3uDeveloper) }
        if let m3uPublisher { fields["Publisher"] = .string(m3uPublisher) }
        if let m3uGenre { fields["Genre"] = .string(m3uGenre) }
        return (fields, conflicts)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedSourceValue(_ value: String?) -> String? {
        guard let trimmed = normalized(value) else { return nil }
        let placeholder = trimmed.lowercased().replacingOccurrences(of: " ", with: "")
        guard !["?", "<?>", "< ? >"].contains(placeholder) else { return nil }
        return trimmed
    }
}

private enum MetaManMetadataHarvesterError: Error, LocalizedError {
    case containerFormat(String)
    case unsupportedFormat(String)
    case notDirectory(String)
    case cannotEnumerate(String)
    case notRegularFile(String)
    case unsafeRelativePath(String)
    case memberTooLarge(String)
    case tooManyCompanionPlaylists(String, String)
    case companionPlaylistTooLarge(String, String)
    case companionPlaylistSetTooLarge(String, String)
    case noTracks(String)
    case unrepresentableTrackMap(String)

    var errorDescription: String? {
        switch self {
        case .containerFormat(let format): ".\(format) is a package container; use the UAC wrapper reader instead of the native-source directory harvester."
        case .unsupportedFormat(let format): "MetaMan does not advertise direct metadata support for .\(format) files."
        case .notDirectory(let path): "Metadata input is not a real directory: \(path)"
        case .cannotEnumerate(let path): "Cannot enumerate metadata input: \(path)"
        case .notRegularFile(let path): "Metadata input is not a regular file: \(path)"
        case .unsafeRelativePath(let path): "Metadata input has an unsafe member path: \(path)"
        case .memberTooLarge(let path): "Member exceeds the metadata-reader safety limit for its format: \(path)"
        case .tooManyCompanionPlaylists(let format, let path): ".\(format.uppercased()) companion directory has too many playlists: \(path)"
        case .companionPlaylistTooLarge(let format, let path): ".\(format.uppercased()) companion playlist exceeds the 4 MiB metadata limit: \(path)"
        case .companionPlaylistSetTooLarge(let format, let path): ".\(format.uppercased()) companion playlists exceed the 32 MiB set limit: \(path)"
        case .noTracks(let path): "MetaMan returned no logical tracks for \(path)."
        case .unrepresentableTrackMap(let path):
            "\(path) has track indexes that UAC cannot map to unique playable subsong entries."
        }
    }
}
