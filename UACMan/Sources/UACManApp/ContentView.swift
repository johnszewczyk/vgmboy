import SwiftUI
import UACContainerCore
import UACManCore

struct ContentView: View {
    @Bindable var model: UACManModel
    @State private var searchText = ""
    @State private var isBatchEditorPresented = false
    @State private var confirmReplaceHarvest = false
    @State private var sortOrder = [KeyPathComparator(\SPCMemberRow.titleSortValue)]

    private var visibleMembers: [SPCMemberRow] {
        guard !searchText.isEmpty else { return model.members }
        return model.members.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.artist ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.album ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.genre ?? "").localizedCaseInsensitiveContains(searchText)
                || $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.path.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            trackTable
        } detail: {
            if model.documentURL == nil {
                welcomeView
            } else {
                metadataInspector
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: model.openPanel) {
                    Label("Open", systemImage: "folder")
                }
                .disabled(model.isHarvestingMetadata)
                Button(action: model.revert) {
                    Label("Revert", systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.hasUnsavedChanges && !model.isHarvestingMetadata)
                Button(action: model.save) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s")
                .disabled(!model.hasUnsavedChanges || model.isHarvestingMetadata)
            }
        }
        .frame(minWidth: 1380, minHeight: 740)
        .sheet(isPresented: $isBatchEditorPresented) {
            batchEditor
        }
        .alert("UACMan", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Replace existing metadata?", isPresented: $confirmReplaceHarvest, titleVisibility: .visible) {
            Button("Replace Existing", role: .destructive) {
                model.harvestSPCMetadata(replaceExisting: true)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This re-reads every SPC member and replaces matching imported fields in the unsaved UAC draft. You can still Revert before saving. Native SPC bytes are never modified.")
        }
    }

    private var trackTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tracks")
                    .font(.headline)
                Spacer()
                Button {
                    model.setSelectedMembers(model.selectedMemberPaths.union(visibleMemberPaths))
                } label: {
                    Image(systemName: "checkmark.square")
                }
                .buttonStyle(.plain)
                .help("Select all visible tracks for batch editing")
                Button {
                    model.setSelectedMembers([])
                } label: {
                    Image(systemName: "xmark.square")
                }
                .buttonStyle(.plain)
                .help("Clear batch selection")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            HStack(spacing: 8) {
                Text("\(model.selectedMemberPaths.count) selected for batch editing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    isBatchEditorPresented = true
                } label: {
                    Label("Batch Edit", systemImage: "slider.horizontal.3")
                }
                .disabled(model.selectedMemberPaths.isEmpty || model.isHarvestingMetadata)
            }
            .padding(.horizontal, 12)

            Group {
                if model.documentURL == nil {
                    ContentUnavailableView(
                        "No package open",
                        systemImage: "music.note.list",
                        description: Text("Open a UAC package to browse its tracks.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.members.isEmpty {
                    ContentUnavailableView(
                        "No SPC members",
                        systemImage: "music.note",
                        description: Text("This package has \(model.allMemberCount) member(s), but none are SPC files.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(visibleMembers, selection: activeMemberSelection, sortOrder: $sortOrder) {
                        TableColumn("Batch") { member in
                            Toggle(
                                "Select \(member.name) for batch editing",
                                isOn: selectionBinding(for: member.path)
                            )
                            .labelsHidden()
                            .toggleStyle(.checkbox)
                        }
                        .width(52)
                        TableColumn("Title", value: \.titleSortValue) { member in
                            Text(member.title ?? "—")
                                .foregroundStyle(member.title == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .width(220)
                        TableColumn("Artist", value: \.artistSortValue) { member in
                            Text(member.artist ?? "—")
                                .foregroundStyle(member.artist == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .width(150)
                        TableColumn("Album", value: \.albumSortValue) { member in
                            Text(member.album ?? "—")
                                .foregroundStyle(member.album == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .width(160)
                        TableColumn("Year", value: \.yearSortValue) { member in
                            Text(member.year ?? "—")
                                .foregroundStyle(member.year == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .width(76)
                        TableColumn("Genre", value: \.genreSortValue) { member in
                            Text(member.genre ?? "—")
                                .foregroundStyle(member.genre == nil ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .width(120)
                        TableColumn("Length", value: \.playLengthSortValue) { member in
                            Text(member.durationText)
                                .monospacedDigit()
                                .foregroundStyle(member.playLengthMs == nil ? .secondary : .primary)
                        }
                        .width(82)
                        TableColumn("File", value: \.name) { member in
                            Text(member.name)
                                .lineLimit(1)
                                .help(member.path)
                        }
                    }
                    .font(.callout)
                    .disabled(model.isHarvestingMetadata)
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Filter tracks")
            .navigationTitle(model.documentURL?.lastPathComponent ?? "UACMan")
            .navigationSubtitle(model.members.isEmpty ? "UAC metadata" : "\(model.members.count) SPC file(s)")
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if model.isHarvestingMetadata {
                    Button(action: model.cancelSPCMetadataHarvest) {
                        Label("Cancel Harvest", systemImage: "stop.circle")
                    }
                } else {
                    Menu {
                        Button("Import native SPC tags · fill missing") {
                            model.harvestSPCMetadata()
                        }
                        Button("Re-import and replace existing…", role: .destructive) {
                            confirmReplaceHarvest = true
                        }
                    } label: {
                        Label("Harvest Tags", systemImage: "arrow.down.doc")
                    }
                    .disabled(model.members.isEmpty || !model.canHarvestSPCMetadata)
                    .help(model.canHarvestSPCMetadata
                        ? "Read native tags from contained SPC tracks"
                        : "Native-tag harvest requires a seekable tar+zstd-seekable UAC")
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 660, ideal: 900, max: 1200)
    }

    private var activeMemberSelection: Binding<String?> {
        Binding(
            get: { model.selectedMemberPath },
            set: { if let path = $0 { model.selectMember(path) } }
        )
    }

    private var welcomeView: some View {
        ContentUnavailableView {
            Label("UAC Metadata", systemImage: "shippingbox")
        } description: {
            Text("Open a UAC package to browse soundtrack-level metadata and edit its SPC tracks.")
        } actions: {
            Button("Open UAC…", action: model.openPanel)
                .keyboardShortcut("o")
        }
    }

    private var metadataInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let url = model.documentURL {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(url.lastPathComponent)
                            .font(.title2.weight(.semibold))
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                GroupBox("Soundtrack / game · shared metadata") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Package ID") {
                            Text(model.packageID)
                                .fontDesign(.monospaced)
                                .textSelection(.enabled)
                        }
                        TextField("Canonical game title", text: tracked(\.packageTitle))
                            .textFieldStyle(.roundedBorder)
                        TextField("Console", text: tracked(\.consoleName))
                            .textFieldStyle(.roundedBorder)
                        Text("Use this level for facts shared by the soundtrack. Each track retains its own title, artist, timing, and native tags.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        MetadataObjectEditor(
                            title: "Soundtrack metadata fields",
                            jsonText: tracked(\.gameMetadataJSON),
                            onEdit: model.markEdited
                        )
                        DisclosureGroup("Game extensions") {
                            jsonEditor("Extensions JSON", text: tracked(\.gameExtensionsJSON))
                        }
                    }
                    .padding(.top, 6)
                }

                if let member = model.selectedMember {
                    GroupBox("Track · per-member metadata") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(member.originalName)
                                    .font(.headline)
                                Text(member.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            MetadataObjectEditor(
                                title: "Track metadata fields",
                                jsonText: trackedMember(\.memberMetadataJSON),
                                onEdit: model.markMemberEdited
                            )
                            DisclosureGroup("Member extensions") {
                                jsonEditor("Extensions JSON", text: tracked(\.memberExtensionsJSON))
                            }
                            DisclosureGroup("Identity and hashes") {
                                VStack(alignment: .leading, spacing: 8) {
                                    hashLine("File BLAKE3", member.blake3)
                                    if let streamHash = member.streamBlake3 {
                                        hashLine("Stream BLAKE3", streamHash)
                                    }
                                    ForEach(Array(member.hashes.enumerated()), id: \.offset) { _, hash in
                                        hashLine("\(hash.scope) · \(hash.profile)", hash.digest)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 6)
                    }
                }

                HStack(spacing: 12) {
                    Label(model.manifestEncodingDescription, systemImage: "text.alignleft")
                    Text("\(model.allMemberCount) total member(s)")
                    Spacer()
                    if model.hasUnsavedChanges {
                        Label("Unsaved edits", systemImage: "pencil.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("MetaMan reads SPC ID666/xID6 into the UAC draft, retaining ordered duplicate tags and raw-block sizes. Original tag bytes stay inside the untouched SPC members instead of being duplicated in the manifest. Save changes only the manifest and preserves the compressed payload byte-for-byte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.members.isEmpty && !model.canHarvestSPCMetadata {
                    Text("Native tag harvest is unavailable for this package: its payload is not indexed as seekable Zstandard.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if model.isHarvestingMetadata {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(model.harvestProgressMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: 1120, alignment: .leading)
        }
    }

    private var batchEditor: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    LabeledContent("Selected tracks") {
                        Text("\(model.selectedMemberPaths.count)")
                    }
                    Text("Only selected SPC tracks are affected. Changes remain in the unsaved draft until Save; Revert restores the opened package.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Operation") {
                    TextField("Metadata field name", text: $batchKey)
                    Picker("Action", selection: $batchOperation) {
                        ForEach(UACBatchFieldOperation.allCases) { operation in
                            Text(operation.title).tag(operation)
                        }
                    }
                    if batchOperation == .replaceText {
                        TextField("Find text", text: $batchSearchText)
                        TextField("Replace with", text: $batchValue)
                    } else if batchOperation != .remove {
                        TextField("Value", text: $batchValue)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Batch Track Metadata")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isBatchEditorPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        model.applyBatchFieldEdit(
                            key: batchKey,
                            operation: batchOperation,
                            value: batchValue,
                            searchText: batchSearchText
                        )
                        isBatchEditorPresented = false
                    }
                    .keyboardShortcut(.return)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 390)
    }

    private var visibleMemberPaths: Set<String> {
        Set(visibleMembers.map(\.path))
    }

    @State private var batchKey = ""
    @State private var batchValue = ""
    @State private var batchSearchText = ""
    @State private var batchOperation: UACBatchFieldOperation = .set

    private func selectionBinding(for path: String) -> Binding<Bool> {
        Binding(
            get: { model.selectedMemberPaths.contains(path) },
            set: { model.setMemberSelected(path, isSelected: $0) }
        )
    }

    private func jsonEditor(_ title: String, text: Binding<String>) -> some View {
        GroupBox(title) {
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity)
    }

    private func hashLine(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func tracked(_ keyPath: ReferenceWritableKeyPath<UACManModel, String>) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: {
                model[keyPath: keyPath] = $0
                model.markEdited()
            }
        )
    }

    private func trackedMember(_ keyPath: ReferenceWritableKeyPath<UACManModel, String>) -> Binding<String> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: {
                model[keyPath: keyPath] = $0
                model.markMemberEdited()
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
