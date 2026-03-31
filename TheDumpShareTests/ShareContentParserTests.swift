import XCTest
import UniformTypeIdentifiers
@testable import TheDumpShare

// MARK: - Mock NSItemProvider

/// A mock that satisfies `NSItemProvider` patterns for testing content extraction
/// without requiring real pasteboard or share sheet data.
final class MockItemProvider: NSItemProvider {
    private let mockTypeIdentifiers: [String]
    private let mockItem: NSSecureCoding

    init(typeIdentifier: String, item: NSSecureCoding) {
        self.mockTypeIdentifiers = [typeIdentifier]
        self.mockItem = item
        super.init()
    }

    // Required by NSItemProvider
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override var registeredTypeIdentifiers: [String] {
        mockTypeIdentifiers
    }

    override func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool {
        mockTypeIdentifiers.contains(typeIdentifier)
    }

    override func loadItem(
        forTypeIdentifier typeIdentifier: String,
        options: [AnyHashable: Any]? = nil
    ) async throws -> NSSecureCoding {
        guard mockTypeIdentifiers.contains(typeIdentifier) else {
            throw NSError(domain: "MockItemProvider", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Type not available"])
        }
        return mockItem
    }
}

// MARK: - Helper to build NSExtensionItem

private func makeExtensionItem(provider: NSItemProvider) -> NSExtensionItem {
    let item = NSExtensionItem()
    item.attachments = [provider]
    return item
}

// MARK: - Content Parsing Tests

final class ShareContentParserTests: XCTestCase {

    private let parser = ShareContentParser()

    // MARK: - URL Extraction

    func test_parseURL_detectsConversationLink() async throws {
        let url = try XCTUnwrap(URL(string: "https://claude.ai/chat/abc123"))
        let provider = MockItemProvider(
            typeIdentifier: UTType.url.identifier,
            item: url as NSURL
        )
        let item = makeExtensionItem(provider: provider)

        let result = await parser.parse(from: [item])

        if case .url(let parsedURL) = result {
            XCTAssertEqual(parsedURL.absoluteString, "https://claude.ai/chat/abc123")
        } else {
            XCTFail("Expected .url, got \(String(describing: result))")
        }
    }

    // MARK: - Text Extraction

    func test_parsePlainText_detectsConversation() async {
        let text = "User: What is Swift?\nAssistant: Swift is a programming language."
        let provider = MockItemProvider(
            typeIdentifier: UTType.plainText.identifier,
            item: text as NSString
        )
        let item = makeExtensionItem(provider: provider)

        let result = await parser.parse(from: [item])

        if case .text(let parsedText) = result {
            XCTAssertEqual(parsedText, text)
        } else {
            XCTFail("Expected .text, got \(String(describing: result))")
        }
    }

    func test_emptyTextReturnsNil() async {
        let provider = MockItemProvider(
            typeIdentifier: UTType.plainText.identifier,
            item: "   \n  " as NSString
        )
        let item = makeExtensionItem(provider: provider)

        let result = await parser.parse(from: [item])

        XCTAssertNil(result, "Whitespace-only text should return nil")
    }

    // MARK: - Priority (URL over Text)

    func test_urlTakesPriorityOverText() async throws {
        let urlProvider = MockItemProvider(
            typeIdentifier: UTType.url.identifier,
            item: try XCTUnwrap(URL(string: "https://chat.openai.com/c/123")) as NSURL
        )
        let textProvider = MockItemProvider(
            typeIdentifier: UTType.plainText.identifier,
            item: "Some conversation text" as NSString
        )
        let item = NSExtensionItem()
        item.attachments = [urlProvider, textProvider]

        let result = await parser.parse(from: [item])

        if case .url(let parsedURL) = result {
            XCTAssertEqual(parsedURL.host, "chat.openai.com")
        } else {
            XCTFail("Expected .url (priority over text), got \(String(describing: result))")
        }
    }

    // MARK: - Empty Items

    func test_emptyItemsReturnsNil() async {
        let result = await parser.parse(from: [])
        XCTAssertNil(result)
    }
}

// MARK: - Source Detection Tests

final class SourceDetectionTests: XCTestCase {

    func test_detectSource_claudeURL() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://claude.ai/chat/abc123")))
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "claude")
    }

    func test_detectSource_chatgptURL() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://chatgpt.com/c/abc123")))
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "chatgpt")
    }

    func test_detectSource_chatOpenAIURL() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://chat.openai.com/c/abc123")))
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "chatgpt")
    }

    func test_detectSource_geminiURL() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://gemini.google.com/app/abc123")))
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "gemini")
    }

    func test_detectSource_unknownURL() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://example.com/page")))
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "unknown")
    }

    func test_detectSource_textContent() {
        let content = SharedContent.text("Some conversation text")
        XCTAssertEqual(ShareContentParser.detectSource(from: content), "unknown")
    }

    func test_detectSource_nilContent() {
        XCTAssertEqual(ShareContentParser.detectSource(from: nil), "unknown")
    }
}

// MARK: - Command Inference Tests

final class CommandInferenceTests: XCTestCase {

    func test_inferCommand_urlOnly() throws {
        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://claude.ai/chat/abc")))
        let command = ShareContentParser.inferCommand(for: content)
        XCTAssertEqual(command, "conversation_link_and_title")
    }

    func test_inferCommand_textContent() {
        let content = SharedContent.text("Some conversation text here")
        let command = ShareContentParser.inferCommand(for: content)
        XCTAssertEqual(command, "share_conversation")
    }
}
