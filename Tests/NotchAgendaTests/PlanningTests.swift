import XCTest
@testable import NotchAgenda

private var planningCalendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
    value.firstWeekday = 2
    value.minimumDaysInFirstWeek = 4
    return value
}
private func day(_ year: Int, _ month: Int, _ date: Int) -> Date {
    planningCalendar.date(from: DateComponents(year: year, month: month, day: date, hour: 12))!
}

final class PlanningTests: XCTestCase {
    @MainActor private func withStore(now: Date = day(2026, 10, 27), _ test: (TaskStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        try test(TaskStore(file: file, now: { now }, calendar: planningCalendar), file)
    }

    @MainActor func testFuturePlanOnlyAppearsOnItsDayAndOverdueCarriesForward() throws {
        try withStore { store, _ in
            store.add("預約剪頭髮", date: day(2026, 11, 3), scope: .day)
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 27), scope: .day, carryOver: true).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2026, 11, 3), scope: .day).count, 1)
            XCTAssertTrue(store.occurrences(on: day(2026, 11, 4), scope: .day).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2026, 11, 4), scope: .day, carryOver: true).count, 1)
        }
    }

    @MainActor func testWeeklyAndMonthlyGoalsBelongToEntirePeriod() throws {
        try withStore { store, _ in
            store.add("完成一章", date: day(2026, 10, 29), scope: .week)
            store.add("讀一本書", date: day(2026, 10, 30), scope: .month)
            XCTAssertEqual(store.occurrences(on: day(2026, 10, 26), scope: .week).count, 1)
            XCTAssertEqual(store.occurrences(on: day(2026, 11, 1), scope: .week).count, 1)
            XCTAssertTrue(store.occurrences(on: day(2026, 11, 2), scope: .week).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2026, 10, 1), scope: .month).count, 1)
            XCTAssertTrue(store.occurrences(on: day(2026, 11, 1), scope: .month).isEmpty)
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 29), scope: .day).isEmpty)
        }
    }

    @MainActor func testAnytimeInboxCanBeScheduledLater() throws {
        try withStore { store, _ in
            store.add("學會游泳", date: nil, scope: .anytime)
            let task = try XCTUnwrap(store.tasks.first)
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 27), scope: .day).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2030, 1, 1), scope: .anytime).count, 1)
            XCTAssertTrue(store.updatePlan(task, scope: .day, date: day(2026, 12, 1), recurrence: .none))
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 27), scope: .anytime).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2026, 12, 1), scope: .day).count, 1)
        }
    }

    @MainActor func testDailyHabitCompletesOnlyOneOccurrenceAndPersists() throws {
        try withStore { store, file in
            store.add("Duolingo", date: day(2026, 10, 27), scope: .day, recurrence: .daily)
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 26), scope: .day).isEmpty)
            let today = try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: .day).first)
            store.setCompleted(today.task, occurrenceDate: today.date, completed: true)
            XCTAssertTrue(try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: .day).first).isCompleted)
            XCTAssertFalse(try XCTUnwrap(store.occurrences(on: day(2026, 10, 28), scope: .day).first).isCompleted)
            let reloaded = TaskStore(file: file, now: { day(2026, 10, 28) }, calendar: planningCalendar)
            XCTAssertFalse(try XCTUnwrap(reloaded.occurrences(on: day(2026, 10, 28), scope: .day).first).isCompleted)
            XCTAssertTrue(try XCTUnwrap(reloaded.occurrences(on: day(2026, 10, 27), scope: .day).first).isCompleted)
            store.setCompleted(today.task, occurrenceDate: today.date, completed: false)
            XCTAssertEqual(store.tasks.first?.records.map(\.action), [.completed])
            XCTAssertFalse(try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: .day).first).isCompleted)
        }
    }

    @MainActor func testExplicitCompletionIsIdempotentAndKeepsRowIdentity() throws {
        try withStore { store, _ in
            store.add("勾選測試", date: day(2026, 10, 27), scope: .day)
            let before = try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: .day).first)
            store.setCompleted(before.task, occurrenceDate: before.date, completed: true)
            store.setCompleted(before.task, occurrenceDate: before.date, completed: true)
            let after = try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: .day).first)
            XCTAssertTrue(after.isCompleted)
            XCTAssertEqual(before.id, after.id)
            XCTAssertEqual(store.tasks.first?.records.count, 1)
            store.setCompleted(before.task, occurrenceDate: before.date, completed: false)
            store.setCompleted(before.task, occurrenceDate: before.date, completed: false)
            XCTAssertEqual(store.tasks.first?.records.count, 1)
        }
    }

    @MainActor func testWeeklyHabitMatchesWeekdayAcrossYearBoundary() throws {
        try withStore(now: day(2026, 12, 29)) { store, _ in
            store.add("週二跑步", date: day(2026, 12, 29), scope: .day, recurrence: .weekly)
            XCTAssertTrue(store.occurrences(on: day(2027, 1, 4), scope: .day).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2027, 1, 5), scope: .day).count, 1)
        }
    }

    @MainActor func testMonthlyHabitClampsToMonthEndWithoutDrift() throws {
        try withStore(now: day(2028, 1, 31)) { store, _ in
            store.add("月底整理", date: day(2028, 1, 31), scope: .day, recurrence: .monthly)
            XCTAssertTrue(store.occurrences(on: day(2028, 2, 28), scope: .day).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2028, 2, 29), scope: .day).count, 1)
            XCTAssertTrue(store.occurrences(on: day(2028, 3, 29), scope: .day).isEmpty)
            XCTAssertEqual(store.occurrences(on: day(2028, 3, 31), scope: .day).count, 1)
        }
    }

    @MainActor func testRecurringGoalsResetPerWeekAndMonth() throws {
        try withStore { store, _ in
            store.add("每週完成一章", date: day(2026, 10, 27), scope: .week, recurrence: .weekly)
            store.add("每月讀一本書", date: day(2026, 10, 27), scope: .month, recurrence: .monthly)
            for scope in [TaskScope.week, .month] {
                let entry = try XCTUnwrap(store.occurrences(on: day(2026, 10, 27), scope: scope).first)
                store.setCompleted(entry.task, occurrenceDate: entry.date, completed: true)
                XCTAssertTrue(try XCTUnwrap(store.occurrences(on: day(2026, 10, 31), scope: scope).first).isCompleted)
                XCTAssertFalse(try XCTUnwrap(store.occurrences(on: day(2026, 11, 2), scope: scope).first).isCompleted)
            }
        }
    }

    @MainActor func testStoppingRepeatPreservesPastCompletion() throws {
        try withStore { store, file in
            store.add("每日練習", date: day(2026, 10, 26), scope: .day, recurrence: .daily)
            let entry = try XCTUnwrap(store.occurrences(on: day(2026, 10, 26), scope: .day).first)
            store.setCompleted(entry.task, occurrenceDate: entry.date, completed: true)
            store.stopRepeating(entry.task)
            XCTAssertTrue(try XCTUnwrap(store.occurrences(on: day(2026, 10, 26), scope: .day).first).isCompleted)
            XCTAssertEqual(store.occurrences(on: day(2026, 10, 27), scope: .day).count, 1)
            XCTAssertTrue(store.occurrences(on: day(2026, 10, 28), scope: .day).isEmpty)
            XCTAssertEqual(TaskStore(file: file).tasks.first?.records.count, 1)
        }
    }

    @MainActor func testEarlyCompletionKeepsScheduledDayAndActualRecordDay() throws {
        try withStore { store, _ in
            store.add("提前做好報告", date: day(2026, 11, 3), scope: .day)
            let future = try XCTUnwrap(store.occurrences(on: day(2026, 11, 3), scope: .day).first)
            store.setCompleted(future.task, occurrenceDate: future.date, completed: true)
            XCTAssertTrue(try XCTUnwrap(store.occurrences(on: day(2026, 11, 3), scope: .day).first).isCompleted)
            XCTAssertEqual(store.records(on: day(2026, 10, 27)).count, 1)
            XCTAssertTrue(store.records(on: day(2026, 11, 3)).isEmpty)
        }
    }
}
