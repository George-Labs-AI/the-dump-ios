import Foundation
import UniformTypeIdentifiers

/// The type of content extracted from the share sheet.
enum SharedContent {
    case text(String)
    case url(URL)
}

/// Extracts shared content from NSExtensionItem and detects source app + appropriate command.
struct ShareContentParser {

    /// Parses the first usable content from extension items.
    /// Priority: URL > Text.
    func parse(from items: [NSExtensionItem]) async -> SharedContent? {
        for item in items {
            guard let attachments = item.attachments else { continue }

            // First pass: look for URLs (higher priority)
            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let content = await extractURL(from: provider) {
                    return content
                }
            }

            // Second pass: look for plain text
            for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let content = await extractText(from: provider) {
                    return content
                }
            }
        }
        return nil
    }

    // MARK: - Source Detection

    /// Infers the source LLM service from the shared content's URL host.
    /// Apple does not expose the source app's bundle ID to share extensions,
    /// so we match against known URL domains instead.
    /// Returns "unknown" for plain text or unrecognized URLs.
    static func detectSource(from content: SharedContent?) -> String {
        guard case .url(let url) = content,
              let host = url.host?.lowercased() else {
            return "unknown"
        }
        if let exact = SharedConstants.knownSourceHosts[host] {
            return exact
        }
        for (knownHost, source) in SharedConstants.knownSourceHosts where host.hasSuffix(".\(knownHost)") {
            return source
        }
        return "unknown"
    }

    // MARK: - Command Inference

    /// Infers the appropriate ingest command based on the content type.
    static func inferCommand(for content: SharedContent) -> String {
        switch content {
        case .url:
            return "conversation_link_and_title"
        case .text:
            return "share_conversation"
        }
    }

    // MARK: - Private Extraction

    private func extractURL(from provider: NSItemProvider) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil)
            if let url = item as? URL {
                return .url(url)
            }
            if let urlString = item as? String, let url = URL(string: urlString) {
                return .url(url)
            }
        } catch {
            #if DEBUG
            print("[ShareContentParser] Failed to load URL: \(error)")
            #endif
        }
        return nil
    }

    private func extractText(from provider: NSItemProvider) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil)
            if let text = item as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return .text(trimmed)
            }
        } catch {
            #if DEBUG
            print("[ShareContentParser] Failed to load text: \(error)")
            #endif
        }
        return nil
    }
}
