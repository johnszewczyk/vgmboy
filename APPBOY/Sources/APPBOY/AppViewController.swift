import UIKit
import WebKit

@MainActor
final class AppViewController: UIViewController {
    private static let obsidianColor = UIColor(red: 9.0 / 255.0, green: 11.0 / 255.0, blue: 15.0 / 255.0, alpha: 1.0)

    private let store = AppBoyStore()
    private let playback = AppBoyPlaybackCoordinator()
    private let webContentPolicy = AppBoyWebContentPolicy()
    private lazy var nativeBridge = AppBoyNativeBridge(store: store, playback: playback)
    private var webView: WKWebView?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.obsidianColor

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(nativeBridge, name: "appBoy")
        configuration.userContentController.addUserScript(nativeBridge.userScript())

        let wk = WKWebView(frame: view.bounds, configuration: configuration)
        wk.translatesAutoresizingMaskIntoConstraints = false
        wk.isOpaque = false
        wk.backgroundColor = Self.obsidianColor
        wk.scrollView.backgroundColor = Self.obsidianColor
        wk.scrollView.contentInsetAdjustmentBehavior = .never
        wk.scrollView.bounces = false
        wk.scrollView.showsHorizontalScrollIndicator = false
        wk.scrollView.showsVerticalScrollIndicator = false
        wk.navigationDelegate = webContentPolicy
        wk.uiDelegate = webContentPolicy

        view.addSubview(wk)
        NSLayoutConstraint.activate([
            wk.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wk.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wk.topAnchor.constraint(equalTo: view.topAnchor),
            wk.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        nativeBridge.attach(to: wk)
        webView = wk

        if let indexURL = AppBoyResourceLocator.indexPageURL(),
           let webRoot = AppBoyResourceLocator.webRootURL() {
            wk.loadFileURL(indexURL, allowingReadAccessTo: webRoot)
        }
    }

    func handleDeepLink(_ url: URL) {
        nativeBridge.emitDeepLink(url: url)
    }

    func flushFrontendState() async {
        guard let webView else { return }
        _ = try? await webView.callAsyncJavaScript(
            "if (window.APPBOY?.flushPendingState) { await window.APPBOY.flushPendingState(); } return true;",
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }
}
