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
    var diagnostics = PlaybackDiagnostics()

    var longPlayEnabled = false
    var manualSeconds = 60
    var fadeSeconds = 6
    var tempo = 1.0
    var equalizerEnabled = true
    var equalizerBandGains = Array(repeating: Float.zero, count: EqualizerConfiguration.bandCount)

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
        applyEqualizer()
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

    func setEqualizerEnabled(_ enabled: Bool) {
        equalizerEnabled = enabled
        applyEqualizer()
    }

    func setEqualizerBandGain(_ gain: Float, at index: Int) {
        guard equalizerBandGains.indices.contains(index) else { return }
        equalizerBandGains[index] = min(
            EqualizerConfiguration.gainRange.upperBound,
            max(EqualizerConfiguration.gainRange.lowerBound, gain)
        )
        applyEqualizer()
    }

    func resetEqualizer() {
        equalizerBandGains = Array(repeating: 0, count: EqualizerConfiguration.bandCount)
        applyEqualizer()
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
            fadeSeconds: fadeSeconds,
            hasNaturalEnding: family?.hasNaturalEnding ?? true
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
        diagnostics = status.diagnostics
    }

    private func applyEqualizer() {
        do {
            try session.setEqualizer(.init(enabled: equalizerEnabled, gainsDecibels: equalizerBandGains))
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
