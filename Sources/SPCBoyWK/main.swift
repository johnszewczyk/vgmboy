import AppKit
import FrontendCommandCore
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    private var optionsWindow: NSWindow?
    private weak var webView: WKWebView?
    private weak var optionsWebView: WKWebView?
    private var localBrowserEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "app-icon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        let nativeBridge = WKNativeBridge()
        nativeBridge.onOpenOptionsWindow = { [weak self] in self?.showOptionsWindow() }
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
        let webView = makeWebView(bridge: nativeBridge, includeCommandDispatcher: true)
        self.webView = webView
        nativeBridge.attachPlaybackEvents(to: webView)
        installApplicationMenu()
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
        if !window.setFrameAutosaveName("SPCBoyWK.Main") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        applyWindowLevels()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWebView(bridge: WKNativeBridge, includeCommandDispatcher: Bool) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(bridge, name: "spcBoyWK")
        configuration.userContentController.addUserScript(bridge.userScript())
        if includeCommandDispatcher {
            configuration.userContentController.addUserScript(WKUserScript(
                source: """
                window.SPCBoyWK = (() => {
                  const pending = [];
                  function dispatch(command) {
                    const app = window.SPCBoyApp;
                    if (!app) {
                      pending.push(command);
                      return;
                    }
                    switch (command) {
                      case "previous": app.playback?.playAdjacent(-1); break;
                      case "playPause": app.playback?.togglePlayback?.(); break;
                      case "next": app.playback?.playAdjacent(1); break;
                      case "openPath":
                        window.spcBoyWK?.choosePath?.().then((snapshot) => {
                          if (snapshot) app.ui?.applyLibrarySnapshot?.(snapshot);
                        });
                        break;
                      case "sidebarPaths": app.ui?.setSidebarMode?.("paths"); break;
                      case "sidebarConsoles": app.ui?.setSidebarMode?.("consoles"); break;
                      case "sidebarDiskPath":
                        if (app.state?.localBrowserEnabled && app.state?.rootPath) {
                          app.ui?.setSidebarMode?.("diskPath");
                        } else {
                          window.spcBoyWK?.choosePath?.().then((snapshot) => {
                            if (snapshot) app.ui?.applyLibrarySnapshot?.(snapshot);
                          });
                        }
                        break;
                      case "favoritesPlaylist": app.ui?.showFavoritesPlaylist?.(); break;
                      case "settings": window.spcBoyWK?.openOptionsWindow?.(); break;
                      default: break;
                    }
                  }
                  window.addEventListener("load", () => pending.splice(0).forEach(dispatch), { once: true });
                  return { dispatch };
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        return webView
    }

    private func showOptionsWindow() {
        if let optionsWindow {
            optionsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let bridge = WKNativeBridge(isOptionsWindow: true)
        bridge.onCloseOptionsWindow = { [weak self] in self?.closeOptionsWindow() }
        bridge.onChooseRootFolder = { [weak self] in self?.choosePath(allowFiles: false) }
        bridge.onChoosePath = { [weak self] in self?.choosePath(allowFiles: true) }
        bridge.onChooseAACExportDirectory = { [weak self] in self?.chooseDirectory(title: "Choose AAC Export Folder") }
        bridge.onAppearanceSettingsChanged = { [weak self] settings in
            self?.broadcastAppearanceSettings(settings)
        }
        bridge.onFrontendSettingsChanged = { [weak self] settings in self?.receiveFrontendSettings(settings) }
        let optionsWebView = makeWebView(bridge: bridge, includeCommandDispatcher: false)
        guard let page = Bundle.module.url(forResource: "index", withExtension: "html") else { return }
        optionsWebView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())

        let optionsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        optionsWindow.title = "SPCBoy Settings"
        optionsWindow.contentView = optionsWebView
        if !optionsWindow.setFrameAutosaveName("SPCBoyWK.Options") {
            optionsWindow.center()
        }
        optionsWindow.isReleasedWhenClosed = false
        optionsWindow.delegate = self
        self.optionsWebView = optionsWebView
        self.optionsWindow = optionsWindow
        applyWindowLevels()
        optionsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOptionsWindow() {
        optionsWindow?.close()
    }

    private func broadcastAppearanceSettings(_ settings: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(settings),
              let data = try? JSONSerialization.data(withJSONObject: settings),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = "window.__spcBoyWKEvent('appearanceSettingsChanged', \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        optionsWebView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func broadcastFrontendSettings(_ settings: SPCBoyPreferencesSnapshot) {
        guard let data = try? JSONEncoder().encode(settings),
              let json = String(data: data, encoding: .utf8) else { return }
        let script = "window.__spcBoyWKEvent('frontendSettingsChanged', \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        optionsWebView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func broadcastPlaybackEvent(name: String, payload: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8),
              let nameData = try? JSONEncoder().encode(name),
              let nameJSON = String(data: nameData, encoding: .utf8) else { return }
        let script = "window.__spcBoyWKEvent(\(nameJSON), \(json));"
        webView?.evaluateJavaScript(script, completionHandler: nil)
        optionsWebView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func receiveFrontendSettings(_ settings: SPCBoyPreferencesSnapshot) {
        localBrowserEnabled = settings.localBrowserEnabled ?? false
        if let value = settings.mainWindowAlwaysOnTop {
            window?.level = value ? .floating : .normal
        }
        if let value = settings.settingsWindowAlwaysOnTop {
            optionsWindow?.level = value ? .floating : .normal
        }
        NSApp.mainMenu?.update()
        broadcastFrontendSettings(settings)
    }

    private func applyWindowLevels() {
        guard let data = UserDefaults.standard.data(forKey: "SPCBoyWK.frontendPreferencesV2"),
              let snapshot = try? JSONDecoder().decode(SPCBoyPreferencesSnapshot.self, from: data) else {
            window?.level = .normal
            optionsWindow?.level = .normal
            return
        }
        window?.level = snapshot.mainWindowAlwaysOnTop == true ? .floating : .normal
        optionsWindow?.level = snapshot.settingsWindowAlwaysOnTop == true ? .floating : .normal
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
        let appMenu = NSMenu(title: "SPCBoy")
        appMenu.addItem(NSMenuItem(title: "About SPCBoy", action: nil, keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide SPCBoy", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").configured { $0.keyEquivalentModifierMask = [.command, .option] })
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "").configured { $0.keyEquivalentModifierMask = [.command, .option] })
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Quit SPCBoy", command: .quit, action: #selector(quit(_:))))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(menuItem("Open Path…", command: .openPath, action: #selector(openPath(_:))))
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(menuItem(FrontendSidebarView.consoles.title, command: .sidebarConsoles, action: #selector(sidebarConsoles(_:))))
        viewMenu.addItem(menuItem(FrontendSidebarView.paths.title, command: .sidebarPaths, action: #selector(sidebarPaths(_:))))
        viewMenu.addItem(menuItem("Favorites Playlist", command: .favoritesPlaylist, action: #selector(favoritesPlaylist(_:))))
        viewMenu.addItem(.separator())
        viewMenu.addItem(menuItem("Local Files", command: .sidebarDiskPath, action: #selector(sidebarDiskPath(_:))))
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
        windowMenu.addItem(menuItem("Close Window", command: .closeWindow, action: #selector(closeWindow(_:))))
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
        webView?.evaluateJavaScript("window.SPCBoyWK?.dispatch(\(value));", completionHandler: nil)
    }

    @objc private func quit(_ sender: Any?) { NSApp.terminate(sender) }
    @objc private func closeWindow(_ sender: Any?) { (NSApp.keyWindow ?? window)?.performClose(sender) }
    @objc private func minimizeWindow(_ sender: Any?) { (NSApp.keyWindow ?? window)?.performMiniaturize(sender) }
    @objc private func openPath(_ sender: Any?) { dispatch(.openPath) }
    @objc private func sidebarPaths(_ sender: Any?) { dispatch(.sidebarPaths) }
    @objc private func sidebarConsoles(_ sender: Any?) { dispatch(.sidebarConsoles) }
    @objc private func sidebarDiskPath(_ sender: Any?) { dispatch(.sidebarDiskPath) }
    @objc private func favoritesPlaylist(_ sender: Any?) { dispatch(.favoritesPlaylist) }
    @objc private func settings(_ sender: Any?) {
        showOptionsWindow()
    }
    @objc private func previous(_ sender: Any?) { dispatch(.previous) }
    @objc private func playPause(_ sender: Any?) { dispatch(.playPause) }
    @objc private func next(_ sender: Any?) { dispatch(.next) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(sidebarConsoles(_:))
                || menuItem.action == #selector(sidebarPaths(_:)) else { return true }
        return !localBrowserEnabled
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow, closingWindow === optionsWindow else { return }
        optionsWebView?.configuration.userContentController.removeAllUserScripts()
        optionsWebView = nil
        optionsWindow = nil
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
