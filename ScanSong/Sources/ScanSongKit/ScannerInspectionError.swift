import Foundation

public enum ScannerInspectionError: LocalizedError {
    case unsupportedRoute(String)
    case missingRequiredAdapter(pluginID: String, extensionName: String)
    case missingDependency(String)
    case library(String)
    case malformedFile(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedRoute(let route):
            return "No scanner inspector is registered for \(route)."
        case .missingRequiredAdapter(let pluginID, let extensionName):
            return "Required \(pluginID) structure adapter is unavailable for .\(extensionName); the source was not flattened into a false single track."
        case .missingDependency(let name):
            return "Required MDX dependency is missing: \(name)."
        case .library(let message):
            return message
        case .malformedFile(let message):
            return message
        }
    }
}
