import AppKit
import Foundation
import ScanSongKit

/// Stores the last complete result for a root outside the canonical catalog.
/// The catalog remains one self-contained SQLite file; these human-readable
/// logs are optional per-source results and never affect a scan.
enum ScannerScanLogStore {
    static let maximumReadBytes = 2 * 1_024 * 1_024
    static let maximumRenderedLines = 2_000

    static func exists(databaseURL: URL, rootID: Int64) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(databaseURL: databaseURL, rootID: rootID).path)
    }

    static func discardAll(databaseURL: URL) {
        try? FileManager.default.removeItem(at: directoryURL(databaseURL: databaseURL))
    }

    static func read(databaseURL: URL, rootID: Int64) -> [String] {
        let url = fileURL(databaseURL: databaseURL, rootID: rootID)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maximumReadBytes),
              let contents = String(data: data, encoding: .utf8) else {
            return ["Unable to read the last scan log."]
        }
        var lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if fileSize > maximumReadBytes {
            lines.append("Log truncated after \(maximumReadBytes / 1_024 / 1_024) MiB to keep this window responsive.")
        }
        if lines.count > maximumRenderedLines {
            lines = Array(lines.prefix(maximumRenderedLines - 1))
            lines.append("Log truncated after \(maximumRenderedLines) lines to keep this window responsive.")
        }
        return lines
    }

    static func writeLastResult(
        databaseURL: URL,
        root: CatalogRoot,
        tally: CatalogScanTally,
        result: CatalogScanResult? = nil,
        terminalMessage: String? = nil
    ) {
        let url = fileURL(databaseURL: databaseURL, rootID: root.id)
        let terminal = terminalMessage ?? root.lastScanError
        let status = terminal == nil ? "complete" : "stopped"
        let resultText: String
        if let terminal, !terminal.isEmpty {
            resultText = terminal
        } else if let result {
            let sourceFailures = result.failures.filter { $0.identity.archiveEntry == nil }.count
            let memberFailures = result.failures.count - sourceFailures
            let visibleSkippedCount = result.skipped.filter {
                ScannerFormatPolicy.normalize($0.extensionName) != "png"
            }.count
            resultText = "\(result.discoveredSourceCount) discovered, \(result.scannedSourceCount) scanned, \(result.trackCount) tracks, \(result.reusedSourceCount) reused, \(sourceFailures) source failures, \(memberFailures) member failures, \(visibleSkippedCount) skipped"
        } else {
            resultText = "\(tally.sourceCount) files, \(root.lastScanTrackCount) tracks"
        }
        let lines = ScanLogFormatter.lines(
            status: status,
            summary: resultText,
            rootPath: root.path,
            failures: result?.failures ?? [],
            skipped: result?.skipped ?? []
        )

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let bounded = Array(lines.prefix(maximumRenderedLines - 1))
                + (lines.count > maximumRenderedLines ? ["Log truncated after \(maximumRenderedLines) lines."] : [])
            try bounded.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Logging must never make a successful scan fail.
        }
    }

    static func summary(root: CatalogRoot, tally: CatalogScanTally) -> String {
        let completed = root.lastScanCompletedAt.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short)
        } ?? "not completed"
        let duration = root.lastScanStartedAt.flatMap { startedAt in
            root.lastScanCompletedAt.map { completedAt in
                " • \(durationText(completedAt.timeIntervalSince(startedAt)))"
            }
        } ?? ""
        let issues = tally.failedSourceCount + tally.inactiveSourceCount + (root.lastScanError?.isEmpty == false ? 1 : 0)
        return "Last scan \(completed)\(duration) • \(tally.sourceCount) files • \(root.lastScanTrackCount) tracks • \(issues) issue\(issues == 1 ? "" : "s")"
    }

    private static func fileURL(databaseURL: URL, rootID: Int64) -> URL {
        directoryURL(databaseURL: databaseURL)
            .appendingPathComponent("root-\(rootID).log", isDirectory: false)
    }

    private static func directoryURL(databaseURL: URL) -> URL {
        let baseURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("ScanSong", isDirectory: true)
            .appendingPathComponent("ScanLogs", isDirectory: true)
            .appendingPathComponent(catalogIdentifier(for: databaseURL), isDirectory: true)
    }

    private static func catalogIdentifier(for databaseURL: URL) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in databaseURL.standardizedFileURL.path.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }

    private static func durationText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

}

@MainActor
final class ScannerScanLogWindow {
    private let window: NSWindow

