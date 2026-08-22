import AppKit
import CatalogBrowserCore
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        let initialState = CatalogBrowserState()
        let stateData = try! JSONEncoder().encode(initialState)
        let stateJSON = String(decoding: stateData, as: UTF8.self)
        configuration.userContentController.addUserScript(WKUserScript(
            source: """
            window.spcbBrowserState = \(stateJSON);
            window.spcBoy = {
              isOptionsWindow: false,
              playbackBackends: [],
              bootstrap: async () => ({ rootPath: null, tree: [], selectedFolderPath: null, selectedBrowserPath: null, playlist: [] }),
              refreshTree: async () => ({ rootPath: null, tree: [], selectedFolderPath: null, selectedBrowserPath: null, playlist: [] }),
              databaseLocation: async () => null,
              databaseRoots: async () => [],
              databaseGames: async () => [],
              databaseFiles: async () => [],
              databaseSearchGames: async () => [],
              databaseGameTracks: async () => [],
              databaseFileTracks: async () => [],
              databaseFolderTracks: async () => [],
              configureArchiveCache: async () => null,
              setRoutingPreferences: async (value) => value || {},
              setPlaybackSettings: () => undefined,
              setAppearanceSettings: () => undefined,
              showSidebarViewMenu: async () => undefined,
              openPath: async () => ({ rootPath: null, tree: [], selectedFolderPath: null, selectedBrowserPath: null, playlist: [] }),
              onCatalogReloaded: () => undefined,
              onLibrarySnapshot: () => undefined,
              onLibraryCommand: () => undefined,
              onNativePlaybackState: () => undefined,
              onPlaybackSettingsChanged: () => undefined,
              onAppearanceSettingsChanged: () => undefined,
              onRoutingPreferencesChanged: () => undefined,
              onTransportShortcut: () => undefined
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        guard let page = Bundle.module.url(forResource: "index", withExtension: "html") else {
            fatalError("SPCBoy WK resources are missing index.html")
        }
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SPCBoy"
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
