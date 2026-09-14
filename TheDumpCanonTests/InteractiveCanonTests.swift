import XCTest
import WebKit
import UIKit
@testable import The_Dump

@MainActor
final class InteractiveCanonTests: XCTestCase {
    func testLegacyAndInteractiveDocumentsDecodeWithMarkdownFallback() throws {
        let base: [String: Any] = ["document_id": "doc", "slug": "roadmap", "title": "Roadmap",
                                   "body": "# Accessible roadmap", "revision": 3]
        func decode(_ fields: [String: Any]) throws -> RoutineDocument {
            try JSONDecoder().decode(RoutineDocument.self, from: JSONSerialization.data(withJSONObject: fields))
        }
        XCTAssertNil(try decode(base).interactiveHTML)
        var fields = base
        fields["interactive_html"] = NSNull()
        XCTAssertNil(try decode(fields).interactiveHTML)
        fields["interactive_html"] = "<button>Next</button>"
        let document = try decode(fields)
        XCTAssertEqual(document.interactiveHTML, "<button>Next</button>")
        XCTAssertEqual(document.body, "# Accessible roadmap")
        XCTAssertEqual(document.revision, 3)
    }

    func testMarkupCannotBreakOutOfSrcdocAttribute() {
        let attack = #"\"><script>parent.location='https://example.invalid'</script>&quot;"#
        let wrapper = InteractiveCanonPolicy.htmlDocument(attack)
        XCTAssertFalse(wrapper.contains(attack))
        XCTAssertTrue(wrapper.contains("sandbox=\"allow-scripts\""))
        XCTAssertFalse(wrapper.contains("allow-same-origin"))
        XCTAssertFalse(wrapper.contains("allow-top-navigation"))
        XCTAssertTrue(wrapper.contains("&amp;quot;"))
        XCTAssertTrue(wrapper.contains("&lt;script&gt;"))
    }

    func testNavigationAllowsOnlyInitialHostAndSrcdoc() {
        XCTAssertTrue(InteractiveCanonPolicy.allowsNavigation(to: URL(string: "about:blank"), isMainFrame: true, initialLoad: true))
        XCTAssertFalse(InteractiveCanonPolicy.allowsNavigation(to: URL(string: "about:blank"), isMainFrame: true, initialLoad: false))
        XCTAssertTrue(InteractiveCanonPolicy.allowsNavigation(to: URL(string: "about:srcdoc#milestone"), isMainFrame: false, initialLoad: false))
        for destination in ["https://example.com", "http://localhost", "file:///etc/passwd", "data:text/html,test",
                            "javascript:alert(1)", "thedump://note/123", "about:blank", "about:srcdoc.evil"] {
            XCTAssertFalse(InteractiveCanonPolicy.allowsNavigation(to: URL(string: destination), isMainFrame: false, initialLoad: false), destination)
        }
    }

