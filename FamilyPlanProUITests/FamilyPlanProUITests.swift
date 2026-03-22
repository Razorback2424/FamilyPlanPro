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
    func testUITestStatusAndDebugRouteShareLaunchMapping() throws {
        let statusApp = XCUIApplication()
        statusApp.launchEnvironment["UITEST_RESET"] = "1"
        statusApp.launchEnvironment["UITEST_STATUS"] = "reviewMode"
        statusApp.launch()
        XCTAssertTrue(statusApp.navigationBars["Review"].waitForExistence(timeout: 2))
        statusApp.terminate()

        let routeApp = XCUIApplication()
        routeApp.launchArguments = ["-ui_debug_route", "review"]
        routeApp.launch()
        XCTAssertTrue(routeApp.navigationBars["Review"].waitForExistence(timeout: 2))
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
    func testCurrentWeekDefaultsMoveToSettings() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "suggestionMode"
        app.launch()

        XCTAssertTrue(app.navigationBars["Suggestions"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Ownership Rules"].exists)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["This Week Meal Defaults"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Edit household defaults"].exists)
    }

    @MainActor
    func testThisWeekOverviewOpensFromFinalizedPlanner() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        let thisWeekEntry = app.buttons["this-week-entry"]
        XCTAssertTrue(thisWeekEntry.waitForExistence(timeout: 2))
        thisWeekEntry.tap()

        XCTAssertTrue(app.navigationBars["This Week"].waitForExistence(timeout: 2))
        let finalizedMeal = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "finalized-meal-")).firstMatch
        XCTAssertTrue(finalizedMeal.waitForExistence(timeout: 2))
    }

    @MainActor
    func testFinalizedGroceryFlowOpensGroupedSectionsAndAllowsItemEdit() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        let groceryLink = app.buttons["Grocery List"]
        XCTAssertTrue(groceryLink.waitForExistence(timeout: 2))
        groceryLink.tap()

        XCTAssertTrue(app.navigationBars["Grocery List"].waitForExistence(timeout: 2))
        let weekdayHeaders = Set(Calendar.current.weekdaySymbols)
        let visibleWeekdayHeaders = Set(app.staticTexts.allElementsBoundByIndex.map(\.label)).intersection(weekdayHeaders)
        XCTAssertGreaterThanOrEqual(visibleWeekdayHeaders.count, 2)

        let addButton = app.buttons["Add Item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))

        let itemFieldsBeforeAdd = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grocery-item-"))
        let initialItemCount = itemFieldsBeforeAdd.count
        addButton.tap()

        let itemFieldsAfterAdd = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grocery-item-"))
        var pollAttempts = 0
        while itemFieldsAfterAdd.count <= initialItemCount && pollAttempts < 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            pollAttempts += 1
        }

        let newestField = itemFieldsAfterAdd.allElementsBoundByIndex.last ?? itemFieldsAfterAdd.element(boundBy: itemFieldsAfterAdd.count - 1)
        XCTAssertTrue(newestField.waitForExistence(timeout: 2))
        if !newestField.isHittable {
            app.swipeUp()
        }
        newestField.tap()
        newestField.typeText("Bananas")
        if app.keyboards.firstMatch.exists {
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            } else if app.keyboards.buttons["Done"].exists {
                app.keyboards.buttons["Done"].tap()
            }
        }
        XCTAssertTrue(((newestField.value as? String) ?? "").contains("Bananas"))
    }

    @MainActor
    func testFinalizedGroceryDeleteUndoRestoresDeletedItem() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["UITEST_STATUS"] = "finalized"
        app.launch()

        let groceryLink = app.buttons["Grocery List"]
        XCTAssertTrue(groceryLink.waitForExistence(timeout: 2))
        groceryLink.tap()

        XCTAssertTrue(app.navigationBars["Grocery List"].waitForExistence(timeout: 2))

        let addButton = app.buttons["Add Item"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 2))

        let itemFieldsBeforeAdd = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grocery-item-"))
        let initialItemCount = itemFieldsBeforeAdd.count
        addButton.tap()

        let itemFieldsAfterAdd = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "grocery-item-"))
        var pollAttempts = 0
        while itemFieldsAfterAdd.count <= initialItemCount && pollAttempts < 10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            pollAttempts += 1
        }

        let newestField = itemFieldsAfterAdd.allElementsBoundByIndex.last ?? itemFieldsAfterAdd.element(boundBy: itemFieldsAfterAdd.count - 1)
        XCTAssertTrue(newestField.waitForExistence(timeout: 2))
        var swipeAttempts = 0
        while !newestField.isHittable && swipeAttempts < 4 {
            app.swipeUp()
            swipeAttempts += 1
        }
        XCTAssertTrue(newestField.isHittable)
        newestField.tap()
        let deletedItemName = "Oranges"
        newestField.typeText(deletedItemName)
        if app.keyboards.firstMatch.exists {
            if app.keyboards.buttons["Return"].exists {
                app.keyboards.buttons["Return"].tap()
            } else if app.keyboards.buttons["Done"].exists {
                app.keyboards.buttons["Done"].tap()
            }
        }

        XCTAssertTrue(((newestField.value as? String) ?? "").contains(deletedItemName))

        newestField.swipeLeft()
        let deleteButton = app.buttons["Delete"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        let undoButton = app.buttons["Undo"].firstMatch
        XCTAssertTrue(undoButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Grocery item deleted"].waitForExistence(timeout: 2))
        undoButton.tap()

        let restoredField = app.textFields.matching(NSPredicate(format: "value CONTAINS %@", deletedItemName)).firstMatch
        XCTAssertTrue(restoredField.waitForExistence(timeout: 2))
        XCTAssertTrue(((restoredField.value as? String) ?? "").contains(deletedItemName))
        XCTAssertFalse(app.staticTexts["Grocery item deleted"].exists)
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
    func testSimpleFridayTemplateCanPrefillSuggestion() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        let templateButton = app.buttons["Use Simple Friday Template"]
        XCTAssertTrue(templateButton.waitForExistence(timeout: 2))
        templateButton.tap()

        let leftoversOption = app.buttons["Leftovers"]
        XCTAssertTrue(leftoversOption.waitForExistence(timeout: 2))
        leftoversOption.tap()

        let saveButton = app.buttons["Save Suggestion"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Suggested: Leftovers"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSaveAndSubmitBlockWhenResponsibleIsUnassigned() throws {
        let mealName = "Tacos \(Int(Date().timeIntervalSince1970))"

        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        let mealField = app.textFields["Meal name"].firstMatch
        XCTAssertTrue(mealField.waitForExistence(timeout: 2))
        mealField.tap()
        mealField.typeText(mealName)

        let responsiblePicker = app.buttons["Partner A"].firstMatch
        if responsiblePicker.waitForExistence(timeout: 2) {
            responsiblePicker.tap()
        } else {
            let fallbackPicker = app.buttons["Responsible"].firstMatch
            XCTAssertTrue(fallbackPicker.waitForExistence(timeout: 2))
            fallbackPicker.tap()
        }

        let unassignedOption = app.buttons["Unassigned"].firstMatch
        XCTAssertTrue(unassignedOption.waitForExistence(timeout: 2))
        unassignedOption.tap()

        let saveButton = app.buttons["Save Suggestion"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 2))
        saveButton.tap()

        let blockedAlert = app.alerts["Assign a Meal Owner"]
        XCTAssertTrue(blockedAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["This meal day has no owner. Choose a responsible person before saving or submitting."].waitForExistence(timeout: 2))
        blockedAlert.buttons["OK"].tap()

        XCTAssertFalse(app.staticTexts["Suggested: \(mealName)"].exists)

        let submitButton = app.buttons["Submit for Review"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        submitButton.tap()

        XCTAssertTrue(app.alerts["Assign a Meal Owner"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testOwnershipRulesFlagOffHidesOwnershipAndSimpleFridayAffordances() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launchEnvironment["FEATURE_FLAGS"] = "ff.meals.ownershipRules=false"
        app.launch()

        XCTAssertTrue(app.navigationBars["Suggestions"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Simple Friday"].exists)
        XCTAssertFalse(app.staticTexts["Default owner: Partner A"].exists)
        XCTAssertFalse(app.buttons["Use Simple Friday Template"].exists)
        XCTAssertFalse(app.staticTexts["Ownership Rules"].exists)
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
