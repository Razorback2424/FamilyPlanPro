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
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Toast",
                                         responsibleUser: userB,
                                         author: userA,
                                         for: slot)
        try manager.save()

        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userA.id)
        XCTAssertEqual(slot.pendingSuggestion?.responsibleUserID, userB.id)
        XCTAssertEqual(plan.status, .suggestionMode)
        manager.submitPlanForReview(plan, by: userA)
        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userA.id)
        XCTAssertEqual(plan.reviewInitiatorUserID, userA.id)

        manager.acceptPendingSuggestion(in: slot)
        manager.finalizeIfPossible(plan)
        XCTAssertEqual(plan.status, .finalized)
        XCTAssertEqual(slot.finalizedSuggestion?.authorUserID, userA.id)
        XCTAssertEqual(slot.finalizedSuggestion?.responsibleUserID, userB.id)
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
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Toast",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try manager.save()

        manager.submitPlanForReview(plan, by: userA)
        _ = manager.rejectPendingSuggestion(in: slot,
                                           newMealName: "Bagel",
                                           author: userB,
                                           responsibleUser: userB,
                                           reasonForChange: nil,
                                           in: plan)

        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(plan.reviewInitiatorUserID, userA.id)
        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.responsibleUserID, userB.id)
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
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Toast",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try manager.save()

        manager.submitPlanForReview(plan, by: userA)
        _ = manager.rejectPendingSuggestion(in: slot,
                                           newMealName: "Bagel",
                                           author: userB,
                                           responsibleUser: userB,
                                           reasonForChange: nil,
                                           in: plan)

        _ = manager.rejectPendingSuggestion(in: slot,
                                           newMealName: "Cereal",
                                           author: userA,
                                           responsibleUser: userA,
                                           reasonForChange: nil,
                                           in: plan)

        XCTAssertEqual(plan.status, .conflict)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(plan.reviewInitiatorUserID, userA.id)
        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userA.id)
        XCTAssertEqual(slot.pendingSuggestion?.responsibleUserID, userA.id)
    }

    func testConflictResolutionReturnsToReviewMode() throws {
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
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Toast",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        manager.submitPlanForReview(plan, by: userA)
        _ = manager.rejectPendingSuggestion(in: slot,
                                           newMealName: "Bagel",
                                           author: userB,
                                           responsibleUser: userB,
                                           reasonForChange: nil,
                                           in: plan)
        _ = manager.rejectPendingSuggestion(in: slot,
                                           newMealName: "Cereal",
                                           author: userA,
                                           responsibleUser: userA,
                                           reasonForChange: "We agreed to try something lighter",
                                           in: plan)

        XCTAssertEqual(plan.status, .conflict)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userA.id)

        _ = manager.resolveConflict(for: slot,
                                     finalMealName: "Smoothies",
                                     decidedBy: userB,
                                     responsibleUser: userA,
                                     reasonForChange: "Mutual agreement",
                                     in: plan)

        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.mealName, "Smoothies")
        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.responsibleUserID, userA.id)
        XCTAssertEqual(slot.pendingSuggestion?.reasonForChange, "Mutual agreement")
    }

    func testFinalizeRequiresAllSlots() throws {
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
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let breakfast = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        let dinner = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)

        _ = manager.setPendingSuggestion(mealName: "Toast",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: breakfast)
        _ = manager.setPendingSuggestion(mealName: "Pasta",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: dinner)

        manager.submitPlanForReview(plan, by: userA)
        manager.acceptPendingSuggestion(in: breakfast)
        manager.finalizeIfPossible(plan)

        XCTAssertEqual(plan.status, .reviewMode)

        manager.acceptPendingSuggestion(in: dinner)
        manager.finalizeIfPossible(plan)

        XCTAssertEqual(plan.status, .finalized)
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
