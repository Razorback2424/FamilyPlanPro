import Foundation
import SwiftData

/// Convenience layer for basic CRUD interactions with SwiftData models.
final class DataManager {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Family
    func createFamily(name: String) -> Family {
        let family = Family(name: name)
        context.insert(family)
        return family
    }

    // MARK: - User
    func addUser(name: String, to family: Family) -> User {
        let user = User(name: name, family: family)
        family.users.append(user)
        context.insert(user)
        return user
    }

    // MARK: - Plan
    func createWeeklyPlan(startDate: Date, for family: Family) -> WeeklyPlan {
        let plan = WeeklyPlan(startDate: startDate, status: .suggestionMode, family: family)
        family.plans.append(plan)
        context.insert(plan)
        return plan
    }

    func addMealSlot(date: Date, type: MealSlot.MealType, to plan: WeeklyPlan) -> MealSlot {
        let slot = MealSlot(date: date, mealType: type, plan: plan)
        plan.slots.append(slot)
        context.insert(slot)
        return slot
    }

    func setPendingSuggestion(title: String, user: User? = nil, for slot: MealSlot) -> MealSuggestion {
        let suggestion = MealSuggestion(title: title, user: user, slot: slot)
        slot.pendingSuggestion = suggestion
        context.insert(suggestion)
        return suggestion
    }

    func acceptPendingSuggestion(in slot: MealSlot) {
        if let pending = slot.pendingSuggestion {
            slot.finalizedSuggestion = pending
            slot.pendingSuggestion = nil
        }
    }

    func rejectPendingSuggestion(in slot: MealSlot, newTitle: String, by user: User?) -> MealSuggestion {
        let suggestion = MealSuggestion(title: newTitle, user: user, slot: slot)
        slot.pendingSuggestion = suggestion
        context.insert(suggestion)
        return suggestion
    }

    func submitPlanForReview(_ plan: WeeklyPlan, by user: User) {
        plan.status = .reviewMode
        plan.lastModifiedByUserID = user.name
    }

    func finalizeIfPossible(_ plan: WeeklyPlan) {
        let pendingSlots = plan.slots.filter { $0.pendingSuggestion != nil }
        if pendingSlots.isEmpty {
            plan.status = .finalized
        }
    }

    // Persist changes
    func save() throws {
        try context.save()
    }
}

/// Debug helper used by tests to load dummy data.
func createDummyData(context: ModelContext) {
    let manager = DataManager(context: context)
    let family = manager.createFamily(name: "Testers")
    _ = manager.addUser(name: "Alice", to: family)
    _ = manager.addUser(name: "Bob", to: family)

    let plan = manager.createWeeklyPlan(startDate: .now, for: family)
    let mondayBreakfast = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
    _ = manager.setPendingSuggestion(title: "Pancakes", user: family.users.first, for: mondayBreakfast)

    try? manager.save()
}
