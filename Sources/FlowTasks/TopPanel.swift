#if os(macOS)
import AppKit
import SwiftUI

// Borderless NSPanel does not accept keyboard focus unless explicitly enabled.
final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor final class TopPanel {
    private var panel: JournalPanel?

    func toggle(store: TaskStore) {
        if let panel, panel.isVisible { panel.orderOut(nil) }
        else { show(store: store) }
    }

    func show(store: TaskStore) {
        guard let screen = NSScreen.main else { return }
        let width: CGFloat = min(460, screen.visibleFrame.width)
        let height: CGFloat = min(780, screen.visibleFrame.height - 16)
        let top = min(screen.visibleFrame.maxY, screen.frame.maxY - screen.safeAreaInsets.top)
        let frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: top - height - 8, width: width, height: height)
        let window: JournalPanel
        if let panel {
            window = panel
        } else {
            window = JournalPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "FlowTasks 浮動日記"
            window.setAccessibilityIdentifier("flowtasks.journalPanel")
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            // Only the top handle drags the window; selecting text must not move it.
            window.isMovableByWindowBackground = false
            window.contentView = NSHostingView(rootView: MacJournalView(store: store, floating: true, dismiss: { [weak window] in window?.orderOut(nil) }))
            panel = window
        }
        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct JournalDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { HandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class HandleView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}
#endif
