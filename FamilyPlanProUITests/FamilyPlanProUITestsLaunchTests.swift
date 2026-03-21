//
//  FamilyPlanProUITestsLaunchTests.swift
//  FamilyPlanProUITests
//
//  Created by Sean Keller on 6/25/25.
//

import XCTest

final class FamilyPlanProUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_RESET"] = "1"
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Planner"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Planner"].tap()
        XCTAssertTrue(app.navigationBars["Weekly Planner"].waitForExistence(timeout: 2))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
