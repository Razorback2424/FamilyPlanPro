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
        XCTAssertTrue(app.staticTexts["Every meal for the week has been finalized. Here's the summary."].exists)
        XCTAssertTrue(app.staticTexts["Test"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testAcceptingAllSlotsDisplaysFinalizedSummary() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "reviewMode"
        app.launch()

        let acceptButton = app.buttons["Accept"].firstMatch
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 2))
        acceptButton.tap()

        let finalizedNavigationBar = app.navigationBars["Finalized"]
        XCTAssertTrue(finalizedNavigationBar.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Test"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Responsible: Alice"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testShowsAddFamilyViewWhenEmpty() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["Create a Family"].exists)
    }

    @MainActor
    func testCreateFamilyGeneratesPlan() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()
        let field = app.textFields["Family Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 1))
        field.tap()
        field.typeText("Test")
        let memberField = app.textFields["Member Name"]
        XCTAssertTrue(memberField.waitForExistence(timeout: 1))
        memberField.tap()
        memberField.typeText("Alex")
        let addButton = app.buttons["Add Person"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 1))
        addButton.tap()
        app.buttons["Create"].tap()
        let suggestions = app.navigationBars["Suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 2))
    }

    @MainActor
    func testAddedMembersAppearInResponsiblePicker() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        let familyField = app.textFields["Family Name"]
        XCTAssertTrue(familyField.waitForExistence(timeout: 1))
        familyField.tap()
        familyField.typeText("Responsible Test")

        let memberField = app.textFields["Member Name"]
        XCTAssertTrue(memberField.waitForExistence(timeout: 1))
        memberField.tap()
        memberField.typeText("Alex")
        let addButton = app.buttons["Add Person"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 1))
        addButton.tap()

        memberField.tap()
        memberField.typeText("Jamie")
        addButton.tap()

        app.buttons["Create"].tap()

        let suggestions = app.navigationBars["Suggestions"]
        XCTAssertTrue(suggestions.waitForExistence(timeout: 2))

        let mealField = app.textFields["Meal name"].firstMatch
        XCTAssertTrue(mealField.waitForExistence(timeout: 2))
        mealField.tap()
        mealField.typeText("Chili")

        let saveButton = app.buttons["Save Suggestion"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Responsible: Alex"].waitForExistence(timeout: 2))

        let predicate = NSPredicate(format: "label CONTAINS[c] %@", "Responsible")
        let responsibleMenu = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(responsibleMenu.waitForExistence(timeout: 2))
        responsibleMenu.tap()

        let alternateOption = app.buttons["Jamie"]
        XCTAssertTrue(alternateOption.waitForExistence(timeout: 2))
        alternateOption.tap()

        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Responsible: Jamie"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testStartNewWeekButtonCreatesPlan() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_EMPTY_STATE"] = "1"
        app.launch()

        let startButton = app.buttons["Start New Week"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        startButton.tap()

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

        let startButton = app.buttons["Start New Week"]
        if startButton.waitForExistence(timeout: 2) {
            startButton.tap()
        }

        let mealField = app.textFields["Meal name"].firstMatch
        XCTAssertTrue(mealField.waitForExistence(timeout: 2))
        mealField.tap()
        mealField.typeText(mealName)

        let saveButton = app.buttons["Save Suggestion"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let suggestionLabelIdentifier = "Suggested: \(mealName)"
        XCTAssertTrue(app.staticTexts[suggestionLabelIdentifier].waitForExistence(timeout: 2))

        app.terminate()

        let relaunch = XCUIApplication()
        relaunch.launchEnvironment["UITEST_RESET"] = "0"
        relaunch.launchEnvironment["UITEST_EMPTY_STATE"] = "1"
        relaunch.launch()

        XCTAssertTrue(relaunch.staticTexts[suggestionLabelIdentifier].waitForExistence(timeout: 2))

        let submitButton = relaunch.buttons["Submit for Review"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        submitButton.tap()

        XCTAssertTrue(relaunch.navigationBars["Review"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
