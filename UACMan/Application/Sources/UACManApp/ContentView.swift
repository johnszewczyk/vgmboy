import SwiftUI

struct ContentView: View {
    @Bindable var model: UACManModel

    var body: some View {
        UACManWebWorkspace(model: model, snapshot: model.webSnapshot)
            .frame(minWidth: 920, minHeight: 600)
            .toolbar(.hidden, for: .windowToolbar)
    }
}
