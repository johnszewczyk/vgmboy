import SwiftUI
import VGMBoyKit

/// A small native test bench with CocoaSpice-style panels. It directly drives
/// the reusable core and deliberately has no catalog or playlist concerns.
struct ContentView: View {
    @Bindable var model: PlayerViewModel
    @State private var selection: AppSection = .playback

    private enum AppSection: String, CaseIterable, Identifiable {
        case playback = "Playback", audio = "Audio", diagnostics = "Diagnostics", core = "Core"
        var id: Self { self }
        var icon: String {
            switch self {
            case .playback: "play.circle"
            case .audio: "speaker.wave.2"
            case .diagnostics: "waveform.path.ecg"
            case .core: "shippingbox"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("VGMBoy") {
                    ForEach(AppSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.icon).tag(section)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("VGMBoy")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text(selection.rawValue).font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Spacer()
                    if selection == .playback { Button("Open…", action: model.openDocument) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)

                ScrollView {
                    switch selection {
                    case .playback: PlaybackPage(model: model)
                    case .audio: AudioPage(model: model)
                    case .diagnostics: DiagnosticsPage(diagnostics: model.diagnostics)
                    case .core: CorePage()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(minWidth: 740, minHeight: 560)
        .background(Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255))
        .onChange(of: model.longPlayEnabled) { _, _ in model.applyTimingChange() }
        .onChange(of: model.manualSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.fadeSeconds) { _, _ in model.applyTimingChange() }
        .onChange(of: model.tempo) { _, _ in model.applyTimingChange() }
    }
}

private struct PlaybackPage: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelCard("Now Playing") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.filePath == nil ? "No file open" : URL(fileURLWithPath: model.filePath!).lastPathComponent)
                        .font(.title3.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(model.filePath ?? "Choose an audio file to start.")
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: 12) {
                    Button(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill", action: model.togglePlay)
                        .keyboardShortcut(.space, modifiers: []).disabled(model.filePath == nil)
                    Button("Stop", systemImage: "stop.fill", action: model.stop).disabled(model.filePath == nil)
                    Spacer()
                    if model.reachedEnd { Text("Ended").foregroundStyle(.secondary) }
                }
                VStack(spacing: 3) {
                    Slider(value: Binding(get: { model.elapsedSeconds }, set: { model.seek(to: $0) }), in: 0...max(model.displayDuration, 1))
                        .disabled(model.filePath == nil)
                    HStack { Text(time(model.elapsedSeconds)); Spacer(); Text(time(model.displayDuration)) }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }

            PanelCard("Long Play") {
                Toggle(isOn: $model.longPlayEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable extended playback").foregroundStyle(.white)
                        Text("Uses a finite playback window for looped game-audio formats.")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(model.filePath == nil || !(family?.supportsLongPlay ?? false))
                OptionRow("Pre-fade length") {
                    Stepper(value: $model.manualSeconds, in: 5...900, step: 5) { Text("\(model.manualSeconds)s").monospacedDigit() }
                }
                OptionRow("End fade") {
                    Stepper(value: $model.fadeSeconds, in: 0...60, step: 1) { Text("\(model.fadeSeconds)s").monospacedDigit() }
                }
            }
            .disabled(model.filePath == nil)

            PanelCard("Track") {
                Text(model.filePath == nil ? "No file open." : "The frontend catalog owns subtrack labels and selection.").foregroundStyle(.secondary)
            }

            PanelCard("Tempo") {
                OptionRow("Playback speed") {
                    Stepper(value: $model.tempo, in: 0.25...2.0, step: 0.25) {
                        Text(model.tempo.formatted(.number.precision(.fractionLength(2))) + "×").monospacedDigit()
                    }
                }
                Text(family?.supportsTempo == true ? "This decoder supports tempo control." : "This decoder uses its native speed.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .disabled(model.filePath == nil || !(family?.supportsTempo ?? false))

            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(.vertical, 2)
    }

    private var family: DecoderFamily? { model.filePath.flatMap(FormatRegistry.family) }

    private func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let whole = Int(seconds.rounded(.down))
        return "\(whole / 60):\(String(format: "%02d", whole % 60))"
    }
}

private struct AudioPage: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        PanelCard("Equalizer") {
            Toggle(isOn: Binding(get: { model.equalizerEnabled }, set: { model.setEqualizerEnabled($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Equalizer").foregroundStyle(.white)
                    Text("The same ten fixed bands used by CocoaSpice, applied inside VGMBoy’s audio graph.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            VStack(spacing: 10) {
                ForEach(EqualizerConfiguration.bandFrequencies.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        Text(label(EqualizerConfiguration.bandFrequencies[index]))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        Slider(value: Binding(get: { Double(model.equalizerBandGains[index]) }, set: { model.setEqualizerBandGain(Float($0), at: index) }),
                               in: Double(EqualizerConfiguration.gainRange.lowerBound)...Double(EqualizerConfiguration.gainRange.upperBound), step: 0.5)
                            .disabled(!model.equalizerEnabled)
                        Text(String(format: "%+.1f", model.equalizerBandGains[index]))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
            HStack { Spacer(); Button("Reset", action: model.resetEqualizer) }
        }
        .padding(.vertical, 2)
    }

    private func label(_ frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}

private struct DiagnosticsPage: View {
    let diagnostics: PlaybackDiagnostics

    var body: some View {
        PanelCard("Playback Diagnostics") {
            DiagnosticRow("Output", diagnostics.isOutputRunning ? "Running" : "Stopped")
            DiagnosticRow("Buffer", "\(diagnostics.bufferedFrames) / \(diagnostics.capacityFrames) frames")
            DiagnosticRow("Underruns", "\(diagnostics.underrunCount)")
            DiagnosticRow("Frames requested", "\(diagnostics.framesRequested)")
            DiagnosticRow("Frames supplied", "\(diagnostics.framesSupplied)")
            DiagnosticRow("Generation", "\(diagnostics.generation)")
            Text("Counters reset when a new track loads. They report core/device health only, never catalog or tag data.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct CorePage: View {
    private let families: [DecoderFamily] = [
        FormatRegistry.libgmeFamily, FormatRegistry.sidplayfpFamily, FormatRegistry.libvgmFamily,
        FormatRegistry.openMPTFamily,
        FormatRegistry.highlyCompleteFamily, FormatRegistry.twoSFFamily, FormatRegistry.vgmstreamFamily,
        FormatRegistry.lazyusfFamily, FormatRegistry.playpsfFamily
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelCard("Bundled Runtime") {
                Text("VGMBoyKit is compiled into this application at build time. It is not a server process and no executable path is selected at runtime.")
                    .foregroundStyle(.white)
                Text("A frontend should report its bundled core version and capabilities, not offer a Core path chooser. Dynamic decoder libraries are part of the app bundle’s packaging contract.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            PanelCard("Registered Decoder Families") {
                ForEach(families, id: \.id) { family in
                    HStack {
                        Text(family.id).foregroundStyle(.white)
                        Spacer()
                        Text(family.supportsTempo ? "Tempo" : "Native speed")
                        Text(family.hasNaturalEnding ? "Natural end" : "Timed")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PanelCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline).foregroundStyle(.white)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct OptionRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View { HStack { Text(title); Spacer(); content } }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack { Text(label); Spacer(); Text(value).monospacedDigit() }.foregroundStyle(.secondary)
    }
}
