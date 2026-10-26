import SwiftUI

@main struct FlowTasksApp: App {
    @State private var store = TaskStore()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    @State private var panel = TopPanel()
    @State private var openedPanel = false
    #endif
    var body: some Scene {
        WindowGroup {
            #if os(macOS)
            MacJournalView(store: store)
                .frame(minWidth: 460, minHeight: 720)
                .onAppear {
                    if !openedPanel { openedPanel = true; panel.show(store: store) }
                }
                .toolbar { Button("頂部待辦", systemImage: "rectangle.topthird.inset.filled") { panel.toggle(store: store) } }
            #else
            ContentView(store: store)
            #endif
        }
        #if os(macOS)
        MenuBarExtra("FlowTasks", systemImage: "checkmark.circle") {
            Button("顯示／隱藏頂部待辦") { panel.toggle(store: store) }
            Divider()
            Button("結束") { NSApplication.shared.terminate(nil) }
        }
        #endif
    }
}

#if os(macOS)
@MainActor final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM executables also need a foreground application to accept typing.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }
}
#endif
