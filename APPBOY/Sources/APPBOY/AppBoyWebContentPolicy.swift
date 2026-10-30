import Foundation
import WebKit

/// Restricts navigation and native bridge calls strictly to the bundled WebUI index document.
@MainActor
final class AppBoyWebContentPolicy: NSObject, WKNavigationDelegate, WKUIDelegate {
    nonisolated static func isTrustedDocument(_ url: URL?) -> Bool {
        guard let url,
              url.isFileURL,
              url.host == nil || url.host == "" || url.host == "localhost",
              let page = AppBoyResourceLocator.indexPageURL() else {
            return false
        }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
            == page.standardizedFileURL.resolvingSymlinksInPath().path
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let allowed = navigationAction.targetFrame?.isMainFrame == true
            && Self.isTrustedDocument(navigationAction.request.url)
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
    ) {
        let allowed = navigationResponse.isForMainFrame
            && Self.isTrustedDocument(navigationResponse.response.url)
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }
}
