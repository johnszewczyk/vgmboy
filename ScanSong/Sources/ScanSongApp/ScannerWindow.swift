import AppKit
import Foundation
import ScanSongKit
import SwiftUI
import UniformTypeIdentifiers

struct ScannerWindow: View {
    @ObservedObject var model: ScannerAppModel
    @Environment(\.openWindow) private var openWindow

    private let windowBackground = Color(red: 30 / 255, green: 30 / 255, blue: 30 / 255)
    private let panelBackground = Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                catalogCard
                    .opacity(model.isBusy ? 0.62 : 1)
                scanPathsCard
                    .opacity(model.isBusy ? 0.62 : 1)
                scannerOptionsCard
                    .opacity(model.isBusy ? 0.62 : 1)
                scanStatusCard
            }
            .padding(20)
        }
        .background(windowBackground)
        .frame(minWidth: 760, idealWidth: 840, minHeight: 560, idealHeight: 700)
        .background(WindowCloseGuard(model: model))
        .onAppear { ScanSongApplicationDelegate.shared?.scannerModel = model }
        .confirmationDialog(
            "Reset all scan paths?",
            isPresented: $model.showsResetPathsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Paths", role: .destructive) { model.resetPaths() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every configured scan path from the catalog. Indexed records stay intact and can be reused when a path is added again.")
        }
        .confirmationDialog(
            "Remove Links?",
            isPresented: $model.showsCleanLinksConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Links", role: .destructive) { model.cleanLinks() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Moved files' records are retained for fast recognition. Permanently remove dead links from database?")
        }
        .confirmationDialog(
            "Reset Database?",
            isPresented: $model.showsResetCatalogConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Database", role: .destructive) { model.resetCatalog() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This empties the selected catalog, including scan paths, indexed tracks, metadata, and scan history. Media files on disk are not changed.")
        }
        .confirmationDialog(
            "Delete Database File?",
            isPresented: $model.showsDeleteCatalogConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Database File", role: .destructive) { model.deleteCatalogFile() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the selected database file from disk. Media files on disk are not changed.")
        }
    }

    private var catalogCard: some View {
        sectionCard(title: "Database File") {
            databaseFileRow
            HStack(spacing: 8) {
                actionButton("Use Default") { model.useDefaultCatalog() }
                    .disabled(model.isBusy)
                actionButton("Add New") { model.addNewCatalog() }
                    .disabled(model.isBusy)
            }
        }
    }

    private var scanPathsCard: some View {
        sectionCard(title: "Scan Paths") {
            if model.roots.isEmpty {
                Text("No scan paths configured.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(model.roots) { root in
                        scanPathRow(root)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    model.toggleAllPathsEnabled()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .help("Enable All / Disable All")
                .accessibilityLabel("Enable All / Disable All Paths")
                .disabled(model.isBusy || model.roots.isEmpty)

                actionButton(model.operationProgress?.operation == .addPath ? "Adding…" : "Add Path") { model.addPaths() }
                    .disabled(model.isBusy)
                actionButton("Reset Paths") { model.showsResetPathsConfirmation = true }
                    .disabled(model.isBusy || model.roots.isEmpty)
                actionButton("Scan All") { model.scanAllPaths() }
                    .disabled(!model.canScanAll)
                actionButton("Check Links") { model.checkLinks() }
                    .disabled(model.isBusy || model.roots.isEmpty)
                actionButton("Remove Links") { model.showsCleanLinksConfirmation = true }
                    .disabled(model.isBusy || !model.hasInactiveLinks)
            }
        }
    }

    private var scannerOptionsCard: some View {
        sectionCard(title: "Scanner Options") {
            HStack(alignment: .center, spacing: 16) {
                Toggle(isOn: $model.deepScan) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deep Scan")
                            .foregroundStyle(.white)
                        Text("Unzip, read metadata for all files.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(model.isBusy)

                Spacer(minLength: 16)

                Button { openWindow(id: "options") } label: {
                    Image(systemName: "gearshape")
                }
                .help("Scanner Options")
                .accessibilityLabel("Scanner Options")
                .disabled(model.isBusy)
            }
        }
    }

    private var scanStatusCard: some View {
        sectionCard(title: "Scan Status") {
            if model.isBusy, let progress = model.operationProgress {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(progress.operation.rawValue) • \(progress.phaseLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    if let startedAt = model.operationStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(ScannerOperationTelemetry.durationText(
                                seconds: context.date.timeIntervalSince(startedAt)
                            ))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if !model.isBusy, let completedOperation = model.completedOperation {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.green)
                    Text(completedOperation.statusText)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(completedOperation.statusText)
            } else {
                scanReadout
            }
            if model.isBusy {
                Group {
                    if let fraction = model.progressFraction {
                        ProgressView(value: fraction)
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(model.progressFraction == nil ? "Processing" : "Source progress")
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if model.isScanning {
                Button(role: .cancel) { model.cancelScan() } label: {
                    Text(model.isCancelling ? "Cancelling…" : "Cancel Scan")
                        .frame(maxWidth: .infinity)
                }
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.isCancelling)
            }
        }
    }

    private var scanReadout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.isBusy ? "Current Operation" : "Status")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(model.scanStatus)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if let detail = model.operationProgress?.detail,
               detail != model.scanStatus {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if model.isBusy,
               model.isScanning || model.operationProgress?.total != nil {
                VStack(alignment: .leading, spacing: 2) {
                    monoStatusField(
                        title: model.isScanning ? " Sources:" : " Items:",
                        value: model.operationProgress.map { progress in
                            if let total = progress.total { return "\(progress.processed) / \(total)" }
                            return String(progress.processed)
                        } ?? "0"
                    )
                    monoStatusField(
                        title: " Fails:",
                        value: model.operationProgress.map { String($0.failures) } ?? "0"
                    )
                }
            }
            if model.isScanning, model.currentFile != nil {
                Text("Current File")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                monoStatusField(title: " Path:", value: model.currentPath ?? "—")
                monoStatusField(title: " File:", value: model.currentFile ?? "—")
            }

        }
    }

    private var databaseFileRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "cylinder")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.databaseFileDisplayPath)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(model.catalogStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button { model.chooseCatalog() } label: {
                    Image(systemName: "folder")
                }
                .help("Open Database File")
                .accessibilityLabel("Open Database File")
                .disabled(model.isBusy)

                Button(role: .destructive) {
                    model.showsResetCatalogConfirmation = true
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Empty Database")
                .accessibilityLabel("Reset Database")
                .disabled(model.isBusy || !model.hasDatabaseFile)

                Button(role: .destructive) { model.showsDeleteCatalogConfirmation = true } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Database File")
                .accessibilityLabel("Delete Database File")
                .disabled(model.isBusy || !model.hasDatabaseFile)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func scanPathRow(_ root: CatalogRoot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { root.isEnabled },
                    set: { model.setPathEnabled(root.id, enabled: $0) }
                )
            )
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(model.isBusy)

            scanPathStatusIcon(root)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.abbreviatedPath(for: root))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .help(root.path)
                Text(model.rootStatusText(root))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button { model.scanPath(root.id) } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help(root.isEnabled ? "Scan Path" : "Scan Path Without Enabling It")
                .disabled(model.isBusy)

                Button { model.showScanLog(root.id) } label: {
                    Image(systemName: "doc.text")
                }
                .help("Show Last Scan Log")
                .disabled(!model.hasScanLog(root.id))

                Button(role: .destructive) { model.removePath(root.id) } label: {
                    Image(systemName: "trash")
                }
                .help("Remove Path")
                .disabled(model.isBusy)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func scanPathStatusIcon(_ root: CatalogRoot) -> some View {
        if model.rootStatusIsEmpty(root) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Scan completed with no playable files")
        } else if model.rootStatusHasIssues(root) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.yellow)
                .accessibilityLabel("Scan completed with issues; see Log for details")
        } else if model.rootStatusIsClean(root) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Scan completed without issues")
        } else {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Not yet scanned")
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monoStatusField(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

private struct WindowCloseGuard: NSViewRepresentable {
    @ObservedObject var model: ScannerAppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        attach(context.coordinator, to: view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.model = model
        attach(context.coordinator, to: view)
    }

    private func attach(_ coordinator: Coordinator, to view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window, window.delegate !== coordinator else { return }
            window.delegate = coordinator
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var model: ScannerAppModel

        init(model: ScannerAppModel) {
            self.model = model
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard model.isBusy else { return true }

            let alert = NSAlert()
            if model.isScanning {
                alert.messageText = "Scan in Progress"
                alert.informativeText = "Cancel the scan and close after completed checkpoints are safely retained?"
                alert.addButton(withTitle: "Keep Scanning")
                alert.addButton(withTitle: "Cancel Scan and Close")
            } else {
                alert.messageText = "Catalog Operation in Progress"
                alert.informativeText = "Close after the current database operation has finished?"
                alert.addButton(withTitle: "Keep Working")
                alert.addButton(withTitle: "Close When Finished")
            }
            guard alert.runModal() == .alertSecondButtonReturn else { return false }
            model.closeWhenWorkIsSafe { [weak sender] in sender?.performClose(nil) }
            return false
        }
    }
}
