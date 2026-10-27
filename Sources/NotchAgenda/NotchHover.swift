#if os(macOS)
import AppKit

/// All rectangles use AppKit global screen coordinates (origin at bottom left).
struct NotchGeometry {
    let triggerFrame: NSRect
    let launcherFrame: NSRect
    let expandedFrame: NSRect
    let bridgeFrame: NSRect

    init(screenFrame: NSRect, visibleFrame: NSRect, safeTop: CGFloat, cameraWidth: CGFloat = 0) {
        let hasNotch = safeTop > 0
        let width = min(max(cameraWidth + 28, hasNotch ? 190 : 160), 360)
        let launcherHeight: CGFloat = 24
        let launcherTop = hasNotch ? screenFrame.maxY - safeTop + 2 : visibleFrame.maxY - 2
        launcherFrame = NSRect(x: screenFrame.midX - width / 2, y: launcherTop - launcherHeight, width: width, height: launcherHeight)
        let triggerWidth = min(width + 40, screenFrame.width)
        triggerFrame = NSRect(x: screenFrame.midX - triggerWidth / 2, y: launcherFrame.minY - 4, width: triggerWidth, height: screenFrame.maxY - launcherFrame.minY + 4)
        let panelWidth = min(460, visibleFrame.width)
        let panelHeight = min(780, visibleFrame.height - 16)
        let panelTop = min(visibleFrame.maxY, screenFrame.maxY - safeTop) - 6
        expandedFrame = NSRect(x: min(max(screenFrame.midX - panelWidth / 2, visibleFrame.minX), visibleFrame.maxX - panelWidth), y: panelTop - panelHeight, width: panelWidth, height: panelHeight)
        // Include the small travel gap so the panel stays open on the way down.
        bridgeFrame = triggerFrame.union(expandedFrame).insetBy(dx: -10, dy: -8)
    }
}

/// A deterministic state machine, independent of AppKit timers or real mouse input.
struct HoverPolicy {
    enum Decision: Equatable { case expand, collapse }
    var openDelay: TimeInterval = 0.24
    var closeDelay: TimeInterval = 0.7
    private var enteredAt: TimeInterval?
    private var exitedAt: TimeInterval?
    private var waitsForExit = false

    mutating func suppressUntilExit() {
        enteredAt = nil
        exitedAt = nil
        waitsForExit = true
    }

    mutating func update(now: TimeInterval, inTrigger: Bool, inPanel: Bool, presented: Bool, protected: Bool) -> Decision? {
        if waitsForExit {
            if !inTrigger { waitsForExit = false }
            enteredAt = nil
            return nil
        }
        if presented {
            enteredAt = nil
            if inTrigger || inPanel || protected { exitedAt = nil; return nil }
            if exitedAt == nil { exitedAt = now }
            if now - exitedAt! >= closeDelay { exitedAt = nil; return .collapse }
        } else {
            exitedAt = nil
            guard inTrigger, !protected else { enteredAt = nil; return nil }
            if enteredAt == nil { enteredAt = now }
            if now - enteredAt! >= openDelay { enteredAt = nil; return .expand }
        }
        return nil
    }
}
#endif
