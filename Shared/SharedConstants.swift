import Foundation

enum SharedConstants {
    /// App Group identifier shared between the main app and the share extension.
    static let appGroupID = "group.George-Labs.The-Dump-App-Two"

    /// Production web server.
    static let defaultBaseURL = "https://thedump.ai"

    /// The web server every API request goes to, in the app and in the share
    /// extension. Release builds always use `defaultBaseURL`; a Debug build
    /// can be pointed elsewhere with `-DumpServerURL <url>` (see
    /// `ServerOverride`). Legal and privacy links don't use this: they always
    /// open thedump.ai.
    static let baseURL: String = {
#if DEBUG
        return ServerOverride.resolvedBaseURL(
            defaultURL: SharedConstants.defaultBaseURL,
            standard: .standard,
            shared: UserDefaults(suiteName: SharedConstants.appGroupID),
            isExtension: Bundle.main.bundleURL.pathExtension == "appex"
        )
#else
        return SharedConstants.defaultBaseURL
#endif
    }()

    /// The backend API service (the Cloud Run service the web app's Settings
    /// page also calls). It runs re-sorting jobs and the onboarding AI steps;
    /// everything else goes to `baseURL`. Not affected by `-DumpServerURL`.
    static let backendBaseURL = "https://mindmerge-backend-55o5dgq4ya-uc.a.run.app"

    /// The web page that explains how to connect The Dump to Claude (the MCP
    /// setup guide). Like the legal links, it always opens thedump.ai.
    static let mcpSetupGuideURL = "https://thedump.ai/mcp"

    /// The hosted MCP server's address, which people paste into Claude's
    /// "Add custom connector" box (D-034: permanent).
    static let mcpServerURL = "https://mcp.thedump.ai/mcp"

    /// Ingest endpoint path (text and links).
    static let ingestEndpoint = "/api/ingest"

    /// Signed-URL endpoint for file uploads (photos shared from Photos go
    /// through the same GCS upload path the main app uses, not /api/ingest).
    static let uploadFileEndpoint = "/api/mobile/upload_file"

    /// Most images accepted from one share-sheet invocation. Must match
    /// `NSExtensionActivationSupportsImageWithMaxCount` in TheDumpShare/Info.plist.
    static let maxSharedImages = 10

    /// UserDefaults key (in the App Group suite) for the pending-note
    /// records both the main app and the share extension write
    /// (`PendingNotesStore`). The same key was used in the main app's
    /// standard defaults before the records moved to the shared suite.
    static let pendingNoteRecordsKey = "pendingNoteRecords.v1"

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
        "gemini.google.com": "gemini"
    ]
}
