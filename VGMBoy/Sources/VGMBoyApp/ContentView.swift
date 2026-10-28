import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ContentView: View {
    @Bindable var model: PlayerViewModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            PlayerWebView(model: model)
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
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .onOpenURL { model.load(fileURL: $0) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return false }

        Task { @MainActor in
            var urls: [URL] = []
            for provider in fileProviders {
                if let url = await droppedFileURL(from: provider) {
                    urls.append(url)
                }
            }
            guard !urls.isEmpty else {
                model.errorMessage = "The dropped items did not contain accessible file URLs."
                return
            }
            model.addFiles(urls)
        }
        return true
    }
}

@MainActor
private func droppedFileURL(from provider: NSItemProvider) async -> URL? {
    await withCheckedContinuation { continuation in
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let value = item as? URL {
                url = value
            } else if let value = item as? Data {
                url = URL(dataRepresentation: value, relativeTo: nil)
            } else if let value = item as? String {
                if let parsed = URL(string: value), parsed.isFileURL {
                    url = parsed
                } else {
                    url = URL(fileURLWithPath: value)
                }
            } else {
                url = nil
            }
            continuation.resume(returning: url?.isFileURL == true ? url?.standardizedFileURL : nil)
        }
    }
}

private struct PlayerWebView: NSViewRepresentable {
    let model: PlayerViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "player")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = view
        if let page = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Resources") {
            context.coordinator.pageURL = page
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.publish()
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "player")
        view.navigationDelegate = nil
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: PlayerViewModel
        weak var webView: WKWebView?
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
