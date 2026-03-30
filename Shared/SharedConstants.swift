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

    /// Known LLM app bundle ID → source name mappings.
    static let knownSources: [String: String] = [
        "com.anthropic.claude": "claude",
        "com.openai.chatgpt": "chatgpt",
        "com.google.gemini": "gemini",
    ]
}
