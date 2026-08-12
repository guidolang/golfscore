import XCTest

final class GolfScoreUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        launch(arguments: ["-ui-testing", "-reset-data"])
    }

    func testAppStartsOnHoleOneWithExpectedBoundaryAndEmptyState() {
        XCTAssertTrue(app.navigationBars["Hole 1"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["holeBackButton"].exists)
        XCTAssertTrue(app.buttons["holeNextButton"].exists)
        XCTAssertTrue(app.buttons["showScorecardButton"].exists)
        XCTAssertTrue(app.staticTexts["Tap + Stroke to record a stroke for this hole."].exists)
        assertScorecardButtonIsAtBottom()
    }

    func testScorecardButtonStaysAtBottomWithShortStrokeList() {
        app.buttons["addStrokeButton"].tap()
        app.buttons["addStrokeButton"].tap()

        assertScorecardButtonIsAtBottom()
    }

    func testLongStrokeListCanScrollToScorecardButton() {
        for _ in 0..<12 {
            app.buttons["addStrokeButton"].tap()
        }

        let button = app.buttons["showScorecardButton"]
        XCTAssertFalse(button.isHittable)
        scrollToElement(button)
    }

    func testPreviousAndNextNavigateAcrossAllHolesAndLastHolePersists() {
        app.buttons["holeNextButton"].tap()
        XCTAssertTrue(app.navigationBars["Hole 2"].exists)
        app.buttons["holeBackButton"].tap()
        XCTAssertTrue(app.navigationBars["Hole 1"].exists)

        for expectedHole in 2...18 {
            app.buttons["holeNextButton"].tap()
            XCTAssertTrue(app.navigationBars["Hole \(expectedHole)"].exists)
        }

        XCTAssertFalse(app.buttons["holeNextButton"].exists)
        XCTAssertTrue(app.buttons["holeBackButton"].exists)

        app.terminate()
        launch(arguments: ["-ui-testing"])
        XCTAssertTrue(app.navigationBars["Hole 18"].exists)
    }

    func testSkippedHoleWarningReflectsWhetherPreviousHoleHasStrokes() {
        let skippedHoleWarning = app.staticTexts["skippedHoleWarning"]

        XCTAssertFalse(skippedHoleWarning.exists)

        app.buttons["holeNextButton"].tap()
        XCTAssertTrue(skippedHoleWarning.exists)
        XCTAssertEqual(skippedHoleWarning.label, "No strokes recorded for the previous hole")
        XCTAssertFalse(app.alerts["Skipped Hole"].exists)

        app.buttons["addStrokeButton"].tap()
        XCTAssertTrue(skippedHoleWarning.exists)
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "1 Stroke")
        XCTAssertFalse(app.alerts["Skipped Hole"].exists)

        app.buttons["holeBackButton"].tap()
        app.buttons["addStrokeButton"].tap()
        XCTAssertFalse(skippedHoleWarning.exists)

        app.buttons["holeNextButton"].tap()
        XCTAssertFalse(skippedHoleWarning.exists)
        XCTAssertFalse(app.alerts["Skipped Hole"].exists)
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "1 Stroke")
    }

    func testStrokeDeletionCanCancelOrDeleteAndRelabelsRows() {
        for _ in 0..<3 {
            app.buttons["addStrokeButton"].tap()
        }

        app.buttons["deleteStrokeButton_2"].tap()
        let deletionAlert = app.alerts["Delete Stroke 2?"]
        XCTAssertTrue(deletionAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(deletionAlert.staticTexts["Do you want to delete this stroke?"].exists)
        deletionAlert.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "3 Strokes")
        XCTAssertTrue(app.buttons["deleteStrokeButton_3"].exists)

        app.buttons["deleteStrokeButton_2"].tap()
        deletionAlert.buttons["Delete"].tap()

        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "2 Strokes")
        XCTAssertTrue(app.buttons["deleteStrokeButton_1"].exists)
        XCTAssertTrue(app.buttons["deleteStrokeButton_2"].exists)
        XCTAssertFalse(app.buttons["deleteStrokeButton_3"].exists)
    }

    func testStrokeNoteCanCancelClearAndSaveTrimmedMultilineText() {
        app.buttons["addStrokeButton"].tap()
        let noteButton = app.buttons["noteStrokeButton_1"]
        XCTAssertTrue(noteButton.exists)

        noteButton.tap()
        XCTAssertTrue(app.navigationBars["Stroke 1"].waitForExistence(timeout: 2))
        let editor = element("strokeNoteTextEditor")
        let clearButton = app.buttons["clearStrokeNoteButton"]
        XCTAssertTrue(clearButton.isHittable)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        editor.tap()
        editor.typeText("  Fairway bunker\nNear the lip  ")
        app.buttons["cancelStrokeNoteButton"].tap()
        XCTAssertFalse(element("strokeNote_1").exists)

        noteButton.tap()
        editor.tap()
        editor.typeText("  Fairway bunker\nNear the lip  ")
        clearButton.tap()
        app.buttons["cancelStrokeNoteButton"].tap()
        XCTAssertFalse(element("strokeNote_1").exists)

        noteButton.tap()
        editor.tap()
        editor.typeText("  Fairway bunker\nNear the lip  ")
        app.buttons["saveStrokeNoteButton"].tap()

        XCTAssertEqual(element("strokeNote_1").label, "Fairway bunker\nNear the lip")
        XCTAssertEqual(noteButton.label, "Edit Note for Stroke 1")
    }

    func testPuttsReminderChecksBothNavigationDirectionsOncePerVisit() {
        app.terminate()
        launch(arguments: ["-ui-testing", "-reset-data", "-ui-testing-putts-reminder"])

        app.buttons["holeNextButton"].tap()
        assertPuttsReminderAndClose()
        XCTAssertTrue(app.navigationBars["Hole 1"].exists)
        app.buttons["holeNextButton"].tap()
        XCTAssertTrue(app.navigationBars["Hole 2"].exists)

        app.buttons["holeBackButton"].tap()
        assertPuttsReminderAndClose()
        XCTAssertTrue(app.navigationBars["Hole 2"].exists)
        app.buttons["holeBackButton"].tap()
        XCTAssertTrue(app.navigationBars["Hole 1"].exists)
    }

    func testScorecardShowsTotalsAndHoleLinkSelectsMainHole() {
        app.terminate()
        launch(arguments: ["-ui-testing", "-reset-data", "-ui-testing-scorecard"])
        openScorecard()

        XCTAssertEqual(element("scorecardHoleCount_1").label, "2")
        XCTAssertEqual(element("scorecardHoleCount_2").label, "0")
        XCTAssertTrue(element("frontNineTotalRow").label.contains("2"))

        let holeTenLink = app.buttons["scorecardHole_10"]
        scrollToElement(holeTenLink)
        XCTAssertEqual(element("scorecardHoleCount_10").label, "3")
        holeTenLink.tap()

        XCTAssertTrue(app.navigationBars["Scorecard"].waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["Hole 10"].exists)
        app.buttons["holeBackButton"].tap()
        XCTAssertTrue(app.navigationBars["Hole 9"].exists)
    }

    func testScorecardCloseReturnsToCurrentHole() {
        app.buttons["holeNextButton"].tap()
        openScorecard()

        app.buttons["closeScorecardButton"].tap()

        XCTAssertFalse(app.navigationBars["Scorecard"].exists)
        XCTAssertTrue(app.navigationBars["Hole 2"].exists)
    }

    func testScorecardResetCanCancelOrClearAllScoresAndReturnToHoleOne() {
        app.terminate()
        launch(arguments: ["-ui-testing", "-reset-data", "-ui-testing-scorecard"])
        openScorecard()

        let resetButton = app.buttons["resetAllButton"]
        scrollToElement(resetButton)
        let shareButton = app.buttons["shareScorecardButton"]
        XCTAssertTrue(shareButton.exists)
        XCTAssertLessThan(shareButton.frame.minY, resetButton.frame.minY)
        resetButton.tap()
        let resetAlert = app.alerts["Reset All Holes?"]
        XCTAssertTrue(resetAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(resetAlert.staticTexts["Do you want to reset all holes?"].exists)
        resetAlert.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Scorecard"].exists)

        resetButton.tap()
        resetAlert.buttons["Reset"].tap()

        XCTAssertTrue(app.navigationBars["Scorecard"].waitForNonExistence(timeout: 2))
        XCTAssertTrue(app.navigationBars["Hole 1"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "0 Strokes")
    }

    func testStrokeAndSelectedHolePersistAcrossRelaunch() {
        app.buttons["holeNextButton"].tap()
        app.buttons["addStrokeButton"].tap()
        XCTAssertTrue(app.staticTexts["skippedHoleWarning"].exists)

        app.terminate()
        launch(arguments: ["-ui-testing"])

        XCTAssertTrue(app.navigationBars["Hole 2"].exists)
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "1 Stroke")
    }

    private func launch(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    private func openScorecard() {
        app.buttons["showScorecardButton"].tap()
        XCTAssertTrue(app.navigationBars["Scorecard"].waitForExistence(timeout: 2))
    }

    private func assertPuttsReminderAndClose() {
        let reminder = app.alerts["Reminder"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 2))
        XCTAssertTrue(reminder.staticTexts["Don't forget to record your putts"].exists)
        XCTAssertEqual(reminder.buttons.count, 1)
        reminder.buttons["Close"].tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func assertScorecardButtonIsAtBottom() {
        let button = app.buttons["showScorecardButton"]
        XCTAssertTrue(button.isHittable)
        XCTAssertLessThan(app.frame.maxY - button.frame.maxY, 80)
    }

    private func scrollToElement(_ element: XCUIElement, maximumSwipes: Int = 8) {
        var swipeCount = 0
        while !element.isHittable && swipeCount < maximumSwipes {
            app.swipeUp()
            swipeCount += 1
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to become visible after scrolling")
    }
}
