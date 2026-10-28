import AppKit
import SwiftUI

@main
struct VGMBoyApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @State private var model = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Audio Files…", action: model.openDocument).keyboardShortcut("o")
            }
            CommandMenu("Playback") {
                Button("Play / Pause", action: model.togglePlay).keyboardShortcut(.space, modifiers: [])
                Button("Stop", action: model.stop).keyboardShortcut(".", modifiers: .command)
            }
        }
    }

}

@MainActor
private final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "app-icon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
    }
}
