import SwiftUI

// MARK: - View State

enum ShareViewState {
    case extracting
    case ready(SharedContent, String) // content, detected source
    case sending
    case success(String) // uuid
    case error(String)
    case notAuthenticated
}

// MARK: - ShareView

struct ShareView: View {
    let extensionItems: [NSExtensionItem]
    let sourceBundleID: String?
    let onDismiss: () -> Void

    @State private var state: ShareViewState = .extracting
    @State private var title: String = ""

    private let parser = ShareContentParser()
    private let apiClient = IngestAPIClient()

    var body: some View {
        NavigationView {
            ZStack {
                ShareColors.background.ignoresSafeArea()

                switch state {
                case .extracting:
                    extractingView
                case .ready(let content, let source):
                    readyView(content: content, source: source)
                case .sending:
                    sendingView
                case .success(let uuid):
                    successView(uuid: uuid)
                case .error(let message):
                    errorView(message: message)
                case .notAuthenticated:
                    notAuthenticatedView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundColor(ShareColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if case .ready = state {
                        Button("Save") { submitContent() }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(ShareColors.accent)
                    }
                }
            }
        }
        .task { await extractContent() }
    }

    // MARK: - State Views

    private var extractingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ShareColors.textSecondary)
            Text("Preparing...")
                .font(.system(size: 15))
                .foregroundColor(ShareColors.textSecondary)
        }
    }

    private func readyView(content: SharedContent, source: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Source badge
            HStack {
                Text(source.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ShareColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ShareColors.accent.opacity(0.12))
                    .cornerRadius(12)
                Spacer()
            }

            // Content preview
            contentPreview(content)
                .padding(12)
                .background(ShareColors.surface)
                .cornerRadius(12)

            // Title field
            TextField("Add a title (optional)", text: $title)
                .font(.system(size: 15))
                .foregroundColor(ShareColors.textPrimary)
                .padding(12)
                .background(ShareColors.surface)
                .cornerRadius(12)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var sendingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(ShareColors.accent)
            Text("Saving to Dump...")
                .font(.system(size: 15))
                .foregroundColor(ShareColors.textSecondary)
        }
    }

    private func successView(uuid: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(ShareColors.success)
            Text("Saved!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ShareColors.textPrimary)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss()
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(ShareColors.warning)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(ShareColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Try Again") { submitContent() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(ShareColors.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ShareColors.accent)
                .cornerRadius(8)
        }
    }

    private var notAuthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(ShareColors.textSecondary)
            Text("Please open The Dump and sign in to share content.")
                .font(.system(size: 15))
                .foregroundColor(ShareColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Content Preview

    @ViewBuilder
    private func contentPreview(_ content: SharedContent) -> some View {
        switch content {
        case .text(let text):
            Text(String(text.prefix(200)) + (text.count > 200 ? "..." : ""))
                .font(.system(size: 13))
                .foregroundColor(ShareColors.textSecondary)
                .lineLimit(6)
        case .url(let url):
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 14))
                    .foregroundColor(ShareColors.accent)
                Text(url.absoluteString)
                    .font(.system(size: 13))
                    .foregroundColor(ShareColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Actions

    private func extractContent() async {
        // Check auth first
        let tokenManager = TokenManager()
        guard tokenManager.isTokenValid else {
            state = .notAuthenticated
            return
        }

        guard let content = await parser.parse(from: extensionItems) else {
            state = .error("Could not read shared content.")
            return
        }

        let source = ShareContentParser.detectSource(from: sourceBundleID)
        state = .ready(content, source)
    }

    private func submitContent() {
        guard case .ready(let content, let source) = state else { return }

        state = .sending
        let command = ShareContentParser.inferCommand(for: content)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let response = try await apiClient.ingest(
                    content: content,
                    source: source,
                    command: command,
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle
                )
                state = .success(response.uuid)
            } catch let error as ShareExtensionError {
                if error == .notAuthenticated || error == .unauthorized {
                    state = .notAuthenticated
                } else {
                    state = .error(error.localizedDescription)
                }
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}

// MARK: - Inline Colors (no asset catalog dependency)

private enum ShareColors {
    static let background = Color(hex: "000000")
    static let surface = Color(hex: "1C1C1E")
    static let accent = Color(hex: "FF2D55")
    static let success = Color(hex: "34C759")
    static let warning = Color(hex: "FF9500")
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
}

// MARK: - Color(hex:) Extension (mirrors Theme.swift)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
