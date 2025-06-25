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
        _ = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        try manager.save()

        // Reopen a new container pointing to the same store
        let container2 = try ModelContainer(for: schema, configurations: [config])
        let families = try container2.mainContext.fetch(FetchDescriptor<Family>())
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families.first?.users.count, 1)
    }
}
