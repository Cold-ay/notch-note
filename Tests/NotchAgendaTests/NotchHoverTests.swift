#if os(macOS)
import AppKit
import XCTest
@testable import NotchAgenda

final class NotchHoverTests: XCTestCase {
    @MainActor func testEscapeReachesPanelDismissAction() throws {
        _ = NSApplication.shared
        let panel = JournalPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 700), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        var dismissed = false
        panel.onEscape = { dismissed = true }
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        panel.sendEvent(escape)
        XCTAssertTrue(dismissed)
    }
    func testDraggingAcrossTopDoesNotOpenPanel() {
        var policy = HoverPolicy()
        XCTAssertNil(policy.update(now: 0, inTrigger: true, inPanel: false, presented: false, protected: true))
        XCTAssertNil(policy.update(now: 10, inTrigger: true, inPanel: false, presented: false, protected: true))
        XCTAssertNil(policy.update(now: 11, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertEqual(policy.update(now: 11.3, inTrigger: true, inPanel: false, presented: false, protected: false), .expand)
    }
    func testHoverRequiresDwellAndLeavingBeforeDwellCancels() {
        var policy = HoverPolicy()
        XCTAssertNil(policy.update(now: 0, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 0.1, inTrigger: false, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 1, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 1.2, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertEqual(policy.update(now: 1.3, inTrigger: true, inPanel: false, presented: false, protected: false), .expand)
    }

    func testMovingFromNotchIntoPanelDoesNotCollapse() {
        var policy = HoverPolicy()
        XCTAssertNil(policy.update(now: 0, inTrigger: false, inPanel: true, presented: true, protected: false))
        XCTAssertNil(policy.update(now: 10, inTrigger: false, inPanel: true, presented: true, protected: false))
        XCTAssertNil(policy.update(now: 11, inTrigger: false, inPanel: false, presented: true, protected: false))
        XCTAssertNil(policy.update(now: 11.4, inTrigger: false, inPanel: true, presented: true, protected: false))
        XCTAssertNil(policy.update(now: 12, inTrigger: false, inPanel: false, presented: true, protected: false))
        XCTAssertEqual(policy.update(now: 12.8, inTrigger: false, inPanel: false, presented: true, protected: false), .collapse)
    }

    func testPinEditingAndMenuProtectionResetCloseTimer() {
        var policy = HoverPolicy()
        XCTAssertNil(policy.update(now: 0, inTrigger: false, inPanel: false, presented: true, protected: false))
        XCTAssertNil(policy.update(now: 1, inTrigger: false, inPanel: false, presented: true, protected: true))
        XCTAssertNil(policy.update(now: 10, inTrigger: false, inPanel: false, presented: true, protected: true))
        XCTAssertNil(policy.update(now: 11, inTrigger: false, inPanel: false, presented: true, protected: false))
        XCTAssertEqual(policy.update(now: 11.8, inTrigger: false, inPanel: false, presented: true, protected: false), .collapse)
    }

    func testEscapeCloseDoesNotReopenUntilMouseLeavesTrigger() {
        var policy = HoverPolicy()
        policy.suppressUntilExit()
        XCTAssertNil(policy.update(now: 0, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 100, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 101, inTrigger: false, inPanel: false, presented: false, protected: false))
        XCTAssertNil(policy.update(now: 102, inTrigger: true, inPanel: false, presented: false, protected: false))
        XCTAssertEqual(policy.update(now: 102.3, inTrigger: true, inPanel: false, presented: false, protected: false), .expand)
    }

    func testNotchedLayoutUsesSafeAreaAndIncludesTravelGap() {
        let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = NSRect(x: 0, y: 70, width: 1512, height: 880)
        let layout = NotchGeometry(screenFrame: screen, visibleFrame: visible, safeTop: 32, cameraWidth: 190)
        XCTAssertTrue(layout.triggerFrame.contains(NSPoint(x: 756, y: 980)))
        XCTAssertFalse(layout.triggerFrame.contains(NSPoint(x: 40, y: 980)))
        XCTAssertLessThanOrEqual(layout.expandedFrame.maxY, screen.maxY - 32)
        XCTAssertTrue(visible.contains(layout.expandedFrame))
        XCTAssertTrue(layout.bridgeFrame.contains(NSPoint(x: 756, y: layout.expandedFrame.maxY + 3)))
    }

    func testExternalDisplayWithNegativeCoordinatesAndNoNotch() {
        let screen = NSRect(x: -1920, y: 200, width: 1920, height: 1080)
        let visible = NSRect(x: -1920, y: 240, width: 1920, height: 1016)
        let layout = NotchGeometry(screenFrame: screen, visibleFrame: visible, safeTop: 0)
        XCTAssertEqual(layout.expandedFrame.midX, screen.midX)
        XCTAssertTrue(visible.contains(layout.expandedFrame))
        XCTAssertTrue(layout.triggerFrame.contains(NSPoint(x: screen.midX, y: screen.maxY - 1)))
        XCTAssertTrue(layout.triggerFrame.contains(NSPoint(x: layout.launcherFrame.midX, y: layout.launcherFrame.midY)))
    }
}
#endif
