import AppKit
import ScanSongKit
import SwiftUI

struct ScannerOptionsView: View {
    @ObservedObject var model: ScannerAppModel
    @State private var selection: OptionsSection = .fileTypes

    private enum OptionsSection: String, Identifiable {
        case fileTypes = "File Types"
        case metadataTags = "Metadata Tags"

        var id: Self { self }
    }

    private let windowBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    private let panelBackground = Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Scanner") {
                    Label("Ignored Types", systemImage: "gearshape")
                        .tag(OptionsSection.fileTypes)
                }
                Section("Catalog") {
                    Label("Metadata Tags", systemImage: "tag")
                        .tag(OptionsSection.metadataTags)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Options")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    Text(selection == .fileTypes ? "Ignored Types" : "Metadata Tags")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selection {
                        case .fileTypes:
                            fileTypesPage
                        case .metadataTags:
                            metadataTagsPage
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .background(windowBackground)
        .background(OptionsWindowConfigurator())
    }

    private var fileTypesPage: some View {
        sectionCard(title: "Ignored Types") {
            Text("Checked types are skipped before scanner inspection because ScanSong has no usable decoder route for them. Uncheck a type only when you want its failures reported while developing support. Supported formats are never ignored because a member is malformed.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.fileTypePolicies) { policy in
                    Toggle(isOn: Binding(
                        get: { model.isFileTypeIgnored(policy) },
                        set: { model.setFileTypeIgnored(policy.id, ignored: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(policy.displayName) (.\(policy.id))")
                                .foregroundStyle(.white)
                            Text(policy.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(model.isBusy)
                    .padding(.vertical, 10)

                    if policy.id != model.fileTypePolicies.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    private var metadataTagsPage: some View {
        sectionCard(title: "Metadata Tags") {
            Text("These names come from source metadata preserved during scanning. Exact source spellings stay separate; the lookup key is trimmed and uppercased. Track and value counts show catalog coverage. A Deep Scan is needed to collect tags for files already in an older catalog.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if model.metadataTagSummaries.isEmpty {
                Text("No source tags are indexed yet. Run a Deep Scan to collect tags from existing files.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                Table(model.metadataTagSummaries) {
                    TableColumn("Tag Name", value: \.tagName)
                    TableColumn("Lookup Key", value: \.normalizedName)
                    TableColumn("Tracks") { summary in
                        Text(summary.trackCount.formatted())
                            .monospacedDigit()
                    }
                    TableColumn("Values") { summary in
                        Text(summary.occurrenceCount.formatted())
                            .monospacedDigit()
                    }
                }
                .frame(minHeight: 240)
            }
        }
    }

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
        .background(RoundedRectangle(cornerRadius: 10).fill(panelBackground))
    }

    private struct OptionsWindowConfigurator: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView { NSView() }

        func updateNSView(_ nsView: NSView, context: Context) {
            guard let window = nsView.window else { return }
            window.minSize = NSSize(width: 620, height: 420)
            window.setFrameAutosaveName("ScanSong.Options")
        }
    }
}
