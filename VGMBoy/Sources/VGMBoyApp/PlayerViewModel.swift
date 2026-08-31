import AppKit
import Observation
import VGMBoyKit

@MainActor
@Observable
final class PlayerViewModel {
    var filePath: String?
    var selectedTrack = 0

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

    private let controller = PlaybackController()

    var displayDuration: Double {
        guard filePath != nil else { return 0 }
        if longPlayEnabled, let family = currentFamily, family.supportsLongPlay {
            return Double(manualSeconds + fadeSeconds)
        }
        return 150 + Double(fadeSeconds)
    }

    private var currentFamily: DecoderFamily? {
        filePath.flatMap(FormatRegistry.family)
    }

    init() {
        _ = controller.subscribe { [weak self] event in
            guard let status = event.status else { return }
            Task { @MainActor in
                self?.apply(status)
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
        filePath = path
        selectedTrack = 0
        errorMessage = nil
        loadSelectedTrack()
    }

    func selectTrack(_ index: Int) {
        guard index >= 0, index != selectedTrack else { return }
        selectedTrack = index
        loadSelectedTrack()
    }

    func togglePlay() {
        do {
            if isPlaying {
                apply(controller.perform(.init(command: .pause)).status)
            } else {
                let event = controller.perform(.init(command: .play))
                if event.kind == .error { throw PlayerControlError.rejected(event.message) }
                apply(event.status)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        apply(controller.perform(.init(command: .stop)).status)
    }

    func seek(to seconds: Double) {
        do {
            let event = controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: Int(max(0, seconds) * 1_000))))
            if event.kind == .error { throw PlayerControlError.rejected(event.message) }
            apply(event.status)
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
        do {
            let mode: PlaybackMode = longPlayEnabled && currentFamily?.supportsLongPlay == true ? .longPlay : .fileDefault
            let loaded = controller.perform(.init(command: .load, payload: .init(
                path: filePath, trackIndex: selectedTrack, tempo: tempo, playbackMode: mode,
                playMilliseconds: manualSeconds * 1_000, fadeMilliseconds: fadeSeconds * 1_000
            )))
            if loaded.kind == .error { throw PlayerControlError.rejected(loaded.message) }
            if seconds > 0 {
                let seeked = controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: Int(seconds * 1_000))))
                if seeked.kind == .error { throw PlayerControlError.rejected(seeked.message) }
            }
            let started = controller.perform(.init(command: .play))
            if started.kind == .error { throw PlayerControlError.rejected(started.message) }
            apply(started.status)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ status: PlaybackStatus?) {
        guard let status else { return }
        isPlaying = status.isPlaying
        elapsedSeconds = status.elapsedSeconds
        reachedEnd = status.reachedEnd
        diagnostics = status.diagnostics
    }

    private func applyEqualizer() {
        do {
            let event = controller.perform(.init(command: .setEqualizer, payload: .init(equalizer: .init(enabled: equalizerEnabled, gainsDecibels: equalizerBandGains))))
            if event.kind == .error { throw PlayerControlError.rejected(event.message) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum PlayerControlError: LocalizedError {
    case rejected(String?)

    var errorDescription: String? {
        switch self {
        case .rejected(let message): return "VGMBoy rejected the control: \(message ?? "unknown error")"
        }
    }
}
