//
//  FamilyPlanProUITests.swift
//  FamilyPlanProUITests
//
//  Created by Sean Keller on 6/25/25.
//

import XCTest

final class FamilyPlanProUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testPlannerDisplaysSuggestionView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_STATUS"] = "suggestionMode"
        app.launch()
        XCTAssertTrue(app.navigationBars["Suggestions"].exists)
    }

    @MainActor
    func testPlannerDisplaysReviewView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_STATUS"] = "reviewMode"
        app.launch()
        XCTAssertTrue(app.navigationBars["Review"].exists)
    }

    @MainActor
    func testPlannerDisplaysFinalizedView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()
        XCTAssertTrue(app.navigationBars["Finalized"].exists)
    }

    @MainActor
    func testShowsAddFamilyViewWhenEmpty() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Create a Family"].exists)
    }

    @MainActor
    func testCreateFamilyGeneratesPlan() throws {
        let app = XCUIApplication()
        app.launch()
        let field = app.textFields["Family Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 1))
        field.tap()
        field.typeText("Test")
        app.buttons["Create"].tap()
        let suggestions = app.navigationBars["Suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