    func testWebKitExecutesControlsButIsolatesOriginAndBlocksNetwork() async throws {
        let received = expectation(description: "Sandboxed document reports its behavior")
        let capture = TestCapture(expectation: received)
        let configuration = InteractiveCanonView.configuration()
        // Test-only observation channel. The production viewer registers none.
        configuration.userContentController.add(capture, name: "testCapture")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: configuration)
        let window = host(webView)
        defer { window.isHidden = true }
        let coordinator = InteractiveCanonView.Coordinator { XCTFail("Interactive viewer failed to load") }
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        coordinator.load(#"""
        <button id="next" onclick="this.textContent='Next milestone'">Now</button>
        <script>
        const result = { violations: [] };
        let reported = false;
        function report() {
          if (reported) return;
          reported = true;
          window.webkit.messageHandlers.testCapture.postMessage(result);
        }
        function reportWhenReady() {
          if (result.nestedRTCBlocked !== undefined && result.violations.includes('connect-src') && result.violations.includes('img-src')) report();
        }
        document.addEventListener('securitypolicyviolation', event => {
          result.violations.push(event.effectiveDirective);
          reportWhenReady();
        });
        try { parent.document.body.innerHTML = 'escaped'; result.parentBlocked = false; } catch (_) { result.parentBlocked = true; }
        try { localStorage.setItem('secret', 'test'); result.storageBlocked = false; } catch (_) { result.storageBlocked = true; }
        document.getElementById('next').click();
        result.button = document.getElementById('next').textContent;
        result.width = window.innerWidth;
        result.rtcBlocked = typeof RTCPeerConnection === 'undefined' && typeof webkitRTCPeerConnection === 'undefined';
        try { window.RTCPeerConnection = function() {}; } catch (_) {}
        result.rtcFrozen = typeof RTCPeerConnection === 'undefined';
        window.addEventListener('message', event => {
          if (event.data && event.data.nestedRTC !== undefined) {
            result.nestedRTCBlocked = event.data.nestedRTC;
            reportWhenReady();
          }
        });
        const nested = document.createElement('iframe');
        nested.srcdoc = '<scr' + 'ipt>parent.postMessage({nestedRTC: typeof RTCPeerConnection === "undefined"}, "*")<' + '/script>';
        document.body.append(nested);
        fetch('https://example.invalid/canon-security-check').catch(() => {});
        const img = new Image(); img.src = 'https://example.invalid/canon-image-check'; document.body.append(img);
        // Report partial results on failure, while normally synchronizing on
        // actual events instead of racing first-launch WebKit subprocesses.
        setTimeout(report, 30000);
        </script>
        """#, in: webView)
        await fulfillment(of: [received], timeout: 60)
        XCTAssertEqual(capture.result?["parentBlocked"] as? Bool, true)
        XCTAssertEqual(capture.result?["storageBlocked"] as? Bool, true)
        XCTAssertEqual(capture.result?["button"] as? String, "Next milestone")
        XCTAssertEqual(capture.result?["width"] as? Int, 390)
        XCTAssertEqual(capture.result?["rtcBlocked"] as? Bool, true)
        XCTAssertEqual(capture.result?["rtcFrozen"] as? Bool, true)
        XCTAssertEqual(capture.result?["nestedRTCBlocked"] as? Bool, true)
        let violations = capture.result?["violations"] as? [String] ?? []
        XCTAssertTrue(violations.contains("connect-src"))
        XCTAssertTrue(violations.contains("img-src"))
        webView.stopLoading()
        configuration.userContentController.removeScriptMessageHandler(forName: "testCapture")
        _ = coordinator // Retain the delegate until completion.
    }

    private func host(_ webView: WKWebView) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: webView.frame)
        let controller = UIViewController()
        controller.view.addSubview(webView)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return window
    }

    func testFileInputAndSensorDelegatesDenyNativeAccess() async throws {
        let ready = expectation(description: "File-input fixture is ready")
        let denied = expectation(description: "WebKit file request is denied by the production delegate")
        let capture = TestCapture(expectation: ready)
        let configuration = InteractiveCanonView.configuration()
        configuration.userContentController.add(capture, name: "testCapture")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: configuration)
        let window = host(webView)
        defer {
            window.isHidden = true
            webView.stopLoading()
            configuration.userContentController.removeScriptMessageHandler(forName: "testCapture")
        }
        let coordinator = InteractiveCanonView.Coordinator { XCTFail("Permission fixture failed to load") }
        let observer = FilePanelObserver(coordinator: coordinator, denied: denied)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = observer
        coordinator.load(#"""
        <input id="file" type="file" aria-label="Choose a file">
        <script>window.webkit.messageHandlers.testCapture.postMessage({ready:true});</script>
        """#, in: webView)
        await fulfillment(of: [ready], timeout: 60)
        let frame = try XCTUnwrap(capture.frame)
        // WebKit evaluates this with native user activation. The generated
        // frame remains sandboxed; no actual file is selected by the test.
        _ = try await webView.callAsyncJavaScript("document.getElementById('file').click();",
                                                  arguments: [:], in: frame, contentWorld: .page)
        await fulfillment(of: [denied], timeout: 15)
        XCTAssertEqual(observer.requests, 1)

        // Opaque-origin/CSP checks normally stop media requests before the
        // native delegate. Exercise its independent denial if one reaches it.
        var decisions = 0
        for type in [WKMediaCaptureType.camera, .microphone, .cameraAndMicrophone] {
            coordinator.webView(webView, requestMediaCapturePermissionFor: frame.securityOrigin,
                                initiatedByFrame: frame, type: type) { decision in
                XCTAssertEqual(decision, .deny)
                decisions += 1
            }
        }
        coordinator.webView(webView, requestDeviceOrientationAndMotionPermissionFor: frame.securityOrigin,
                            initiatedByFrame: frame) { decision in
            XCTAssertEqual(decision, .deny)
            decisions += 1
        }
        XCTAssertEqual(decisions, 4)
        _ = observer
    }

    func testRoadmapRendersAndFiltersAtPhoneWidth() async throws {
        let received = expectation(description: "Roadmap control updates visible milestones")
        let capture = TestCapture(expectation: received)
        let configuration = InteractiveCanonView.configuration()
        configuration.userContentController.add(capture, name: "testCapture")
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: configuration)
        let window = host(webView)
        defer { window.isHidden = true }
        let coordinator = InteractiveCanonView.Coordinator { XCTFail("Roadmap failed to load") }
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        coordinator.load(#"""
        <style>
        *{box-sizing:border-box}body{margin:0;padding:24px;font:16px -apple-system,sans-serif;background:#f4f2ec;color:#203d35}
        h1{font-size:32px;letter-spacing:-1px;margin:8px 0}small{letter-spacing:2px}p{line-height:1.5}
        select{width:100%;padding:12px;font:inherit;border:1px solid #bac9c2;border-radius:8px;background:white}
        .cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:20px}
        article{padding:20px;background:white;border-radius:12px}article[hidden]{display:none}
        @media(max-width:600px){.cards{grid-template-columns:1fr}}
        </style><small>PRODUCT ROADMAP</small><h1>Make room for what's next.</h1>
        <p>A living plan from your notes. Explore priorities and milestones.</p>
        <label for="phase">Planning horizon</label><select id="phase"><option value="all">All horizons</option><option value="next">Next</option></select>
        <section class="cards"><article data-phase="now"><small>NOW</small><h2>Capture the essentials</h2><p>Bring project notes into one place.</p></article>
        <article data-phase="next"><small>NEXT</small><h2>See the bigger picture</h2><p>Turn notes into useful, interactive roadmaps.</p><details><summary>Milestone details</summary><p>Release the first read-only viewer.</p></details></article>
        <article data-phase="later"><small>LATER</small><h2>Keep plans connected</h2><p>Explore relationships across your projects.</p></article></section>
        <script>
        const select = document.getElementById('phase');
        select.onchange = () => document.querySelectorAll('article').forEach(card => card.hidden = select.value !== 'all' && card.dataset.phase !== select.value);
        select.value = 'next'; select.dispatchEvent(new Event('change'));
        document.querySelector('details').open = true;
        window.webkit.messageHandlers.testCapture.postMessage({visible:document.querySelectorAll('article:not([hidden])').length,
          width:window.innerWidth, contentWidth:document.documentElement.scrollWidth, expanded:document.querySelector('details').open});
        </script>
        """#, in: webView)
        await fulfillment(of: [received], timeout: 60)
        XCTAssertEqual(capture.result?["visible"] as? Int, 1)
        XCTAssertEqual(capture.result?["width"] as? Int, 390)
        XCTAssertEqual(capture.result?["contentWidth"] as? Int, 390)
        XCTAssertEqual(capture.result?["expanded"] as? Bool, true)
        let snapshot = try await webView.takeSnapshot(configuration: nil)
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Interactive roadmap at phone width"
        attachment.lifetime = .keepAlways
        add(attachment)
        webView.stopLoading()
        configuration.userContentController.removeScriptMessageHandler(forName: "testCapture")
        _ = coordinator
    }
}

private final class TestCapture: NSObject, WKScriptMessageHandler {
    let expectation: XCTestExpectation
    var result: [String: Any]?
    var frame: WKFrameInfo?

    init(expectation: XCTestExpectation) { self.expectation = expectation }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard result == nil else { return }
        result = message.body as? [String: Any]
        frame = message.frameInfo
        expectation.fulfill()
    }
}

@MainActor
private final class FilePanelObserver: NSObject, WKUIDelegate {
    let coordinator: InteractiveCanonView.Coordinator
    let denied: XCTestExpectation
    var requests = 0

    init(coordinator: InteractiveCanonView.Coordinator, denied: XCTestExpectation) {
        self.coordinator = coordinator
        self.denied = denied
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        requests += 1
        coordinator.webView(webView, runOpenPanelWith: parameters, initiatedByFrame: frame) { urls in
            XCTAssertNil(urls)
            completionHandler(urls)
            self.denied.fulfill()
        }
    }
}
