import XCTest
import SwiftData
@testable import FamilyPlanPro

@MainActor
final class WorkflowTests: XCTestCase {
    private final class RecordingNotificationScheduler: NotificationScheduler {
        var authorizationRequests = 0
        var scheduled: [String] = []
        var scheduledDates: [String: Date] = [:]
        var cancelled: [String] = []

        func requestAuthorization() {
            authorizationRequests += 1
        }

        func schedule(id: String, at date: Date, title: String, body: String) {
            scheduled.append(id)
            scheduledDates[id] = date
        }

        func cancel(ids: [String]) {
            cancelled.append(contentsOf: ids)
        }
    }

    private func makeContainer() throws -> ModelContainer {
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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeStage1Flags() -> FeatureFlags {
        FeatureFlags(
            mealsOwnershipRules: true,
            mealsGroceryList: true,
            notificationsGroceryCadence: true,
            mealsBudgetStatus: true
        )
    }

    private func finalizeCurrentWeek(plan: WeeklyPlan, manager: DataManager, reviewer: User) {
        manager.submitPlanForReview(plan, by: reviewer)
        for (index, slot) in plan.slots.sorted(by: { $0.date < $1.date }).enumerated() {
            let owner = slot.owner ?? reviewer
            _ = manager.setPendingSuggestion(mealName: "Meal \(index + 1)",
                                             responsibleUser: owner,
                                             author: reviewer,
                                             for: slot)
            manager.acceptPendingSuggestion(in: slot)
        }
        manager.finalizeIfPossible(plan)
    }

    func testBootstrapCreatesSevenDinnerSlotsWithOwnershipRulesAndSimpleFriday() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext, flags: makeStage1Flags())
        let family = manager.createFamily(name: "Test")
        let partnerA = manager.addUser(name: "Partner A", to: family)
        let partnerB = manager.addUser(name: "Partner B", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        let slots = plan.slots.sorted { $0.date < $1.date }

        XCTAssertEqual(slots.count, 7)
        XCTAssertTrue(slots.allSatisfy { $0.mealType == .dinner })

        let expectedOwners: [DayOfWeek: UUID] = [
            .sunday: partnerB.id,
            .monday: partnerA.id,
            .tuesday: partnerB.id,
            .wednesday: partnerA.id,
            .thursday: partnerB.id,
            .friday: partnerA.id,
            .saturday: partnerA.id,
        ]

        for slot in slots {
            XCTAssertEqual(slot.owner?.id, expectedOwners[slot.dayOfWeek], "Unexpected owner for \(slot.dayOfWeek)")
        }

        guard let fridaySlot = slots.first(where: { $0.dayOfWeek == .friday }) else {
            return XCTFail("Expected Friday dinner slot")
        }
        XCTAssertTrue(fridaySlot.isSimple)
    }

    func testBootstrapWithOwnershipRulesDisabledLeavesOwnersUnset() throws {
        let container = try makeContainer()
        let flags = FeatureFlags(
            mealsOwnershipRules: false,
            mealsGroceryList: false,
            notificationsGroceryCadence: false,
            mealsBudgetStatus: false
        )
        let manager = DataManager(context: container.mainContext, flags: flags)
        let family = manager.createFamily(name: "Test")
        _ = manager.addUser(name: "Partner A", to: family)
        _ = manager.addUser(name: "Partner B", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        XCTAssertEqual(plan.slots.count, 7)
        XCTAssertTrue(plan.slots.allSatisfy { $0.owner == nil && !$0.isSimple })
    }

    func testUpdatingOwnershipRuleReassignsUnsuggestedSlotsAndPreservesExplicitAssignments() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext, flags: makeStage1Flags())
        let family = manager.createFamily(name: "Test")
        let partnerA = manager.addUser(name: "Partner A", to: family)
        let partnerB = manager.addUser(name: "Partner B", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        guard let mondaySlot = plan.slots.first(where: { $0.dayOfWeek == .monday }) else {
            return XCTFail("Expected Monday dinner slot")
        }

        XCTAssertEqual(mondaySlot.owner?.id, partnerA.id)

        manager.updateOwnershipRule(for: .monday, owner: partnerB, in: plan)
        XCTAssertEqual(mondaySlot.owner?.id, partnerB.id)

        let suggestion = manager.setPendingSuggestion(mealName: "Tacos",
                                                      responsibleUser: partnerA,
                                                      author: partnerA,
                                                      for: mondaySlot)
        XCTAssertEqual(mondaySlot.owner?.id, partnerA.id)

        manager.updateOwnershipRule(for: .monday, owner: partnerB, in: plan)
        XCTAssertEqual(mondaySlot.owner?.id, partnerA.id)

        container.mainContext.delete(suggestion)
        mondaySlot.pendingSuggestion = nil
        manager.syncOwnersForAssignments(in: plan)
        XCTAssertEqual(mondaySlot.owner?.id, partnerB.id)
    }

