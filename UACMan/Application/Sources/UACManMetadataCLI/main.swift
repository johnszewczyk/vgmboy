import Foundation
import UACWrapperCore
import UACManCore

private struct HarvestResponse: Encodable {
    let schemaVersion = 1
    let memberMetadata: [String: [String: UACJSONValue]]
    let trackMetadata: [String: [MetaManMetadataTrackProjection]]
    let gameMetadata: [String: UACJSONValue]
    let sharedFieldConflicts: [String]
    let diagnosticCount: Int
    let failures: [String]
}

@main
private enum UACManMetadataCLI {
    static func main() {
        do {
            let arguments = CommandLine.arguments
            let response: HarvestResponse
            switch (arguments.count, arguments.dropFirst().first) {
            case (3, "harvest-spc-directory"):
                let root = URL(fileURLWithPath: arguments[2], isDirectory: true)
                let outcome = try SPCMetadataHarvester.harvest(directoryURL: root)
                let shared = SPCMetadataProjector.sharedFields(from: outcome.items.map(\.projection))
                response = HarvestResponse(
                    memberMetadata: Dictionary(uniqueKeysWithValues: outcome.items.map {
                        ($0.memberPath, $0.projection.memberFields)
                    }),
                    trackMetadata: [:],
                    gameMetadata: shared.fields,
                    sharedFieldConflicts: shared.conflicts,
                    diagnosticCount: outcome.diagnosticCount,
                    failures: outcome.failures
                )
            case (4, "harvest-format-directory"):
                let outcome = try MetaManMetadataHarvester.harvest(
                    directoryURL: URL(fileURLWithPath: arguments[3], isDirectory: true),
                    formatExtension: arguments[2]
                )
                response = HarvestResponse(
                    memberMetadata: outcome.memberMetadata,
                    trackMetadata: outcome.trackMetadata,
                    gameMetadata: [:],
                    sharedFieldConflicts: [],
                    diagnosticCount: outcome.diagnosticCount,
                    failures: outcome.failures
                )
            default:
                throw CLIError.usage
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            let output = try encoder.encode(response)
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data([0x0A]))
            if !response.failures.isEmpty {
                throw CLIError.harvestFailures(response.failures.count)
            }
        } catch {
            let message = "uacman-metadata: \(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(message.utf8))
            exit(2)
        }
    }
}

private enum CLIError: Error, LocalizedError {
    case usage
    case harvestFailures(Int)

    var errorDescription: String? {
        switch self {
        case .usage:
            "usage: UACManMetadataCLI harvest-spc-directory <directory> | harvest-format-directory <extension> <directory>"
        case .harvestFailures(let count):
            "MetaMan could not read \(count) source file(s); no metadata should be imported."
        }
    }
}
