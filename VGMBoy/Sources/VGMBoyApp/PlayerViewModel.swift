import AppKit
import Observation
import VGMBoyArchiveCore
import VGMBoyKit

private struct SessionFile: Hashable {
    let sourceURL: URL
    let archiveEntry: String?

    var name: String { archiveEntry ?? sourceURL.lastPathComponent }
    var location: String {
        guard let archiveEntry else { return sourceURL.path }
        return "\(sourceURL.path) :: \(archiveEntry)"
    }
}

@MainActor
@Observable
final class PlayerViewModel {
    private var sessionFiles: [SessionFile] = []
    var volume = 1.0
    var monoEnabled = false
    var statistics = PlaybackStatistics()
    var filePath: String?
    var selectedTrack = 0
    var trackCount = 0
    private var hasPlaybackLoaded = false

    var isPlaying = false
    var reachedEnd = false
    var elapsedSeconds = 0.0
    var errorMessage: String?
    var diagnostics = PlaybackDiagnostics()

    private var currentSource: SessionFile?
    private var archiveEntry: String?

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
        if let archiveEntry { return FormatRegistry.family(for: archiveEntry) }
        return filePath.flatMap(FormatRegistry.family)
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
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        addFiles(panel.urls)
    }

    func load(fileURL: URL) {
        addFiles([fileURL])
    }

    func addFiles(_ urls: [URL]) {
        let materializer = ArchiveMaterializer()
        var incoming: [SessionFile] = []
        var listingError: String?

        for rawURL in urls {
            let url = rawURL.standardizedFileURL
            guard url.isFileURL else {
                listingError = "Choose a local file."
                continue
            }
            if FormatRegistry.family(for: url.path) != nil {
                incoming.append(SessionFile(sourceURL: url, archiveEntry: nil))
                continue
            }
            guard ArchiveContainerKind(archiveURL: url) != nil else {
                listingError = "Unsupported format: \(url.lastPathComponent)"
                continue
            }
            do {
                let playableEntries = try materializer.listEntries(archivePath: url.path).filter {
                    FormatRegistry.archiveMaterializationRequirement(for: [$0]) != nil
                }
                if playableEntries.isEmpty {
                    listingError = "No supported audio tracks were found in \(url.lastPathComponent)."
                } else {
                    incoming.append(contentsOf: playableEntries.map {
                        SessionFile(sourceURL: url, archiveEntry: $0)
                    })
                }
            } catch {
                listingError = error.localizedDescription
            }
        }
        materializer.release()

        guard !incoming.isEmpty else {
            errorMessage = listingError ?? "No supported audio files selected."
            return
        }

        var seen = Set(sessionFiles)
        let uniqueIncoming = incoming.filter { seen.insert($0).inserted }
        let capacity = max(0, 2_000 - sessionFiles.count)
        let additions = Array(uniqueIncoming.prefix(capacity))
        sessionFiles.append(contentsOf: additions)
        guard let first = additions.first ?? incoming.first(where: { sessionFiles.contains($0) }) else {
            errorMessage = "This local session is full. Restart VGMBoy to clear it."
            return
        }
        load(source: first)
        if uniqueIncoming.count > additions.count {
            errorMessage = "Local session limit reached; only the first 2,000 files are kept."
        }
    }

    private func load(source: SessionFile) {
        currentSource = source
        archiveEntry = source.archiveEntry
        filePath = source.sourceURL.path
        selectedTrack = 0
        trackCount = 0
        hasPlaybackLoaded = false
        errorMessage = nil
        loadSelectedTrack()
    }

    func selectTrack(_ index: Int) {
        guard (0 ..< trackCount).contains(index), index != selectedTrack else { return }
        selectedTrack = index
        loadSelectedTrack(autoplay: isPlaying)
    }

    func togglePlay() {
        do {
            if isPlaying {
                apply(controller.perform(.init(command: .pause)).status)
            } else if !hasPlaybackLoaded {
                loadSelectedTrack()
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
        hasPlaybackLoaded = false
    }

    func seek(to seconds: Double) {
        if !hasPlaybackLoaded {
            loadSelectedTrack(resumeAt: seconds, autoplay: false)
            return
        }
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
        loadSelectedTrack(resumeAt: resumeAt, autoplay: isPlaying)
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

    private func loadSelectedTrack(resumeAt seconds: Double = 0, autoplay: Bool = true) {
        guard let filePath else { return }
        do {
            let mode: PlaybackMode = longPlayEnabled && currentFamily?.supportsLongPlay == true ? .longPlay : .fileDefault
            let loaded = controller.perform(.init(command: .load, payload: .init(
                path: filePath, archiveEntry: archiveEntry, trackIndex: selectedTrack, tempo: tempo, playbackMode: mode,
                playMilliseconds: manualSeconds * 1_000, fadeMilliseconds: fadeSeconds * 1_000
            )))
            if loaded.kind == .error { throw PlayerControlError.rejected(loaded.message) }
            hasPlaybackLoaded = true
            if seconds > 0 {
                let seeked = controller.perform(.init(command: .seek, payload: .init(positionMilliseconds: Int(seconds * 1_000))))
                if seeked.kind == .error { throw PlayerControlError.rejected(seeked.message) }
            }
            if autoplay {
                let started = controller.perform(.init(command: .play))
                if started.kind == .error { throw PlayerControlError.rejected(started.message) }
                apply(started.status)
            } else { apply(controller.status()) }
            errorMessage = nil
        } catch {
            hasPlaybackLoaded = controller.status().statistics.trackIndex != nil
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ status: PlaybackStatus?) {
        guard let status else { return }
        isPlaying = status.isPlaying
        elapsedSeconds = status.elapsedSeconds
        reachedEnd = status.reachedEnd
        diagnostics = status.diagnostics
        statistics = status.statistics
        if let trackCount = status.statistics.trackCount {
            self.trackCount = trackCount
        }
        hasPlaybackLoaded = status.statistics.trackIndex != nil
        if let trackIndex = status.statistics.trackIndex {
            selectedTrack = trackIndex
        } else if trackCount == 0 {
            selectedTrack = 0
        }
        if let message = status.errorMessage { errorMessage = message }
    }


    var webSnapshot: [String: Any] {
        [
            "file": currentSource?.name ?? "Open a music file",
            "path": currentSource?.location ?? "Local playback · original formats · native audio output",
            "loaded": filePath != nil, "playing": isPlaying, "ended": reachedEnd,
            "elapsed": elapsedSeconds, "window": max(displayDuration, elapsedSeconds + 1),
            "family": currentFamily?.id ?? "No source", "track": selectedTrack + 1, "trackCount": trackCount,
            "supportsTempo": currentFamily?.supportsTempo ?? false,
            "supportsLongPlay": currentFamily?.supportsLongPlay ?? false,
            "longPlay": longPlayEnabled, "length": manualSeconds, "fade": fadeSeconds,
            "tempo": tempo, "volume": volume, "mono": monoEnabled,
            "eqEnabled": equalizerEnabled, "gains": equalizerBandGains.map(Double.init),
            "frequencies": EqualizerConfiguration.bandFrequencies.map(Double.init),
            "error": errorMessage ?? "",
            "formats": FormatRegistry.playbackDescriptors.map { descriptor in
                ["family": descriptor.familyID, "extensions": descriptor.extensions.sorted().joined(separator: " · "),
                 "tempo": descriptor.supportsTempo, "longPlay": descriptor.supportsLongPlay] as [String: Any]
            },
            "files": sessionFiles.enumerated().map { index, source in
                ["index": index, "name": source.name, "selected": source == currentSource] as [String: Any]
            },
            "diagnostics": ["buffered": diagnostics.bufferedFrames, "capacity": diagnostics.capacityFrames,
                "underruns": diagnostics.underrunCount, "requested": diagnostics.framesRequested,
                "supplied": diagnostics.framesSupplied, "generation": diagnostics.generation,
                "rate": diagnostics.sampleRate, "running": diagnostics.isOutputRunning,
                "decoderRate": statistics.decoderSampleRate, "decoded": statistics.decodedFrames,
                "positionFrames": statistics.audiblePositionFrames] as [String: Any]
        ]
    }

    func handleWebCommand(_ command: String, value: Any?) {
        let number = (value as? NSNumber)?.doubleValue
        let finite = number.flatMap { $0.isFinite ? $0 : nil }
        switch command {
        case "open": openDocument()
        case "toggle": if filePath != nil { togglePlay() }
        case "stop": stop()
        case "file":
            if let number = finite, number.rounded() == number, number >= 0, number < Double(sessionFiles.count) {
                load(source: sessionFiles[Int(number)])
            }
        case "previous", "next":
            if let currentSource, let index = sessionFiles.firstIndex(of: currentSource) {
                let next = index + (command == "next" ? 1 : -1)
                if sessionFiles.indices.contains(next) { load(source: sessionFiles[next]) }
            }
        case "track":
            if let number = finite, number.rounded() == number, number >= 1, number <= Double(trackCount) {
                selectTrack(Int(number) - 1)
            }
        case "seek": if let number = finite { seek(to: min(max(0, number), max(displayDuration, elapsedSeconds))) }
        case "longPlay": if let enabled = value as? Bool { longPlayEnabled = enabled; applyTimingChange() }
        case "length": if let number = finite { manualSeconds = Int(min(86400, max(5, number))); applyTimingChange() }
        case "fade": if let number = finite { fadeSeconds = Int(min(60, max(0, number))); applyTimingChange() }
        case "tempo": if let number = finite { tempo = min(2, max(0.25, number)); applyTimingChange() }
        case "volume":
            if let number = finite { volume = min(1, max(0, number)); perform(.setOutputVolume, .init(outputVolume: Float(volume))) }
        case "mono": if let enabled = value as? Bool { monoEnabled = enabled; perform(.setMonoEnabled, .init(monoEnabled: enabled)) }
        case "eqEnabled": if let enabled = value as? Bool { setEqualizerEnabled(enabled) }
        case "eq":
            if let values = value as? [String: NSNumber], let band = values["band"]?.intValue,
               let gain = values["gain"]?.floatValue, gain.isFinite { setEqualizerBandGain(gain, at: band) }
        case "resetEQ": resetEqualizer()
        case "reveal": if let filePath { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: filePath)]) }
        case "dismissError": errorMessage = nil
        default: break
        }
    }

    private func perform(_ command: PlaybackControlCommand, _ payload: PlaybackControlPayload) {
        let event = controller.perform(.init(command: command, payload: payload))
        if event.kind == .error { errorMessage = event.message }
        apply(event.status)
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
