import SwiftUI

@main
struct UACManApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var model = UACManModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear { model.openCommandLineFileIfPresent() }
                .onOpenURL { model.openDocument($0) }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Options…") {
                    openWindow(id: "options")
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .newItem) {
                Button("Open UAC…", action: model.openPanel)
                    .keyboardShortcut("o")
                Button("Open Collection…", action: model.openCollectionPanel)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Save UAC Metadata", action: model.save)
                    .keyboardShortcut("s")
                    .disabled(!model.hasUnsavedChanges)
                Button("Revert Metadata", action: model.revert)
                    .disabled(!model.hasUnsavedChanges)
            }
        }

        Window("Options", id: "options") {
            UACManOptionsView(model: model)
        }
        .defaultSize(width: 720, height: 760)
    }
}
