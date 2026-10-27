#if os(macOS)
import AppKit

/// All rectangles use AppKit global screen coordinates (origin at bottom left).
struct NotchGeometry {
    let hasNotch: Bool
    let triggerFrame: NSRect
    let launcherFrame: NSRect
    let expandedFrame: NSRect
    let bridgeFrame: NSRect

    /// Reads both global and screen-local auxiliary rectangles without assuming the
    /// display starts at (0, 0). All returned measurements are points, not pixels.
    static func cameraFrame(screenFrame: NSRect, safeTop: CGFloat, leftArea: NSRect?, rightArea: NSRect?) -> NSRect? {
        guard safeTop > 0, let left = leftArea, let right = rightArea,
              left.width > 0, right.width > 0 else { return nil }
        let width = right.minX - left.maxX
        guard width > 0, width < screenFrame.width else { return nil }
        let isLocal = abs(left.minX) < 1 && abs(right.maxX - screenFrame.width) < 1
        let isGlobal = abs(left.minX - screenFrame.minX) < 1 && abs(right.maxX - screenFrame.maxX) < 1
        guard isLocal || isGlobal else { return nil }
        let x = left.maxX + (isGlobal ? 0 : screenFrame.minX)
        return NSRect(x: x, y: screenFrame.maxY - safeTop, width: width, height: safeTop)
    }

    init(screenFrame: NSRect, visibleFrame: NSRect, safeTop: CGFloat, cameraWidth: CGFloat = 0, cameraFrame: NSRect? = nil) {
        hasNotch = safeTop > 0
        let measured = cameraFrame.flatMap { frame -> NSRect? in
            guard frame.width > 0, frame.minX >= screenFrame.minX, frame.maxX <= screenFrame.maxX else { return nil }
            return frame
        }
        let fallbackWidth = cameraWidth > 0 ? cameraWidth : min(220, max(140, safeTop * 6))
        let width = hasNotch ? min(measured?.width ?? fallbackWidth, screenFrame.width) : 160
        let centerX = hasNotch ? measured?.midX ?? screenFrame.midX : screenFrame.midX
        if hasNotch {
            // Match the hardware width exactly; only a five-point lip is added below it.
            launcherFrame = NSRect(x: centerX - width / 2, y: screenFrame.maxY - safeTop - 5, width: width, height: safeTop + 5)
        } else {
            // Preserve the existing non-notched capsule and menu-bar positioning.
            launcherFrame = NSRect(x: centerX - width / 2, y: visibleFrame.maxY - 26, width: width, height: 24)
        }
        let triggerWidth = min(width + (hasNotch ? 20 : 40), screenFrame.width)
        triggerFrame = NSRect(x: centerX - triggerWidth / 2, y: launcherFrame.minY - 4, width: triggerWidth, height: screenFrame.maxY - launcherFrame.minY + 4)
        let panelWidth = min(460, visibleFrame.width)
        let panelHeight = min(780, visibleFrame.height - 16)
        let panelTop = min(visibleFrame.maxY, screenFrame.maxY - safeTop) + (hasNotch ? 0 : -6)
        expandedFrame = NSRect(x: min(max(centerX - panelWidth / 2, visibleFrame.minX), visibleFrame.maxX - panelWidth), y: panelTop - panelHeight, width: panelWidth, height: panelHeight)
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
