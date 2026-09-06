import Foundation
import Combine

@MainActor
final class RoutineDocumentViewModel: ObservableObject {
    /// Blocks rendered per "page". Documents can run to ~200K chars, so the
    /// body is split once (off the main actor) and rendered in slices.
    static let pageSize = 60

    @Published private(set) var document: RoutineDocument?
    @Published private(set) var blocks: [IndexedMarkdownBlock] = []
    @Published private(set) var visibleCount: Int = 0
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    let routineSlug: String
    let documentSlug: String
    let fallbackTitle: String

    init(routineSlug: String, documentSlug: String, fallbackTitle: String) {
        self.routineSlug = routineSlug
        self.documentSlug = documentSlug
        self.fallbackTitle = fallbackTitle
    }

    var visibleBlocks: ArraySlice<IndexedMarkdownBlock> {
        blocks.prefix(visibleCount)
    }

    var hasMore: Bool { visibleCount < blocks.count }

    var remainingCount: Int { max(0, blocks.count - visibleCount) }

    var bodyCharacterCount: Int { document?.body.count ?? 0 }

    func loadIfNeeded() async {
        guard document == nil else { return }
        await load()
    }

    func reload() async {
        document = nil
        blocks = []
        visibleCount = 0
        await load()
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let doc = try await RoutinesService.shared.fetchDocument(
                routineSlug: routineSlug,
                documentSlug: documentSlug
            )
            let body = doc.body
            // Parsing a very large body is a linear scan over every line;
            // keep it off the main actor so the spinner keeps animating.
            let parsed = await Task.detached(priority: .userInitiated) {
                MarkdownBlockParser.parse(body)
            }.value
            document = doc
            blocks = parsed
            visibleCount = min(Self.pageSize, parsed.count)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func showMore() {
        visibleCount = min(visibleCount + Self.pageSize, blocks.count)
    }

    func showAll() {
        visibleCount = blocks.count
    }
}
