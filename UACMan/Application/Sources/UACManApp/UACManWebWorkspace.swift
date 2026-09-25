import AppKit
import SwiftUI
import WebKit
import UACManCore

struct UACManWebWorkspace: NSViewRepresentable {
    let model: UACManModel
    let snapshot: [String: Any]

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "uacman")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        let resourceBundleURL = Bundle.main.resourceURL?.appendingPathComponent("UACMan_UACManApp.bundle")
        let resourceBundle = resourceBundleURL.flatMap { Bundle(url: $0) }
        guard let page = resourceBundle?.url(forResource: "index", withExtension: "html")
            ?? Bundle.module.url(forResource: "index", withExtension: "html") else {
            fatalError("UACMan web workspace resources are missing index.html")
        }
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.snapshot = snapshot
        context.coordinator.renderIfReady()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let model: UACManModel
        weak var webView: WKWebView?
        var snapshot: [String: Any] = [:]
        private var pageReady = false

        init(model: UACManModel) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            renderIfReady()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
        }

        func renderIfReady() {
            guard pageReady, let webView else { return }
            webView.callAsyncJavaScript(
                "window.UACMan && window.UACMan.render(state)",
                arguments: ["state": snapshot],
                in: nil,
                in: .page
            ) { _ in }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let payload = message.body as? [String: Any],
                  let action = payload["action"] as? String else { return }

            switch action {
            case "openUAC": model.openPanel()
            case "openCollection": model.openCollectionPanel()
            case "rescanCollection":
                if let path = model.collectionRootURL?.path {
                    model.openCollection(URL(fileURLWithPath: path))
                }
            case "cancelCollectionScan": model.cancelCurrentCollectionScan()
            case "chooseTagAnalyzerFolder": model.chooseTagAnalyzerFolderPanel()
            case "cancelTagAnalysis": model.cancelTagAnalysis()
            case "loadTagAnalyzerMatches":
                model.loadTagAnalyzerMatches(tagName: payload["tagName"] as? String ?? "")
            case "commitTagAnalyzerMatch":
                model.commitTagAnalyzerMatch(
                    tagName: payload["tagName"] as? String ?? "",
                    archiveRelativePath: payload["archiveRelativePath"] as? String ?? "",
                    memberRelativePath: payload["memberRelativePath"] as? String ?? "",
                    storageScope: payload["storageScope"] as? String ?? "",
                    storageKey: payload["storageKey"] as? String ?? "",
                    expectedValueJSON: payload["expectedValueJSON"] as? String ?? "",
                    newName: payload["newName"] as? String ?? "",
                    value: payload["value"] as? String ?? "",
                    valueIsJSON: payload["valueIsJSON"] as? Bool ?? false
                )
            case "deleteTagAnalyzerMatch":
                model.deleteTagAnalyzerMatch(
                    tagName: payload["tagName"] as? String ?? "",
                    archiveRelativePath: payload["archiveRelativePath"] as? String ?? "",
                    memberRelativePath: payload["memberRelativePath"] as? String ?? "",
                    storageScope: payload["storageScope"] as? String ?? "",
                    storageKey: payload["storageKey"] as? String ?? "",
                    expectedValueJSON: payload["expectedValueJSON"] as? String ?? ""
                )
            case "selectPackage":
                if let path = payload["path"] as? String { model.selectCollectionPackage(path) }
            case "selectMember":
                if let path = payload["path"] as? String { model.selectMember(path) }
            case "previewMember":
                if let path = payload["path"] as? String { model.previewMember(path: path) }
            case "closeFilePreview": model.closeFilePreview()
            case "save": model.save()
            case "revert": model.revert()
            case "harvest": model.harvestSPCMetadata()
            case "replaceHarvest": model.harvestSPCMetadata(replaceExisting: true)
            case "cancelHarvest": model.cancelSPCMetadataHarvest()
            case "renameMetadataKey":
                model.renameMetadataKey(
                    from: payload["from"] as? String ?? "",
                    to: payload["to"] as? String ?? ""
                )
            case "addMetadataKey":
                model.addMetadataKey(
                    key: payload["key"] as? String ?? "",
                    scope: payload["scope"] as? String ?? "package",
                    value: payload["value"] as? String ?? ""
                )
            case "deleteMetadataKey":
                model.deleteMetadataKey(key: payload["key"] as? String ?? "", scope: payload["scope"] as? String ?? "")
            case "updateMetadataValue":
                model.updateMetadataValue(key: payload["key"] as? String ?? "", scope: payload["scope"] as? String ?? "", value: payload["value"] as? String ?? "")
            case "commitMetadataRow":
                model.commitMetadataRow(key: payload["key"] as? String ?? "", newKey: payload["newKey"] as? String ?? "", scope: payload["scope"] as? String ?? "", value: payload["value"] as? String, structuredValueJSON: payload["valueJSON"] as? String)
            case "renameMember":
                model.renameMember(path: payload["path"] as? String ?? "", name: payload["name"] as? String ?? "")
            case "addMemberTag":
                model.addMemberTag(path: payload["path"] as? String ?? "", scope: payload["scope"] as? String ?? "memberMetadata", key: payload["key"] as? String ?? "", value: payload["value"] as? String ?? "")
            case "addMemberTags":
                model.addMemberTags(paths: payload["paths"] as? [String] ?? [], key: payload["key"] as? String ?? "", value: payload["value"] as? String ?? "")
            case "commitMemberTag":
                model.commitMemberTag(path: payload["path"] as? String ?? "", scope: payload["scope"] as? String ?? "memberMetadata", key: payload["key"] as? String ?? "", newKey: payload["newKey"] as? String ?? "", value: payload["value"] as? String ?? "", structuredValueJSON: payload["valueJSON"] as? String)
            case "deleteMemberTag":
                model.deleteMemberTag(path: payload["path"] as? String ?? "", scope: payload["scope"] as? String ?? "memberMetadata", key: payload["key"] as? String ?? "")
            case "commitTechnicalRow":
                model.commitTechnicalRow(scope: payload["scope"] as? String ?? "", key: payload["key"] as? String ?? "", newKey: payload["newKey"] as? String ?? "", value: payload["value"] as? String ?? "")
            case "deleteTechnicalRow":
                model.deleteTechnicalRow(scope: payload["scope"] as? String ?? "", key: payload["key"] as? String ?? "")
            case "setPackageTitle":
                model.packageTitle = payload["value"] as? String ?? ""
                model.markEdited()
            case "setConsole":
                model.consoleName = payload["value"] as? String ?? ""
                model.markEdited()
            case "setGameMetadata":
                model.gameMetadataJSON = payload["value"] as? String ?? "{}"
                model.markEdited()
            case "setGameExtensions":
                model.gameExtensionsJSON = payload["value"] as? String ?? "{}"
                model.markEdited()
            case "setMemberMetadata":
                model.memberMetadataJSON = payload["value"] as? String ?? "{}"
                model.markMemberEdited()
            case "setMemberExtensions":
                model.memberExtensionsJSON = payload["value"] as? String ?? "{}"
                model.markEdited()
            case "dismissError": model.errorMessage = nil
            default: break
            }
        }
    }
}
