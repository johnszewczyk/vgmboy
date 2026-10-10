import AppKit
import Darwin
import Dispatch
import Foundation
import SwiftUI

@MainActor
final class ScanSongApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: ScanSongApplicationDelegate?
    weak var scannerModel: ScannerAppModel?
    private var terminationSignal: DispatchSourceSignal?
    private var terminationWasSignalled = false

    override init() {
        super.init()
        Self.shared = self

        // launch.sh uses SIGTERM to retire the previous development build.
        // Ignore the default abrupt signal action and route it through the same
        // cooperative close path used by the native UI.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self, !self.terminationWasSignalled else { return }
                self.terminationWasSignalled = true
                NSApplication.shared.terminate(nil)
            }
        }
        source.resume()
        terminationSignal = source
    }

    deinit {
        terminationSignal?.cancel()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = scannerModel, model.isBusy else { return .terminateNow }

        if terminationWasSignalled {
            model.closeWhenWorkIsSafe { sender.reply(toApplicationShouldTerminate: true) }
            return .terminateLater
        }

        let alert = NSAlert()
        if model.isScanning {
            alert.messageText = "Scan in Progress"
            alert.informativeText = "Cancel the scan and quit after completed checkpoints are safely retained?"
            alert.addButton(withTitle: "Keep Scanning")
            alert.addButton(withTitle: "Cancel Scan and Quit")
        } else {
            alert.messageText = "Catalog Operation in Progress"
            alert.informativeText = "Quit after the current database operation has finished?"
            alert.addButton(withTitle: "Keep Working")
            alert.addButton(withTitle: "Quit When Finished")
        }
        guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        model.closeWhenWorkIsSafe { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

@main
struct ScanSongApplication: App {
    @NSApplicationDelegateAdaptor(ScanSongApplicationDelegate.self) private var applicationDelegate
    @StateObject private var model = ScannerAppModel()

    init() {
        if let iconURL = Bundle.main.url(forResource: "app-icon", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("ScanSong") { ScannerWindow(model: model) }
            .defaultSize(width: 840, height: 700)
            .commands {
                ScannerCommands()
            }

        Window("Options", id: "options") {
            ScannerOptionsView(model: model)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 720, height: 520)
        .windowResizability(.contentMinSize)
    }
}

private struct ScannerCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Options…") {
                openWindow(id: "options")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
