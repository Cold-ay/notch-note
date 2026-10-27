import XCTest
@testable import NotchAgenda

final class CompletionFlowTests: XCTestCase {
    @MainActor func testRepeatedMovesBetweenListsDoNotCreateAuditLogNoise() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        let today = Date()
        let store = TaskStore(file: file, now: { today })
        for scope in TaskScope.allCases {
            let recurrence: TaskRepeat = scope == .day ? .daily : scope == .week ? .weekly : scope == .month ? .monthly : .none
            store.add(scope.title, date: scope == .anytime ? nil : today, scope: scope, recurrence: recurrence)
            for _ in 0..<5 {
                let pending = try XCTUnwrap(store.pendingOccurrences(on: today, scope: scope).first)
                XCTAssertTrue(store.setCompleted(pending.task, occurrenceDate: pending.date, completed: true))
                XCTAssertTrue(store.pendingOccurrences(on: today, scope: scope).isEmpty)
                let done = try XCTUnwrap(store.completedOccurrences(on: today, scope: scope).first)
                XCTAssertEqual(done.task.records.count, 1)
                XCTAssertTrue(store.returnToPending(done))
                XCTAssertTrue(store.completedOccurrences(on: today, scope: scope).isEmpty)
                XCTAssertEqual(store.tasks.first(where: { $0.id == pending.task.id })?.records.map(\.action), [.completed])
            }
        }
        let reloaded = TaskStore(file: file, now: { today })
        for scope in TaskScope.allCases {
            XCTAssertEqual(reloaded.pendingOccurrences(on: today, scope: scope).count, 1)
            XCTAssertTrue(reloaded.completedOccurrences(on: today, scope: scope).isEmpty)
            if scope != .anytime {
                let component: Calendar.Component = scope == .day ? .day : scope == .week ? .weekOfYear : .month
                let next = reloaded.calendar.date(byAdding: component, value: 1, to: today)!
                let nextEntry = try XCTUnwrap(reloaded.pendingOccurrences(on: next, scope: scope).first)
                reloaded.setCompleted(nextEntry.task, occurrenceDate: nextEntry.date, completed: true)
                XCTAssertEqual(reloaded.pendingOccurrences(on: today, scope: scope).count, 1)
                XCTAssertEqual(reloaded.completedOccurrences(on: next, scope: scope).count, 1)
                XCTAssertEqual(reloaded.tasks.first(where: { $0.id == nextEntry.task.id })?.records.count, 2)
            }
        }
    }

    @MainActor func testLegacyRestartLogsAreCompactedWithoutChangingPeriodState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("tasks.json")
        let calendar = Calendar.taskCalendar
        let first = calendar.startOfDay(for: Date())
        let second = calendar.date(byAdding: .day, value: 1, to: first)!
        let id = UUID()
        func record(_ action: String, date: Date, offset: TimeInterval) -> [String: Any] {
            ["id": UUID().uuidString, "title": "Duolingo", "action": action,
             "timestamp": date.addingTimeInterval(offset).timeIntervalSinceReferenceDate,
             "occurrenceDate": date.timeIntervalSinceReferenceDate, "scope": "day"]
        }
        let oldTask: [String: Any] = [
            "id": id.uuidString, "title": "Duolingo", "completed": false,
            "date": first.timeIntervalSinceReferenceDate, "createdAt": first.timeIntervalSinceReferenceDate,
            "scope": "day", "recurrence": "daily", "records": [
                record("completed", date: first, offset: 10), record("reopened", date: first, offset: 20),
                record("completed", date: second, offset: 10), record("reopened", date: second, offset: 20),
                record("completed", date: second, offset: 30)
            ]
        ]
        try JSONSerialization.data(withJSONObject: [oldTask]).write(to: file)
        let store = TaskStore(file: file)
        XCTAssertEqual(store.pendingOccurrences(on: first, scope: .day).count, 1)
        XCTAssertTrue(store.completedOccurrences(on: first, scope: .day).isEmpty)
        XCTAssertEqual(store.completedOccurrences(on: second, scope: .day).count, 1)
        XCTAssertEqual(store.tasks.first?.records.map(\.action), [.completed, .completed])
        store.add("保存新格式", date: nil)
        let persisted = String(decoding: try Data(contentsOf: file), as: UTF8.self)
        XCTAssertFalse(persisted.contains("reopened"))
        let reloaded = TaskStore(file: file)
        XCTAssertEqual(reloaded.pendingOccurrences(on: first, scope: .day).count, 1)
        XCTAssertEqual(reloaded.completedOccurrences(on: second, scope: .day).count, 1)
        let done = try XCTUnwrap(reloaded.completedOccurrences(on: second, scope: .day).first)
        XCTAssertTrue(reloaded.returnToPending(done))
        XCTAssertEqual(reloaded.tasks.first(where: { $0.id == id })?.records.count, 2)
        reloaded.setCompleted(done.task, occurrenceDate: done.date, completed: true)
        XCTAssertEqual(reloaded.tasks.first(where: { $0.id == id })?.records.count, 2)
    }
}
