import XCTest
@testable import The_Dump

/// The voice recorder's timer reads like Paper's "1:12".
final class VoiceTimerTextTests: XCTestCase {
    func testMinutesHaveNoLeadingZero() {
        XCTAssertEqual(VoiceMemoView.timerText(0), "0:00")
        XCTAssertEqual(VoiceMemoView.timerText(72.9), "1:12")
        XCTAssertEqual(VoiceMemoView.timerText(605), "10:05")
        XCTAssertEqual(VoiceMemoView.timerText(-3), "0:00")
    }
}
