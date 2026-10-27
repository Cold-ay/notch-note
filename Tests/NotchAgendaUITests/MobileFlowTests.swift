import XCTest

final class MobileFlowTests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launchEnvironment["NOTCHAGENDA_TEST_STORE"] = UUID().uuidString
        app.launch()
        return app
    }
    @MainActor private func add(_ text: String, in app: XCUIApplication) {
        let input = app.textViews["journal.task.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        input.tap(); input.typeText(text)
        if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].tap() }
        app.buttons["journal.task.add"].tap()
    }
    @MainActor func testCompleteReopenDeleteRestoreAndPersistence() {
        let app = launch()
        app.buttons["journal.tab.anytime"].tap()
        add("Read a book\nWater plants", in: app)
        XCTAssertTrue(app.staticTexts["Read a book"].waitForExistence(timeout: 5))
        let checkbox = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "task.complete.")).firstMatch
        checkbox.tap()
        XCTAssertFalse(app.staticTexts["Read a book"].exists)
        app.segmentedControls["journal.content"].buttons["已完成"].tap()
        XCTAssertTrue(app.staticTexts["Read a book"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "task.complete.")).firstMatch.tap()
        app.segmentedControls["journal.content"].buttons["待辦事項"].tap()
        let menu = app.buttons["事項選項"].firstMatch
        menu.tap(); app.buttons["刪除"].tap()
        app.buttons["trash.open"].tap()
        XCTAssertTrue(app.buttons["還原"].waitForExistence(timeout: 5))
        app.buttons["還原"].tap()
        app.buttons["trash.close"].tap()
        app.terminate(); app.launch()
        app.buttons["journal.tab.anytime"].tap()
        XCTAssertTrue(app.staticTexts["Read a book"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Water plants"].exists)
    }
    @MainActor func testRecurringTaskResetsOnFollowingDay() {
        let app = launch()
        app.buttons["journal.repeat"].tap()
        app.buttons["每天"].tap()
        add("Practice Duolingo", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "task.complete.")).firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Practice Duolingo"].exists)
        app.buttons["journal.nextDate"].tap()
        XCTAssertTrue(app.staticTexts["Practice Duolingo"].waitForExistence(timeout: 5))
        app.buttons["journal.previousDate"].tap()
        XCTAssertFalse(app.staticTexts["Practice Duolingo"].exists)
    }
    @MainActor func testLanguageAppearanceAndDiarySurviveRelaunch() {
        let app = launch()
        app.buttons["settings.open"].tap()
        app.buttons["settings.language"].tap()
        app.buttons["English"].tap()
        app.buttons["settings.appearance.rose"].tap()
        let dotted = app.buttons["settings.paper.dotted"]
        if !dotted.isHittable { app.swipeUp() }
        dotted.tap()
        app.buttons["settings.close"].tap()
        app.segmentedControls["journal.content"].buttons["Journal"].tap()
        let diary = app.textViews["journal.diary.input"]
        XCTAssertTrue(diary.waitForExistence(timeout: 5))
        diary.tap(); diary.typeText("A good day worth remembering.")
        app.buttons["keyboard.done"].tap()
        let saved = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Saved · ")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.segmentedControls["journal.content"].buttons["Journal"].tap()
        XCTAssertTrue(app.textViews["journal.diary.input"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["journal.diary.input"].value as? String, "A good day worth remembering.")
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.buttons["settings.language"].exists)
        XCTAssertTrue(app.staticTexts["English"].exists)
        XCTAssertTrue(app.buttons["settings.appearance.rose"].isSelected)
        if !app.buttons["settings.paper.dotted"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["settings.paper.dotted"].isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "iPhone dark language settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
