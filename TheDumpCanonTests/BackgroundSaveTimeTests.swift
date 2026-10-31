import UIKit
import XCTest
@testable import The_Dump

/// The extra time iOS gives a note's save after the app leaves the screen is
/// handed back exactly once, whether the save ends first or iOS asks for the
/// time back first. iOS ends an app that holds on to it past its limit.
@MainActor
final class BackgroundSaveTimeTests: XCTestCase {
    func testHandedBackWhenTheSaveEnds() {
        let ios = FakeBackgroundTime()
        let time = ios.start()

        time.end()

        XCTAssertEqual(ios.ended, [FakeBackgroundTime.task])
    }

    // A save stuck on a slow connection: iOS asks first, and the save ends
    // later, when the app comes back.
    func testHandedBackOnceWhenIOSAsksBeforeTheSaveEnds() {
        let ios = FakeBackgroundTime()
        let time = ios.start()

        ios.expire?()
        XCTAssertEqual(ios.ended, [FakeBackgroundTime.task])

        time.end()
        XCTAssertEqual(ios.ended, [FakeBackgroundTime.task])
    }

    func testNothingToHandBackWhenIOSGaveNoTime() {
        let ios = FakeBackgroundTime(gives: .invalid)
        let time = ios.start()

        time.end()

        XCTAssertEqual(ios.ended, [])
    }
}

/// Stands in for iOS: hands out a task, keeps the code to run when it wants
/// the time back, and records what was handed back.
@MainActor
private final class FakeBackgroundTime {
    nonisolated static let task = UIBackgroundTaskIdentifier(rawValue: 7)

    private let gives: UIBackgroundTaskIdentifier
    var expire: (@MainActor @Sendable () -> Void)?
    var ended: [UIBackgroundTaskIdentifier] = []

    init(gives: UIBackgroundTaskIdentifier = FakeBackgroundTime.task) {
        self.gives = gives
    }

    func start() -> BackgroundSaveTime {
        BackgroundSaveTime(
            begin: { expired in
                self.expire = expired
                return self.gives
            },
            end: { self.ended.append($0) }
        )
    }
}
