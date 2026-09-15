import Foundation

/// Related-file data supplied by a client for formats whose metadata or track
/// map depends on a companion source (for example HES plus M3U). Callers bound
/// the admitted files and aggregate bytes; MetaMan never opens paths named here.
public struct MetadataCompanionFile: Equatable, Sendable {
    public let relativePath: String
    public let data: Data

    public init(relativePath: String, data: Data) {
        self.relativePath = relativePath
        self.data = data
    }
}

public struct MetadataReadContext: Equatable, Sendable {
    public let companionFiles: [MetadataCompanionFile]

    public init(companionFiles: [MetadataCompanionFile] = []) {
        self.companionFiles = companionFiles
    }

    func companionData(beside sourceName: String, fileExtension: String) -> Data? {
        let source = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
        return companionFiles.first { companion in
            let path = URL(fileURLWithPath: companion.relativePath)
            guard path.pathExtension.caseInsensitiveCompare(fileExtension) == .orderedSame else { return false }
            return path.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(source) == .orderedSame
        }?.data
    }

    func containsCompanion(beside sourceName: String, fileExtension: String) -> Bool {
        let source = URL(fileURLWithPath: sourceName).deletingPathExtension().lastPathComponent
        return companionFiles.contains { companion in
            let path = URL(fileURLWithPath: companion.relativePath)
            return path.pathExtension.caseInsensitiveCompare(fileExtension) == .orderedSame
                && path.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(source) == .orderedSame
        }
    }

    func appending(_ companion: MetadataCompanionFile) -> MetadataReadContext {
        MetadataReadContext(companionFiles: companionFiles + [companion])
    }
}
