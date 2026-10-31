import XCTest
@testable import The_Dump

/// Leaving a note mid-edit saves after its screen has gone, and opening the
/// same note again builds a new screen that loads straight away. The new
/// screen must wait for that save, or it shows (and then autosaves over)
/// the text from before the edit. Every test is async on purpose:
/// releasing a main-actor object at the end of a synchronous test crashes
/// under Xcode 26.
@MainActor
final class NoteSaveOnLeaveTests: XCTestCase {

    /// What happened, in order.
    @MainActor
    private final class Log {
        var events: [String] = []
    }

    /// A save that ends only once `gate` is opened.
    private func heldSave(_ gate: AsyncStream<Void>, log: Log, named name: String) -> Task<Void, Never> {
        Task {
            for await _ in gate { break }
            log.events.append(name)
        }
    }

    /// Lets every task that can run on the main actor do so.
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    func test_reopeningANote_waitsForTheSaveFromLeavingIt() async {
        let noteID = "note-\(UUID().uuidString)"
        let log = Log()
        let (gate, open) = AsyncStream<Void>.makeStream()
        NoteDetailViewModel.track(heldSave(gate, log: log, named: "saved"), asSaveOnLeaveOf: noteID)

        let reopen = Task {
            await NoteDetailViewModel.waitForSaveOnLeave(of: noteID)
            log.events.append("loaded")
        }
        await settle()
        XCTAssertEqual(log.events, [], "the note loaded before the save from leaving it had landed")

        open.yield()
        await reopen.value
        XCTAssertEqual(log.events, ["saved", "loaded"])
    }

    func test_anotherNote_loadsWithoutWaiting() async {
        let log = Log()
        let (gate, open) = AsyncStream<Void>.makeStream()
        NoteDetailViewModel.track(heldSave(gate, log: log, named: "saved"), asSaveOnLeaveOf: "note-\(UUID().uuidString)")

        let other = Task {
            await NoteDetailViewModel.waitForSaveOnLeave(of: "note-\(UUID().uuidString)")
            log.events.append("other loaded")
        }
        await settle()
        XCTAssertEqual(log.events, ["other loaded"])

        open.yield()
        await other.value
    }

    func test_anEarlierSaveEnding_doesNotEndTheWaitForALaterOne() async {
        let noteID = "note-\(UUID().uuidString)"
        let log = Log()
        let (firstGate, openFirst) = AsyncStream<Void>.makeStream()
        let (secondGate, openSecond) = AsyncStream<Void>.makeStream()
        NoteDetailViewModel.track(heldSave(firstGate, log: log, named: "first saved"), asSaveOnLeaveOf: noteID)
        NoteDetailViewModel.track(heldSave(secondGate, log: log, named: "second saved"), asSaveOnLeaveOf: noteID)

        openFirst.yield()
        await settle()
        let reopen = Task {
            await NoteDetailViewModel.waitForSaveOnLeave(of: noteID)
            log.events.append("loaded")
        }
        await settle()
        XCTAssertEqual(log.events, ["first saved"], "the note loaded before the later save had landed")

        openSecond.yield()
        await reopen.value
        XCTAssertEqual(log.events, ["first saved", "second saved", "loaded"])
    }
}
