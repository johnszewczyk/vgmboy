import ArchiveCacheCore
import ArchiveMaterializationCore
import CatalogReader
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CocoaSpiceGalleryArtwork {
    private static let cacheRootURL = ZipArchiveSupport.cacheDirectoryURL
        .appendingPathComponent("GalleryArtwork", isDirectory: true)
    private static let materializer = FrontendArchiveCacheMaterializer(
        cacheRootURL: cacheRootURL,
        preferenceKeys: ArchiveCachePreferenceKeys(
            modeKey: AppDefaultsKey.archiveCacheMode,
            limitKey: AppDefaultsKey.archiveCacheLimitBytes
        ),
        decompressUACManifestFrame: UACZstandardCLIFrameCodec.shared.manifestDecoder
    )
    private static let reader = TitleSnapArtworkReader(materializer: materializer)

    static func thumbnailPNG(for game: CatalogGalleryGame, maximumPixelSize: Int = 640) throws -> Data {
        let sourceData = try reader.readPNG(sourcePath: game.sourcePath, locator: game.titleSnap)
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ArchiveMaterializationError.emptyOutput
        }
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width > 0, height > 0 else { throw ArchiveMaterializationError.emptyOutput }
        guard max(width, height) > maximumPixelSize else { return sourceData }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ArchiveMaterializationError.emptyOutput
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ArchiveMaterializationError.emptyOutput
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ArchiveMaterializationError.emptyOutput }
        return output as Data
    }
}
