#if os(macOS)
import AppKit
import XCTest
import SwiftUI
@testable import FlowTasks

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

    @MainActor func testCheckboxRemainsHittableInsideActualJournalAfterCompletion() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TaskStore(file: directory.appendingPathComponent("tasks.json"))
        store.add("勾選後留在原位", date: Date(), scope: .day)
        let panel = JournalPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 780), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: MacJournalView(store: store, floating: true))
        panel.contentView = host
        defer { panel.contentView = nil }
        func checkbox(in view: NSView) -> FirstClickCheckboxButton? {
            if let button = view as? FirstClickCheckboxButton { return button }
            return view.subviews.lazy.compactMap { checkbox(in: $0) }.first
        }
        var found: FirstClickCheckboxButton?
        for _ in 0..<50 {
            host.layoutSubtreeIfNeeded()
            found = checkbox(in: host)
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
        let completedButton = try XCTUnwrap(checkbox(in: host))
        XCTAssertEqual(completedButton.state, .on)
        completedButton.performClick(nil)
        XCTAssertFalse(try XCTUnwrap(store.tasks.first).completed)
        XCTAssertEqual(store.tasks.first?.records.map(\.action), [.completed, .reopened])
    }
}
#endif
