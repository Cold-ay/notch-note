#if os(macOS)
import AppKit
import XCTest
import SwiftUI
@testable import NotchAgenda

final class CheckboxTests: XCTestCase {
    @MainActor func testCheckboxAcceptsInactivePanelFirstClickAndFullHitArea() {
        _ = NSApplication.shared
        let button = FirstClickCheckboxButton(frame: NSRect(x: 10, y: 10, width: 32, height: 32))
        XCTAssertTrue(button.acceptsFirstMouse(for: nil))
        XCTAssertTrue(button.hitTest(NSPoint(x: 11, y: 11)) === button)
        XCTAssertTrue(button.hitTest(NSPoint(x: 40, y: 40)) === button)
        XCTAssertNil(button.hitTest(NSPoint(x: 50, y: 50)))
    }

    @MainActor func testNativeCheckboxSendsExplicitCheckedState() {
        _ = NSApplication.shared
        var values: [Bool] = []
        let coordinator = JournalCheckbox.Coordinator { values.append($0); return true }
        let button = FirstClickCheckboxButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        button.setButtonType(.switch)
        button.target = coordinator
        button.action = #selector(JournalCheckbox.Coordinator.changed(_:))
        button.performClick(nil)
        button.performClick(nil)
        XCTAssertEqual(values, [true, false])
    }

    @MainActor func testFailedSaveRestoresCheckboxState() {
        _ = NSApplication.shared
        let coordinator = JournalCheckbox.Coordinator { _ in false }
        let button = FirstClickCheckboxButton(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        button.setButtonType(.switch)
        button.target = coordinator
        button.action = #selector(JournalCheckbox.Coordinator.changed(_:))
        button.performClick(nil)
        XCTAssertEqual(button.state, .off)
    }

    @MainActor func testCompletionMovesToCompletedListAndCanReturnWithoutLogging() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TaskStore(file: directory.appendingPathComponent("tasks.json"))
        store.add("完成後收進列表", date: Date(), scope: .day)
        let panel = JournalPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 780), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: AnyView(MacJournalView(store: store, floating: true).id("pending")))
        panel.contentView = host
        defer { panel.contentView = nil }
        func control(in view: NSView, identifier: String = "journal.checkbox") -> FirstClickCheckboxButton? {
            if let button = view as? FirstClickCheckboxButton, button.accessibilityIdentifier() == identifier { return button }
            return view.subviews.lazy.compactMap { control(in: $0, identifier: identifier) }.first
        }
        var found: FirstClickCheckboxButton?
        for _ in 0..<50 {
            host.layoutSubtreeIfNeeded()
            found = control(in: host)
            if found != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let button = try XCTUnwrap(found)
        // hitTest takes a point in the receiver's superview coordinates; the root
        // hosting view and the window frame have opposite flipped coordinate systems.
        let point = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: host.superview)
        XCTAssertTrue(host.hitTest(point) === button, "Paper decoration and row layout must not intercept the checkbox.")
        button.performClick(nil)
        XCTAssertTrue(try XCTUnwrap(store.tasks.first).completed)
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(host.hitTest(point) === button, "The completed row must no longer receive clicks in the pending list.")
        XCTAssertEqual(store.completedOccurrences(on: Date(), scope: .day).count, 1)
        XCTAssertTrue(store.pendingOccurrences(on: Date(), scope: .day).isEmpty)
        host.rootView = AnyView(MacJournalView(store: store, floating: true, initialContent: .completed).id("completed"))
        for _ in 0..<50 {
            host.layoutSubtreeIfNeeded()
            if control(in: host, identifier: "journal.returnToPending") != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let returnButton = try XCTUnwrap(control(in: host, identifier: "journal.returnToPending"))
        returnButton.performClick(nil)
        XCTAssertFalse(try XCTUnwrap(store.tasks.first).completed)
        XCTAssertEqual(store.tasks.first?.records.map(\.action), [.completed])
        XCTAssertEqual(store.pendingOccurrences(on: Date(), scope: .day).count, 1)
        XCTAssertTrue(store.completedOccurrences(on: Date(), scope: .day).isEmpty)
    }

    @MainActor func testDiaryEditorAutosavesAndFlushesDraftWhenSwitchingDates() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("journal.json")
        let journal = JournalStore(file: file)
        let today = Date()
        let tomorrow = Calendar.taskCalendar.date(byAdding: .day, value: 1, to: today)!
        let panel = JournalPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 700), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: AnyView(JournalEditor(journal: journal, date: today, scope: .day).id("today")))
        panel.contentView = host
        defer { panel.contentView = nil }
        func editor(in view: NSView) -> NSTextView? {
            if let editor = view as? NSTextView { return editor }
            return view.subviews.lazy.compactMap { editor(in: $0) }.first
        }
        for _ in 0..<50 {
            host.layoutSubtreeIfNeeded()
            if editor(in: host) != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let textView = try XCTUnwrap(editor(in: host))
        textView.string = "今天的日記\n真正輸入的文字。"
        textView.didChangeText()
        for _ in 0..<80 {
            if journal.entry(on: today, scope: .day)?.text == textView.string { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(journal.entry(on: today, scope: .day)?.text, "今天的日記\n真正輸入的文字。")
        journal.setDraft("切頁前最後一行", on: today, scope: .day)
        host.rootView = AnyView(JournalEditor(journal: journal, date: tomorrow, scope: .day).id("tomorrow"))
        for _ in 0..<50 {
            host.layoutSubtreeIfNeeded()
            if !journal.hasDraft(on: today, scope: .day) { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let loaded = JournalStore(file: file)
        XCTAssertEqual(loaded.text(on: today, scope: .day), "切頁前最後一行")
        XCTAssertEqual(loaded.text(on: tomorrow, scope: .day), "")
    }
}
#endif
