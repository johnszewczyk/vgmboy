import SwiftUI
import UACWrapperCore
import UACManCore

private enum MetadataDraftValueKind: String, CaseIterable, Identifiable {
    case text = "Text"
    case json = "JSON"
    case structured = "Nested"

    var id: Self { self }
}

private struct MetadataDraftField: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String
    var kind: MetadataDraftValueKind
    var preservedStructuredValue: UACJSONValue?

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        kind: MetadataDraftValueKind,
        preservedStructuredValue: UACJSONValue? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.kind = kind
        self.preservedStructuredValue = preservedStructuredValue
    }
}

struct MetadataObjectEditor: View {
    let title: String
    @Binding var jsonText: String
    let onEdit: () -> Void

    @State private var fields: [MetadataDraftField] = []
    @State private var errorMessage: String?
    @State private var lastEncodedText = ""
    @State private var showRawJSON = false
    @State private var hasLoaded = false
    @State private var metadataObjectIsValid = true

    var body: some View {
        GroupBox(title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Field")
                        .frame(width: 190, alignment: .leading)
                    Text("Value")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("")
                        .frame(width: 26)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach($fields) { $field in
                    HStack(spacing: 8) {
                        TextField("Field name", text: $field.key)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 190)
                        if field.kind == .structured {
                            Text(field.value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .help("Edit nested arrays or objects in Exhaustive JSON · beta below.")
                        } else {
                            TextField(field.kind == .text ? "Text value" : "JSON value", text: $field.value)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            Picker("Value type", selection: $field.kind) {
                                Text("Text").tag(MetadataDraftValueKind.text)
                                Text("JSON").tag(MetadataDraftValueKind.json)
                            }
                            .labelsHidden()
                            .frame(width: 72)
                            .onChange(of: field.kind) { oldKind, newKind in
                                if oldKind == .text, newKind == .json {
                                    field.value = encoded(.string(field.value))
                                } else if oldKind == .json, newKind == .text,
                                          let data = field.value.data(using: .utf8),
                                          let value = try? JSONDecoder().decode(UACJSONValue.self, from: data),
                                          case .string(let string) = value {
                                    field.value = string
                                }
                            }
                        }
                        Button {
                            fields.removeAll { $0.id == field.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .help("Remove this field")
                        .frame(width: 26)
                    }
                }

                HStack {
                    Button {
                        fields.append(MetadataDraftField(key: "", value: "", kind: .text))
                    } label: {
                        Label("Add field", systemImage: "plus")
                    }
                    Spacer()
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                }

                DisclosureGroup("Exhaustive JSON · beta", isExpanded: $showRawJSON) {
                    TextEditor(text: $jsonText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 125)
                        .scrollContentBackground(.hidden)
                        .onChange(of: jsonText) { _, newValue in
                            guard hasLoaded, newValue != lastEncodedText else { return }
                            reloadFields(from: newValue)
                        }
                }
                .font(.caption)
            }
            .padding(.top, 6)
            .onAppear {
                if !hasLoaded { reloadFields(from: jsonText) }
            }
            .onChange(of: fields) { _, _ in
                guard hasLoaded else { return }
                commitFields()
            }
        }
    }

    private func reloadFields(from text: String) {
        guard let data = text.data(using: .utf8),
              let value = try? JSONDecoder().decode(UACJSONValue.self, from: data),
              case .object(let object) = value else {
            fields = []
            errorMessage = "Metadata must be a valid JSON object."
            metadataObjectIsValid = false
            hasLoaded = true
            return
        }
        fields = object.keys.sorted().compactMap { key in
            guard let value = object[key] else { return nil }
            switch value {
            case .string(let string):
                return MetadataDraftField(key: key, value: string, kind: .text)
            case .object(let nested):
                return MetadataDraftField(
                    key: key,
                    value: "Nested object · \(nested.count) field(s)",
                    kind: .structured,
                    preservedStructuredValue: value
                )
            case .array(let nested):
                return MetadataDraftField(
                    key: key,
                    value: "Nested array · \(nested.count) item(s)",
                    kind: .structured,
                    preservedStructuredValue: value
                )
            default:
                return MetadataDraftField(key: key, value: encoded(value), kind: .json)
            }
        }
        lastEncodedText = text
        errorMessage = nil
        metadataObjectIsValid = true
        hasLoaded = true
    }

    private func commitFields() {
        guard metadataObjectIsValid else { return }
        var object: [String: UACJSONValue] = [:]
        for field in fields {
            let key = field.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty { continue }
            guard object[key] == nil else {
                errorMessage = "Field names must be unique."
                return
            }
            switch field.kind {
            case .text:
                object[key] = .string(field.value)
            case .json:
                guard let data = field.value.data(using: .utf8),
                      let value = try? JSONDecoder().decode(UACJSONValue.self, from: data) else {
                    errorMessage = "\(key) needs a valid JSON value, or choose Text."
                    return
                }
                object[key] = value
            case .structured:
                guard let preserved = field.preservedStructuredValue else { continue }
                object[key] = preserved
            }
        }
        do {
            let encoded = try UACManifestEditor.prettyJSON(object)
            lastEncodedText = encoded
            let changed = jsonText != encoded
            if changed { jsonText = encoded }
            errorMessage = nil
            if changed { onEdit() }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func encoded(_ value: UACJSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}
