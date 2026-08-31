import Foundation

/// Format-specific filesystem preparation required after an archive set has
/// been extracted. The rules are shared because the decoder receives only a
/// clean directory-backed path; no frontend is allowed to reinterpret them.
public enum ArchiveDependencyPreparation {
    /// lazyusf resolves `.usflib` references through the extensionless library
    /// name stored in the USF set. These hard links live only in the extracted
    /// playback directory and never modify the source archive.
    public static func prepareLazyUSFAliases(in materializedArchiveURL: URL) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: materializedArchiveURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for libraryURL in contents where libraryURL.pathExtension.lowercased() == "usflib" {
            let aliasURL = libraryURL.deletingPathExtension()
            guard !FileManager.default.fileExists(atPath: aliasURL.path) else { continue }
            try FileManager.default.linkItem(at: libraryURL, to: aliasURL)
        }
    }

    /// Some flat Wwise archives contain TXTP manifests whose references retain
    /// the original directory hierarchy. Build cache-only hard-link aliases
    /// for uniquely named siblings so vgmstream sees the paths declared by the
    /// manifest without modifying the source.
    public static func prepareTXTPDependencies(in materializedArchiveURL: URL) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: materializedArchiveURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var filesByLeafName: [String: [URL]] = [:]
        var txtpFiles: [URL] = []
        for case let fileURL as URL in enumerator {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            if fileURL.pathExtension.lowercased() == "txtp" {
                txtpFiles.append(fileURL)
            } else {
                filesByLeafName[fileURL.lastPathComponent, default: []].append(fileURL)
            }
        }

        for txtpURL in txtpFiles {
            guard let contents = try? String(contentsOf: txtpURL, encoding: .utf8) else { continue }
            for rawLine in contents.split(whereSeparator: \.isNewline) {
                let rawReference = rawLine
                    .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                    .first
                    .map(String.init)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let reference = rawReference.replacingOccurrences(of: "\\", with: "/")
                guard !reference.isEmpty,
                      !reference.hasPrefix("/"),
                      !reference.contains(".."),
                      let leafName = reference.split(separator: "/").last.map(String.init),
                      let candidates = filesByLeafName[leafName],
                      candidates.count == 1 else {
                    continue
                }

                let aliasURL = txtpURL.deletingLastPathComponent()
                    .appendingPathComponent(reference, isDirectory: false)
                guard !fileManager.fileExists(atPath: aliasURL.path) else { continue }
                try fileManager.createDirectory(
                    at: aliasURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.linkItem(at: candidates[0], to: aliasURL)
            }
        }
    }
}
