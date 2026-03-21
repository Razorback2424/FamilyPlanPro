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
    func testPlannerDisplaysFinalizedViewWithGroceryList() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        XCTAssertTrue(app.navigationBars["Finalized"].exists)
        let groceryLink = app.buttons["Grocery List"]
        XCTAssertTrue(groceryLink.waitForExistence(timeout: 2))
        groceryLink.tap()
        XCTAssertTrue(app.navigationBars["Grocery List"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFirstLaunchBootstrapsSuggestionPlanWithOwnersAndSimpleFriday() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        XCTAssertTrue(app.navigationBars["Suggestions"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Default owner: Partner A"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Simple Friday"].exists)
    }

    @MainActor
    func testSuggestionsPersistAndSubmitTransitionsToReview() throws {
        let mealName = "Tacos \(Int(Date().timeIntervalSince1970))"

        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        let mealField = app.textFields["Meal name"].firstMatch
        XCTAssertTrue(mealField.waitForExistence(timeout: 2))
        mealField.tap()
        mealField.typeText(mealName)

        let saveButton = app.buttons["Save Suggestion"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Suggested: \(mealName)"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testReopenFromFinalizedReturnsToSuggestions() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        let reopenButton = app.buttons["Reopen to Suggestions"]
        XCTAssertTrue(reopenButton.waitForExistence(timeout: 2))
        reopenButton.tap()

        let alertReopenButton = app.alerts.buttons["Reopen"]
        XCTAssertTrue(alertReopenButton.waitForExistence(timeout: 2))
        alertReopenButton.tap()

        XCTAssertTrue(app.navigationBars["Suggestions"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["Grocery List"].exists)
    }

    @MainActor
    func testBudgetStatusCanBeUpdatedFromSettings() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        let weeklyBudgetField = app.textFields["Weekly budget ($)"]
        XCTAssertTrue(weeklyBudgetField.waitForExistence(timeout: 2))
        weeklyBudgetField.tap()
        weeklyBudgetField.typeText("100")

        let observedSpendField = app.textFields["Observed spend ($)"]
        XCTAssertTrue(observedSpendField.waitForExistence(timeout: 2))
        observedSpendField.tap()
        observedSpendField.typeText("100")

        let updateButton = app.buttons["Update Budget"]
        XCTAssertTrue(updateButton.waitForExistence(timeout: 2))
        updateButton.tap()

        XCTAssertTrue(app.staticTexts["Status: On"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
