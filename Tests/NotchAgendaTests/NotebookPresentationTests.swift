#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import NotchAgenda

final class NotebookPresentationTests: XCTestCase {
    @MainActor func testOriginalLayoutAndDraftSurviveAppearanceChangesWithOptionalPreviews() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TaskStore(file: directory.appendingPathComponent("tasks.json"))
        store.add("Keep my writing 原文", date: Date(), scope: .day)
        let preferences = store.preferences
        preferences.setLanguage(.english)
        let panel = JournalPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 780), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: AnyView(MacJournalView(store: store, floating: true)))
        panel.contentView = host
        defer { panel.contentView = nil }
        func editor(in view: NSView) -> NSTextView? {
            if let editor = view as? NSTextView { return editor }
            return view.subviews.lazy.compactMap { editor(in: $0) }.first
        }
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
        let composer = try XCTUnwrap(editor(in: host), "Original layout opens directly with a task composer.")
        composer.string = "Unsubmitted draft 待寫"
        composer.didChangeText()
        let draft = composer.string
        for appearance in NotebookAppearance.allCases {
            preferences.setAppearance(appearance)
            preferences.setPaper(.grid)
            for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
            XCTAssertTrue(editor(in: host) === composer, "Changing appearance must keep the same editor.")
            XCTAssertEqual(editor(in: host)?.string, draft)
            if let output = ProcessInfo.processInfo.environment["NOTCHAGENDA_PREVIEW_DIR"] {
                let folder = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try snapshot(host, to: folder.appendingPathComponent("appearance-\(appearance.id).png"))
            }
        }
        if let output = ProcessInfo.processInfo.environment["NOTCHAGENDA_PREVIEW_DIR"] {
            host.rootView = AnyView(AppSettingsView(preferences: preferences))
            for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
            try snapshot(host, to: URL(fileURLWithPath: output).appendingPathComponent("settings-appearance.png"))
        }
        XCTAssertEqual(store.tasks.first?.title, "Keep my writing 原文")
    }
    @MainActor private func snapshot(_ host: NSView, to file: URL) throws {
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: file)
    }

}
#endif
