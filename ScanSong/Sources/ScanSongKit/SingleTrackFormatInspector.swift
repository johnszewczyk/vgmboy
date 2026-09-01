import Foundation

/// Used by routes whose decoder owns playback metadata but does not currently
/// expose a scanner metadata adapter. The route still publishes one logical
/// track, matching the previous built-in behavior.
public struct SingleTrackFormatInspector: ScanFormatHandler {
    public let descriptor: ScannerPluginDescriptor

    public init(descriptor: ScannerPluginDescriptor) {
        self.descriptor = descriptor
    }

    public func inspect(fileURL: URL, route: ScannerRoute) async throws -> ScanInspection {
        ScanInspection(
            route: route,
            tracks: [ScanTrackMetadata(trackIndex: 0, trackCount: 1, metadata: nil)]
        )
    }
}
