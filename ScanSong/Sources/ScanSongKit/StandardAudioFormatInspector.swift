import Foundation

public struct StandardAudioFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) throws -> ScanInspection {
        let metadata = try StandardAudioInspector.inspect(fileURL: fileURL)
        return ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: metadata)]
        )
    }
}
