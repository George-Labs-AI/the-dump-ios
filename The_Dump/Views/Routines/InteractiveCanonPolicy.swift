import Foundation

/// Defense in depth: an opaque iframe origin, a policy before any generated
/// markup, an inherited parent policy, a native resource blocker, and native
/// navigation filtering. No generated content is interpolated as parent markup.
enum InteractiveCanonPolicy {
    static let contentSecurityPolicy = "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:; font-src data:; media-src data:; base-uri 'none'; form-action 'none'; frame-src 'none'; worker-src 'none'; connect-src 'none'; webrtc 'block'"

    // Additional defense where CSP's webrtc directive is not implemented.
    // This runs before page scripts in every frame, including nested srcdocs.
    static let disableRealtimeNetworking = """
    (() => {
      for (const name of ['RTCPeerConnection', 'webkitRTCPeerConnection', 'RTCDataChannel', 'WebTransport']) {
        try { Object.defineProperty(globalThis, name, {value: undefined, writable: false, configurable: false}); } catch (_) {}
      }
    })();
    """

    static let networkRules = #"[{"trigger":{"url-filter":"^[a-zA-Z][a-zA-Z0-9+.-]*://"},"action":{"type":"block"}}]"#

    static func htmlDocument(_ html: String) -> String {
        let policy = "<meta http-equiv=\"Content-Security-Policy\" content=\"\(contentSecurityPolicy)\">"
        let viewport = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        let inner = "<!doctype html><html><head><meta charset=\"utf-8\">\(policy)\(viewport)</head><body>\(html)</body></html>"
        return """
        <!doctype html><html><head><meta charset="utf-8">\(policy)\(viewport)
        <style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:white}iframe{display:block;border:0;width:100%;height:100%}</style>
        </head><body><iframe title="Interactive canon document" sandbox="allow-scripts" referrerpolicy="no-referrer" allow="camera 'none'; microphone 'none'; geolocation 'none'; clipboard-read 'none'; clipboard-write 'none'; payment 'none'; fullscreen 'none'" srcdoc="\(escapeAttribute(inner))"></iframe></body></html>
        """
    }

    static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Only the host's initial blank document and its srcdoc frame can load.
    /// Links (including source notes) are available in the native Text view.
    static func allowsNavigation(to url: URL?, isMainFrame: Bool, initialLoad: Bool) -> Bool {
        guard let url else { return false }
        if isMainFrame { return initialLoad && url.absoluteString == "about:blank" }
        let withoutFragment = url.absoluteString.components(separatedBy: "#")[0]
        return withoutFragment == "about:srcdoc"
    }
}
