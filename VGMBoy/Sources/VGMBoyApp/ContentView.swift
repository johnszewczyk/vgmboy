import SwiftUI
import WebKit

struct ContentView: View {
    @Bindable var model: PlayerViewModel

    var body: some View {
        PlayerWebView(model: model)
            .frame(minWidth: 760, minHeight: 560)
            .onOpenURL { model.load(fileURL: $0) }
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

    func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.publish() }

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
