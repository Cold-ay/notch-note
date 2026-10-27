#if os(macOS)
import AppKit

struct PanelPresentation: Equatable {
    var frame: NSRect
    var opacity: CGFloat
}

/// A position/opacity transition: equal-sized endpoints avoid journal reflow.
struct PanelSlideMotion {
    static let openingDuration: TimeInterval = 0.52
    static let closingDuration: TimeInterval = 0.46
    let from: PanelPresentation
    let to: PanelPresentation
    let startedAt: TimeInterval
    let duration: TimeInterval

    static func retractedFrame(from expandedFrame: NSRect, safeTop: CGFloat) -> NSRect {
        expandedFrame.offsetBy(dx: 0, dy: min(80, max(48, safeTop * 1.75)))
    }

    func sample(at time: TimeInterval) -> PanelPresentation {
        let progress = duration > 0 ? min(1, max(0, (time - startedAt) / duration)) : 1
        let t = CGFloat(progress * progress * (3 - 2 * progress))
        return PanelPresentation(
            frame: NSRect(x: from.frame.minX + (to.frame.minX - from.frame.minX) * t,
                          y: from.frame.minY + (to.frame.minY - from.frame.minY) * t,
                          width: from.frame.width + (to.frame.width - from.frame.width) * t,
                          height: from.frame.height + (to.frame.height - from.frame.height) * t),
            opacity: from.opacity + (to.opacity - from.opacity) * t)
    }
    func isFinished(at time: TimeInterval) -> Bool { time >= startedAt + duration }
}

@MainActor final class PanelSlideAnimator {
    private weak var window: NSWindow?
    private var motion: PanelSlideMotion?
    private var timer: Timer?
    private var completion: (() -> Void)?
    var isRunning: Bool { motion != nil }

    func presentation(of window: NSWindow) -> PanelPresentation {
        if self.window === window, let motion { return motion.sample(at: ProcessInfo.processInfo.systemUptime) }
        return PanelPresentation(frame: window.frame, opacity: window.alphaValue)
    }

    func animate(_ window: NSWindow, to destination: PanelPresentation, duration: TimeInterval, completion: (() -> Void)? = nil) {
        let current = presentation(of: window)
        cancel()
        self.window = window
        self.completion = completion
        motion = PanelSlideMotion(from: current, to: destination, startedAt: ProcessInfo.processInfo.systemUptime, duration: duration)
        apply(current, to: window)
        if duration <= 0 { advance(); return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advance() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        motion = nil
        completion = nil
        window = nil
    }

    private func advance() {
        guard let window, let motion else { cancel(); return }
        let time = ProcessInfo.processInfo.systemUptime
        apply(motion.sample(at: time), to: window)
        if motion.isFinished(at: time) {
            let callback = completion
            cancel()
            callback?()
        }
    }
    private func apply(_ presentation: PanelPresentation, to window: NSWindow) {
        window.setFrame(presentation.frame, display: true)
        window.alphaValue = presentation.opacity
    }
}
#endif
