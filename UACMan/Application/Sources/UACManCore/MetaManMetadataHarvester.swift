import Foundation
import MetaManCore
import UACWrapperCore

public struct MetaManMetadataHarvestOutcome: Sendable {
    public let memberMetadata: [String: [String: UACJSONValue]]
    public let trackMetadata: [String: [MetaManMetadataTrackProjection]]
    public let failures: [String]
    public let diagnosticCount: Int

    public init(
        memberMetadata: [String: [String: UACJSONValue]],
        trackMetadata: [String: [MetaManMetadataTrackProjection]] = [:],
        failures: [String],
        diagnosticCount: Int
    ) {
        self.memberMetadata = memberMetadata
        self.trackMetadata = trackMetadata
        self.failures = failures
        self.diagnosticCount = diagnosticCount
    }
}

public struct MetaManMetadataTrackProjection: Encodable, Sendable {
    /// The native decoder/subsong index. UAC stores this as a decimal string
    /// in playlist entries because the manifest keeps playlist fields open.
    public let sourceTrackIndex: Int?
    public let metadata: [String: UACJSONValue]

    public init(sourceTrackIndex: Int?, metadata: [String: UACJSONValue]) {
        self.sourceTrackIndex = sourceTrackIndex
        self.metadata = metadata
    }
}

public enum MetaManMetadataHarvester {
    private static let maximumMemberSize: UInt64 = 64 * 1024 * 1024
    private static let maximumCompanionPlaylistSize: UInt64 = 4 * 1024 * 1024
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
        var gbsPlaylistsByDirectory: [String: [URL]] = [:]
        for case let url as URL in enumerator {
            let fileExtension = url.pathExtension.lowercased()
            let isTarget = fileExtension == ext
            let isGBSPlaylist = ext == "gbs" && fileExtension == "m3u"
            guard isTarget || isGBSPlaylist else { continue }
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
            } else {
                gbsPlaylistsByDirectory[url.deletingLastPathComponent().standardizedFileURL.path, default: []]
                    .append(url)
            }
        }
        files.sort { $0.path < $1.path }

        var memberMetadata: [String: [String: UACJSONValue]] = [:]
        var trackMetadata: [String: [MetaManMetadataTrackProjection]] = [:]
        var failures: [String] = []
        var diagnosticCount = 0
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
                if ext == "gbs" {
                    let directory = file.url.deletingLastPathComponent().standardizedFileURL.path
                    let playlistURLs = gbsPlaylistsByDirectory[directory] ?? []
                    let companions = try playlistURLs.sorted { $0.lastPathComponent < $1.lastPathComponent }.map { playlistURL in
                        let playlistAttributes = try FileManager.default.attributesOfItem(atPath: playlistURL.path)
                        guard let playlistSize = playlistAttributes[.size] as? NSNumber,
                              playlistSize.uint64Value <= maximumCompanionPlaylistSize else {
                            throw MetaManMetadataHarvesterError.companionPlaylistTooLarge(playlistURL.lastPathComponent)
                        }
                        return MetadataCompanionFile(
                            relativePath: playlistURL.lastPathComponent,
                            data: try Data(contentsOf: playlistURL, options: [.mappedIfSafe])
                        )
                    }
                    context = MetadataReadContext(companionFiles: companions)
                } else {
                    context = MetadataReadContext()
                }
                let result = try MetaManCore.readResult(fileURL: file.url, context: context)
                guard !result.tracks.isEmpty else {
                    throw MetaManMetadataHarvesterError.noTracks(file.path)
                }
                diagnosticCount += result.tracks.reduce(0) { $0 + $1.document.diagnostics.count }
                trackMetadata[file.path] = result.tracks.map { track in
                    MetaManMetadataTrackProjection(
                        sourceTrackIndex: track.sourceTrackIndex,
                        metadata: MetaManMetadataProjector.memberFields(from: track.document)
                    )
                }
                if result.tracks.count == 1, let track = result.tracks.first {
                    memberMetadata[file.path] = MetaManMetadataProjector.memberFields(from: track.document)
                } else {
                    let indexes = result.tracks.compactMap(\.sourceTrackIndex)
                    guard indexes.count == result.tracks.count,
                          indexes.allSatisfy({ $0 >= 0 }),
                          Set(indexes).count == indexes.count else {
                        throw MetaManMetadataHarvesterError.unrepresentableTrackMap(file.path)
                    }
                    memberMetadata[file.path] = MetaManMetadataProjector.sharedMemberFields(
                        from: result.tracks.map(\.document),
                        sourceTrackIndices: indexes
                    )
                }
            } catch {
                memberMetadata.removeValue(forKey: file.path)
                trackMetadata.removeValue(forKey: file.path)
                failures.append("\(file.path): \(error.localizedDescription)")
            }
        }

        return MetaManMetadataHarvestOutcome(
            memberMetadata: memberMetadata,
            trackMetadata: trackMetadata,
            failures: failures,
            diagnosticCount: diagnosticCount
        )
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
    case companionPlaylistTooLarge(String)
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
        case .companionPlaylistTooLarge(let path): "GBS companion playlist exceeds the 4 MiB metadata limit: \(path)"
        case .noTracks(let path): "MetaMan returned no logical tracks for \(path)."
        case .unrepresentableTrackMap(let path):
            "\(path) has track indexes that UAC cannot map to unique playable subsong entries."
        }
    }
}
