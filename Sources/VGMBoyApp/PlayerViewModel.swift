import AppKit
import Observation
import VGMBoyKit

@MainActor
@Observable
final class PlayerViewModel {
    var filePath: String?
    var systemName = ""
    var trackCount = 0
    var tracks: [TrackMetadata] = []
    var selectedTrack = 0
    var currentSong: TrackMetadata?

    var isPlaying = false
    var reachedEnd = false
    var elapsedSeconds = 0.0
    var errorMessage: String?

    var longPlayEnabled = false
    var manualSeconds = 60
    var fadeSeconds = 6
    var tempo = 1.0

    private let session = PlaybackSession()

    var displayDuration: Double {
        guard filePath != nil else { return 0 }
        if longPlayEnabled, let family = currentFamily, family.supportsLongPlay {
            return Double(manualSeconds + fadeSeconds)
        }
        if let song = currentSong {
            let play = Double(song.playMs > 0 ? song.playMs : 0) / 1000.0
            let introLoop = Double(max(song.introMs + song.loopMs, song.loopMs)) / 1000.0
            let base = max(play, introLoop)
            return base > 0 ? base + Double(fadeSeconds) : 150 + Double(fadeSeconds)
        }
        return 150 + Double(fadeSeconds)
    }

    private var currentFamily: DecoderFamily? {
        filePath.flatMap(FormatRegistry.family)
    }

    init() {
        session.setStatusHandler { [weak self] status in
            Task { @MainActor in
                self?.apply(status)
            }
        }
        session.setCompletionHandler { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(fileURL: url)
    }

    func load(fileURL: URL) {
        let path = fileURL.path
        guard FormatRegistry.family(for: path) != nil else {
            errorMessage = "Unsupported format: \(path)"
            return
        }
        do {
            let inspection = try AudioInspector.inspect(path: path)
            filePath = path
            systemName = inspection.system
            trackCount = inspection.trackCount
            tracks = inspection.tracks
            selectedTrack = 0
            errorMessage = nil
            loadSelectedTrack()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectTrack(_ index: Int) {
        guard index != selectedTrack else { return }
        selectedTrack = index
        loadSelectedTrack()
    }

    func togglePlay() {
        do {
            if isPlaying {
                session.pause()
                isPlaying = false
            } else {
                try session.play()
                isPlaying = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        session.stop()
        isPlaying = false
        elapsedSeconds = 0
        reachedEnd = false
    }

    func seek(to seconds: Double) {
        do {
            try session.seek(to: seconds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyTimingChange() {
        guard filePath != nil else { return }
        let resumeAt = elapsedSeconds
        loadSelectedTrack(resumeAt: resumeAt)
    }

    private func loadSelectedTrack(resumeAt seconds: Double = 0) {
        guard let filePath else { return }
        let metadata = selectedTrack < tracks.count ? tracks[selectedTrack] : nil
        let family = currentFamily
        let plan = TimingPolicy.plan(
            supportsLongPlay: family?.supportsLongPlay ?? false,
            metadata: metadata,
            longPlayEnabled: longPlayEnabled,
            manualSeconds: manualSeconds,
            fadeSeconds: fadeSeconds
        )
        do {
            let loaded = try session.load(path: filePath, trackIndex: selectedTrack, plan: plan, tempo: tempo)
            currentSong = loaded
            if seconds > 0 {
                try session.seek(to: seconds)
            }
            try session.play()
            isPlaying = true
            reachedEnd = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ status: PlaybackStatus) {
        isPlaying = status.isPlaying
        elapsedSeconds = status.elapsedSeconds
        reachedEnd = status.reachedEnd
    }
}