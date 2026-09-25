import SwiftUI

struct ContentView: View {
    @Bindable var model: UACManModel

    var body: some View {
        UACManWebWorkspace(model: model, snapshot: model.webSnapshot)
            .frame(minWidth: 640, minHeight: 480)
    }
}
