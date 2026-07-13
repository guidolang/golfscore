import XCTest

final class GolfScoreUITests: XCTestCase {
    private var app: XCUIApplication!

    private var totalStrokesElement: XCUIElement {
        app.descendants(matching: .any)["totalStrokesCount"]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-data"]
        app.launch()
    }

    func testAddStrokeReachesMaximumAndHoleResetCanCancelOrConfirm() {
        app.buttons["holeButton_1"].tap()

        XCTAssertTrue(app.navigationBars["Hole 1"].exists)
        let addButton = app.buttons["addStrokeButton"]
        for _ in 0..<9 {
            addButton.tap()
        }

        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "9 Strokes")
        XCTAssertFalse(addButton.isEnabled)
        XCTAssertTrue(app.otherElements["strokeRow_1"].exists || app.staticTexts["Stroke 1"].exists)

        let resetHoleButton = app.buttons["resetHoleButton"]
        scrollToElement(resetHoleButton)
        resetHoleButton.tap()
        XCTAssertTrue(app.alerts.staticTexts["Do you want to reset this hole?"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "9 Strokes")

        resetHoleButton.tap()
        app.alerts.buttons["Reset"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["holeStrokeCount"].label, "0 Strokes")
        XCTAssertTrue(addButton.isEnabled)
    }

    func testHomeTogglesBetweenNineAndEighteenHolesWithoutNavigationBar() {
        XCTAssertEqual(app.navigationBars.count, 0)
        XCTAssertTrue(app.buttons["holeButton_1"].exists)
        XCTAssertFalse(app.buttons["holeButton_10"].exists)

        let toggleButton = app.buttons["holeCountToggleButton"]
        scrollToElement(toggleButton)
        XCTAssertEqual(toggleButton.label, "Show 18 Holes")
        toggleButton.tap()

        XCTAssertTrue(app.buttons["holeButton_10"].exists)
        XCTAssertTrue(app.buttons["holeButton_1"].exists)

        let hole18 = app.buttons["holeButton_18"]
        scrollToElement(hole18)
        hole18.tap()
        app.buttons["addStrokeButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        scrollToElement(totalStrokesElement)
        XCTAssertEqual(totalStrokesElement.label, "1 Total Strokes")
        scrollToElement(toggleButton)
        XCTAssertEqual(toggleButton.label, "Show 9 Holes")
        toggleButton.tap()

        XCTAssertTrue(app.buttons["holeButton_9"].exists)
        XCTAssertFalse(app.buttons["holeButton_10"].exists)
        XCTAssertEqual(totalStrokesElement.label, "1 Total Strokes")
        XCTAssertEqual(app.navigationBars.count, 0)
    }

    func testResetAllCanCancelOrConfirm() {
        app.buttons["holeButton_2"].tap()
        app.buttons["addStrokeButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        scrollToElement(totalStrokesElement)
        XCTAssertEqual(totalStrokesElement.label, "1 Total Strokes")
        let resetAllButton = app.buttons["resetAllButton"]
        scrollToElement(resetAllButton)
        resetAllButton.tap()
        XCTAssertTrue(app.alerts.staticTexts["Do you want to reset all holes?"].exists)
        app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(totalStrokesElement.label, "1 Total Strokes")

        resetAllButton.tap()
        app.alerts.buttons["Reset"].firstMatch.tap()
        XCTAssertEqual(totalStrokesElement.label, "0 Total Strokes")
    }

    func testScorePersistsAcrossRelaunchWithoutResetArgument() {
        app.buttons["holeButton_3"].tap()
        app.buttons["addStrokeButton"].tap()
        app.terminate()

        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        scrollToElement(totalStrokesElement)
        XCTAssertEqual(totalStrokesElement.label, "1 Total Strokes")
    }

    private func scrollToElement(_ element: XCUIElement, maximumSwipes: Int = 6) {
        var swipeCount = 0
        while !element.isHittable && swipeCount < maximumSwipes {
            app.swipeUp()
            swipeCount += 1
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to become visible after scrolling")
    }

}
