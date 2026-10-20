import Foundation
import WebKit

/// Both navigation and native capabilities are restricted to the bundled app.
final class SB2WebContentPolicy: NSObject, WKNavigationDelegate {
    static func isTrustedDocument(_ url: URL?) -> Bool {
        guard let url, url.isFileURL,
              url.host == nil || url.host == "" || url.host == "localhost",
              let page = Bundle.module.url(forResource: "index", withExtension: "html") else { return false }
        return url.standardizedFileURL.resolvingSymlinksInPath().path
            == page.standardizedFileURL.resolvingSymlinksInPath().path
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(navigationAction.targetFrame?.isMainFrame == true
            && Self.isTrustedDocument(navigationAction.request.url) ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        decisionHandler(navigationResponse.isForMainFrame
            && Self.isTrustedDocument(navigationResponse.response.url) ? .allow : .cancel)
    }
}
