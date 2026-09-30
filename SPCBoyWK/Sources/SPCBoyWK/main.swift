import AppKit
import FrontendCommandCore
import MediaPlayer
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var window: NSWindow?
    private var optionsWindow: NSWindow?
    private weak var webView: WKWebView?
    private weak var optionsWebView: WKWebView?
    private weak var closePlaylistMenuItem: NSMenuItem?
    private var playlistTabShortcutMonitor: Any?
    private var mediaKeyMonitor: Any?
    private var remoteTransportController: FocusedMediaTransportController?
    private enum TransportInputSource: Equatable {
        case focusedMediaKey
        case remoteCommand
    }
    private struct PendingRemoteTransportInput {
        let token: UUID
        let task: Task<Void, Never>
    }
    private var recentFocusedTransportInputs: [String: TimeInterval] = [:]
    private var pendingRemoteTransportInputs: [String: PendingRemoteTransportInput] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        if let iconURL = Bundle.main.url(forResource: "app-icon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        let nativeBridge = WKNativeBridge()
        nativeBridge.onOpenOptionsWindow = { [weak self] in self?.showOptionsWindow() }
        nativeBridge.onCloseMainWindow = { [weak self] in self?.window?.performClose(nil) }
        nativeBridge.onChooseAACExportDirectory = { [weak self] in self?.chooseDirectory(title: "Choose AAC Export Folder") }
        nativeBridge.onAppearanceSettingsChanged = { [weak self] settings in
            self?.broadcastAppearanceSettings(settings)
        }
        nativeBridge.onFrontendSettingsChanged = { [weak self] settings in self?.receiveFrontendSettings(settings) }
        nativeBridge.onFrontendEqualizerSettingsChanged = { [weak self] settings in
            self?.broadcastFrontendEqualizerSettings(settings)
        }
        let remoteTransport = FocusedMediaTransportController { [weak self] command in
            self?.dispatchTransportCommand(command, source: .remoteCommand)
        }
        remoteTransport.configure()
        remoteTransportController = remoteTransport
        nativeBridge.onNowPlayingInfoChanged = { [weak remoteTransport] nowPlaying in
            remoteTransport?.updateNowPlaying(nowPlaying)
        }
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
        window.tabbingMode = .disallowed
        window.contentView = webView
        window.delegate = self
        if !window.setFrameAutosaveName("SPCBoyWK.Main") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        playlistTabShortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  NSApp.keyWindow === self.window,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  let character = event.charactersIgnoringModifiers,
                  let digit = character.first?.wholeNumberValue,
                  (1...9).contains(digit) else {
                return event
            }
            self.dispatchCustom("selectPlaylistTab:\(digit)")
            return nil
        }
        mediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.systemDefined]) { [weak self] event in
            guard let self,
                  NSApp.isActive,
                  event.type == .systemDefined,
                  event.subtype.rawValue == 8 else {
                return event
            }

            let keyCode = (event.data1 & 0xFFFF0000) >> 16
            let keyState = (event.data1 & 0x0000FF00) >> 8
            let command: String
            switch keyCode {
            case 18: command = "previous"
            case 16: command = "playPause"
            case 17: command = "next"
            default: return event
            }

            if keyState == 0xA {
                self.dispatchTransportCommand(command, source: .focusedMediaKey)
            }
            // Consume both press and release while SPCBoy is active so the
            // system does not hand the same transport key to Music.
            return nil
        }
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
                  let playbackCommandQueue = Promise.resolve();
                  function playbackIsPlaying(app) {
                    const transportState = app.state?.nativePlayback?.transportState;
                    return typeof transportState === "string"
                      ? transportState === "playing"
                      : Boolean(app.state?.isPlaying);
                  }
                  function dispatchPlaybackCommand(app, command) {
                    const operation = playbackCommandQueue.catch(() => {}).then(async () => {
                      const isPlaying = playbackIsPlaying(app);
                      if (command === "playPause"
                          || (command === "play" && !isPlaying)
                          || (command === "pause" && isPlaying)) {
                        await app.playback?.togglePlayback?.();
                      }
                    });
                    playbackCommandQueue = operation.catch((error) => {
                      console.error("[SPCBoy] transport command failed", error);
                    });
                  }
                  function dispatch(command) {
                    const app = window.SPCBoyApp;
                    if (!app) {
                      pending.push(command);
                      return;
                    }
                    const playlistTabPrefix = "selectPlaylistTab:";
                    if (command.startsWith(playlistTabPrefix)) {
                      const index = Number(command.slice(playlistTabPrefix.length)) - 1;
                      app.ui?.activatePlaylistTabAtIndex?.(index);
                      return;
                    }
                    switch (command) {
                      case "previous": app.playback?.playAdjacent(-1); break;
                      case "play": dispatchPlaybackCommand(app, "play"); break;
                      case "pause": dispatchPlaybackCommand(app, "pause"); break;
                      case "playPause": dispatchPlaybackCommand(app, "playPause"); break;
                      case "next": app.playback?.playAdjacent(1); break;
                      case "newPlaylistTab": app.ui?.createPlaylistTab?.({ duplicateActive: true }); break;
                      case "closePlaylistTab": app.ui?.closePlaylistTab?.(); break;
                      case "sidebarPaths": app.ui?.setSidebarMode?.("paths"); break;
                      case "sidebarConsoles": app.ui?.setSidebarMode?.("consoles"); break;
                      case "favoritesPlaylist": app.ui?.showFavoritesPlaylist?.(); break;
                      case "playbackHistory": app.ui?.showPlaybackHistory?.(); break;
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
        bridge.onChooseAACExportDirectory = { [weak self] in self?.chooseDirectory(title: "Choose AAC Export Folder") }
        bridge.onAppearanceSettingsChanged = { [weak self] settings in
            self?.broadcastAppearanceSettings(settings)
        }
        bridge.onFrontendSettingsChanged = { [weak self] settings in self?.receiveFrontendSettings(settings) }
        bridge.onFrontendEqualizerSettingsChanged = { [weak self] settings in
            self?.broadcastFrontendEqualizerSettings(settings)
        }
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
        optionsWindow.tabbingMode = .disallowed
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

    private func broadcastFrontendEqualizerSettings(_ settings: SPCBoyEqualizerPreferencesPatch) {
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
        let newPlaylistItem = NSMenuItem(title: "Duplicate Playlist in New Tab", action: #selector(newPlaylistTab(_:)), keyEquivalent: "t")
        newPlaylistItem.keyEquivalentModifierMask = [.command]
        newPlaylistItem.target = self
        fileMenu.addItem(newPlaylistItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(menuItem("Console View", command: .sidebarConsoles, action: #selector(sidebarConsoles(_:))))
        viewMenu.addItem(menuItem("Path View", command: .sidebarPaths, action: #selector(sidebarPaths(_:))))
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
        let closeItem = menuItem("Close Playlist Tab", command: .closeWindow, action: #selector(closeWindow(_:)))
        closePlaylistMenuItem = closeItem
        windowMenu.addItem(closeItem)
        windowMenu.addItem(.separator())
        for index in 1...9 {
            let tabItem = NSMenuItem(title: "Playlist \(index)", action: #selector(selectPlaylistTab(_:)), keyEquivalent: String(index))
            tabItem.keyEquivalentModifierMask = [.command]
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
        webView?.evaluateJavaScript("window.SPCBoyWK?.dispatch(\(value));", completionHandler: nil)
    }

    @objc private func quit(_ sender: Any?) { NSApp.terminate(sender) }
    @objc private func closeWindow(_ sender: Any?) {
        let target = NSApp.keyWindow ?? window
        guard let target else { return }
        if target === window {
            dispatchClosePlaylistTab()
        } else {
            target.performClose(sender)
        }
    }
    @objc private func minimizeWindow(_ sender: Any?) { (NSApp.keyWindow ?? window)?.performMiniaturize(sender) }
    @objc private func favoritesPlaylist(_ sender: Any?) { dispatch(.favoritesPlaylist) }
    @objc private func playbackHistory(_ sender: Any?) { dispatch(.playbackHistory) }
    @objc private func sidebarPaths(_ sender: Any?) { dispatch(.sidebarPaths) }
    @objc private func sidebarConsoles(_ sender: Any?) { dispatch(.sidebarConsoles) }
    @objc private func settings(_ sender: Any?) {
        showOptionsWindow()
    }
    @objc private func previous(_ sender: Any?) { dispatch(.previous) }
    @objc private func playPause(_ sender: Any?) { dispatch(.playPause) }
    @objc private func next(_ sender: Any?) { dispatch(.next) }
    @objc private func newPlaylistTab(_ sender: Any?) { dispatchCustom("newPlaylistTab") }
    @objc private func selectPlaylistTab(_ sender: NSMenuItem) {
        dispatchCustom("selectPlaylistTab:\(sender.tag)")
    }

    private func dispatchClosePlaylistTab() {
        dispatchCustom("closePlaylistTab")
    }

    private func dispatchCustom(_ command: String) {
        let encoded = try! JSONEncoder().encode(command)
        webView?.evaluateJavaScript("window.SPCBoyWK?.dispatch(\(String(decoding: encoded, as: UTF8.self)));", completionHandler: nil)
    }

    private func dispatchTransportCommand(_ command: String, source: TransportInputSource) {
        let action: String
        switch command {
        case "previous": action = "previous"
        case "play", "pause", "playPause": action = "playPause"
        case "next": action = "next"
        default:
            dispatchCustom(command)
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if source == .focusedMediaKey {
            pendingRemoteTransportInputs.removeValue(forKey: action)?.task.cancel()
            recentFocusedTransportInputs[action] = now
            dispatchCustom(command)
            return
        }

        if let focusedTimestamp = recentFocusedTransportInputs[action] {
            if now >= focusedTimestamp, now - focusedTimestamp <= 0.15 {
                recentFocusedTransportInputs.removeValue(forKey: action)
                return
            }
            recentFocusedTransportInputs.removeValue(forKey: action)
        }

        if NSApp.isActive {
            guard pendingRemoteTransportInputs[action] == nil else { return }
            let token = UUID()
            let task = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
                guard let self,
                      self.pendingRemoteTransportInputs[action]?.token == token else { return }
                self.pendingRemoteTransportInputs.removeValue(forKey: action)
                self.dispatchCustom(command)
            }
            pendingRemoteTransportInputs[action] = PendingRemoteTransportInput(token: token, task: task)
            return
        }

        dispatchCustom(command)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(closeWindow(_:)) {
            menuItem.title = NSApp.keyWindow === window ? "Close Playlist Tab" : "Close Window"
            return true
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let playlistTabShortcutMonitor { NSEvent.removeMonitor(playlistTabShortcutMonitor) }
        if let mediaKeyMonitor { NSEvent.removeMonitor(mediaKeyMonitor) }
        playlistTabShortcutMonitor = nil
        mediaKeyMonitor = nil
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        NSApp.mainMenu?.update()
    }

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
