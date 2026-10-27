#if os(macOS)
import AppKit
import XCTest
@testable import NotchAgenda

final class PanelSlideTests: XCTestCase {
    private let expanded = NSRect(x: 400, y: 100, width: 460, height: 780)

    func testOpeningMovesDownWithoutResizingAndEasesAtBothEnds() {
        let hidden = PanelSlideMotion.retractedFrame(from: expanded, safeTop: 32)
        let motion = PanelSlideMotion(from: PanelPresentation(frame: hidden, opacity: 0), to: PanelPresentation(frame: expanded, opacity: 1), startedAt: 0, duration: 1)
        XCTAssertEqual(motion.sample(at: 0).frame, hidden)
        XCTAssertEqual(motion.sample(at: 1).frame, expanded)
        let early = motion.sample(at: 0.1)
        let middle = motion.sample(at: 0.5)
        let late = motion.sample(at: 0.9)
        XCTAssertGreaterThan(early.frame.minY, middle.frame.minY)
        XCTAssertGreaterThan(middle.frame.minY, late.frame.minY)
        XCTAssertEqual(middle.frame.size, expanded.size)
        XCTAssertEqual(middle.opacity, 0.5, accuracy: 0.0001)
        XCTAssertLessThan(early.opacity, 0.1)
        XCTAssertGreaterThan(late.opacity, 0.9)
    }

    func testClosingMovesUpAndFadesWithStableSize() {
        let hidden = PanelSlideMotion.retractedFrame(from: expanded, safeTop: 0)
        let motion = PanelSlideMotion(from: PanelPresentation(frame: expanded, opacity: 1), to: PanelPresentation(frame: hidden, opacity: 0), startedAt: 10, duration: 1)
        XCTAssertGreaterThan(motion.sample(at: 10.5).frame.minY, expanded.minY)
        XCTAssertEqual(motion.sample(at: 10.5).frame.size, expanded.size)
        XCTAssertEqual(motion.sample(at: 11).opacity, 0)
        XCTAssertEqual(motion.sample(at: 11).frame, hidden)
    }

    func testReversingRetractionContinuesFromExactPresentation() {
        let hidden = PanelSlideMotion.retractedFrame(from: expanded, safeTop: 32)
        let closing = PanelSlideMotion(from: PanelPresentation(frame: expanded, opacity: 1), to: PanelPresentation(frame: hidden, opacity: 0), startedAt: 0, duration: 1)
        let interrupted = closing.sample(at: 0.4)
        let opening = PanelSlideMotion(from: interrupted, to: PanelPresentation(frame: expanded, opacity: 1), startedAt: 0.4, duration: 1)
        XCTAssertEqual(opening.sample(at: 0.4), interrupted)
        XCTAssertLessThan(opening.sample(at: 0.9).frame.minY, interrupted.frame.minY)
        XCTAssertGreaterThan(opening.sample(at: 0.9).opacity, interrupted.opacity)
    }

    func testMotionClampsSamplesAndZeroDurationForReducedMotion() {
        let from = PanelPresentation(frame: expanded, opacity: 0)
        let to = PanelPresentation(frame: expanded.offsetBy(dx: 0, dy: 60), opacity: 1)
        let motion = PanelSlideMotion(from: from, to: to, startedAt: 10, duration: 1)
        XCTAssertEqual(motion.sample(at: -100), from)
        XCTAssertEqual(motion.sample(at: 100), to)
        XCTAssertFalse(motion.isFinished(at: 10.5))
        XCTAssertTrue(motion.isFinished(at: 11))
        XCTAssertEqual(PanelSlideMotion(from: from, to: to, startedAt: 0, duration: 0).sample(at: 0), to)
    }

    @MainActor func testReplacingAnimationDropsOldHideCompletion() {
        _ = NSApplication.shared
        let window = JournalPanel(contentRect: expanded, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let animator = PanelSlideAnimator()
        defer { animator.cancel() }
        var oldHideCalled = false
        var newShowCalled = false
        animator.animate(window, to: PanelPresentation(frame: expanded.offsetBy(dx: 0, dy: 60), opacity: 0), duration: 1) { oldHideCalled = true }
        XCTAssertTrue(animator.isRunning)
        animator.animate(window, to: PanelPresentation(frame: expanded, opacity: 1), duration: 0) { newShowCalled = true }
        XCTAssertFalse(oldHideCalled)
        XCTAssertTrue(newShowCalled)
        XCTAssertFalse(animator.isRunning)
        XCTAssertEqual(window.frame, expanded)
        XCTAssertEqual(window.alphaValue, 1)
    }
}
#endif
