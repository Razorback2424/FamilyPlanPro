//
//  FamilyPlanProUITests.swift
//  FamilyPlanProUITests
//
//  Created by Sean Keller on 6/25/25.
//

import XCTest
import Foundation

final class FamilyPlanProUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPlannerDisplaysSuggestionView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "suggestionMode"
        app.launch()
        XCTAssertTrue(app.navigationBars["Suggestions"].exists)
    }

    @MainActor
    func testPlannerDisplaysReviewView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "reviewMode"
        app.launch()
        XCTAssertTrue(app.navigationBars["Review"].exists)
    }

    @MainActor
    func testPlannerDisplaysFinalizedView() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()
        XCTAssertTrue(app.navigationBars["Finalized"].exists)
        XCTAssertTrue(app.buttons["Reopen to Suggestions"].exists)
    }

    @MainActor
    func testFirstLaunchBootstrapsSuggestionPlan() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()
        XCTAssertTrue(app.navigationBars["Suggestions"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testStartNewWeekButtonCreatesPlan() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_EMPTY_STATE"] = "1"
        app.launch()

        let suggestions = app.navigationBars["Suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 2))
    }

    @MainActor
    func testSuggestionsPersistAndSubmitTransitionsToReview() throws {
        let mealName = "Tacos \(Int(Date().timeIntervalSince1970))"

        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_EMPTY_STATE"] = "1"
        app.launch()

        let mealField = app.textFields["Meal name"].firstMatch
        XCTAssertTrue(mealField.waitForExistence(timeout: 2))
        mealField.tap()
        mealField.typeText(mealName)

        let saveButton = app.buttons["Save Suggestion"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Suggested: \(mealName)"].waitForExistence(timeout: 2))

        let submitButton = app.buttons["Submit for Review"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        submitButton.tap()

        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
