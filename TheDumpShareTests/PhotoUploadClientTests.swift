import XCTest
@testable import TheDumpShare

// Reuses `MockURLProtocol` from IngestAPIClientTests.swift (same test module).

private let signedURLJSON = Data("""
{
    "uploadUrl": "https://storage.googleapis.com/mindmerge-notes-file-uploads/signed?X-Goog-Signature=abc",
    "storagePath": "uploads/user/photo_abc.jpg",
    "originalFilename": "photo_abc.jpg",
    "metadata": {"user_email": "u@example.com"},
    "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "isQuickNote": false
}
""".utf8)

private func makeResponse(for url: URL, statusCode: Int) -> HTTPURLResponse {
    // swiftlint:disable:next force_unwrapping
    HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

final class PhotoUploadClientTests: XCTestCase {

    private var session: URLSession!
    private var tokenManager: TokenManager!
    private var tokenSuiteName: String!
    private var sut: PhotoUploadClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        tokenSuiteName = "test.photoupload.\(UUID().uuidString)"
        tokenManager = TokenManager(suiteName: tokenSuiteName)
        tokenManager.saveToken("test-firebase-token", expiresIn: 3600)
        sut = PhotoUploadClient(tokenManager: tokenManager, urlSession: session)
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

    func test_upload_requestsSignedURLThenPutsBytes() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                return (makeResponse(for: url, statusCode: 200), signedURLJSON)
            }
            return (makeResponse(for: url, statusCode: 200), Data())
        }

        let response = try await sut.upload(jpegData: Data([0xFF, 0xD8, 0x00]))

        XCTAssertEqual(response.uuid, "a1b2c3d4-e5f6-7890-abcd-ef1234567890")
        XCTAssertEqual(response.storagePath, "uploads/user/photo_abc.jpg")

        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)

        let signRequest = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(signRequest.httpMethod, "POST")
        XCTAssertEqual(signRequest.url?.path, SharedConstants.uploadFileEndpoint)
        XCTAssertEqual(signRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-firebase-token")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(signRequest.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["contentType"] as? String, "image/jpeg")
        XCTAssertEqual(body?["isQuickNote"] as? Bool, false)
        let filename = try XCTUnwrap(body?["filename"] as? String)
        XCTAssertTrue(filename.hasPrefix("photo_") && filename.hasSuffix(".jpg"), "unexpected filename \(filename)")

        let putRequest = MockURLProtocol.capturedRequests[1]
        XCTAssertEqual(putRequest.httpMethod, "PUT")
        XCTAssertEqual(putRequest.url?.host, "storage.googleapis.com")
        XCTAssertEqual(putRequest.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
    }

    func test_upload_withoutToken_throwsNotAuthenticated() async {
        tokenManager.clearToken()

        do {
            _ = try await sut.upload(jpegData: Data([0xFF, 0xD8]))
            XCTFail("Expected error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
    }

    func test_upload_401_throwsUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeResponse(for: url, statusCode: 401), Data("{\"error\":\"Invalid auth token\"}".utf8))
        }

        do {
            _ = try await sut.upload(jpegData: Data([0xFF, 0xD8]))
            XCTFail("Expected error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_upload_429_throwsRateLimited() async {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            return (makeResponse(for: url, statusCode: 429), Data("{\"error\":\"limit\"}".utf8))
        }

        do {
            _ = try await sut.upload(jpegData: Data([0xFF, 0xD8]))
            XCTFail("Expected error")
        } catch let error as ShareExtensionError {
            XCTAssertEqual(error, .rateLimited)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_upload_gcsPutFailure_throwsServerError() async {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST" {
                return (makeResponse(for: url, statusCode: 200), signedURLJSON)
            }
            return (makeResponse(for: url, statusCode: 403), Data())
        }

        do {
            _ = try await sut.upload(jpegData: Data([0xFF, 0xD8]))
            XCTFail("Expected error")
        } catch let error as ShareExtensionError {
            if case .serverError(let message) = error {
                XCTAssertTrue(message.contains("403"), "message was \(message)")
            } else {
                XCTFail("Expected .serverError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
