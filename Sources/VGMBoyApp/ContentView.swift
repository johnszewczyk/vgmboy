import SwiftUI
import VGMBoyKit

struct ContentView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        VStack(spacing: 20) {
            metadataHeader
            transportBar
            positionBar
            timingControls
            if model.trackCount > 1 {
                trackPicker
            }
            statusLine
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 440)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open…", action: { model.openDocument() })
            }
        }
        .onChange(of: model.longPlayEnabled) { _, _ in model.applyTimingChange() }
        .onChange(of: model.manualSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.fadeSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.tempo) { _, _ in model.applyTimingChange() }
    }

    private var metadataHeader: some View {
        VStack(spacing: 4) {
            Text(model.currentSong?.song.isEmpty == false ? model.currentSong!.song : "(untitled)")
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Text(model.currentSong?.game.isEmpty == false ? model.currentSong!.game : model.filePath ?? "No file open")
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(model.currentSong?.author.isEmpty == false ? "\(model.currentSong!.author) · " : "")\(model.systemName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transportBar: some View {
        HStack(spacing: 12) {
            Button(action: { model.togglePlay() }) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 32)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut(.space, modifiers: [])

            Button(action: { model.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .frame(width: 32)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(model.filePath == nil)
        }
        .frame(height: 44)
    }

    private var positionBar: some View {
        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { model.elapsedSeconds },
                    set: { model.seek(to: $0) }
                ),
                in: 0...max(model.displayDuration, 1)
            )
            HStack {
                Text(formatTime(model.elapsedSeconds))
                Spacer()
                Text(formatTime(model.displayDuration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var timingControls: some View {
        HStack(spacing: 24) {
            Toggle("Long Play", isOn: $model.longPlayEnabled)
                .toggleStyle(.switch)

            HStack(spacing: 6) {
                Stepper(value: $model.manualSeconds, in: 5...900, step: 5) {
                    Text("Length")
                }
                Text("\(model.manualSeconds)s")
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Stepper(value: $model.fadeSeconds, in: 0...60, step: 1) {
                    Text("Fade")
                }
                Text("\(model.fadeSeconds)s")
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Stepper(value: $model.tempo, in: 0.25...2.0, step: 0.25) {
                    Text("Tempo")
                }
                Text(model.tempo.formatted(.number.precision(.fractionLength(2))))
                    .monospacedDigit()
            }
        }
        .disabled(model.filePath == nil)
    }

    private var trackPicker: some View {
        Picker("Track", selection: $model.selectedTrack) {
            ForEach(0..<model.trackCount, id: \.self) { index in
                Text(trackLabel(index)).tag(index)
            }
        }
        .onChange(of: model.selectedTrack) { _, newValue in
            model.selectTrack(newValue)
        }
        .frame(maxWidth: 360)
    }

    private var statusLine: some View {
        HStack {
            if let error = model.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            } else {
                Text("VGMBoy audio core — libgme — \(model.trackCount) track(s)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.reachedEnd {
                Text("ended")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func trackLabel(_ index: Int) -> String {
        if index < model.tracks.count {
            let song = model.tracks[index].song
            return song.isEmpty ? "Track \(index + 1)" : "\(index + 1). \(song)"
        }
        return "Track \(index + 1)"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds.rounded(.down))
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }
}