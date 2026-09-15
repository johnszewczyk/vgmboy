import Foundation
import MetaManCore
import UACContainerCore

public struct SPCMetadataHarvestOutcome: Sendable {
    public let items: [SPCMetadataHarvestItem]
    public let failures: [String]
    public let diagnosticCount: Int
    public let wasCancelled: Bool

    public init(items: [SPCMetadataHarvestItem], failures: [String], diagnosticCount: Int, wasCancelled: Bool) {
        self.items = items
        self.failures = failures
        self.diagnosticCount = diagnosticCount
        self.wasCancelled = wasCancelled
    }
}

public enum SPCMetadataHarvester {
    public static func harvest(
        packageURL: URL,
        memberPaths: [String],
        decompressManifestFrame: @escaping UACManifestFrameDecoder,
        decompressFrame: @escaping @Sendable (Data, UInt32?) throws -> Data,
        progress: @escaping @Sendable (Int, Int, String) -> Void = { _, _, _ in }
    ) throws -> SPCMetadataHarvestOutcome {
        var items: [SPCMetadataHarvestItem] = []
        var failures: [String] = []
        var diagnosticCount = 0
        var wasCancelled = false

        for (index, path) in memberPaths.enumerated() {
            if Task.isCancelled {
                wasCancelled = true
                break
            }
            do {
                let virtualFile = try UACSeekableMemberFile(
                    url: packageURL,
                    memberPath: path,
                    decompressManifestFrame: decompressManifestFrame,
                    decompressFrame: decompressFrame
                )
                guard virtualFile.size <= UInt64(Int.max),
                      virtualFile.size <= 64 * 1024 * 1024 else {
                    throw SPCMetadataHarvesterError.memberTooLarge(path)
                }
                let data = try virtualFile.read(at: 0, byteCount: Int(virtualFile.size))
                let document = try MetaManCore.read(
                    data: data,
                    formatHint: "spc",
                    displayName: URL(fileURLWithPath: path).lastPathComponent
                )
                diagnosticCount += document.diagnostics.count
                items.append(SPCMetadataHarvestItem(
                    memberPath: path,
                    projection: SPCMetadataProjector.project(document)
                ))
            } catch {
                failures.append("\(path): \(error.localizedDescription)")
            }
            progress(index + 1, memberPaths.count, path)
        }
        return SPCMetadataHarvestOutcome(
            items: items,
            failures: failures,
            diagnosticCount: diagnosticCount,
            wasCancelled: wasCancelled
        )
    }
}

private enum SPCMetadataHarvesterError: Error, LocalizedError {
    case memberTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .memberTooLarge(let path):
            "SPC member is larger than the 64 MiB metadata-reader safety limit: \(path)"
        }
    }
}
