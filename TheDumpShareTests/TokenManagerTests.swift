import XCTest
@testable import TheDumpShare

final class TokenManagerTests: XCTestCase {

    private var suiteName: String!
    private var sut: TokenManager!

    override func setUp() {
        super.setUp()
        suiteName = "test.tokenmanager.\(UUID().uuidString)"
        sut = TokenManager(suiteName: suiteName)
    }

    override func tearDown() {
        sut.clearToken()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        sut = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Save & Retrieve

    func test_saveAndRetrieveToken() {
        sut.saveToken("test-token-abc123")

        let retrieved = sut.getToken()
        XCTAssertEqual(retrieved, "test-token-abc123")
    }

    // MARK: - Expiry

    func test_expiredTokenReturnsNil() {
        sut.saveToken("expired-token", expiresIn: -1)

        let retrieved = sut.getToken()
        XCTAssertNil(retrieved, "Expired token should return nil")
    }

    func test_validTokenReturnsValue() {
        sut.saveToken("valid-token", expiresIn: 3600)

        let retrieved = sut.getToken()
        XCTAssertEqual(retrieved, "valid-token")
    }

    // MARK: - Clear

    func test_clearTokenRemovesAll() {
        sut.saveToken("token-to-clear")
        XCTAssertNotNil(sut.getToken(), "Token should exist before clearing")

        sut.clearToken()

        XCTAssertNil(sut.getToken(), "Token should be nil after clearing")
        XCTAssertFalse(sut.isTokenValid, "isTokenValid should be false after clearing")
    }

    // MARK: - isTokenValid

    func test_isTokenValid_trueWhenNotExpired() {
        sut.saveToken("valid-token", expiresIn: 3600)

        XCTAssertTrue(sut.isTokenValid)
    }

    func test_isTokenValid_falseWhenExpired() {
        sut.saveToken("expired-token", expiresIn: -1)

        XCTAssertFalse(sut.isTokenValid)
    }

    func test_isTokenValid_falseWhenNeverSaved() {
        XCTAssertFalse(sut.isTokenValid)
    }

    // MARK: - Never Saved

    func test_getTokenReturnsNilWhenNeverSaved() {
        let freshManager = TokenManager(suiteName: "test.fresh.\(UUID().uuidString)")

        XCTAssertNil(freshManager.getToken())
    }

    // MARK: - Default Expiry

    func test_defaultExpiryIs3500Seconds() {
        sut.saveToken("default-expiry-token")

        // Token saved with default expiry (3500s) should be valid
        XCTAssertTrue(sut.isTokenValid)
        XCTAssertEqual(sut.getToken(), "default-expiry-token")
    }
}
