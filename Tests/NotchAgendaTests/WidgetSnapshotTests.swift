import XCTest
@testable import NotchAgenda

final class WidgetSnapshotTests: XCTestCase {
    @MainActor func testWidgetExcludesFutureDoneAndTrashAndResetsRecurringTask() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        calendar.firstWeekday = 2
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let store = TaskStore(file: directory.appendingPathComponent("tasks.json"), now: { today }, calendar: calendar)
        store.add("Duolingo", date: today, scope: .day, recurrence: .daily)
        store.add("Future", date: tomorrow, scope: .day)
        store.add("Deleted", date: nil, scope: .anytime)
        store.add("Week goal", date: today, scope: .week)
        let deleted = try XCTUnwrap(store.tasks.first { $0.title == "Deleted" })
        XCTAssertTrue(store.delete(deleted))
        let recurring = try XCTUnwrap(store.pendingOccurrences(on: today, scope: .day).first)
        XCTAssertTrue(store.setCompleted(recurring.task, occurrenceDate: recurring.date, completed: true))
        XCTAssertEqual(store.widgetOccurrences(on: today).map(\.task.title), ["Week goal"])
        XCTAssertEqual(store.widgetOccurrences(on: tomorrow).map(\.task.title), ["Duolingo", "Future", "Week goal"])
        let reloaded = TaskStore(file: directory.appendingPathComponent("tasks.json"), now: { tomorrow }, calendar: calendar)
        XCTAssertEqual(reloaded.widgetOccurrences(on: tomorrow), store.widgetOccurrences(on: tomorrow))
    }
}
