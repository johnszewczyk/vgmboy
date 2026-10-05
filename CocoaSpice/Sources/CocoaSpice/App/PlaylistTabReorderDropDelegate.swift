import SwiftUI

@MainActor
struct PlaylistTabReorderDropDelegate: DropDelegate {
    let destinationTabID: String
    @Binding var draggedTabID: String?
    let model: PlayerViewModel
    let animationDuration: Double

    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedTabID else { return false }
        return draggedTabID != destinationTabID
            && model.playlistTabs.contains(where: { $0.id == draggedTabID })
            && model.playlistTabs.contains(where: { $0.id == destinationTabID })
    }

    func dropEntered(info: DropInfo) {
        guard let draggedTabID,
              let destinationIndex = model.playlistTabs.firstIndex(where: { $0.id == destinationTabID }),
              model.playlistTabs.firstIndex(where: { $0.id == draggedTabID }) != destinationIndex else { return }
        let animation = animationDuration > 0
            ? Animation.easeInOut(duration: animationDuration)
            : Animation.linear(duration: 0.001)
        withAnimation(animation) {
            model.movePlaylistTab(draggedTabID, toIndex: destinationIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTabID = nil
        return true
    }
}
