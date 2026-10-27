import XCTest
@testable import NotchAgenda

final class AppPreferencesTests: XCTestCase {
    @MainActor private func withPreferences(_ body: (AppPreferences, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("preferences.json")
        try body(AppPreferences(file: file), file)
    }

    @MainActor func testLanguageAppearanceAndPaperSurviveRestartIndependently() throws {
        try withPreferences { preferences, file in
            XCTAssertEqual(preferences.appearance, .cream)
            XCTAssertEqual(preferences.paper, .ruled)
            for language in AppLanguage.allCases {
                XCTAssertTrue(preferences.setLanguage(language))
                XCTAssertEqual(AppPreferences(file: file).language, language)
            }
            for appearance in NotebookAppearance.allCases {
                for paper in NotebookPaper.allCases {
                    XCTAssertTrue(preferences.setAppearance(appearance))
                    XCTAssertTrue(preferences.setPaper(paper))
                    let reloaded = AppPreferences(file: file)
                    XCTAssertEqual(reloaded.appearance, appearance)
                    XCTAssertEqual(reloaded.paper, paper)
                    XCTAssertEqual(reloaded.language, .english)
                }
            }
        }
    }

    @MainActor func testHoverSpeedMigratesAndPersistsWithoutChangingOtherPreferences() throws {
        try withPreferences { _, file in
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(#"{"language":"en","appearance":"rose","paper":"dotted"}"#.utf8).write(to: file)
            let preferences = AppPreferences(file: file)
            XCTAssertEqual(preferences.hoverSpeed, .medium)
            for speed in HoverSpeed.allCases {
                XCTAssertTrue(preferences.setHoverSpeed(speed))
                let reloaded = AppPreferences(file: file)
                XCTAssertEqual(reloaded.hoverSpeed, speed)
                XCTAssertEqual(reloaded.language, .english)
                XCTAssertEqual(reloaded.appearance, .rose)
                XCTAssertEqual(reloaded.paper, .dotted)
            }
        }
    }

    @MainActor func testAppearanceChangesLeaveUserDataUntouched() throws {
        try withPreferences { preferences, file in
            let store = TaskStore(file: file.deletingLastPathComponent().appendingPathComponent("tasks.json"))
            store.add("保留原文 user text", date: Date(), scope: .day)
            store.journal.setDraft("今天的日記不翻譯。", on: Date(), scope: .day)
            store.journal.flushAllDrafts()
            let original = store.tasks
            preferences.setAppearance(.rose)
            preferences.setPaper(.grid)
            preferences.setLanguage(.english)
            XCTAssertEqual(store.tasks, original)
            XCTAssertEqual(store.journal.text(on: Date(), scope: .day), "今天的日記不翻譯。")
        }
    }

    @MainActor func testThreeLanguagesCoverDatesCountsAndSystemErrorPrefixes() throws {
        try withPreferences { preferences, _ in
            XCTAssertEqual(preferences.text("我的筆記本"), "我的筆記本")
            preferences.setLanguage(.simplifiedChinese)
            XCTAssertEqual(preferences.text("設定"), "设置")
            XCTAssertEqual(preferences.text("週目標"), "周目标")
            let filename = "/tmp/我的筆記.json"
            XCTAssertTrue(preferences.text("未能儲存設定：" + filename).hasSuffix(filename))
            preferences.setLanguage(.english)
            XCTAssertEqual(preferences.text("我的筆記本"), "My notebooks")
            XCTAssertEqual(preferences.format("已完成（%d）", 3), "Done (3)")
            XCTAssertEqual(preferences.weekdaySymbols, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
            XCTAssertEqual(preferences.text("未能儲存設定：" + filename), "Could not save settings: " + filename)
            for page in NotebookPage.allCases {
                XCTAssertNotEqual(preferences.text(page.title), page.title)
                XCTAssertNotEqual(preferences.text(page.subtitle), page.subtitle)
            }
            for appearance in NotebookAppearance.allCases { XCTAssertNotEqual(preferences.text(appearance.title), appearance.title) }
            for paper in NotebookPaper.allCases { XCTAssertNotEqual(preferences.text(paper.title), paper.title) }
        }
    }

    @MainActor func testOldBookshelfSettingsRestoreOriginalAppearanceAndKeepLanguage() throws {
        try withPreferences { _, file in
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(#"{"language":"en","notebooks":["month"],"startsOnShelf":true,"covers":{"day":"forest"}}"#.utf8).write(to: file)
            let loaded = AppPreferences(file: file)
            XCTAssertEqual(loaded.language, .english)
            XCTAssertEqual(loaded.appearance, .cream)
            XCTAssertEqual(loaded.paper, .ruled)
            XCTAssertTrue(loaded.setPaper(.dotted))
            XCTAssertEqual(AppPreferences(file: file).language, .english)
        }
    }

    @MainActor func testCorruptSettingsAreNeverOverwritten() throws {
        try withPreferences { _, file in
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let original = Data("{broken JSON".utf8)
            try original.write(to: file)
            let loaded = AppPreferences(file: file)
            XCTAssertFalse(loaded.setLanguage(.english))
            XCTAssertEqual(try Data(contentsOf: file), original)
            XCTAssertNotNil(loaded.errorMessage)
        }
    }

    @MainActor func testFailedSaveDoesNotPretendLanguageChanged() throws {
        try withPreferences { _, file in
            let blocker = file.deletingLastPathComponent().appendingPathComponent("blocker")
            try FileManager.default.createDirectory(at: blocker.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: blocker)
            let loaded = AppPreferences(file: blocker.appendingPathComponent("preferences.json"))
            XCTAssertFalse(loaded.setLanguage(.english))
            XCTAssertEqual(loaded.language, .traditionalChinese)
            XCTAssertNotNil(loaded.errorMessage)
        }
    }
}
