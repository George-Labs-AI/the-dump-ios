import XCTest
@testable import The_Dump

/// The Debug-only `-DumpServerURL` override. A bad value must never send
/// requests somewhere unexpected: anything not allowed falls back to
/// thedump.ai.
final class ServerOverrideTests: XCTestCase {
    private let fallback = "https://thedump.ai"
    private var suiteName: String!
    private var standard: UserDefaults!
    private var shared: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.serveroverride.\(UUID().uuidString)"
        standard = UserDefaults(suiteName: suiteName + ".standard")
        shared = UserDefaults(suiteName: suiteName + ".shared")
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName + ".standard")
        UserDefaults.standard.removePersistentDomain(forName: suiteName + ".shared")
        standard = nil
        shared = nil
        super.tearDown()
    }

    func testDefaultIsProductionServer() {
        XCTAssertEqual(SharedConstants.defaultBaseURL, "https://thedump.ai")
    }

    func testAcceptsHTTPSAndLocalServers() {
        let candidate = "https://candidate.example.com"
        XCTAssertEqual(ServerOverride.validatedBaseURL(candidate), candidate)
        XCTAssertEqual(ServerOverride.validatedBaseURL("http://localhost:5001"), "http://localhost:5001")
        XCTAssertEqual(ServerOverride.validatedBaseURL("http://127.0.0.1:5001"), "http://127.0.0.1:5001")
        XCTAssertEqual(ServerOverride.validatedBaseURL("http://LOCALHOST"), "http://LOCALHOST")
    }

    func testTrimsTrailingSlashAndWhitespace() {
        XCTAssertEqual(ServerOverride.validatedBaseURL("https://example.com/"), "https://example.com")
        XCTAssertEqual(ServerOverride.validatedBaseURL("  https://example.com  "), "https://example.com")
    }

    func testRejectsAnythingElse() {
        let rejected: [String?] = [
            nil,
            "",
            "   ",
            "not a url",
            "example.com",
            "http://example.com",
            "http://192.168.1.5:5001",
            "ftp://example.com",
            "javascript:alert(1)",
            "https://",
            "https://user:pass@example.com",
            "https://example.com/api",
            "https://example.com?x=1",
            "https://example.com#top"
        ]
        for value in rejected {
            XCTAssertNil(ServerOverride.validatedBaseURL(value), "\(String(describing: value)) should be rejected")
        }
    }

    func testAppUsesLaunchArgumentAndSharesItWithExtension() throws {
        standard.set("https://candidate.example.com", forKey: ServerOverride.key)

        let app = ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: standard, shared: shared, isExtension: false)
        XCTAssertEqual(app, "https://candidate.example.com")
        XCTAssertEqual(shared.string(forKey: ServerOverride.key), "https://candidate.example.com")

        let extensionDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName + ".ext"))
        let ext = ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: extensionDefaults, shared: shared, isExtension: true)
        XCTAssertEqual(ext, "https://candidate.example.com")
        UserDefaults.standard.removePersistentDomain(forName: suiteName + ".ext")
    }

    func testLaunchWithoutArgumentClearsTheSharedCopy() {
        shared.set("https://stale.example.com", forKey: ServerOverride.key)

        let app = ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: standard, shared: shared, isExtension: false)
        XCTAssertEqual(app, fallback)
        XCTAssertNil(shared.string(forKey: ServerOverride.key))

        let ext = ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: standard, shared: shared, isExtension: true)
        XCTAssertEqual(ext, fallback)
    }

    func testInvalidOverrideFallsBackInBothProcesses() {
        standard.set("http://example.com", forKey: ServerOverride.key)

        XCTAssertEqual(ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: standard, shared: shared, isExtension: false), fallback)
        XCTAssertEqual(ServerOverride.resolvedBaseURL(defaultURL: fallback, standard: standard, shared: shared, isExtension: true), fallback)
    }
}
