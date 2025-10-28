import XCTest
import SwiftData
@testable import FamilyPlanPro

final class PersistenceTests: XCTestCase {
    func testLocalPersistence() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Test.sqlite")
        let config = ModelConfiguration(url: url, schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        _ = manager.addUser(name: "Dummy", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        _ = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        try manager.save()

        // Reopen a new container pointing to the same store
        let container2 = try ModelContainer(for: schema, configurations: [config])
        let families = try container2.mainContext.fetch(FetchDescriptor<Family>())
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families.first?.members.count, 1)
    }

    func testCurrentWeekPlanPrepopulatesSlotsAndSuggestionsPersist() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Test-WeekPlan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Store.sqlite")
        let config = ModelConfiguration(url: url, schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let alice = manager.addUser(name: "Alice", to: family)
        let bob = manager.addUser(name: "Bob", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)

        XCTAssertEqual(plan.mealSlots.count, DayOfWeek.allCases.count * MealType.allCases.count)

        guard let mondayBreakfast = plan.mealSlots.first(where: { $0.dayOfWeek == .monday && $0.mealType == .breakfast }) else {
            XCTFail("Expected monday breakfast slot")
            return
        }

        _ = manager.setPendingSuggestion(mealName: "Tacos",
                                         responsibleUser: bob,
                                         author: alice,
                                         for: mondayBreakfast)
        try manager.save()

        let container2 = try ModelContainer(for: schema, configurations: [config])
        let descriptor = FetchDescriptor<WeeklyPlan>()
        let storedPlans = try container2.mainContext.fetch(descriptor)
        XCTAssertEqual(storedPlans.count, 1)
        guard let storedPlan = storedPlans.first else {
            XCTFail("Missing plan")
            return
        }

        XCTAssertEqual(storedPlan.mealSlots.count, DayOfWeek.allCases.count * MealType.allCases.count)
        let persistedSlot = storedPlan.mealSlots.first { $0.dayOfWeek == .monday && $0.mealType == .breakfast }
        XCTAssertEqual(persistedSlot?.pendingSuggestion?.mealName, "Tacos")
        XCTAssertEqual(persistedSlot?.pendingSuggestion?.authorUserID, alice.id)
        XCTAssertEqual(persistedSlot?.pendingSuggestion?.responsibleUserID, bob.id)

        try? FileManager.default.removeItem(at: directory)
    }
}
