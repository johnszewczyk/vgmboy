import AppKit
import CatalogReader
import SwiftUI

struct GalleryView: View {
    @Bindable var model: PlayerViewModel

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 10)]

    var body: some View {
        let visibleGames = model.visibleGalleryGames
        Group {
            if model.galleryIsLoading {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading artwork index…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.galleryLoadError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Retry") { model.retryGalleryLoad() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else if visibleGames.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(!model.galleryHasLoaded
                        ? "Gallery waits for startup to finish."
                        : model.galleryGames.isEmpty
                            ? "No indexed Title Snap artwork was found."
                            : "No artwork titles match the current console selection.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleGames) { game in
                            GalleryArtworkTile(
                                game: game,
                                isSelected: model.selectedGalleryGameID == game.id,
                                select: { model.selectGalleryGame(game) },
                                play: { model.playGalleryGame(game) }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct GalleryArtworkTile: View {
    let game: CatalogGalleryGame
    let isSelected: Bool
    let select: () -> Void
    let play: () -> Void

    @State private var artwork: NSImage?

    var body: some View {
        Button(action: select) {
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    if let artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                        Image(systemName: "music.note")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.78)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(game.game)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                        if !game.system.isEmpty {
                            Text(game.system)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.09), lineWidth: isSelected ? 2 : 1)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(game.game)\(game.system.isEmpty ? "" : " • \(game.system)") — double-click to play")
        .simultaneousGesture(TapGesture(count: 2).onEnded { play() })
        .contextMenu {
            Button("Play Now", systemImage: "play.fill", action: play)
        }
        .task(id: game.id) {
            await loadArtworkIfNeeded()
        }
    }

    @MainActor
    private func loadArtworkIfNeeded() async {
        if let cached = GalleryArtworkMemoryCache.images.object(forKey: game.id as NSString) {
            artwork = cached
            return
        }
        await GalleryArtworkLoadGate.shared.acquire()
        guard !Task.isCancelled else {
            await GalleryArtworkLoadGate.shared.release()
            return
        }
        let game = game
        let data = await Task.detached(priority: .utility) {
            try? CocoaSpiceGalleryArtwork.thumbnailPNG(for: game)
        }.value
        await GalleryArtworkLoadGate.shared.release()
        guard !Task.isCancelled, let data, let image = NSImage(data: data) else { return }
        let decodedCost = Int(image.size.width * image.size.height * 4)
        GalleryArtworkMemoryCache.images.setObject(
            image,
            forKey: game.id as NSString,
            cost: max(data.count, decodedCost)
        )
        artwork = image
    }
}

private actor GalleryArtworkLoadGate {
    static let shared = GalleryArtworkLoadGate()

    private var availableSlots = 3
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if availableSlots > 0 {
            availableSlots -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            availableSlots += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

@MainActor
private enum GalleryArtworkMemoryCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 48
        cache.totalCostLimit = 64 * 1_024 * 1_024
        return cache
    }()
}