    init(root: CatalogRoot, summary: String, lines: [String]) {
        let sections = ScannerScanLogSections(lines: lines)

        let summaryLabel = NSTextField(labelWithString: summary)
        summaryLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.maximumNumberOfLines = 1

        let operationLabel = NSTextField(labelWithString: sections.operationSummary ?? "No scan summary was recorded.")
        operationLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        operationLabel.textColor = .tertiaryLabelColor
        operationLabel.lineBreakMode = .byTruncatingTail
        operationLabel.maximumNumberOfLines = 1

        let tabs = NSTabView()
        tabs.tabViewType = .topTabsBezelBorder
        tabs.addTabViewItem(Self.makeTab(
            title: "Failures",
            rows: sections.failures,
            emptyMessage: "No failures were recorded for this path.",
            truncated: sections.isTruncated
        ))
        tabs.addTabViewItem(Self.makeTab(
            title: "Unrecognized",
            rows: sections.unrecognized,
            emptyMessage: "No unrecognized files were recorded for this path.",
            truncated: sections.isTruncated
        ))
        tabs.addTabViewItem(Self.makeTab(
            title: "Ignored",
            rows: sections.ignored,
            emptyMessage: "No ignored files were recorded for this path.",
            truncated: sections.isTruncated
        ))

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 6
        content.addArrangedSubview(summaryLabel)
        content.addArrangedSubview(operationLabel)
        content.addArrangedSubview(tabs)
        summaryLabel.heightAnchor.constraint(equalToConstant: 22).isActive = true
        operationLabel.heightAnchor.constraint(equalToConstant: 18).isActive = true
        tabs.widthAnchor.constraint(greaterThanOrEqualToConstant: 680).isActive = true
        tabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        let rootView = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12)
        ])

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 720, height: 450)
        window.title = "Scan Log — \(URL(fileURLWithPath: root.path).lastPathComponent)"
        window.contentView = rootView
        window.center()
        window.isReleasedWhenClosed = false
    }

    private static func makeTab(
        title: String,
        rows: [String],
        emptyMessage: String,
        truncated: Bool
    ) -> NSTabViewItem {
        let item = NSTabViewItem(identifier: title)
        item.label = "\(title) · \(rows.count)\(truncated ? "+" : "")"

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .secondaryLabelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = rows.isEmpty ? emptyMessage : rows.joined(separator: "\n").appending("\n")

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.documentView = textView
        item.view = scrollView
        return item
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }
}

private struct ScannerScanLogSections {
    var operationSummary: String?
    var failures: [String] = []
    var unrecognized: [String] = []
    var ignored: [String] = []
    var isTruncated = false

    init(lines: [String]) {
        var containsFilteredPNG = false
        for line in lines {
            if line == ScanLogFormatter.header { continue }
            if line.hasPrefix("Log truncated") {
                isTruncated = true
                operationSummary = [operationSummary, line].compactMap { $0 }.joined(separator: " • ")
                continue
            }
            if line.hasPrefix("Unable to read") {
                operationSummary = [operationSummary, line].compactMap { $0 }.joined(separator: " • ")
                continue
            }
            guard let firstSeparator = line.range(of: " | "),
                  let secondSeparator = line.range(of: " | ", range: firstSeparator.upperBound..<line.endIndex) else {
                continue
            }

            let status = String(line[..<firstSeparator.lowerBound])
            let detail = String(line[firstSeparator.upperBound..<secondSeparator.lowerBound])
            let path = String(line[secondSeparator.upperBound...])
            if status == "complete" || status == "stopped" {
                operationSummary = detail
                continue
            }
            guard !Self.isPNGDiagnostic(detail: detail, path: path) else {
                containsFilteredPNG = true
                continue
            }

            switch status {
            case "ignored": ignored.append(line)
            case "unrecognized": unrecognized.append(line)
            default: failures.append(line)
            }
        }
        if isTruncated || containsFilteredPNG {
            operationSummary = operationSummary.map(Self.omitStaleSkippedTotal)
        }
    }

    private static func isPNGDiagnostic(detail: String, path: String) -> Bool {
        detail.localizedCaseInsensitiveContains("(.png")
            || URL(fileURLWithPath: path).pathExtension.lowercased() == "png"
    }

    private static func omitStaleSkippedTotal(_ summary: String) -> String {
        summary.replacingOccurrences(of: #", \d+ skipped\b"#, with: "", options: .regularExpression)
    }
}