    func testCounterReviewKeepsReviewMode() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)
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

        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.responsibleUserID, userB.id)
    }

    func testConflictOnSecondRejection() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)
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
                                           reasonForChange: nil,
                                           in: plan)

        XCTAssertEqual(plan.status, .conflict)
        XCTAssertEqual(plan.lastModifiedByUserID, userB.id)
        XCTAssertEqual(slot.pendingSuggestion?.authorUserID, userA.id)
    }

    func testFinalizeRequiresAllSevenDinnerSlotsAccepted() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext, flags: makeStage1Flags())
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)

        let plan = manager.createCurrentWeekPlan(for: family)
        let slots = plan.slots.sorted { $0.date < $1.date }

        manager.submitPlanForReview(plan, by: userA)

        for slot in slots.prefix(6) {
            _ = manager.setPendingSuggestion(mealName: "Meal", responsibleUser: slot.owner ?? userA, author: userA, for: slot)
            manager.acceptPendingSuggestion(in: slot)
        }
        manager.finalizeIfPossible(plan)

        XCTAssertEqual(plan.status, .reviewMode)
        XCTAssertNil(plan.groceryList)

        if let lastSlot = slots.last {
            _ = manager.setPendingSuggestion(mealName: "Last Meal", responsibleUser: lastSlot.owner ?? userA, author: userA, for: lastSlot)
            manager.acceptPendingSuggestion(in: lastSlot)
        }
        manager.finalizeIfPossible(plan)

        XCTAssertEqual(plan.status, .finalized)
        XCTAssertEqual(plan.groceryList?.items.count, 7)
    }

    func testFinalizeGeneratesSingleGroceryListGroupedByDay() throws {
        let container = try makeContainer()
        let scheduler = RecordingNotificationScheduler()
        let manager = DataManager(context: container.mainContext,
                                  flags: makeStage1Flags(),
                                  groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        let family = manager.createFamily(name: "Test")
        let reviewer = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        finalizeCurrentWeek(plan: plan, manager: manager, reviewer: reviewer)

        XCTAssertEqual(plan.status, .finalized)
        XCTAssertNotNil(plan.groceryList)
        XCTAssertEqual(plan.groceryList?.items.count, 7)
        let dayRefs = Set(plan.groceryList?.items.compactMap(\.dayRef) ?? [])
        XCTAssertEqual(dayRefs.count, 7)
        XCTAssertEqual(scheduler.authorizationRequests, 1)
    }

    func testReopenToSuggestionClearsGroceryListAndCancelsCadence() throws {
        let container = try makeContainer()
        let scheduler = RecordingNotificationScheduler()
        let manager = DataManager(context: container.mainContext,
                                  flags: makeStage1Flags(),
                                  groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        let family = manager.createFamily(name: "Test")
        let reviewer = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        finalizeCurrentWeek(plan: plan, manager: manager, reviewer: reviewer)
        manager.reopenPlanToSuggestion(plan)

        XCTAssertEqual(plan.status, .suggestionMode)
        XCTAssertNil(plan.groceryList)
        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-sun"))
        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-thu"))
    }

    func testReconcileGroceryCadenceCancelsWhenListBecomesEmpty() throws {
        let container = try makeContainer()
        let scheduler = RecordingNotificationScheduler()
        let manager = DataManager(context: container.mainContext,
                                  flags: makeStage1Flags(),
                                  groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        let family = manager.createFamily(name: "Test")
        let reviewer = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)

        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        finalizeCurrentWeek(plan: plan, manager: manager, reviewer: reviewer)
        let items = plan.groceryList?.items ?? []
        for item in items {
            container.mainContext.delete(item)
        }
        plan.groceryList?.items.removeAll()

        manager.reconcileGroceryCadence(for: plan)

        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-sun"))
        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-thu"))
    }

    func testReconcileGroceryCadenceCancelsForNonCurrentWeekPlan() throws {
        let container = try makeContainer()
        let scheduler = RecordingNotificationScheduler()
        let manager = DataManager(context: container.mainContext,
                                  flags: makeStage1Flags(),
                                  groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        let family = manager.createFamily(name: "Test")
        let reviewer = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)

        let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfWeek(for: .now))!
        let plan = manager.createWeeklyPlan(startDate: lastWeekStart, for: family)
        for dayOffset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: lastWeekStart)!
            _ = manager.addMealSlot(date: date, type: .dinner, to: plan)
        }
        finalizeCurrentWeek(plan: plan, manager: manager, reviewer: reviewer)

        XCTAssertNotNil(plan.groceryList)
        manager.reconcileGroceryCadence(for: plan)

        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-sun"))
        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-thu"))
    }

    func testReconcileGroceryCadenceCancelsWhenCadenceFlagTurnsOff() throws {
        let container = try makeContainer()
        let scheduler = RecordingNotificationScheduler()
        let enabledManager = DataManager(context: container.mainContext,
                                         flags: makeStage1Flags(),
                                         groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        let family = enabledManager.createFamily(name: "Test")
        let reviewer = enabledManager.addUser(name: "Alice", to: family)
        _ = enabledManager.addUser(name: "Bob", to: family)

        let plan = enabledManager.getOrCreateCurrentWeekPlan(for: family)
        finalizeCurrentWeek(plan: plan, manager: enabledManager, reviewer: reviewer)

        let disabledFlags = FeatureFlags(
            mealsOwnershipRules: true,
            mealsGroceryList: true,
            notificationsGroceryCadence: false,
            mealsBudgetStatus: true
        )
        let disabledManager = DataManager(context: container.mainContext,
                                          flags: disabledFlags,
                                          groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: scheduler))
        disabledManager.reconcileGroceryCadence(for: plan)

        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-sun"))
        XCTAssertTrue(scheduler.cancelled.contains("grocery-\(plan.id.uuidString)-thu"))
    }

    func testGroceryCadenceSchedulerSchedulesBothDaysBeforeSundayRun() {
        let scheduler = RecordingNotificationScheduler()
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let beforeSundayRun = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: weekStart)!
        let cadence = GroceryCadenceScheduler(scheduler: scheduler, now: { beforeSundayRun })

        cadence.scheduleNudges(weekStart: weekStart, weekId: "week-1")

        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertEqual(Set(scheduler.scheduled), ["grocery-week-1-sun", "grocery-week-1-thu"])
    }

    func testGroceryCadenceSchedulerSchedulesOnlyThursdayAfterSundayRun() {
        let scheduler = RecordingNotificationScheduler()
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let sundayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: weekStart)!
        let cadence = GroceryCadenceScheduler(scheduler: scheduler, now: { sundayEvening })

        cadence.scheduleNudges(weekStart: weekStart, weekId: "week-2")

        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertEqual(scheduler.scheduled, ["grocery-week-2-thu"])
        XCTAssertNil(scheduler.scheduledDates["grocery-week-2-sun"])
    }

    func testGroceryCadenceSchedulerSchedulesNothingAfterThursdayRun() {
        let scheduler = RecordingNotificationScheduler()
        let calendar = Calendar.current
        let weekStart = calendar.startOfWeek(for: Date())
        let thursday = calendar.date(byAdding: .day, value: 4, to: weekStart)!
        let afterThursdayRun = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: thursday)!
        let cadence = GroceryCadenceScheduler(scheduler: scheduler, now: { afterThursdayRun })

        cadence.scheduleNudges(weekStart: weekStart, weekId: "week-3")

        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertTrue(scheduler.cancelled.contains("grocery-week-3-sun"))
        XCTAssertTrue(scheduler.cancelled.contains("grocery-week-3-thu"))
    }

    func testBudgetStatusTransitions() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext, flags: makeStage1Flags())
        let family = manager.createFamily(name: "Test")
        let reviewer = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)
        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        finalizeCurrentWeek(plan: plan, manager: manager, reviewer: reviewer)

        manager.updateBudgetTarget(for: plan, dollars: 100)
        XCTAssertEqual(plan.budgetStatus, .unset)

        manager.updateObservedBudget(for: plan, dollars: 80)
        XCTAssertEqual(plan.budgetStatus, .under)

        manager.updateObservedBudget(for: plan, dollars: 103)
        XCTAssertEqual(plan.budgetStatus, .on)

        manager.updateObservedBudget(for: plan, dollars: 120)
        XCTAssertEqual(plan.budgetStatus, .over)

        manager.updateBudgetTarget(for: plan, dollars: 0)
        XCTAssertEqual(plan.budgetStatus, .unset)
    }

    func testReplacingSuggestionsDoesNotLeaveOrphans() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .dinner, to: plan)

        _ = manager.setPendingSuggestion(title: "Pasta", user: userA, for: slot)
        _ = manager.setPendingSuggestion(title: "Soup", user: userA, for: slot)
        XCTAssertEqual(slot.pendingSuggestion?.title, "Soup")

        manager.acceptPendingSuggestion(in: slot)
        _ = manager.setPendingSuggestion(title: "Salad", user: userA, for: slot)

        let suggestions = try container.mainContext.fetch(FetchDescriptor<MealSuggestion>())
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(slot.pendingSuggestion?.title, "Salad")
        XCTAssertNil(slot.finalizedSuggestion)
    }

    func testDeletingMealSlotCleansSuggestions() throws {
        let container = try makeContainer()
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Test")
        let userA = manager.addUser(name: "Alice", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .dinner, to: plan)

        _ = manager.setPendingSuggestion(title: "Tacos", user: userA, for: slot)
        manager.acceptPendingSuggestion(in: slot)
        manager.deleteMealSlot(slot)

        let suggestions = try container.mainContext.fetch(FetchDescriptor<MealSuggestion>())
        XCTAssertEqual(suggestions.count, 0)
    }
}
