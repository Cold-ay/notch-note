import SwiftUI

@main struct NotchAgendaApp: App {
    @State private var store = TaskStore()
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @State private var panel = TopPanel()
    @State private var openedPanel = false
    #endif
    var body: some Scene {
        WindowGroup("NotchAgenda", id: "main") {
            #if os(macOS)
            MacJournalView(store: store)
                .frame(minWidth: 460, minHeight: 720)
                .onAppear {
                    appDelegate.journal = store.journal
                    appDelegate.panel = panel
                    appDelegate.openMainWindow = showMainWindow
                    if !openedPanel {
                        openedPanel = true
                        panel.start(store: store)
                        // Bootstrap the shared store once, then start quietly at the notch.
                        DispatchQueue.main.async {
                            for window in NSApp.windows where !(window is NSPanel) && window.canBecomeMain { window.orderOut(nil) }
                        }
                    }
                }
                .toolbar { Button("頂部待辦", systemImage: "rectangle.topthird.inset.filled") { panel.toggle(store: store) } }
            #else
            ContentView(store: store)
            #endif
        }
        #if os(macOS)
        MenuBarExtra("NotchAgenda", systemImage: "checkmark.circle") {
            Button("顯示／隱藏頂部待辦") { panel.toggle(store: store) }
            Button("開啟主視窗", action: showMainWindow)
            Toggle("啟用頂部 Hover", isOn: Binding(get: { panel.state.hoverEnabled }, set: { panel.setHoverEnabled($0) }))
            if panel.state.isPresented {
                Toggle("保持面板展開", isOn: Binding(get: { panel.state.isPinned }, set: { panel.setPinned($0) }))
            }
            Divider()
            Button("結束") { NSApplication.shared.terminate(nil) }
        }
        #endif
    }
    #if os(macOS)
    private func showMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate()
    }
    #endif
}

#if os(macOS)
@MainActor final class MacAppDelegate: NSObject, NSApplicationDelegate {
    weak var journal: JournalStore?
    weak var panel: TopPanel?
    var openMainWindow: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow?()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { panel?.stop() }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard journal?.flushAllDrafts() != false else {
            let alert = NSAlert()
            alert.messageText = "日記尚未儲存"
            alert.informativeText = journal?.errorMessage ?? "未儲存文字仍在編輯區，請先處理儲存問題。"
            alert.addButton(withTitle: "返回日記")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM executables also need a foreground application to accept typing.
        NSApplication.shared.setActivationPolicy(.regular)
    }
}
#endif
