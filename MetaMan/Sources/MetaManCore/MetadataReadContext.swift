import Foundation

/// Host-supplied decompressor for bounded metadata frames inside containers.
/// MetaMan owns the container and metadata parsing; hosts choose their codec
/// implementation without making MetaManCore spawn a process or link a
/// platform-specific Zstandard runtime.
public typealias MetadataContainerFrameDecoder = @Sendable (
    _ compressedFrame: Data,
    _ expectedByteCount: Int,
    _ maximumMemoryByteCount: Int
) throws -> Data

/// Named related-file bytes for data-based readers whose metadata or track map
/// depends on companions. `relativePath` and `sourceRelativePath` share the
/// host's package-relative coordinate system when the latter is supplied; a
/// file-URL convenience reader may use sibling basenames. This context never
/// authorizes arbitrary path access.
public struct MetadataCompanionFile: Equatable, Sendable {
    /// Path relative to the source file's containing directory.
    public let relativePath: String
    public let data: Data

    public init(relativePath: String, data: Data) {
        self.relativePath = relativePath
        self.data = data
    }
}

public struct MetadataReadContext: Equatable, Sendable {
    public let companionFiles: [MetadataCompanionFile]
    /// Optional source member path relative to the same package root used by
    /// companion paths. Readers use it to resolve playlist references exactly
    /// when the caller already knows the package layout.
    public let sourceRelativePath: String?

    public init(companionFiles: [MetadataCompanionFile] = [], sourceRelativePath: String? = nil) {
        self.companionFiles = companionFiles
        self.sourceRelativePath = sourceRelativePath
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

    func companionData(named relativePath: String) -> Data? {
        guard let requestedPath = Self.normalizedRelativePath(relativePath) else { return nil }
        return companionFiles.first { companion in
            guard let candidatePath = Self.normalizedRelativePath(companion.relativePath) else { return false }
            return candidatePath.caseInsensitiveCompare(requestedPath) == .orderedSame
        }?.data
    }

    func appending(_ companion: MetadataCompanionFile) -> MetadataReadContext {
        MetadataReadContext(companionFiles: companionFiles + [companion], sourceRelativePath: sourceRelativePath)
    }

    private static func normalizedRelativePath(_ path: String) -> String? {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("\\"), !path.contains("\0") else {
            return nil
        }
        let components = path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
        guard !components.isEmpty, !components.contains("..") else { return nil }
        return components.filter { $0 != "." }.joined(separator: "/")
    }
}
