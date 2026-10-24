import SwiftUI

@main
struct VGMBoyApp: App {
    @State private var model = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1060, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Audio Files…", action: model.openDocument).keyboardShortcut("o")
            }
            CommandMenu("Playback") {
                Button("Play / Pause", action: model.togglePlay).keyboardShortcut(.space, modifiers: [])
                Button("Stop", action: model.stop).keyboardShortcut(".", modifiers: .command)
            }
        }
    }
}