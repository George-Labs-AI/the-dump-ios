#if DEBUG
import Foundation

/// Debug builds only: points the app and the share extension at a web server
/// other than thedump.ai (for example a test server, or a server running on
/// this Mac) without editing code. None of this is
/// compiled into Release builds, so App Store builds always use
/// `SharedConstants.defaultBaseURL`.
///
/// To use it, launch the app with the argument pair `-DumpServerURL <url>`:
///
///     xcrun simctl launch <simulator id> George-Labs.The-Dump-App-Two \
///         -DumpServerURL https://<test-server-host>
///
/// or add the same two arguments under Edit Scheme > Run > Arguments. Launch
/// again without them to go back to thedump.ai. Only https addresses are
/// accepted, plus http://localhost and http://127.0.0.1 for a local server;
/// anything else is ignored and the default is used.
enum ServerOverride {
    /// UserDefaults key. The launch argument sets it in the app's standard
    /// defaults for that launch only.
    nonisolated static let key = "DumpServerURL"

    /// `raw` as a base URL with no trailing slash (every call site appends a
    /// path that starts with "/"), or nil when it is missing or not allowed.
    nonisolated static func validatedBaseURL(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/"
        else { return nil }

        switch scheme {
        case "https":
            break
        case "http" where host == "localhost" || host == "127.0.0.1":
            break
        default:
            return nil
        }

        var base = trimmed
        while base.hasSuffix("/") { base.removeLast() }
        return base
    }

    /// The server this process should use. The share extension runs as its
    /// own process and never sees the app's launch arguments, so the app
    /// copies what it was launched with into the App Group defaults (and
    /// clears the copy when launched without it), and the extension reads
    /// that copy.
    nonisolated static func resolvedBaseURL(
        defaultURL: String,
        standard: UserDefaults,
        shared: UserDefaults?,
        isExtension: Bool
    ) -> String {
        let raw: String?
        if isExtension {
            raw = shared?.string(forKey: key)
        } else {
            raw = standard.string(forKey: key)
            if let raw {
                shared?.set(raw, forKey: key)
            } else {
                shared?.removeObject(forKey: key)
            }
        }
        return validatedBaseURL(raw) ?? defaultURL
    }
}
#endif
