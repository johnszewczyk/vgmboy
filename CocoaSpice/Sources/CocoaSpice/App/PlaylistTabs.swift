import Foundation

struct CocoaSpicePlaylistTab: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var tracks: [TrackItem]
    var selectedTrackID: String?
    var selectedTrackIDs: Set<String>

    init(
        id: String = UUID().uuidString,
        title: String = "Playlist",
        tracks: [TrackItem] = [],
        selectedTrackID: String? = nil,
        selectedTrackIDs: Set<String> = []
    ) {
        self.id = id
        self.title = title
        self.tracks = tracks
        self.selectedTrackID = selectedTrackID
        self.selectedTrackIDs = selectedTrackIDs
    }
}

struct CocoaSpicePlaylistTabsSnapshot: Sendable {
    var tabs: [CocoaSpicePlaylistTab]
    var activeTabID: String
}

@MainActor
enum CocoaSpicePlaylistTabsStore {
    private static let maximumFileSize = 256 * 1_024 * 1_024
    private static let maximumTabCount = 64

    private struct Payload: Codable {
        var version: Int
        var activeTabID: String
        var tabs: [TabRecord]
    }

    private struct TabRecord: Codable {
        var id: String
        var title: String
        var tracks: [String]
        var selectedTrackID: String?
        var selectedTrackIDs: [String]
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CocoaSpice", isDirectory: true)
            .appendingPathComponent("playlist-tabs-v1.json")
    }

    static func load(supportedExtensions: Set<String>) -> CocoaSpicePlaylistTabsSnapshot? {
        do {
            let url = fileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? NSNumber,
                  size.intValue <= maximumFileSize else { return nil }
            let payload = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: url))
            guard payload.version == 1,
                  !payload.tabs.isEmpty,
                  payload.tabs.count <= maximumTabCount,
                  payload.tabs.contains(where: { $0.id == payload.activeTabID }),
                  Set(payload.tabs.map(\.id)).count == payload.tabs.count else { return nil }

            let tabs = payload.tabs.map { record in
                let tracks = record.tracks.compactMap(TrackItem.fromPersistedValue)
                    .filter { supportedExtensions.contains($0.playablePathExtension) }
                let trackIDs = Set(tracks.map(\.id))
                let selectedID = record.selectedTrackID.flatMap { trackIDs.contains($0) ? $0 : nil }
                return CocoaSpicePlaylistTab(
                    id: record.id,
                    title: String(record.title.prefix(120)),
                    tracks: tracks,
                    selectedTrackID: selectedID,
                    selectedTrackIDs: Set(record.selectedTrackIDs.filter(trackIDs.contains))
                )
            }
            return CocoaSpicePlaylistTabsSnapshot(tabs: tabs, activeTabID: payload.activeTabID)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: CocoaSpicePlaylistTabsSnapshot) {
        guard !snapshot.tabs.isEmpty,
              snapshot.tabs.count <= maximumTabCount,
              snapshot.tabs.contains(where: { $0.id == snapshot.activeTabID }) else { return }
        let payload = Payload(
            version: 1,
            activeTabID: snapshot.activeTabID,
            tabs: snapshot.tabs.map { tab in
                TabRecord(
                    id: tab.id,
                    title: String(tab.title.prefix(120)),
                    tracks: tab.tracks.map(\.persistedValue),
                    selectedTrackID: tab.selectedTrackID,
                    selectedTrackIDs: tab.selectedTrackIDs.sorted()
                )
            }
        )
        do {
            let data = try JSONEncoder().encode(payload)
            guard data.count <= maximumFileSize else { return }
            let url = fileURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }
}
