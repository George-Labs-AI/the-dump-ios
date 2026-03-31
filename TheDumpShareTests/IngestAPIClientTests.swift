import XCTest
@testable import TheDumpShare

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    /// Handler called for each intercepted request.
    /// Set this before each test to control the response.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Captured requests for inspection in tests.
    static var capturedRequests: [URLRequest] = []

    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedRequests.append(request)

        guard let handler = Self.requestHandler else {
            let error = NSError(domain: "MockURLProtocol", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No handler set"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

private func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeSuccessResponse(for url: URL) -> HTTPURLResponse {
    // swiftlint:disable:next force_unwrapping
    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
}

private func makeErrorResponse(for url: URL, statusCode: Int) -> HTTPURLResponse {
    // swiftlint:disable:next force_unwrapping
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

private let successJSON = Data("""
{
    "message": "Conversation ingested successfully.",
    "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "gcs_path": "gs://mindmerge-notes-file-uploads/test",
    "source": "claude",
    "command": "share_conversation"
}
""".utf8)

// MARK: - IngestAPIClient Tests

final class IngestAPIClientTests: XCTestCase {

    private var session: URLSession!
    private var tokenManager: TokenManager!
    private var tokenSuiteName: String!
    private var sut: IngestAPIClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        session = makeTestSession()
        tokenSuiteName = "test.ingest.\(UUID().uuidString)"
        tokenManager = TokenManager(suiteName: tokenSuiteName)
        tokenManager.saveToken("test-firebase-token", expiresIn: 3600)
        sut = IngestAPIClient(tokenManager: tokenManager, urlSession: session)
    }

    override func tearDown() {
        tokenManager.clearToken()
        UserDefaults.standard.removePersistentDomain(forName: tokenSuiteName)
        MockURLProtocol.reset()
        sut = nil
        tokenManager = nil
        session = nil
        super.tearDown()
    }

    // MARK: - Request Format

    func test_ingestText_requestFormat() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.text("User asked a question\nAssistant answered it")
        _ = try await sut.ingest(
            content: content,
            source: "claude",
            command: "share_conversation",
            title: nil
        )

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        let requestURL = try XCTUnwrap(request.url)
        XCTAssertTrue(requestURL.absoluteString.hasSuffix("/api/ingest"))

        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["source"] as? String, "claude")
        XCTAssertEqual(body["command"] as? String, "share_conversation")

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.first?["role"], "user")
        XCTAssertEqual(messages?.first?["content"], "User asked a question\nAssistant answered it")
    }

    func test_ingestURL_requestFormat() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.url(try XCTUnwrap(URL(string: "https://claude.ai/chat/abc123")))
        _ = try await sut.ingest(
            content: content,
            source: "claude",
            command: "conversation_link_and_title",
            title: "My Chat"
        )

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["command"] as? String, "conversation_link_and_title")
        XCTAssertEqual(body["url"] as? String, "https://claude.ai/chat/abc123")
        XCTAssertEqual(body["title"] as? String, "My Chat")
    }

    // MARK: - Authorization Header

    func test_authorizationHeader_includesBearer() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.text("test")
        _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-firebase-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Title

    func test_titleIncludedWhenProvided() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.text("conversation text")
        _ = try await sut.ingest(content: content, source: "chatgpt", command: "share_conversation", title: "My Chat Title")

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["title"] as? String, "My Chat Title")
    }

    func test_titleOmittedWhenNil() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.text("conversation text")
        _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)

        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertNil(body["title"], "Title should not be present in payload when nil")
    }

    // MARK: - Missing Token

    func test_missingToken_throwsNotAuthenticated() async {
        let emptyTokenManager = TokenManager(suiteName: "test.empty.\(UUID().uuidString)")
        let client = IngestAPIClient(tokenManager: emptyTokenManager, urlSession: session)

        let content = SharedContent.text("test")
        do {
            _ = try await client.ingest(content: content, source: "claude", command: "share_conversation", title: nil)
            XCTFail("Expected notAuthenticated error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Response Handling

    func test_200Response_returnsSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeSuccessResponse(for: url), successJSON)
        }

        let content = SharedContent.text("test")
        let response = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)

        XCTAssertEqual(response.uuid, "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
        XCTAssertEqual(response.message, "Conversation ingested successfully.")
    }

    func test_401Response_throwsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let errorData = Data(#"{"error": "Invalid token"}"#.utf8)
            return (makeErrorResponse(for: url, statusCode: 401), errorData)
        }

        let content = SharedContent.text("test")
        do {
            _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)
            XCTFail("Expected unauthorized error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_400Response_throwsBadRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let errorData = Data(#"{"error": "Missing required field: source"}"#.utf8)
            return (makeErrorResponse(for: url, statusCode: 400), errorData)
        }

        let content = SharedContent.text("test")
        do {
            _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)
            XCTFail("Expected badRequest error")
        } catch let error as ShareExtensionError {
            if case .badRequest(let message) = error {
                XCTAssertEqual(message, "Missing required field: source")
            } else {
                XCTFail("Expected badRequest, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_429Response_throwsRateLimited() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let errorData = Data(#"{"error": "Monthly usage limit exceeded"}"#.utf8)
            return (makeErrorResponse(for: url, statusCode: 429), errorData)
        }

        let content = SharedContent.text("test")
        do {
            _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)
            XCTFail("Expected rateLimited error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_500Response_throwsServerError() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            let errorData = Data(#"{"error": "Internal server error"}"#.utf8)
            return (makeErrorResponse(for: url, statusCode: 500), errorData)
        }

        let content = SharedContent.text("test")
        do {
            _ = try await sut.ingest(content: content, source: "claude", command: "share_conversation", title: nil)
            XCTFail("Expected serverError")
        } catch let error as ShareExtensionError {
            if case .serverError = error {
                // expected
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
