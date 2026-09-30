import AppKit
import FrontendCommandCore
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    private weak var webView: WKWebView?
    private weak var surfaceView: ViewBoySurfaceView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        if let iconURL = Bundle.main.url(forResource: "app-icon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        let nativeBridge = WKNativeBridge()
        nativeBridge.onCloseMainWindow = { [weak self] in self?.window?.performClose(nil) }
        nativeBridge.onChooseRootFolder = { [weak self] in self?.choosePath(allowFiles: false) }
        nativeBridge.onChoosePath = { [weak self] in self?.choosePath(allowFiles: true) }
        nativeBridge.onChooseAACExportDirectory = { [weak self] in self?.chooseDirectory(title: "Choose AAC Export Folder") }
        nativeBridge.onAppearanceSettingsChanged = { [weak self] settings in
            self?.broadcastAppearanceSettings(settings)
        }
        nativeBridge.onFrontendSettingsChanged = { [weak self] settings in self?.receiveFrontendSettings(settings) }
        nativeBridge.onPlaybackEvent = { [weak self] name, payload in
            self?.broadcastPlaybackEvent(name: name, payload: payload)
        }
        let metalChevronOverlay = ViewBoyMetalChevronOverlay(frame: .zero)
        let webView = makeWebView(
            bridge: nativeBridge,
            metalChevronOverlayAvailable: metalChevronOverlay.isAvailable
        )
        self.webView = webView
        let surfaceView = ViewBoySurfaceView(webView: webView, metalChevronOverlay: metalChevronOverlay)
        self.surfaceView = surfaceView
        nativeBridge.onMetalChevronUpdate = { [weak self] geometry in
            self?.surfaceView?.updateMetalChevrons(geometry)
        }
        nativeBridge.attachPlaybackEvents(to: webView)
        installApplicationMenu()
        guard let page = URL(string: "viewboy://app/index.html") else {
            fatalError("ViewBoy resource URL is invalid")
        }
        webView.load(URLRequest(url: page))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ViewBoy"
        window.tabbingMode = .disallowed
        window.contentView = surfaceView
        if !window.setFrameAutosaveName("ViewBoy.Main") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        applyWindowLevels()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWebView(bridge: WKNativeBridge, metalChevronOverlayAvailable: Bool) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(ViewBoyResourceSchemeHandler(), forURLScheme: "viewboy")
        configuration.userContentController.add(bridge, name: "viewBoy")
        configuration.userContentController.addUserScript(bridge.userScript())
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.__viewBoyMetalChevronOverlay = \(metalChevronOverlayAvailable ? "true" : "false");",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController.addUserScript(WKUserScript(
            source: """
            window.__viewBoyCommandQueue = [];
            window.ViewBoy = {
              dispatch(command) { window.__viewBoyCommandQueue.push(command); }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }

    private func broadcastAppearanceSettings(_ settings: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(settings),
              let data = try? JSONSerialization.data(withJSONObject: settings),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = "window.__viewBoyEvent('appearanceSettingsChanged', \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func broadcastFrontendSettings(_ settings: ViewBoyPreferencesSnapshot) {
        guard let data = try? JSONEncoder().encode(settings),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = "window.__viewBoyEvent('frontendSettingsChanged', \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func broadcastPlaybackEvent(name: String, payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let nameData = try? JSONEncoder().encode(name),
              let nameJSON = String(data: nameData, encoding: .utf8) else { return }
        let script = "window.__viewBoyEvent(\(nameJSON), \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func receiveFrontendSettings(_ settings: ViewBoyPreferencesSnapshot) {
        if let value = settings.mainWindowAlwaysOnTop {
            window?.level = value ? .floating : .normal
        }
        NSApp.mainMenu?.update()
        broadcastFrontendSettings(settings)
    }

    private func applyWindowLevels() {
        guard let data = UserDefaults.standard.data(forKey: "ViewBoy.frontendPreferencesV3"),
              let snapshot = try? JSONDecoder().decode(ViewBoyPreferencesSnapshot.self, from: data) else {
            window?.level = .normal
            return
        }
        window?.level = snapshot.mainWindowAlwaysOnTop == true ? .floating : .normal
    }

    private func choosePath(allowFiles: Bool) -> String? {
        let panel = NSOpenPanel()
        panel.title = allowFiles ? "Open Local Path" : "Choose Local Files Folder"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = allowFiles
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.standardizedFileURL.path
    }

    private func chooseDirectory(title: String) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.standardizedFileURL.path
    }

    private func installApplicationMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "ViewBoy")
        appMenu.addItem(NSMenuItem(title: "About ViewBoy", action: nil, keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide ViewBoy", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").configured { $0.keyEquivalentModifierMask = [.command, .option] })
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "").configured { $0.keyEquivalentModifierMask = [.command, .option] })
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Quit ViewBoy", command: .quit, action: #selector(quit(_:))))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(menuItem("Open Path…", command: .openPath, action: #selector(openPath(_:))))
        let newPlaylistItem = NSMenuItem(title: "Duplicate Playlist in New Tab", action: #selector(newPlaylistTab(_:)), keyEquivalent: "t")
        newPlaylistItem.keyEquivalentModifierMask = [.command]
        newPlaylistItem.target = self
        fileMenu.addItem(newPlaylistItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(menuItem("Path View", command: .sidebarPaths, action: #selector(sidebarPaths(_:))))
        viewMenu.addItem(menuItem("Console View", command: .sidebarConsoles, action: #selector(sidebarConsoles(_:))))
        viewMenu.addItem(menuItem("Disk Path…", command: .sidebarDiskPath, action: #selector(sidebarDiskPath(_:))))
        viewMenu.addItem(.separator())
        viewMenu.addItem(menuItem("Favorites Playlist", command: .favoritesPlaylist, action: #selector(favoritesPlaylist(_:))))
        viewMenu.addItem(menuItem("Playback History", command: .playbackHistory, action: #selector(playbackHistory(_:))))
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        let playbackMenuItem = NSMenuItem()
        let playbackMenu = NSMenu(title: "Playback")
        playbackMenu.addItem(menuItem("Previous", command: .previous, action: #selector(previous(_:))))
        playbackMenu.addItem(menuItem("Play/Pause", command: .playPause, action: #selector(playPause(_:))))
        playbackMenu.addItem(menuItem("Next", command: .next, action: #selector(next(_:))))
        playbackMenuItem.submenu = playbackMenu
        mainMenu.addItem(playbackMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(menuItem("Minimize", command: .minimizeWindow, action: #selector(minimizeWindow(_:))))
        windowMenu.addItem(menuItem("Close Playlist Tab", command: .closeWindow, action: #selector(closeWindow(_:))))
        windowMenu.addItem(.separator())
        for index in 1...9 {
            let tabItem = NSMenuItem(title: "Playlist \(index)", action: #selector(selectPlaylistTab(_:)), keyEquivalent: String(index))
            tabItem.keyEquivalentModifierMask = [.command, .option]
            tabItem.target = self
            tabItem.tag = index
            windowMenu.addItem(tabItem)
        }
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        let settingsMenuItem = NSMenuItem()
        let settingsMenu = NSMenu(title: "Options")
        settingsMenu.addItem(menuItem("Settings", command: .settings, action: #selector(settings(_:))))
        settingsMenuItem.submenu = settingsMenu
        mainMenu.addItem(settingsMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func menuItem(_ title: String, command: FrontendCommand, action: Selector) -> NSMenuItem {
        let shortcut = FrontendShortcutCatalog.shortcut(for: command)
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent(for: shortcut.key))
        item.keyEquivalentModifierMask = modifierFlags(for: shortcut.modifiers)
        item.target = self
        return item
    }

    private func keyEquivalent(for key: String) -> String {
        switch key {
        case "F7": return String(UnicodeScalar(0xF70A)!)
        case "F8": return String(UnicodeScalar(0xF70B)!)
        case "F9": return String(UnicodeScalar(0xF70C)!)
        default: return key
        }
    }

    private func modifierFlags(for modifiers: Set<FrontendShortcutModifier>) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }

    private func dispatch(_ command: FrontendCommand) {
        let encoded = try! JSONEncoder().encode(command.rawValue)
        let value = String(decoding: encoded, as: UTF8.self)
        webView?.evaluateJavaScript("window.ViewBoy?.dispatch(\(value));", completionHandler: nil)
    }

    private func dispatchCustom(_ command: String) {
        let encoded = try! JSONEncoder().encode(command)
        let value = String(decoding: encoded, as: UTF8.self)
        webView?.evaluateJavaScript("window.ViewBoy?.dispatch(\(value));", completionHandler: nil)
    }

    @objc private func quit(_ sender: Any?) { NSApp.terminate(sender) }
    @objc private func closeWindow(_ sender: Any?) { dispatch(.closeWindow) }
    @objc private func newPlaylistTab(_ sender: Any?) { dispatchCustom("newPlaylistTab") }
    @objc private func selectPlaylistTab(_ sender: NSMenuItem) {
        dispatchCustom("selectPlaylistTab:\(sender.tag)")
    }
    @objc private func sidebarPaths(_ sender: Any?) { dispatch(.sidebarPaths) }
    @objc private func sidebarConsoles(_ sender: Any?) { dispatch(.sidebarConsoles) }
    @objc private func sidebarDiskPath(_ sender: Any?) { dispatch(.sidebarDiskPath) }
    @objc private func favoritesPlaylist(_ sender: Any?) { dispatch(.favoritesPlaylist) }
    @objc private func playbackHistory(_ sender: Any?) { dispatch(.playbackHistory) }
    @objc private func minimizeWindow(_ sender: Any?) { (NSApp.keyWindow ?? window)?.performMiniaturize(sender) }
    @objc private func openPath(_ sender: Any?) { dispatch(.openPath) }
    @objc private func settings(_ sender: Any?) {
        dispatch(.settings)
    }
    @objc private func previous(_ sender: Any?) { dispatch(.previous) }
    @objc private func playPause(_ sender: Any?) { dispatch(.playPause) }
    @objc private func next(_ sender: Any?) { dispatch(.next) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private extension NSMenuItem {
    func configured(_ update: (NSMenuItem) -> Void) -> NSMenuItem {
        update(self)
        return self
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
