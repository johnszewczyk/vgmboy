import SwiftUI
import VGMBoyKit

/// A deliberately small CocoaSpice-style Options surface for exercising the
/// shared playback core. VGMBoy is not a playlist application; Playback is
/// simply the first component page and the remaining pages expose core state.
struct ContentView: View {
    @Bindable var model: PlayerViewModel
    @State private var selection: AppSection = .playback

    private enum AppSection: String, CaseIterable, Identifiable {
        case playback = "Playback"
        case audio = "Audio"
        case diagnostics = "Diagnostics"
        case core = "Core"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .playback: "waveform"
            case .audio: "speaker.wave.2"
            case .diagnostics: "waveform.path.ecg"
            case .core: "puzzlepiece.extension"
            }
        }
    }

    private let windowBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Components") {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Options")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text(selection.rawValue)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if selection == .playback {
                        Button("Open…", action: model.openDocument)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selection {
                        case .playback: playbackPage
                        case .audio: audioPage
                        case .diagnostics: diagnosticsPage
                        case .core: corePage
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(windowBackground)
        .onChange(of: model.longPlayEnabled) { _, _ in model.applyTimingChange() }
        .onChange(of: model.manualSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.fadeSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.tempo) { _, _ in model.applyTimingChange() }
    }

    private var playbackPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "Now Playing") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.filePath == nil ? "No file open" : URL(fileURLWithPath: model.filePath!).lastPathComponent)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(model.filePath ?? "Choose an audio file to start.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill", action: model.togglePlay)
                        .keyboardShortcut(.space, modifiers: [])
                        .disabled(model.filePath == nil)
                    Button("Stop", systemImage: "stop.fill", action: model.stop)
                        .disabled(model.filePath == nil)
                    Spacer()
                    if model.reachedEnd { Text("Ended").foregroundStyle(.secondary) }
                }

                VStack(spacing: 3) {
                    Slider(
                        value: Binding(get: { model.elapsedSeconds }, set: { model.seek(to: $0) }),
                        in: 0...max(model.displayDuration, 1)
                    )
                    .disabled(model.filePath == nil)
                    HStack {
                        Text(time(model.elapsedSeconds))
                        Spacer()
                        Text(time(model.displayDuration))
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }

            sectionCard(title: "Long Play") {
                Toggle(isOn: $model.longPlayEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable extended playback").foregroundStyle(.white)
                        Text("Uses a finite playback window for looped game-audio formats.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(model.filePath == nil || !(family?.supportsLongPlay ?? false))

                OptionRow("Pre-fade length") {
                    Stepper(value: $model.manualSeconds, in: 5...900, step: 5) {
                        Text("\(model.manualSeconds)s").monospacedDigit()
                    }
                }
                OptionRow("End fade") {
                    Stepper(value: $model.fadeSeconds, in: 0...60, step: 1) {
                        Text("\(model.fadeSeconds)s").monospacedDigit()
                    }
                }
            }
            .disabled(model.filePath == nil)

            sectionCard(title: "Play Speed") {
                OptionRow("Playback speed") {
                    Stepper(value: $model.tempo, in: 0.25...2.0, step: 0.25) {
                        Text(model.tempo.formatted(.number.precision(.fractionLength(2))) + "×")
                            .monospacedDigit()
                    }
                }
                Text("Tempo support by decoder core")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ForEach(decoderFamilies, id: \.id) { decoderFamily in
                    HStack {
                        Text(decoderFamily.id)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(decoderFamily.supportsTempo ? "Supported" : "Native speed")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                Text(family?.supportsTempo == true ? "The selected track uses this control." : "The selected track stays at its core's native speed.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .disabled(model.filePath == nil || !(family?.supportsTempo ?? false))

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var audioPage: some View {
        sectionCard(title: "Equalizer") {
            Toggle(isOn: Binding(get: { model.equalizerEnabled }, set: { model.setEqualizerEnabled($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Equalizer").foregroundStyle(.white)
                    Text("The ten fixed bands used by CocoaSpice, applied inside VGMBoy's audio graph.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            VStack(spacing: 10) {
                ForEach(EqualizerConfiguration.bandFrequencies.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(equalizerLabel(EqualizerConfiguration.bandFrequencies[index]))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        Slider(
                            value: Binding(
                                get: { Double(model.equalizerBandGains[index]) },
                                set: { model.setEqualizerBandGain(Float($0), at: index) }
                            ),
                            in: Double(EqualizerConfiguration.gainRange.lowerBound)...Double(EqualizerConfiguration.gainRange.upperBound),
                            step: 0.5
                        )
                        .disabled(!model.equalizerEnabled)
                        Text(String(format: "%+.1f", model.equalizerBandGains[index]))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Reset", action: model.resetEqualizer)
            }
        }
    }

    private var diagnosticsPage: some View {
        sectionCard(title: "Playback Diagnostics") {
            diagnosticRow("Output", model.diagnostics.isOutputRunning ? "Running" : "Stopped")
            diagnosticRow("Buffer", "\(model.diagnostics.bufferedFrames) / \(model.diagnostics.capacityFrames) frames")
            diagnosticRow("Underruns", "\(model.diagnostics.underrunCount)")
            diagnosticRow("Frames requested", "\(model.diagnostics.framesRequested)")
            diagnosticRow("Frames supplied", "\(model.diagnostics.framesSupplied)")
            diagnosticRow("Generation", "\(model.diagnostics.generation)")
            Text("Counters reset when a new track loads. They report core and device health only, never catalog or tag data.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var corePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard(title: "VGMBoy Runtime") {
                Text("VGMBoyKit is compiled into this application at build time. It is not a server process and has no runtime core selector.")
                    .foregroundStyle(.white)
                Text("The command line and this small GUI are test skins over the same decoder, timing, equalizer, and audio-output core.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            sectionCard(title: "Registered Decoder Families") {
                ForEach(decoderFamilies, id: \.id) { family in
                    HStack {
                        Text(family.id).foregroundStyle(.white)
                        Spacer()
                        Text(family.supportsTempo ? "Tempo" : "Native speed")
                        Text(family.hasNaturalEnding ? "Natural end" : "Timed")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private let decoderFamilies: [DecoderFamily] = [
        FormatRegistry.libgmeFamily,
        FormatRegistry.sidplayfpFamily,
        FormatRegistry.libvgmFamily,
        FormatRegistry.openMPTFamily,
        FormatRegistry.amigaFamily,
        FormatRegistry.highlyCompleteFamily,
        FormatRegistry.twoSFFamily,
        FormatRegistry.vgmstreamFamily,
        FormatRegistry.lazyusfFamily,
        FormatRegistry.playpsfFamily
    ]

    private var family: DecoderFamily? { model.filePath.flatMap(FormatRegistry.family) }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds.rounded(.down))
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }

    private func equalizerLabel(_ frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Divider()
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)))
    }

    private struct OptionRow<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        init(_ title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                content
            }
        }
    }

    private func diagnosticRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
