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
        family.members.append(user)
        context.insert(user)
        return user
    }

    // MARK: - Plan
    func createWeeklyPlan(startDate: Date, for family: Family) -> WeeklyPlan {
        let plan = WeeklyPlan(startDate: startDate, status: .suggestionMode, family: family)
        family.weeklyPlans.append(plan)
        context.insert(plan)
        return plan
    }

    func addMealSlot(dayOfWeek: DayOfWeek, mealType: MealType, to plan: WeeklyPlan) -> MealSlot {
        let slot = MealSlot(dayOfWeek: dayOfWeek, mealType: mealType, plan: plan)
        plan.mealSlots.append(slot)
        context.insert(slot)
        return slot
    }

    /// Creates a new weekly plan for the current week (Sunday-Saturday)
    /// and pre-populates meal slots for each day and meal type.
    func createCurrentWeekPlan(for family: Family) -> WeeklyPlan {
        let start = Calendar.current.startOfWeek(for: .now)
        let plan = createWeeklyPlan(startDate: start, for: family)

        for day in DayOfWeek.allCases {
            for meal in MealType.allCases {
                if !plan.mealSlots.contains(where: { $0.dayOfWeek == day && $0.mealType == meal }) {
                    _ = addMealSlot(dayOfWeek: day, mealType: meal, to: plan)
                }
            }
        }

        plan.mealSlots.sort { lhs, rhs in
            if lhs.dayOfWeek.rawValue != rhs.dayOfWeek.rawValue {
                return lhs.dayOfWeek.rawValue < rhs.dayOfWeek.rawValue
            }

            let mealOrder = MealType.allCases
            let lhsIndex = mealOrder.firstIndex(of: lhs.mealType) ?? 0
            let rhsIndex = mealOrder.firstIndex(of: rhs.mealType) ?? 0
            return lhsIndex < rhsIndex
        }

        return plan
    }

    func setPendingSuggestion(mealName: String,
                              responsibleUser: User? = nil,
                              author: User? = nil,
                              reasonForChange: String? = nil,
                              for slot: MealSlot) -> MealSuggestion {
        let suggestion = MealSuggestion(mealName: mealName,
                                        responsibleUserID: responsibleUser?.id,
                                        authorUserID: author?.id,
                                        reasonForChange: reasonForChange,
                                        slot: slot)
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

    func rejectPendingSuggestion(in slot: MealSlot,
                                 newMealName: String,
                                 author: User?,
                                 responsibleUser: User?,
                                 reasonForChange: String? = nil,
                                 in plan: WeeklyPlan) -> MealSuggestion {
        let previousModifierID = plan.lastModifiedByUserID
        let rejectingUserID = author?.id

        var shouldEnterConflict = false
        if let lastUserID = previousModifierID,
           let rejectingUserID,
           lastUserID != rejectingUserID {
            if let initiatorID = plan.reviewInitiatorUserID {
                shouldEnterConflict = lastUserID != initiatorID
            } else {
                shouldEnterConflict = true
            }
        }

        if shouldEnterConflict {
            plan.status = .conflict
        } else if plan.status != .conflict {
            plan.status = .reviewMode
        }

        let suggestion = MealSuggestion(mealName: newMealName,
                                        responsibleUserID: responsibleUser?.id,
                                        authorUserID: author?.id,
                                        reasonForChange: reasonForChange,
                                        slot: slot)
        slot.pendingSuggestion = suggestion
        plan.lastModifiedByUserID = author?.id
        context.insert(suggestion)
        return suggestion
    }

    func submitPlanForReview(_ plan: WeeklyPlan, by user: User) {
        plan.status = .reviewMode
        plan.reviewInitiatorUserID = user.id
        plan.lastModifiedByUserID = user.id
    }

    func finalizeIfPossible(_ plan: WeeklyPlan) {
        let allSlotsFinalized = plan.mealSlots.allSatisfy { slot in
            slot.pendingSuggestion == nil && slot.finalizedSuggestion != nil
        }
        if allSlotsFinalized {
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
    let author = manager.addUser(name: "Alice", to: family)
    let responsible = manager.addUser(name: "Bob", to: family)

    let plan = manager.createWeeklyPlan(startDate: .now, for: family)
    let mondayBreakfast = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
    _ = manager.setPendingSuggestion(mealName: "Pancakes",
                                     responsibleUser: responsible,
                                     author: author,
                                     for: mondayBreakfast)

    try? manager.save()
}
