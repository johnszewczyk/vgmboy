import AppKit
import SwiftUI
import WebKit

struct ContentView: View {
    @Bindable var model: PlayerViewModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            PlayerWebView(model: model, isDropTargeted: $isDropTargeted)
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    }
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color.cyan)
                            Text("DROP AUDIO FILES OR ARCHIVES")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white)
                            Text("VGMBoy will prepare archive members for playback")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.7))
                        }
                    }
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .onOpenURL { model.load(fileURL: $0) }
    }
}

private func localFileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let fileURLObjects = pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [.urlReadingFileURLsOnly: true]
    ) ?? []
    let urls = fileURLObjects.compactMap { object -> URL? in
        guard let url = object as? URL, url.isFileURL else { return nil }
        return url.standardizedFileURL
    }

    let filenamesType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
    let filenameURLs = (pasteboard.propertyList(forType: filenamesType) as? [String] ?? [])
        .map { URL(fileURLWithPath: $0).standardizedFileURL }

    var seen = Set<URL>()
    return (urls + filenameURLs).filter { seen.insert($0).inserted }
}

private struct PlayerWebView: NSViewRepresentable {
    let model: PlayerViewModel
    @Binding var isDropTargeted: Bool

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "player")
        let view = DropHandlingWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        view.onDropTargetChanged = { [weak coordinator = context.coordinator] targeted in
            coordinator?.dropTargetChanged?(targeted)
        }
        view.onFileURLsDropped = { [weak coordinator = context.coordinator] urls in
            coordinator?.model.addFiles(urls)
        }
        context.coordinator.webView = view
        if let page = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Resources") {
            context.coordinator.pageURL = page
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.dropTargetChanged = { [dropTargetBinding = _isDropTargeted] targeted in
            dropTargetBinding.wrappedValue = targeted
        }
        context.coordinator.publish()
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "player")
        view.navigationDelegate = nil
        (view as? DropHandlingWebView)?.onDropTargetChanged = nil
        (view as? DropHandlingWebView)?.onFileURLsDropped = nil
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: PlayerViewModel
        weak var webView: WKWebView?
        var dropTargetChanged: ((Bool) -> Void)?
        var pageURL: URL?
        var ready = false
        var lastSnapshot: Data?

        init(model: PlayerViewModel) { self.model = model }

        func publish() {
            // Reading the snapshot also registers SwiftUI observation dependencies.
            let snapshot = model.webSnapshot
            guard ready, let data = try? JSONSerialization.data(withJSONObject: snapshot, options: .sortedKeys), data != lastSnapshot else { return }
            lastSnapshot = data
            webView?.callAsyncJavaScript("window.vgm.render(state)", arguments: ["state": snapshot], in: nil, in: .page, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  message.webView === webView,
                  message.frameInfo.request.url?.standardizedFileURL == pageURL?.standardizedFileURL,
                  let body = message.body as? [String: Any], let command = body["command"] as? String else { return }
            if command == "ready" { ready = true; lastSnapshot = nil }
            else { model.handleWebCommand(command, value: body["value"]) }
            publish()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.targetFrame?.isMainFrame == true && navigationAction.request.url?.standardizedFileURL == pageURL?.standardizedFileURL ? .allow : .cancel)
        }
    }
}

@MainActor
private final class DropHandlingWebView: WKWebView {
    var onDropTargetChanged: ((Bool) -> Void)?
    var onFileURLsDropped: (([URL]) -> Void)?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !localFileURLs(from: sender.draggingPasteboard).isEmpty else { return [] }
        onDropTargetChanged?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !localFileURLs(from: sender.draggingPasteboard).isEmpty else { return [] }
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDropTargetChanged?(false)
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        !localFileURLs(from: sender.draggingPasteboard).isEmpty
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = localFileURLs(from: sender.draggingPasteboard)
        onDropTargetChanged?(false)
        guard !urls.isEmpty else { return false }
        onFileURLsDropped?(urls)
        return true
    }
}
