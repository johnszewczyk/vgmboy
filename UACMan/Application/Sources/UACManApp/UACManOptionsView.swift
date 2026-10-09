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
    @State private var draftColors: [String: String]
    @State private var invalidColorKeys: Set<String> = []

    private let colorTokens = [
        ColorToken(key: "bg", label: "Window background"),
        ColorToken(key: "panel", label: "Panel"),
        ColorToken(key: "panel-2", label: "Raised panel"),
        ColorToken(key: "table-title-bg", label: "Table title bar background"),
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
        let initialDarkPalette = model.skinPreferences.appearanceMode == .dark
        _draftColors = State(initialValue: initialDarkPalette ? model.skinPreferences.darkColors : model.skinPreferences.lightColors)
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
                    Divider()
                    nestedTablesSection
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(minWidth: 640, minHeight: 620)
        .onAppear {
            draftColors = currentDraftPalette
        }
        .onChange(of: colorScheme) { _, scheme in
            if model.skinPreferences.appearanceMode == .system {
                draftColors = scheme == .dark ? model.skinPreferences.darkColors : model.skinPreferences.lightColors
            }
        }
        .onChange(of: model.skinPreferences.appearanceMode) { _, _ in
            draftColors = currentDraftPalette
            invalidColorKeys.removeAll()
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Colors")
                    .font(.headline)
                Spacer()
                Picker("Appearance", selection: appearanceModeBinding) {
                    Text("System").tag(UACManAppearanceMode.system)
                    Text("Light").tag(UACManAppearanceMode.light)
                    Text("Dark").tag(UACManAppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .labelsHidden()
            }

            Text("System follows macOS. Light and Dark switch the workspace skin immediately. Set the table title bar background independently; use 3 or 6 digit hex, RGB channels such as 255 128 0, or any CSS named color.")
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

    private var nestedTablesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nested Tables")
                    .font(.headline)
                Spacer()
                Picker("Nested Tables", selection: nestedTableModeBinding) {
                    Text("Staircase").tag(UACManNestedTableMode.staircase)
                    Text("Seamless").tag(UACManNestedTableMode.seamless)
                    Text("Spaced").tag(UACManNestedTableMode.spaced)
                    Text("Pop-up").tag(UACManNestedTableMode.popup)
                }
                .pickerStyle(.segmented)
                .frame(width: 390)
                .labelsHidden()
            }

            Text("Choose how unfolded tables appear. Staircase aligns each child table with the parent’s second column.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
                _ = model.setSkinColor(normalized, token: token, darkPalette: editsDarkPalette)
            }
        )
    }

    private var appearanceModeBinding: Binding<UACManAppearanceMode> {
        Binding(
            get: { model.skinPreferences.appearanceMode },
            set: { mode in
                model.updateSkinPreferences { $0.appearanceMode = mode }
            }
        )
    }

    private var nestedTableModeBinding: Binding<UACManNestedTableMode> {
        Binding(
            get: { model.skinPreferences.nestedTableMode },
            set: { mode in
                model.updateSkinPreferences { $0.nestedTableMode = mode }
            }
        )
    }

    private var editsDarkPalette: Bool {
        model.skinPreferences.usesDarkPalette(systemIsDark: colorScheme == .dark)
    }

    private var currentDraftPalette: [String: String] {
        editsDarkPalette ? model.skinPreferences.darkColors : model.skinPreferences.lightColors
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
        _ = model.setSkinColor(normalized, token: token, darkPalette: editsDarkPalette)
        draftColors[token] = normalized
    }

    private func resetColor(_ token: String) {
        model.resetSkinColor(token: token, darkPalette: editsDarkPalette)
        draftColors[token] = currentDraftPalette[token]
        invalidColorKeys.remove(token)
    }

    private func restoreDefaults() {
        model.resetSkinPreferences()
        draftColors = currentDraftPalette
        invalidColorKeys.removeAll()
    }
}
