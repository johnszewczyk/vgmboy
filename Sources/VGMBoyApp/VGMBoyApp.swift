import SwiftUI

@main
struct VGMBoyApp: App {
    @State private var model = PlayerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}