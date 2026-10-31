import XCTest
import AVFoundation
@testable import The_Dump

/// A call or another app taking the microphone ends a voice memo and keeps
/// it, rather than pausing it: resuming afterwards would start the file
/// over and lose everything said before the call.
@MainActor
final class VoiceInterruptionTests: XCTestCase {
    /// Posts an interruption the way the system does, then lets the main
    /// run loop turn, because the recorder hears about it there.
    private func interrupt(_ type: AVAudioSession.InterruptionType) {
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue]
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func testACallWhileRecordingEndsTheMemoInsteadOfPausingIt() {
        let recorder = AudioRecorderService()
        recorder.stopsOnInterruption = true
        recorder.state = .recording
        interrupt(.began)
        XCTAssertEqual(recorder.state, .stopped)
    }

    func testACallWhilePausedEndsTheMemoToo() {
        let recorder = AudioRecorderService()
        recorder.stopsOnInterruption = true
        recorder.state = .paused
        interrupt(.began)
        XCTAssertEqual(recorder.state, .stopped)
    }

    func testTheEndOfACallChangesNothing() {
        let recorder = AudioRecorderService()
        recorder.stopsOnInterruption = true
        recorder.state = .recording
        interrupt(.ended)
        XCTAssertEqual(recorder.state, .recording)
    }

    // Onboarding's recorders leave this off, so a call is handled as before.
    func testRecordersThatDontTurnItOnAreLeftAlone() {
        let recorder = AudioRecorderService()
        recorder.state = .recording
        interrupt(.began)
        XCTAssertEqual(recorder.state, .recording)
    }
}
