import SwiftUI
import UACManCore

struct UACManOptionsView: View {
    @Environment(\.colorScheme) private var colorScheme
    private struct ColorToken: Identifiable {
        let key: String
        let label: String
        var id: String { key }
    }

    @Bindable var model: UACManModel
    @State private var darkPalette = false
    @State private var draftColors: [String: String]
    @State private var invalidColorKeys: Set<String> = []

    private let colorTokens = [
        ColorToken(key: "bg", label: "Window background"),
        ColorToken(key: "panel", label: "Panel"),
        ColorToken(key: "panel-2", label: "Raised panel"),
        ColorToken(key: "line", label: "Borders"),
        ColorToken(key: "text", label: "Main text"),
        ColorToken(key: "muted", label: "Muted text"),
        ColorToken(key: "soft", label: "Secondary text"),
        ColorToken(key: "accent", label: "Accent"),
        ColorToken(key: "accent-soft", label: "Accent background"),
        ColorToken(key: "hover", label: "Hover"),
        ColorToken(key: "selected", label: "Selection"),
        ColorToken(key: "green", label: "Success"),
        ColorToken(key: "red", label: "Error")
    ]

    init(model: UACManModel) {
        self.model = model
        _draftColors = State(initialValue: model.skinPreferences.lightColors)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance")
                        .font(.title2.weight(.semibold))
                    Text("Changes apply to the workspace immediately and are saved on this Mac.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore Defaults", action: restoreDefaults)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    colorsSection
                    Divider()
                    typographySection
                    Divider()
                    tablesSection
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(minWidth: 640, minHeight: 620)
        .onAppear {
            darkPalette = colorScheme == .dark
        }
        .onChange(of: colorScheme) { _, scheme in
            darkPalette = scheme == .dark
        }
        .onChange(of: darkPalette) { _, useDark in
            draftColors = useDark ? model.skinPreferences.darkColors : model.skinPreferences.lightColors
            invalidColorKeys.removeAll()
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Colors")
                    .font(.headline)
                Spacer()
                Picker("Palette", selection: $darkPalette) {
                    Text("Light").tag(false)
                    Text("Dark").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                .labelsHidden()
            }

            Text("The active palette follows the macOS appearance. Use 3 or 6 digit hex, RGB channels such as 255 128 0, or any CSS named color.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(colorTokens) { token in
                    colorRow(token)
                }
            }
        }
    }

    private func colorRow(_ token: ColorToken) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(token.label)
                    .frame(width: 160, alignment: .leading)
                TextField("Hex, RGB, or CSS color name", text: colorBinding(for: token.key))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitColor(token.key) }
                Button("Reset") { resetColor(token.key) }
                    .buttonStyle(.borderless)
            }
            if invalidColorKeys.contains(token.key) {
                Text("Enter a CSS named color, 3 or 6 digit hex, or three RGB channels from 0 to 255.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 172)
            }
        }
    }

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Font Sizes")
                .font(.headline)

            sizeControl(
                title: "Interface text",
                value: fontSizeBinding(\.interfaceFontSize),
                range: 11...18,
                step: 0.5
            )
            sizeControl(
                title: "Table text",
                value: fontSizeBinding(\.tableFontSize),
                range: 8...16,
                step: 0.5
            )
        }
    }

    private var tablesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tables")
                .font(.headline)

            sizeControl(
                title: "Table frame corner radius",
                value: fontSizeBinding(\.tableSurfaceRadius),
                range: 0...16,
                step: 1
            )
            sizeControl(
                title: "Table cell corner radius",
                value: fontSizeBinding(\.tableCellRadius),
                range: 0...10,
                step: 1
            )
        }
    }

    private func sizeControl(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .frame(width: 220, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text("\(value.wrappedValue, specifier: "%.1f") px")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
    }

    private func colorBinding(for token: String) -> Binding<String> {
        Binding(
            get: { draftColors[token] ?? "" },
            set: { newValue in
                draftColors[token] = newValue
                invalidColorKeys.remove(token)
                guard let normalized = UACManSkinPreferences.normalizedColorInput(newValue) else { return }
                _ = model.setSkinColor(normalized, token: token, darkPalette: darkPalette)
            }
        )
    }

    private func fontSizeBinding(
        _ keyPath: WritableKeyPath<UACManSkinPreferences, Double>
    ) -> Binding<Double> {
        Binding(
            get: { model.skinPreferences[keyPath: keyPath] },
            set: { newValue in
                model.updateSkinPreferences { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func commitColor(_ token: String) {
        let input = draftColors[token] ?? ""
        guard let normalized = UACManSkinPreferences.normalizedColorInput(input) else {
            if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resetColor(token)
            } else {
                invalidColorKeys.insert(token)
            }
            return
        }
        _ = model.setSkinColor(normalized, token: token, darkPalette: darkPalette)
        draftColors[token] = normalized
    }

    private func resetColor(_ token: String) {
        model.resetSkinColor(token: token, darkPalette: darkPalette)
        let palette = darkPalette ? model.skinPreferences.darkColors : model.skinPreferences.lightColors
        draftColors[token] = palette[token]
        invalidColorKeys.remove(token)
    }

    private func restoreDefaults() {
        model.resetSkinPreferences()
        draftColors = darkPalette ? model.skinPreferences.darkColors : model.skinPreferences.lightColors
        invalidColorKeys.removeAll()
    }
}
