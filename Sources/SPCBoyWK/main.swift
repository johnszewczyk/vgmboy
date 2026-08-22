import AppKit
import CatalogBrowserCore
import FrontendCommandCore
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private weak var webView: WKWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        let nativeBridge = WKNativeBridge()
        configuration.userContentController.add(nativeBridge, name: "spcBoyWK")
        let initialState = CatalogBrowserState()
        let stateData = try! JSONEncoder().encode(initialState)
        let stateJSON = String(decoding: stateData, as: UTF8.self)
        configuration.userContentController.addUserScript(nativeBridge.userScript())
        configuration.userContentController.addUserScript(WKUserScript(
            source: """
            window.spcbBrowserState = \(stateJSON);
            window.SPCBoyWK = {
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
                  case "sidebarPaths": app.ui?.setSidebarMode?.("paths"); break;
                  case "sidebarConsoles": app.ui?.setSidebarMode?.("consoles"); break;
                  case "sidebarDiskPath": app.ui?.setSidebarMode?.("diskPath"); break;
                  case "settings": window.spcBoyWK?.openOptionsWindow?.(); break;
                  default: break;
                }
              }
              window.addEventListener("load", () => pending.splice(0).forEach(dispatch), { once: true });
              return { dispatch };
            }();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
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
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
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

        let sidebarMenuItem = NSMenuItem()
        let sidebarMenu = NSMenu(title: "Sidebar")
        sidebarMenu.addItem(menuItem("Paths", command: .sidebarPaths, action: #selector(sidebarPaths(_:))))
        sidebarMenu.addItem(menuItem("Consoles", command: .sidebarConsoles, action: #selector(sidebarConsoles(_:))))
        sidebarMenu.addItem(menuItem("Disk Path", command: .sidebarDiskPath, action: #selector(sidebarDiskPath(_:))))
        sidebarMenuItem.submenu = sidebarMenu
        mainMenu.addItem(sidebarMenuItem)

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
    @objc private func settings(_ sender: Any?) { dispatch(.settings) }
    @objc private func previous(_ sender: Any?) { dispatch(.previous) }
    @objc private func playPause(_ sender: Any?) { dispatch(.playPause) }
    @objc private func next(_ sender: Any?) { dispatch(.next) }

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
