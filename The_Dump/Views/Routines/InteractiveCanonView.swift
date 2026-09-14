import SwiftUI
import WebKit

/// A fresh, ephemeral viewer for each document. It has no native script message
/// handlers, account cookies, file access, persistent storage, or external links.
struct InteractiveCanonView: UIViewRepresentable {
    let html: String
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFailure: onFailure) }

    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.addUserScript(WKUserScript(
            source: InteractiveCanonPolicy.disableRealtimeNetworking,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        ))
        return configuration
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.isOpaque = false
        webView.backgroundColor = .white
        // CSS fixes the host viewport; keep native scrolling enabled so long
        // iframe documents still respond to touch and accessibility gestures.
        webView.scrollView.bounces = false
        context.coordinator.load(html, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onFailure = onFailure
        if context.coordinator.html != html { context.coordinator.load(html, in: webView) }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.active = false
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var onFailure: () -> Void
        var html: String?
        var active = true
        private var initialLoad = true

        init(onFailure: @escaping () -> Void) { self.onFailure = onFailure }

        func load(_ html: String, in webView: WKWebView) {
            self.html = html
            initialLoad = true
            // Fail closed: never load generated scripts before the blocker is
            // installed, even when the platform cannot compile the rule list.
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "canon-offline-v1",
                encodedContentRuleList: InteractiveCanonPolicy.networkRules
            ) { [weak self, weak webView] rules, _ in
                guard let self, self.active, self.html == html, let webView else { return }
                guard let rules else { self.onFailure(); return }
                webView.configuration.userContentController.removeAllContentRuleLists()
                webView.configuration.userContentController.add(rules)
                webView.loadHTMLString(InteractiveCanonPolicy.htmlDocument(html), baseURL: nil)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.targetFrame else { decisionHandler(.cancel); return }
            let allowed = InteractiveCanonPolicy.allowsNavigation(
                to: navigationAction.request.url, isMainFrame: target.isMainFrame, initialLoad: initialLoad
            )
            if allowed && target.isMainFrame { initialLoad = false }
            decisionHandler(allowed ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failUnlessCancelled(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failUnlessCancelled(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            if active { onFailure() }
        }

        private func failUnlessCancelled(_ error: Error) {
            let nsError = error as NSError
            if active && !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) {
                onFailure()
            }
        }

        // Interactive documents consume only their published content. They do
        // not need user-selected files or native sensor permissions.
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            completionHandler(nil)
        }

        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.deny)
        }

        func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.deny)
        }

        // Generated alert/confirm/prompt calls must not create native UI.
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(false)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            completionHandler(nil)
        }
    }
}
