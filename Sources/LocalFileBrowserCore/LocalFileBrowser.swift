import Foundation

/// A filesystem node exposed to a frontend sidebar. The core deliberately
/// knows nothing about playback, catalogs, or UI state; callers provide the
/// playable-file predicate owned by their decoder surface.
public struct LocalFileBrowserNode: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case folder
        case file
    }

    public let id: String
    public let kind: Kind
    public let name: String
    public let path: String
    public let parentPath: String?
    public let children: [LocalFileBrowserNode]
    public let childrenLoaded: Bool
    public let alwaysExpanded: Bool

    public init(
        id: String,
        kind: Kind,
        name: String,
        path: String,
        parentPath: String? = nil,
        children: [LocalFileBrowserNode] = [],
        childrenLoaded: Bool,
        alwaysExpanded: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.path = path
        self.parentPath = parentPath
        self.children = children
        self.childrenLoaded = childrenLoaded
        self.alwaysExpanded = alwaysExpanded
    }
}

public struct LocalFileBrowserTarget: Equatable, Sendable {
    public let rootPath: String
    public let selectedPath: String

    public init(rootPath: String, selectedPath: String) {
        self.rootPath = rootPath
        self.selectedPath = selectedPath
    }
}

public enum LocalFileBrowserError: LocalizedError, Equatable, Sendable {
    case missingPath(String)
    case unsupportedTarget(String)
    case rootIsNotDirectory(String)
    case pathOutsideRoot(String)
    case unreadableDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .missingPath(let path):
            return "The local path does not exist: \(path)"
        case .unsupportedTarget(let path):
            return "The local path is not a readable file or folder: \(path)"
        case .rootIsNotDirectory(let path):
            return "The local browser root is not a folder: \(path)"
        case .pathOutsideRoot(let path):
            return "The local browser cannot access a path outside its selected folder: \(path)"
        case .unreadableDirectory(let path):
            return "The local folder could not be read: \(path)"
        }
    }
}

/// Shared local-file navigation primitives for native frontends.
///
/// A session is rooted at one user-selected folder. Listing is shallow and
/// deterministic: hidden entries are omitted, folders precede playable files,
/// and natural name ordering is used within each group. No recursive scan or
/// permission request is performed by this type.
public struct LocalFileBrowserSession: Sendable {
    public typealias PlayableFilePredicate = @Sendable (URL) -> Bool

    public let rootURL: URL
    private let isPlayableFile: PlayableFilePredicate

    public init(rootURL: URL, isPlayableFile: @escaping PlayableFilePredicate) throws {
        let normalizedRoot = rootURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalizedRoot.path, isDirectory: &isDirectory) else {
            throw LocalFileBrowserError.missingPath(normalizedRoot.path)
        }
        guard isDirectory.boolValue else {
            throw LocalFileBrowserError.rootIsNotDirectory(normalizedRoot.path)
        }
        self.rootURL = normalizedRoot
        self.isPlayableFile = isPlayableFile
    }

    public func target(for inputURL: URL) throws -> LocalFileBrowserTarget {
        let normalized = inputURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: normalized.path) else {
            throw LocalFileBrowserError.missingPath(normalized.path)
        }
        guard isWithinRoot(normalized) else {
            throw LocalFileBrowserError.pathOutsideRoot(normalized.path)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized.path, isDirectory: &isDirectory) else {
            throw LocalFileBrowserError.missingPath(normalized.path)
        }
        let selected = isDirectory.boolValue ? normalized : normalized.deletingLastPathComponent()
        return LocalFileBrowserTarget(rootPath: rootURL.path, selectedPath: selected.path)
    }

    public func rootNode() throws -> LocalFileBrowserNode {
        LocalFileBrowserNode(
            id: rootURL.path,
            kind: .folder,
            name: displayName(for: rootURL),
            path: rootURL.path,
            children: try children(of: rootURL),
            childrenLoaded: true,
            alwaysExpanded: true
        )
    }

    public func children(of folderURL: URL) throws -> [LocalFileBrowserNode] {
        let folder = folderURL.standardizedFileURL
        guard isWithinRoot(folder) else {
            throw LocalFileBrowserError.pathOutsideRoot(folder.path)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LocalFileBrowserError.rootIsNotDirectory(folder.path)
        }

        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw LocalFileBrowserError.unreadableDirectory(folder.path)
        }

        var folders: [LocalFileBrowserNode] = []
        var files: [LocalFileBrowserNode] = []
        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if values?.isDirectory == true {
                folders.append(LocalFileBrowserNode(
                    id: entry.path,
                    kind: .folder,
                    name: displayName(for: entry),
                    path: entry.path,
                    parentPath: folder.path,
                    childrenLoaded: false
                ))
            } else if values?.isRegularFile == true, isPlayableFile(entry) {
                files.append(LocalFileBrowserNode(
                    id: entry.path,
                    kind: .file,
                    name: displayName(for: entry),
                    path: entry.path,
                    parentPath: folder.path,
                    childrenLoaded: true
                ))
            }
        }

        let sort: (LocalFileBrowserNode, LocalFileBrowserNode) -> Bool = {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        folders.sort(by: sort)
        files.sort(by: sort)
        return folders + files
    }

    public func resolve(path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard isWithinRoot(url) else {
            throw LocalFileBrowserError.pathOutsideRoot(url.path)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalFileBrowserError.missingPath(url.path)
        }
        return url
    }

    private func isWithinRoot(_ url: URL) -> Bool {
        let rootPath = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        return url.path == rootURL.path || url.path.hasPrefix(rootPath)
    }

    private func displayName(for url: URL) -> String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}
