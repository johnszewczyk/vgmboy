import CryptoKit
import Foundation

struct MarkdownDocument: Sendable {
    let path: String
    let title: String
}

struct MarkdownDirectory: Sendable {
    let projectRoot: URL
    let markdownRoot: URL

    init(projectRoot: URL) throws {
        self.projectRoot = projectRoot.standardizedFileURL
        self.markdownRoot = projectRoot.appendingPathComponent("Docs/md", isDirectory: true)
            .standardizedFileURL
        try FileManager.default.createDirectory(at: markdownRoot, withIntermediateDirectories: true)
    }

    var projectRootPath: String { projectRoot.path }
    var markdownRootPath: String { markdownRoot.path }

    var projectRootFileURL: String { projectRoot.absoluteString }
    var markdownRootFileURL: String { markdownRoot.absoluteString }

    func documents() throws -> [MarkdownDocument] {
        guard let enumerator = FileManager.default.enumerator(
            at: markdownRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw DirectoryError.cannotEnumerate(markdownRoot.path)
        }

        var documents: [MarkdownDocument] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  url.pathExtension.lowercased() == "md",
                  let relative = relativeMarkdownPath(for: url) else {
                continue
            }
            let source = try String(contentsOf: url, encoding: .utf8)
            let fallback = Self.prettyName(url.deletingPathExtension().lastPathComponent)
            let title = source
                .split(whereSeparator: \.isNewline)
                .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") })
                .map { String($0.drop { $0 == "#" || $0 == " " }).trimmingCharacters(in: .whitespaces) }
                .flatMap { $0.isEmpty ? nil : $0 } ?? fallback
            documents.append(MarkdownDocument(path: relative, title: title))
        }
        return documents.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    func read(path: String) throws -> [String: Any] {
        let url = try markdownURL(for: path, mustExist: true)
        let data = try Data(contentsOf: url)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw DirectoryError.notUTF8(path)
        }
        return [
            "path": path,
            "title": title(for: markdown, fallback: url.deletingPathExtension().lastPathComponent),
            "markdown": markdown,
            "version": version(for: data),
            "documentFileURL": url.absoluteString
        ]
    }

    func save(path: String, markdown: String, expectedVersion: String) throws -> [String: Any] {
        let url = try markdownURL(for: path, mustExist: true)
        let currentData = try Data(contentsOf: url)
        let currentVersion = version(for: currentData)
        guard currentVersion == expectedVersion else {
            throw DirectoryError.conflict(path)
        }
        let newData = Data(markdown.utf8)
        try newData.write(to: url, options: .atomic)
        return [
            "path": path,
            "markdown": markdown,
            "version": version(for: newData),
            "documentFileURL": url.absoluteString
        ]
    }

    func create(path: String, markdown: String) throws -> [String: Any] {
        let url = try markdownURL(for: path, mustExist: false)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw DirectoryError.alreadyExists(path)
        }
        let data = Data(markdown.utf8)
        try data.write(to: url, options: .atomic)
        return [
            "path": path,
            "title": title(for: markdown, fallback: url.deletingPathExtension().lastPathComponent),
            "markdown": markdown,
            "version": version(for: data),
            "documentFileURL": url.absoluteString
        ]
    }

    func fileURL(relativeToDocumentPath path: String) throws -> URL {
        try markdownURL(for: path, mustExist: true)
    }

    private func markdownURL(for relativePath: String, mustExist: Bool) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("\\") else {
            throw DirectoryError.invalidPath
        }
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count >= 2,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              components.last?.lowercased().hasSuffix(".md") == true else {
            throw DirectoryError.invalidPath
        }

        let candidate = markdownRoot.appending(path: relativePath).standardizedFileURL
        let rootPath = markdownRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path.hasPrefix(rootPath + "/") else {
            throw DirectoryError.invalidPath
        }
        if mustExist {
            let values = try resolved.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw DirectoryError.notFound(relativePath)
            }
        }
        return resolved
    }

    private func relativeMarkdownPath(for url: URL) -> String? {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let root = markdownRoot.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolved.path.hasPrefix(root + "/") else { return nil }
        return String(resolved.path.dropFirst(root.count + 1))
    }

    private func version(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func title(for source: String, fallback: String) -> String {
        let fallbackTitle = Self.prettyName(fallback)
        guard let heading = source
            .split(whereSeparator: \.isNewline)
            .first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }) else {
            return fallbackTitle
        }
        let title = String(heading.drop { $0 == "#" || $0 == " " }).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? fallbackTitle : title
    }

    private static func prettyName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
    }
}

enum DirectoryError: LocalizedError {
    case cannotEnumerate(String)
    case invalidPath
    case notFound(String)
    case notUTF8(String)
    case conflict(String)
    case alreadyExists(String)

    var errorDescription: String? {
        switch self {
        case .cannotEnumerate(let path): "Unable to read the documentation folder at \(path)."
        case .invalidPath: "The document path is invalid or outside Docs/md."
        case .notFound(let path): "The Markdown file no longer exists: \(path)"
        case .notUTF8(let path): "The Markdown file is not valid UTF-8: \(path)"
        case .conflict(let path): "This document changed on disk while it was being edited: \(path)"
        case .alreadyExists(let path): "A document already exists at \(path)."
        }
    }
}
