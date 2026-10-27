#if os(macOS)
import AppKit
import XCTest
@testable import NotchAgenda

final class NotchHoverTests: XCTestCase {
    func testNotchMatchesMeasuredCameraSizeWithoutExtraBrandCapsule() {
        let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = NSRect(x: 0, y: 70, width: 1512, height: 880)
        for width in [CGFloat(164), 190, 236] {
            let camera = NSRect(x: screen.midX - width / 2, y: 950, width: width, height: 32)
            let layout = NotchGeometry(screenFrame: screen, visibleFrame: visible, safeTop: 32, cameraFrame: camera)
            XCTAssertTrue(layout.hasNotch)
            XCTAssertEqual(layout.launcherFrame.width, width)
            XCTAssertEqual(layout.launcherFrame.midX, camera.midX)
            XCTAssertEqual(layout.launcherFrame.height, 37)
            XCTAssertEqual(layout.launcherFrame.maxY, screen.maxY)
            XCTAssertEqual(layout.expandedFrame.maxY, camera.minY)
        }
    }

    func testAuxiliaryAreasSupportGlobalAndLocalExternalCoordinates() throws {
        let screen = NSRect(x: -1512, y: 200, width: 1512, height: 982)
        let localLeft = NSRect(x: 0, y: 950, width: 661, height: 32)
        let localRight = NSRect(x: 851, y: 950, width: 661, height: 32)
        let local = try XCTUnwrap(NotchGeometry.cameraFrame(screenFrame: screen, safeTop: 32, leftArea: localLeft, rightArea: localRight))
        let global = try XCTUnwrap(NotchGeometry.cameraFrame(screenFrame: screen, safeTop: 32, leftArea: localLeft.offsetBy(dx: -1512, dy: 200), rightArea: localRight.offsetBy(dx: -1512, dy: 200)))
        XCTAssertEqual(local, global)
        XCTAssertEqual(local.midX, screen.midX)
        XCTAssertEqual(local.width, 190)
        XCTAssertEqual(local.maxY, screen.maxY)
        XCTAssertNil(NotchGeometry.cameraFrame(screenFrame: screen, safeTop: 0, leftArea: localLeft, rightArea: localRight))
        XCTAssertNil(NotchGeometry.cameraFrame(screenFrame: screen, safeTop: 32, leftArea: .zero, rightArea: .zero))
    }

    func testNoNotchKeepsExistingCapsuleAndPlacement() {
        let screen = NSRect(x: 100, y: 200, width: 1920, height: 1080)
        let visible = NSRect(x: 100, y: 240, width: 1920, height: 1016)
        let layout = NotchGeometry(screenFrame: screen, visibleFrame: visible, safeTop: 0)
        XCTAssertFalse(layout.hasNotch)
        XCTAssertEqual(layout.launcherFrame, NSRect(x: screen.midX - 80, y: visible.maxY - 26, width: 160, height: 24))
        XCTAssertEqual(layout.triggerFrame.width, 200)
        XCTAssertEqual(layout.expandedFrame.maxY, visible.maxY - 6)
    }

    func testNotchFallbackRemainsBoundedWhenMeasurementsUnavailable() {
        let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
        let layout = NotchGeometry(screenFrame: screen, visibleFrame: screen, safeTop: 32)
        XCTAssertTrue(layout.hasNotch)
        XCTAssertEqual(layout.launcherFrame.midX, screen.midX)
        XCTAssertLessThanOrEqual(layout.launcherFrame.width, 220)
        XCTAssertEqual(layout.launcherFrame.height, 37)
    }
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
