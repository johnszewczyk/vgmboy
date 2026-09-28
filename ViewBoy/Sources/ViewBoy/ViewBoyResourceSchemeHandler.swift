import Foundation
import WebKit

/// Serves only ViewBoy's packaged interface resources under one same-origin
/// URL, so WebKit can load ES modules without granting file:// directory access.
final class ViewBoyResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    private static let resourceTypes: [String: String] = [
        "index.html": "text/html",
        "yoga-screen.css": "text/css",
        "yoga-app.js": "text/javascript",
        "yoga-layout.js": "text/javascript",
        "yoga-YGEnums.js": "text/javascript",
        "yoga-wasm-base64-esm.js": "text/javascript",
        "yoga-wrapAssembly.js": "text/javascript",
        "yoga-LICENSE.txt": "text/plain"
    ]

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              url.scheme == "viewboy",
              url.host == "app",
              url.pathComponents.count == 2,
              let mimeType = Self.resourceTypes[url.lastPathComponent],
              let resourceURL = Bundle.module.url(
                forResource: URL(fileURLWithPath: url.lastPathComponent).deletingPathExtension().lastPathComponent,
                withExtension: URL(fileURLWithPath: url.lastPathComponent).pathExtension
              ),
              let data = try? Data(contentsOf: resourceURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "\(mimeType); charset=utf-8",
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "no-store"
            ]
        ) else {
            urlSchemeTask.didFailWithError(URLError(.cannotParseResponse))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
