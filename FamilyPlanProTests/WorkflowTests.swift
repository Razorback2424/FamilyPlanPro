import XCTest
import SwiftData
@testable import FamilyPlanPro

final class WorkflowTests: XCTestCase {
    func testStateTransitions() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Toast", user: userA, for: slot)
        try manager.save()

        XCTAssertEqual(plan.status, .suggestionMode)
        manager.submitPlanForReview(plan, by: userA)
        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userA.name)

        manager.acceptPendingSuggestion(in: slot)
        manager.finalizeIfPossible(plan)
        XCTAssertEqual(plan.status, .finalized)
    }

    func testCounterReviewKeepsReviewMode() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Toast", user: userA, for: slot)
        try manager.save()

        manager.submitPlanForReview(plan, by: userA)
        _ = manager.rejectPendingSuggestion(in: slot, newTitle: "Bagel", by: userB, in: plan)

        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.name)
    }

    func testConflictOnSecondRejection() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Toast", user: userA, for: slot)
        try manager.save()

        manager.submitPlanForReview(plan, by: userA)
        _ = manager.rejectPendingSuggestion(in: slot, newTitle: "Bagel", by: userB, in: plan)

        _ = manager.rejectPendingSuggestion(in: slot, newTitle: "Cereal", by: userA, in: plan)

        XCTAssertEqual(plan.status, .conflict)
        XCTAssertEqual(plan.lastModifiedByUserID, userA.name)
    }

    func testCurrentPlanLookup() throws {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let startOfWeek = calendar.startOfWeek(for: Date())
        let plan = WeeklyPlan(startDate: startOfWeek)
        let plans = [plan]

        calendar.firstWeekday = 1
        let startOfThisWeek = calendar.startOfWeek(for: Date())
        let found = plans.first { calendar.isDate($0.startDate, equalTo: startOfThisWeek, toGranularity: .day) }
        XCTAssertNotNil(found)
    }
}
