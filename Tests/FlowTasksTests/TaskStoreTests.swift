import XCTest
#if os(macOS)
import AppKit
#endif
@testable import FlowTasks

final class TaskStoreTests: XCTestCase {
    @MainActor func testBatchQueueUndoAndPersistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        let store = TaskStore(file: file)
        let date = Date(timeIntervalSince1970: 1000)
        store.add(" 第一件 \n\n第二件\r\n第三件 ", date: date)
        XCTAssertEqual(store.pending.map(\.title), ["第一件", "第二件", "第三件"])
        let first = try XCTUnwrap(store.pending.first)
        store.later(first)
        XCTAssertEqual(store.pending.last?.id, first.id)
        XCTAssertEqual(store.pending.last?.date, store.calendar.startOfDay(for: date))
        store.complete(first)
        XCTAssertEqual(store.pending.count, 2)
        store.undo()
        XCTAssertEqual(store.pending.count, 3)
        XCTAssertEqual(TaskStore(file: file).tasks, store.tasks)
        store.schedule(first, date: nil)
        XCTAssertNil(store.tasks.first(where: { $0.id == first.id })?.date)
    }
    @MainActor func testFailedWriteDoesNotDiscardTask() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("file")
        try Data().write(to: blocker)
        let store = TaskStore(file: blocker.appendingPathComponent("tasks.json"))
        store.add("保留輸入", date: nil)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.tasks.isEmpty)
    }

    @MainActor func testJournalKeepsCompletionAndReopeningAcrossLaunches() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = TaskStore(file: file, now: { now })
        XCTAssertTrue(store.add("寫日記", date: nil))
        let task = try XCTUnwrap(store.pending.first)
        XCTAssertEqual(task.createdAt, now)
        now.addTimeInterval(120)
        store.complete(task)
        let completionTime = now
        XCTAssertEqual(store.tasks.first?.completedAt, completionTime)
        XCTAssertEqual(store.tasks.first?.records.first?.title, "寫日記")
        now.addTimeInterval(86_400)
        store.complete(task)
        XCTAssertFalse(try XCTUnwrap(store.tasks.first).completed)
        XCTAssertNil(store.tasks.first?.completedAt)
        XCTAssertEqual(store.tasks.first?.records.map(\.action), [.completed, .reopened])
        XCTAssertEqual(store.tasks.first?.records.first?.timestamp, completionTime)
        store.complete(task)
        XCTAssertEqual(store.tasks.first?.records.count, 3)
        let reloaded = TaskStore(file: file)
        XCTAssertEqual(reloaded.tasks, store.tasks)
        store.undo()
        XCTAssertEqual(store.tasks.first?.records.count, 2)
        XCTAssertFalse(try XCTUnwrap(store.tasks.first).completed)
    }

    @MainActor func testLegacyFilePreservesTasksWithoutInventingDates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("tasks.json")
        let id = UUID()
        let original = """
        [{"id":"\(id.uuidString)","title":"舊版事項","completed":true}]
        """
        try Data(original.utf8).write(to: file)
        let store = TaskStore(file: file)
        let task = try XCTUnwrap(store.tasks.first)
        XCTAssertEqual(task.id, id)
        XCTAssertTrue(task.completed)
        XCTAssertNil(task.createdAt)
        XCTAssertNil(task.completedAt)
        XCTAssertTrue(task.records.isEmpty)
        store.add("新的一頁", date: nil)
        let reloaded = TaskStore(file: file)
        XCTAssertEqual(reloaded.tasks.count, 2)
        XCTAssertTrue(try XCTUnwrap(reloaded.tasks.first).completed)
        XCTAssertNil(reloaded.tasks.first?.completedAt)
    }

    @MainActor func testUnreadableFileIsNeverOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("tasks.json")
        let original = Data("{damaged JSON".utf8)
        try original.write(to: file)
        let store = TaskStore(file: file)
        XCTAssertFalse(store.add("未儲存輸入", date: nil))
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertNotNil(store.errorMessage)
    }

    #if os(macOS)
    @MainActor func testBorderlessPanelCanAcceptKeyboardFocus() {
        _ = NSApplication.shared
        let panel = JournalPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
    }
    #endif
}
