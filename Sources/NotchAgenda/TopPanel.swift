#if os(macOS)
import AppKit
import Combine
import Observation
import SwiftUI

final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    var onEscape: (() -> Void)?
    var acceptsEscape: () -> Bool = { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
    override func sendEvent(_ event: NSEvent) {
        // Intercept before NSTextView consumes Escape; leave IME composition and
        // sheets/popovers to AppKit so their own cancellation still works.
        if event.type == .keyDown, event.keyCode == 53, onEscape != nil,
           event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
           attachedSheet == nil, childWindows?.isEmpty ?? true, acceptsEscape(),
           !((firstResponder as? NSTextView)?.hasMarkedText() ?? false) {
            onEscape?()
            return
        }
        super.sendEvent(event)
    }
}

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor @Observable final class IslandState {
    var isPresented = false
    var isPinned = false
    var hoverEnabled: Bool
    init(hoverEnabled: Bool) { self.hoverEnabled = hoverEnabled }
}

@MainActor final class TopPanel {
    let state: IslandState
    private var panel: JournalPanel?
    private var launchers: [String: LauncherPanel] = [:]
    private var activeScreenID: String?
    private weak var store: TaskStore?
    private let defaults: UserDefaults
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var policy = HoverPolicy()
    private var menuTracking = false
    private var transition = 0
    private var started = false
    private let slideAnimator = PanelSlideAnimator()
    private var isRetracting = false
    private var allowHoverResume = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        state = IslandState(hoverEnabled: defaults.object(forKey: "notchagenda.hoverEnabled") as? Bool ?? true)
    }

    func start(store: TaskStore) {
        self.store = store
        guard !started else { return }
        started = true
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.refreshScreens() } }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.menuTracking = true } }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.menuTracking = false } }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: AppPreferences.didChange)
            .sink { [weak self] _ in Task { @MainActor in self?.refreshTitles() } }.store(in: &subscriptions)
        refreshScreens()
        updateTimer()
    }

    func stop() {
        transition += 1
        slideAnimator.cancel()
        isRetracting = false
        allowHoverResume = false
        timer?.invalidate()
        timer = nil
        subscriptions.removeAll()
        for launcher in launchers.values { launcher.orderOut(nil) }
        launchers.removeAll()
        panel?.orderOut(nil)
        state.isPresented = false
        started = false
    }

    func setHoverEnabled(_ enabled: Bool) {
        state.hoverEnabled = enabled
        defaults.set(enabled, forKey: "notchagenda.hoverEnabled")
        policy = HoverPolicy()
        refreshScreens()
        updateTimer()
        if !enabled && !state.isPinned { collapse() }
    }

    func setPinned(_ pinned: Bool) { state.isPinned = pinned }

    func toggle(store: TaskStore) {
        if state.isPresented { collapse() }
        else { show(store: store) }
    }

    // A manual invocation is pinned and may take keyboard focus. Hover never does.
    func show(store: TaskStore) {
        self.store = store
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        present(on: screen, focus: true, pinned: true)
    }

    func collapse(automatically: Bool = false) {
        guard state.isPresented else { return }
        // Avoid hiding an editor that could not save its text.
        guard store?.journal.flushAllDrafts() != false else { state.isPinned = true; return }
        transition += 1
        let generation = transition
        state.isPresented = false
        state.isPinned = false
        policy.suppressUntilExit()
        guard let panel else { return }
        let finish: () -> Void = { [weak self, weak panel] in
            guard let self, self.transition == generation else { return }
            panel?.orderOut(nil)
            self.isRetracting = false
            self.allowHoverResume = false
            if let screen = self.activeScreenID, self.state.hoverEnabled { self.launchers[screen]?.orderFrontRegardless() }
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            slideAnimator.cancel()
            finish()
            return
        }
        isRetracting = true
        allowHoverResume = automatically
        let safeTop = NSScreen.screens.first(where: { screenID($0) == activeScreenID })?.safeAreaInsets.top ?? 0
        let current = slideAnimator.presentation(of: panel)
        let destination = PanelPresentation(frame: PanelSlideMotion.retractedFrame(from: current.frame, safeTop: safeTop), opacity: 0)
        slideAnimator.animate(panel, to: destination, duration: (store?.preferences.hoverSpeed ?? .medium).closingDuration, completion: finish)
    }

    private func updateTimer() {
        timer?.invalidate()
        timer = nil
        guard started && state.hoverEnabled else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard state.hoverEnabled, store != nil else { return }
        let mouse = NSEvent.mouseLocation
        if isRetracting, allowHoverResume, let panel,
           let currentScreen = NSScreen.screens.first(where: { screenID($0) == activeScreenID }) {
            let presentation = slideAnimator.presentation(of: panel)
            let overVisiblePanel = presentation.opacity > 0.12 && presentation.frame.insetBy(dx: -10, dy: -8).contains(mouse)
            if overVisiblePanel || geometry(currentScreen).triggerFrame.contains(mouse) {
                present(on: currentScreen, focus: false, pinned: false)
                return
            }
        }
        let screen: NSScreen?
        if state.isPresented { screen = NSScreen.screens.first { screenID($0) == activeScreenID } }
        else { screen = NSScreen.screens.first { geometry($0).triggerFrame.contains(mouse) } }
        guard let screen else {
            _ = policy.update(now: ProcessInfo.processInfo.systemUptime, inTrigger: false, inPanel: false, presented: false, protected: false)
            return
        }
        let layout = geometry(screen)
        let inPanel = panel.map { window in
            state.isPresented && (window.frame.insetBy(dx: -10, dy: -8).contains(mouse) || layout.bridgeFrame.contains(mouse))
        } ?? false
        let editing = panel.map { $0.isKeyWindow && $0.firstResponder is NSTextView } ?? false
        let modal = panel?.attachedSheet != nil || !(panel?.childWindows?.isEmpty ?? true) || menuTracking
        let protected = state.isPinned || editing || modal || NSEvent.pressedMouseButtons != 0
        let decision = policy.update(now: ProcessInfo.processInfo.systemUptime, inTrigger: layout.triggerFrame.contains(mouse), inPanel: inPanel, presented: state.isPresented, protected: protected)
        switch decision {
        case .expand: present(on: screen, focus: false, pinned: false)
        case .collapse: collapse(automatically: true)
        case nil: break
        }
    }

    private func present(on screen: NSScreen, focus: Bool, pinned: Bool) {
        guard let store else { return }
        transition += 1
        let layout = geometry(screen)
        let window: JournalPanel
        if let panel { window = panel }
        else {
            window = JournalPanel(contentRect: layout.expandedFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = store.preferences.text("NotchAgenda 頂部日記")
            window.setAccessibilityIdentifier("notchagenda.journalPanel")
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.becomesKeyOnlyIfNeeded = false
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.isMovableByWindowBackground = false
            window.onEscape = { [weak self] in self?.collapse() }
            window.acceptsEscape = { [weak self] in self?.menuTracking != true }
            window.contentView = NSHostingView(rootView: IslandExpandedView(store: store, state: state, pin: { [weak self] in self?.setPinned($0) }, dismiss: { [weak self] in self?.collapse() }))
            panel = window
        }
        let canContinue = window.isVisible && activeScreenID == screenID(screen) && (state.isPresented || isRetracting)
        let current = canContinue ? slideAnimator.presentation(of: window) : nil
        slideAnimator.cancel()
        isRetracting = false
        allowHoverResume = false
        activeScreenID = screenID(screen)
        launchers[screenID(screen)]?.orderOut(nil)
        state.isPinned = pinned
        state.isPresented = true
        let destination = PanelPresentation(frame: layout.expandedFrame, opacity: 1)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let initial = reduceMotion ? destination : current ?? PanelPresentation(frame: PanelSlideMotion.retractedFrame(from: layout.expandedFrame, safeTop: screen.safeAreaInsets.top), opacity: 0)
        window.setFrame(initial.frame, display: true)
        window.alphaValue = initial.opacity
        if focus { window.makeKeyAndOrderFront(nil) }
        else { window.orderFrontRegardless() }
        if !reduceMotion && initial != destination {
            slideAnimator.animate(window, to: destination, duration: store.preferences.hoverSpeed.openingDuration)
        }
    }

    private func screenID(_ screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? screen.localizedName
    }

    private func geometry(_ screen: NSScreen) -> NotchGeometry {
        let camera = NotchGeometry.cameraFrame(screenFrame: screen.frame, safeTop: screen.safeAreaInsets.top, leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
        return NotchGeometry(screenFrame: screen.frame, visibleFrame: screen.visibleFrame, safeTop: screen.safeAreaInsets.top, cameraFrame: camera)
    }

    private func refreshScreens() {
        guard started else { return }
        if isRetracting {
            transition += 1
            slideAnimator.cancel()
            panel?.orderOut(nil)
            isRetracting = false
            allowHoverResume = false
        }
        let current = Set(NSScreen.screens.map(screenID))
        for id in Array(launchers.keys) where !current.contains(id) { launchers.removeValue(forKey: id)?.orderOut(nil) }
        guard let store else { return }
        for screen in NSScreen.screens {
            let id = screenID(screen)
            let layout = geometry(screen)
            let launcher: LauncherPanel
            if let existing = launchers[id] { launcher = existing }
            else {
                launcher = LauncherPanel(contentRect: layout.launcherFrame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                launcher.title = store.preferences.text("NotchAgenda hover 入口")
                launcher.level = .statusBar
                launcher.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                launcher.isOpaque = false
                launcher.backgroundColor = .clear
                launcher.hasShadow = false
                launcher.hidesOnDeactivate = false
                launcher.ignoresMouseEvents = true // Do not block menu-bar clicks.
                launcher.contentView = NSHostingView(rootView: IslandLauncherView(store: store, hasNotch: layout.hasNotch))
                launchers[id] = launcher
            }
            if let host = launcher.contentView as? NSHostingView<IslandLauncherView> {
                host.rootView = IslandLauncherView(store: store, hasNotch: layout.hasNotch)
            }
            launcher.setFrame(layout.launcherFrame, display: true)
            if state.hoverEnabled && !(state.isPresented && activeScreenID == id) { launcher.orderFrontRegardless() }
            else { launcher.orderOut(nil) }
        }
        if state.isPresented {
            if let screen = NSScreen.screens.first(where: { screenID($0) == activeScreenID }) ?? NSScreen.main {
                let pinned = state.isPinned
                present(on: screen, focus: false, pinned: pinned)
            } else { collapse() }
        }
    }

    private func refreshTitles() {
        guard let store else { return }
        panel?.title = store.preferences.text("NotchAgenda 頂部日記")
        for launcher in launchers.values { launcher.title = store.preferences.text("NotchAgenda hover 入口") }
    }
}

private struct IslandExpandedView: View {
    let store: TaskStore
    let state: IslandState
    var pin: (Bool) -> Void
    var dismiss: () -> Void
    private var prefs: AppPreferences { store.preferences }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("NotchAgenda", systemImage: "checklist").font(.system(size: 11, weight: .semibold))
                Spacer()
                Button { pin(!state.isPinned) } label: { Image(systemName: state.isPinned ? "pin.fill" : "pin").frame(width: 28, height: 24) }
                    .help(prefs.text(state.isPinned ? "取消釘選，移開滑鼠後自動收起" : "釘選，保持面板展開")).accessibilityLabel(prefs.text(state.isPinned ? "取消釘選" : "釘選面板"))
                Button(action: dismiss) { Image(systemName: "chevron.up").frame(width: 26, height: 24) }.help(prefs.text("收起 · Esc")).accessibilityLabel(prefs.text("收起頂部日記"))
            }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 14).padding(.vertical, 3)
            MacJournalView(store: store, floating: true)
        }.padding(5).background(.black, in: RoundedRectangle(cornerRadius: 24)).environment(\.locale, prefs.locale)
    }
}

private struct IslandLauncherView: View {
    let store: TaskStore
    let hasNotch: Bool
    var body: some View {
        Group {
            if hasNotch {
                // Hardware covers the upper area; draw only a quiet handle below it.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule().fill(.white.opacity(0.25)).frame(width: 22, height: 2).padding(.bottom, 1)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let count = store.pendingOccurrences(on: context.date, scope: .day, carryOver: true).count
                    HStack(spacing: 7) {
                        Image(systemName: "checklist").font(.system(size: 10))
                        Text("NotchAgenda").font(.system(size: 10, weight: .medium))
                        Text("\(count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    }.foregroundStyle(.white.opacity(0.9)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black, in: UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))
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
