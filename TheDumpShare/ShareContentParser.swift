import Foundation
import UIKit
import UniformTypeIdentifiers

/// The type of content extracted from the share sheet.
enum SharedContent {
    case text(String)
    case url(URL)
    /// Images (screenshots, camera roll photos). Providers are kept rather
    /// than loaded bytes so each image is decoded only when it is uploaded;
    /// the extension's memory limit can't hold several full photos at once.
    case images([NSItemProvider])
}

/// Extracts shared content from NSExtensionItem and detects source app + appropriate command.
struct ShareContentParser {

    /// Parses the first usable content from extension items.
    /// Priority: Images > URL > Text.
    ///
    /// Images come first because Photos (and some other apps) can attach a
    /// `file://` URL alongside the image; treating that as a link would send
    /// a useless file path to the ingest endpoint.
    func parse(from items: [NSExtensionItem]) async -> SharedContent? {
        let imageProviders = items
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        if !imageProviders.isEmpty {
            return .images(Array(imageProviders.prefix(SharedConstants.maxSharedImages)))
        }

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
    /// Returns "photos" for images and "unknown" for plain text or
    /// unrecognized URLs.
    static func detectSource(from content: SharedContent?) -> String {
        if case .images = content {
            return "photos"
        }
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
    /// Images don't go through /api/ingest (see `PhotoUploadClient`); the
    /// value for them is informational only.
    static func inferCommand(for content: SharedContent) -> String {
        switch content {
        case .url:
            return "conversation_link_and_title"
        case .text:
            return "share_conversation"
        case .images:
            return "upload_photo"
        }
    }

    // MARK: - Image Loading

    /// Loads the raw bytes of one shared image. Tries the data representation
    /// of the most specific image type the provider offers (e.g. public.heic),
    /// then falls back to `loadItem`, which some apps answer with a file URL,
    /// a `UIImage`, or `Data`.
    static func loadImageData(from provider: NSItemProvider) async -> Data? {
        let typeIdentifier = provider.registeredTypeIdentifiers
            .first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier

        if let data = await loadDataRepresentation(from: provider, typeIdentifier: typeIdentifier) {
            return data
        }

        do {
            let item = try await provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil)
            if let data = item as? Data {
                return data
            }
            if let url = item as? URL {
                let didStartAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if didStartAccess { url.stopAccessingSecurityScopedResource() }
                }
                return try Data(contentsOf: url)
            }
            if let image = item as? UIImage {
                return image.pngData()
            }
        } catch {
            #if DEBUG
            print("[ShareContentParser] Failed to load image: \(error)")
            #endif
        }
        return nil
    }

    private static func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                continuation.resume(returning: data)
            }
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
