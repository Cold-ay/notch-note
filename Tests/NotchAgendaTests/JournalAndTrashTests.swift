import XCTest
@testable import NotchAgenda

private var diaryCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}
private func diaryDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    diaryCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
}

final class JournalAndTrashTests: XCTestCase {
    @MainActor private func withStore(_ body: (TaskStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = diaryDate(2026, 10, 27)
        try body(TaskStore(file: directory.appendingPathComponent("tasks.json"), now: { now }, calendar: diaryCalendar), directory)
    }

    @MainActor func testDeletingInboxTaskPersistsAndCanRestoreAfterRestart() throws {
        try withStore { store, directory in
            store.add("暫時不做", date: nil, scope: .anytime)
            let task = try XCTUnwrap(store.activeTasks.first)
            XCTAssertTrue(store.delete(task))
            XCTAssertTrue(store.activeTasks.isEmpty)
            XCTAssertTrue(store.pending.isEmpty)
            XCTAssertTrue(store.occurrences(on: diaryDate(2026, 10, 27), scope: .anytime).isEmpty)
            XCTAssertEqual(store.deletedTasks.first?.id, task.id)
            let loaded = TaskStore(file: directory.appendingPathComponent("tasks.json"))
            XCTAssertEqual(loaded.deletedTasks.count, 1)
            XCTAssertTrue(loaded.restore(task))
            XCTAssertEqual(loaded.activeTasks.first?.id, task.id)
            XCTAssertTrue(loaded.deletedTasks.isEmpty)
            XCTAssertNil(TaskStore(file: directory.appendingPathComponent("tasks.json")).tasks.first?.deletedAt)
        }
    }

    @MainActor func testInboxCompletionAndDeletionPreserveHistory() throws {
        try withStore { store, _ in
            store.add("做完的事", date: nil, scope: .anytime)
            let task = try XCTUnwrap(store.activeTasks.first)
            XCTAssertTrue(store.setCompleted(task, occurrenceDate: nil, completed: true))
            XCTAssertTrue(store.pending.isEmpty)
            XCTAssertTrue(store.delete(task))
            XCTAssertEqual(store.records(on: diaryDate(2026, 10, 27)).first?.title, task.title)
            XCTAssertFalse(store.setCompleted(task, occurrenceDate: nil, completed: false))
            XCTAssertTrue(store.restore(task))
            XCTAssertTrue(try XCTUnwrap(store.activeTasks.first).completed)
            XCTAssertEqual(store.activeTasks.first?.records.count, 1)
        }
    }

    @MainActor func testDeletingRecurringSeriesHidesFutureOccurrencesAndUndoRestores() throws {
        try withStore { store, _ in
            store.add("Duolingo", date: diaryDate(2026, 10, 27), scope: .day, recurrence: .daily)
            let task = try XCTUnwrap(store.tasks.first)
            store.delete(task)
            XCTAssertTrue(store.occurrences(on: diaryDate(2026, 10, 28), scope: .day).isEmpty)
            store.undo()
            XCTAssertEqual(store.occurrences(on: diaryDate(2026, 10, 28), scope: .day).count, 1)
            XCTAssertTrue(store.deletedTasks.isEmpty)
        }
    }

    @MainActor func testJournalSeparatesDaysWeeksAndMonthsAndSurvivesRestart() throws {
        try withStore { store, directory in
            let notes = store.journal
            let tuesday = diaryDate(2026, 10, 27)
            notes.setDraft("今天\n很開心。", on: tuesday, scope: .day)
            notes.setDraft("本週走完一段路。", on: tuesday, scope: .week)
            notes.setDraft("十月的回望。", on: tuesday, scope: .month)
            XCTAssertTrue(notes.flushAllDrafts())
            let loaded = JournalStore(file: directory.appendingPathComponent("journal.json"), calendar: diaryCalendar)
            XCTAssertEqual(loaded.text(on: tuesday, scope: .day), "今天\n很開心。")
            XCTAssertEqual(loaded.text(on: diaryDate(2026, 10, 28), scope: .day), "")
            XCTAssertEqual(loaded.text(on: diaryDate(2026, 11, 1), scope: .week), "本週走完一段路。")
            XCTAssertEqual(loaded.text(on: diaryDate(2026, 11, 2), scope: .week), "")
            XCTAssertEqual(loaded.text(on: diaryDate(2026, 10, 1), scope: .month), "十月的回望。")
            XCTAssertEqual(loaded.text(on: diaryDate(2026, 11, 1), scope: .month), "")
            XCTAssertEqual(loaded.entries.count, 3)
        }
    }

    @MainActor func testJournalUndoAndTaskUndoAreIndependent() throws {
        try withStore { store, _ in
            let date = diaryDate(2026, 10, 27)
            store.add("保留任務復原", date: nil)
            let task = try XCTUnwrap(store.tasks.first)
            store.delete(task)
            store.journal.setDraft("第一版", on: date, scope: .day)
            XCTAssertTrue(store.journal.saveDraft(on: date, scope: .day))
            store.journal.setDraft("第二版", on: date, scope: .day)
            XCTAssertTrue(store.journal.saveDraft(on: date, scope: .day))
            XCTAssertTrue(store.journal.undo(on: date, scope: .day))
            XCTAssertEqual(store.journal.text(on: date, scope: .day), "第一版")
            XCTAssertEqual(store.deletedTasks.count, 1)
            store.undo()
            XCTAssertEqual(store.activeTasks.count, 1)
            XCTAssertEqual(store.journal.text(on: date, scope: .day), "第一版")
        }
    }

    @MainActor func testEmptyJournalCanBeClearedAndUndone() throws {
        try withStore { store, _ in
            let date = diaryDate(2026, 10, 27)
            let notes = store.journal
            notes.setDraft("想保留的話", on: date, scope: .day)
            notes.saveDraft(on: date, scope: .day)
            notes.setDraft("", on: date, scope: .day)
            XCTAssertTrue(notes.saveDraft(on: date, scope: .day))
            XCTAssertNil(notes.entry(on: date, scope: .day))
            XCTAssertTrue(notes.undo(on: date, scope: .day))
            XCTAssertEqual(notes.text(on: date, scope: .day), "想保留的話")
        }
    }

    @MainActor func testJournalWriteFailureKeepsEveryDraftAndOriginalFile() throws {
        try withStore { _, directory in
            let file = directory.appendingPathComponent("bad-journal.json")
            let original = Data("{broken".utf8)
            try original.write(to: file)
            let notes = JournalStore(file: file, calendar: diaryCalendar)
            let today = diaryDate(2026, 10, 27)
            notes.setDraft("今天未儲存的文字", on: today, scope: .day)
            notes.setDraft("明天未儲存的文字", on: diaryDate(2026, 10, 28), scope: .day)
            XCTAssertFalse(notes.flushAllDrafts())
            XCTAssertEqual(notes.drafts.count, 2)
            XCTAssertEqual(notes.text(on: today, scope: .day), "今天未儲存的文字")
            XCTAssertEqual(try Data(contentsOf: file), original)
            XCTAssertNotNil(notes.errorMessage)
        }
    }

    @MainActor func testCivilDateJournalKeysSurviveTimezoneChanges() throws {
        try withStore { store, directory in
            store.journal.setDraft("旅行中的一天", on: diaryDate(2026, 10, 27), scope: .day)
            store.journal.flushAllDrafts()
            var otherCalendar = diaryCalendar
            otherCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
            let localDate = otherCalendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
            let loaded = JournalStore(file: directory.appendingPathComponent("journal.json"), calendar: otherCalendar)
            XCTAssertEqual(loaded.text(on: localDate, scope: .day), "旅行中的一天")
        }
    }
}
