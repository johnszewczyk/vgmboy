import Foundation

enum AppBoyResourceLocator {
    static func webRootURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebUI") {
            return direct.deletingLastPathComponent()
        }
        if let moduleIndex = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "WebUI") {
            return moduleIndex.deletingLastPathComponent()
        }
        if let flatModuleIndex = Bundle.module.url(forResource: "index", withExtension: "html") {
            return flatModuleIndex.deletingLastPathComponent()
        }
        if let flatMainIndex = Bundle.main.url(forResource: "index", withExtension: "html") {
            return flatMainIndex.deletingLastPathComponent()
        }
        return nil
    }

    static func indexPageURL() -> URL? {
        webRootURL()?.appendingPathComponent("index.html")
    }
}
