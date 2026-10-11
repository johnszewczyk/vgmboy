import Foundation

/// Reads a catalog-selected PNG preview without giving frontends archive or
/// path-resolution rules of their own.
///
/// The frontend supplies an isolated archive materializer and owns image
/// decoding, caching, and presentation. Archive reads are serialized because
/// the materializer keeps a short-lived lease until `release()`.
public final class TitleSnapArtworkReader: @unchecked Sendable {
    private let materializer: ArchivePlaybackMaterializer
    private let archiveReadLock = NSLock()

    public init(materializer: ArchivePlaybackMaterializer) {
        self.materializer = materializer
    }

    public func readPNG(sourcePath: String, locator: String) throws -> Data {
        let sourceURL = URL(fileURLWithPath: sourcePath).standardizedFileURL
        guard !sourcePath.isEmpty, !locator.isEmpty,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ArchiveMaterializationError.missingSource(sourcePath)
        }

        let memberPath: String?
        let imageURL: URL?
        if locator.hasPrefix("archive-member:") {
            memberPath = String(locator.dropFirst("archive-member:".count))
            imageURL = nil
        } else if let parsed = URL(string: locator), parsed.isFileURL {
            memberPath = nil
            imageURL = parsed.standardizedFileURL
        } else if locator.hasPrefix("/") {
            memberPath = nil
            imageURL = URL(fileURLWithPath: locator).standardizedFileURL
        } else if URL(fileURLWithPath: locator).pathExtension.lowercased() == "png" {
            memberPath = locator
            imageURL = nil
        } else {
            throw ArchiveMaterializationError.invalidEntry
        }

        let imageData: Data
        if let memberPath {
            guard URL(fileURLWithPath: memberPath).pathExtension.lowercased() == "png" else {
                throw ArchiveMaterializationError.invalidEntry
            }
            archiveReadLock.lock()
            defer {
                materializer.release()
                archiveReadLock.unlock()
            }
            let materializedURL = try materializer.materialize(
                archiveURL: sourceURL,
                entryPath: memberPath,
                requirement: .selectedEntry
            )
            imageData = try Data(contentsOf: materializedURL, options: .mappedIfSafe)
        } else if let imageURL {
            guard imageURL.pathExtension.lowercased() == "png",
                  imageURL.deletingLastPathComponent() == sourceURL.deletingLastPathComponent(),
                  let values = try? imageURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ArchiveMaterializationError.invalidEntry
            }
            imageData = try Data(contentsOf: imageURL, options: .mappedIfSafe)
        } else {
            throw ArchiveMaterializationError.invalidEntry
        }

        let pngSignature = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        guard imageData.count <= 32 * 1_024 * 1_024,
              imageData.starts(with: pngSignature) else {
            throw ArchiveMaterializationError.emptyOutput
        }
        return imageData
    }
}
