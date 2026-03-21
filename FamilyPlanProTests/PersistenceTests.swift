import XCTest
import SwiftData
@testable import FamilyPlanPro

@MainActor
final class PersistenceTests: XCTestCase {
    func testLocalPersistence() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            OwnershipRulesSnap.self,
            MealSlot.self,
            MealSuggestion.self,
            GroceryList.self,
            GroceryItem.self,
        ])
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Test.sqlite")
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        _ = manager.addUser(name: "Dummy", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        _ = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)
        try manager.save()

        let container2 = try ModelContainer(for: schema, configurations: [config])
        let families = try container2.mainContext.fetch(FetchDescriptor<Family>())
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families.first?.members.count, 1)
    }

    func testCurrentWeekPlanPersistsSevenDinnerSlotsOwnershipAndSimpleFriday() throws {
        let schema = Schema([
            Family.self,
            User.self,
            WeeklyPlan.self,
            OwnershipRulesSnap.self,
            MealSlot.self,
            MealSuggestion.self,
            GroceryList.self,
            GroceryItem.self,
        ])
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Test-WeekPlan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Store.sqlite")
        let config = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [config])
        let flags = FeatureFlags(mealsOwnershipRules: true, mealsGroceryList: true, notificationsGroceryCadence: true, mealsBudgetStatus: true)
        let manager = DataManager(context: container.mainContext, flags: flags)
        let family = manager.createFamily(name: "Test")
        let alice = manager.addUser(name: "Alice", to: family)
        let bob = manager.addUser(name: "Bob", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)

        XCTAssertEqual(plan.mealSlots.count, 7)
        XCTAssertTrue(plan.mealSlots.allSatisfy { $0.mealType == .dinner })

        let mondayDinner = plan.mealSlots.first { $0.dayOfWeek == .monday }
        let sundayDinner = plan.mealSlots.first { $0.dayOfWeek == .sunday }
        let fridayDinner = plan.mealSlots.first { $0.dayOfWeek == .friday }

        XCTAssertEqual(mondayDinner?.owner?.id, alice.id)
        XCTAssertEqual(sundayDinner?.owner?.id, bob.id)
        XCTAssertEqual(fridayDinner?.owner?.id, alice.id)
        XCTAssertEqual(fridayDinner?.isSimple, true)

        _ = manager.setPendingSuggestion(mealName: "Tacos",
                                         responsibleUser: bob,
                                         author: alice,
                                         for: mondayDinner!)
        try manager.save()

        let container2 = try ModelContainer(for: schema, configurations: [config])
        let storedPlans = try container2.mainContext.fetch(FetchDescriptor<WeeklyPlan>())
        XCTAssertEqual(storedPlans.count, 1)
        guard let storedPlan = storedPlans.first else {
            return XCTFail("Missing stored plan")
        }

        XCTAssertEqual(storedPlan.mealSlots.count, 7)
        let persistedMonday = storedPlan.mealSlots.first { $0.dayOfWeek == .monday }
        let persistedFriday = storedPlan.mealSlots.first { $0.dayOfWeek == .friday }
        XCTAssertEqual(persistedMonday?.pendingSuggestion?.mealName, "Tacos")
        XCTAssertEqual(persistedMonday?.pendingSuggestion?.responsibleUserID, bob.id)
        XCTAssertEqual(persistedFriday?.isSimple, true)
    }

    func testFamilySettingsPersistEditsAndMembershipChanges() throws {
        let schema = Schema([
            Family.self,
            User.self,
        ])

        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FamilySettings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Store.sqlite")
        let config = ModelConfiguration(schema: schema, url: url)

        let container = try ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Original")
        let alice = manager.addUser(name: "Alice", to: family)
        try manager.save()

        family.name = "Updated Family"
        _ = manager.addUser(name: "Bob", to: family)
        container.mainContext.delete(alice)
        try container.mainContext.save()

        let container2 = try ModelContainer(for: schema, configurations: [config])
        let fetchedFamilies = try container2.mainContext.fetch(FetchDescriptor<Family>())

        XCTAssertEqual(fetchedFamilies.count, 1)
        XCTAssertEqual(fetchedFamilies.first?.name, "Updated Family")
        XCTAssertEqual(fetchedFamilies.first?.members.count, 1)
        XCTAssertEqual(fetchedFamilies.first?.members.first?.name, "Bob")
    }
}
