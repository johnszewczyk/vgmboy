import AppKit
import Foundation
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var directory: MarkdownDirectory?
    private var watcher: MarkdownDirectoryWatcher?
    private var pendingRefresh: DispatchWorkItem?
    private var closeWindowMenuItem: NSMenuItem?
    private var minimizeWindowMenuItem: NSMenuItem?
    private var zoomWindowMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSWindow.allowsAutomaticWindowTabbing = false
        installMainMenu()

        do {
            let projectRoot = try locateProjectRoot()
            let directory = try MarkdownDirectory(projectRoot: projectRoot)
            self.directory = directory
            installWatcher(root: directory.markdownRoot)
            createWindow(projectRoot: projectRoot)
        } catch {
            FileHandle.standardError.write(Data("VGMManDocs startup error: \(error.localizedDescription)\n".utf8))
            showStartupError(error)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: "About VGMManDocs",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit VGMManDocs",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "File")
        let closeItem = NSMenuItem(
            title: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeWindowMenuItem = closeItem
        fileMenu.addItem(closeItem)
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z"))
        editMenu.items.last?.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        let windowMenuItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "Window")
        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        )
        minimizeWindowMenuItem = minimizeItem
        windowMenu.addItem(minimizeItem)
        let zoomItem = NSMenuItem(
            title: "Zoom",
            action: #selector(NSWindow.zoom(_:)),
            keyEquivalent: "\r"
        )
        zoomItem.keyEquivalentModifierMask = [.command]
        zoomWindowMenuItem = zoomItem
        windowMenu.addItem(zoomItem)
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let request = message.body as? [String: Any],
              let identifier = request["id"] as? String,
              let method = request["method"] as? String,
              let directory else { return }
        do {
            let result: Any
            switch method {
            case "list":
                result = try listPayload(using: directory)
            case "read":
                result = try directory.read(path: requiredString("path", from: request))
            case "save":
                result = try directory.save(
                    path: requiredString("path", from: request),
                    markdown: requiredString("markdown", from: request),
                    expectedVersion: requiredString("expectedVersion", from: request)
                )
            case "create":
                result = try directory.create(
                    path: requiredString("path", from: request),
                    markdown: requiredString("markdown", from: request)
                )
            case "openExternal":
                result = try openExternal(requiredString("url", from: request))
            case "openLocal":
                result = try openLocal(requiredString("url", from: request), directory: directory)
            default:
                throw BridgeError.unknownMethod(method)
            }
            send(["id": identifier, "ok": true, "value": result])
        } catch {
            send(["id": identifier, "ok": false, "error": error.localizedDescription])
        }
    }

    private func createWindow(projectRoot: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "vgmManDocs")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.underPageBackgroundColor = NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.078, alpha: 1)
        self.webView = view

        guard let page = Bundle.module.url(forResource: "index", withExtension: "html") else {
            showStartupError(BridgeError.missingPage)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        closeWindowMenuItem?.target = window
        minimizeWindowMenuItem?.target = window
        zoomWindowMenuItem?.target = window
        window.title = "VGMManDocs"
        window.minSize = NSSize(width: 820, height: 560)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.078, alpha: 1)
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        view.loadFileURL(page, allowingReadAccessTo: projectRoot)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func locateProjectRoot() throws -> URL {
        var candidate = Bundle.main.bundleURL.standardizedFileURL
        for _ in 0..<8 {
            candidate = candidate.deletingLastPathComponent()
            let package = candidate.appendingPathComponent("Package.swift")
            if candidate.lastPathComponent == "VGMManDocs",
               FileManager.default.fileExists(atPath: package.path) {
                return candidate
            }
        }
        throw BridgeError.projectRootNotFound
    }

    private func installWatcher(root: URL) {
        watcher = MarkdownDirectoryWatcher(root: root) { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.scheduleRefresh() }
        }
        watcher?.start()
    }

    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.webView?.evaluateJavaScript("window.VGMManDocs?.refreshFromDisk()")
        }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func listPayload(using directory: MarkdownDirectory) throws -> [String: Any] {
        let docs = try directory.documents().map { ["path": $0.path, "title": $0.title] }
        return [
            "documents": docs,
            "projectRootURL": directory.projectRootFileURL,
            "markdownRootURL": directory.markdownRootFileURL
        ]
    }

    private func requiredString(_ key: String, from request: [String: Any]) throws -> String {
        guard let value = request[key] as? String else { throw BridgeError.missingField(key) }
        return value
    }

    private func openExternal(_ rawURL: String) throws -> Bool {
        guard let url = URL(string: rawURL),
              ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
            throw BridgeError.unsafeExternalURL
        }
        return NSWorkspace.shared.open(url)
    }

    private func openLocal(_ rawURL: String, directory: MarkdownDirectory) throws -> Bool {
        guard let url = URL(string: rawURL), url.isFileURL else { throw BridgeError.unsafeLocalURL }
        let root = URL(fileURLWithPath: directory.projectRootPath, isDirectory: true)
            .resolvingSymlinksInPath().standardizedFileURL.path
        let target = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard target.hasPrefix(root + "/") else { throw BridgeError.unsafeLocalURL }
        return NSWorkspace.shared.open(url)
    }

    private func send(_ payload: [String: Any]) {
        guard let webView,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.VGMManDocs?._receive(\(json))")
    }

    private func showStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "VGMManDocs could not start"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }
}

enum BridgeError: LocalizedError {
    case missingPage
    case projectRootNotFound
    case missingField(String)
    case unknownMethod(String)
    case unsafeExternalURL
    case unsafeLocalURL

    var errorDescription: String? {
        switch self {
        case .missingPage: "The packaged viewer page is missing. Rebuild VGMManDocs."
        case .projectRootNotFound: "The VGMManDocs project folder could not be located next to the app bundle."
        case .missingField(let key): "The viewer request is missing its \(key) value."
        case .unknownMethod(let method): "The viewer request is not supported: \(method)"
        case .unsafeExternalURL: "Only web and email links can be opened outside VGMManDocs."
        case .unsafeLocalURL: "This local link points outside the VGMMan repository."
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.run()
