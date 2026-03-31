import Foundation

enum SharedConstants {
    /// App Group identifier shared between the main app and the share extension.
    static let appGroupID = "group.George-Labs.The-Dump-App-Two"

    /// Backend base URL.
    static let baseURL = "https://thedump.ai"

    /// Ingest endpoint path.
    static let ingestEndpoint = "/api/ingest"

    /// UserDefaults key for the cached Firebase ID token.
    static let tokenKey = "shared_firebase_id_token"

    /// UserDefaults key for the token expiry date.
    static let tokenExpiryKey = "shared_firebase_token_expiry"

    /// Known LLM URL host → source name mappings for content-based source detection.
    /// Apple does not expose the source app's bundle ID to share extensions,
    /// so we infer the source from the URL domain when a link is shared.
    static let knownSourceHosts: [String: String] = [
        "claude.ai": "claude",
        "chatgpt.com": "chatgpt",
        "chat.openai.com": "chatgpt",
        "gemini.google.com": "gemini",
    ]
}
