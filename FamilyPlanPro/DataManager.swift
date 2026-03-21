import Foundation
import SwiftData

/// Convenience layer for basic CRUD interactions with SwiftData models.
final class DataManager {
    private let context: ModelContext
    private let flags: FeatureFlags
    private let groceryCadenceScheduler: GroceryCadenceScheduler?

    init(context: ModelContext,
         flags: FeatureFlags = FeatureFlags(),
         groceryCadenceScheduler: GroceryCadenceScheduler? = nil) {
        self.context = context
        self.flags = flags
        self.groceryCadenceScheduler = groceryCadenceScheduler
    }

    // MARK: - Bootstrap
    func getOrCreateDefaultFamily() -> Family {
        if let existing = fetchFamilies().first {
            return existing
        }
        let family = createFamily(name: "My Family")
        return family
    }

    func getOrCreateCurrentWeekPlan(for family: Family) -> WeeklyPlan {
        if let existing = currentWeekPlan(for: family) {
            ensureSeededSlots(for: existing)
            ensureOwnershipRules(for: existing, family: family)
            syncOwnersForAssignments(in: existing)
            return existing
        }
        let plan = createCurrentWeekPlan(for: family)
        return plan
    }

    private func fetchFamilies() -> [Family] {
        let descriptor = FetchDescriptor<Family>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func currentWeekPlan(for family: Family) -> WeeklyPlan? {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: Date())
        let descriptor = FetchDescriptor<WeeklyPlan>(sortBy: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)])
        let plans = (try? context.fetch(descriptor)) ?? []
        return plans.first {
            $0.family === family && calendar.isDate($0.startDate, equalTo: startOfWeek, toGranularity: .day)
        }
    }

    private func ensureSeededSlots(for plan: WeeklyPlan) {
        let calendar = Calendar.current
        let start = calendar.startOfWeek(for: plan.startDate)
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            let hasDinnerSlot = plan.slots.contains { slot in
                slot.mealType == .dinner && calendar.isDate(slot.date, inSameDayAs: date)
            }
            if !hasDinnerSlot {
                _ = addMealSlot(date: date, type: .dinner, to: plan)
            }
        }
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
        ensureOwnershipRules(for: plan, family: family)
        return plan
    }

    func addMealSlot(date: Date, type: MealType, to plan: WeeklyPlan) -> MealSlot {
        let slot = MealSlot(date: date, mealType: type, plan: plan)
        if flags.mealsOwnershipRules {
            applyOwnership(to: slot, plan: plan)
        }
        plan.slots.append(slot)
        context.insert(slot)
        return slot
    }

    func addMealSlot(dayOfWeek: DayOfWeek, mealType: MealType, to plan: WeeklyPlan) -> MealSlot {
        let start = Calendar.current.startOfWeek(for: plan.startDate)
        let offset = dayOfWeek.rawValue - DayOfWeek.sunday.rawValue
        let date = Calendar.current.date(byAdding: .day, value: offset, to: start) ?? start
        return addMealSlot(date: date, type: mealType, to: plan)
    }

    /// Creates a new weekly plan for the current week (Sunday-Saturday)
    /// and pre-populates dinner slots for each day.
    func createCurrentWeekPlan(for family: Family) -> WeeklyPlan {
        let start = Calendar.current.startOfWeek(for: .now)
        let plan = createWeeklyPlan(startDate: start, for: family)
        let calendar = Calendar.current
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: start)!
            _ = addMealSlot(date: date, type: .dinner, to: plan)
        }
        return plan
    }

    func setPendingSuggestion(mealName: String,
                              responsibleUser: User? = nil,
                              author: User? = nil,
                              reasonForChange: String? = nil,
                              for slot: MealSlot) -> MealSuggestion {
        deleteSuggestion(slot.pendingSuggestion)
        deleteSuggestion(slot.finalizedSuggestion)
        let suggestion = MealSuggestion(mealName: mealName,
                                        responsibleUserID: responsibleUser?.id,
                                        authorUserID: author?.id,
                                        reasonForChange: reasonForChange,
                                        slot: slot)
        slot.pendingSuggestion = suggestion
        slot.owner = responsibleUser
        context.insert(suggestion)
        return suggestion
    }

    func setPendingSuggestion(title: String, user: User? = nil, for slot: MealSlot) -> MealSuggestion {
        setPendingSuggestion(mealName: title, responsibleUser: user, author: user, for: slot)
    }

    func acceptPendingSuggestion(in slot: MealSlot) {
        if let pending = slot.pendingSuggestion {
            deleteSuggestion(slot.finalizedSuggestion)
            slot.finalizedSuggestion = pending
            slot.pendingSuggestion = nil
            if let family = slot.plan?.family {
                slot.owner = family.members.first(where: { $0.id == pending.responsibleUserID })
            } else {
                slot.owner = nil
            }
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

        deleteSuggestion(slot.pendingSuggestion)
        deleteSuggestion(slot.finalizedSuggestion)

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

        let suggestion = MealSuggestion(mealName: newMealName,
                                        responsibleUserID: responsibleUser?.id,
                                        authorUserID: author?.id,
                                        reasonForChange: reasonForChange,
                                        slot: slot)
        slot.pendingSuggestion = suggestion
        slot.owner = responsibleUser
        if shouldEnterConflict {
            plan.status = .conflict
        } else {
            if plan.status != .conflict {
                plan.status = .reviewMode
            }
            plan.lastModifiedByUserID = author?.id
        }
        context.insert(suggestion)
        return suggestion
    }

    func resolveConflict(for slot: MealSlot,
                         finalMealName: String,
                         decidedBy user: User?,
                         responsibleUser: User?,
                         reasonForChange: String? = nil,
                         in plan: WeeklyPlan) -> MealSuggestion {
        let trimmedName = finalMealName.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!trimmedName.isEmpty, "Final meal name must not be empty")

        let suggestion = MealSuggestion(mealName: trimmedName,
                                        responsibleUserID: responsibleUser?.id,
                                        authorUserID: user?.id,
                                        reasonForChange: reasonForChange,
                                        slot: slot)
        slot.pendingSuggestion = suggestion
        slot.owner = responsibleUser
        plan.lastModifiedByUserID = user?.id
        plan.status = .reviewMode
        context.insert(suggestion)
        return suggestion
    }

    func submitPlanForReview(_ plan: WeeklyPlan, by user: User) {
        guard isCurrentWeek(plan), !plan.slots.isEmpty else { return }
        plan.status = .reviewMode
        plan.reviewInitiatorUserID = user.id
        plan.lastModifiedByUserID = user.id
    }

    func reopenPlanToSuggestion(_ plan: WeeklyPlan) {
        plan.status = .suggestionMode
        if flags.mealsGroceryList, let list = plan.groceryList {
            cancelGroceryCadence(for: plan)
            context.delete(list)
            plan.groceryList = nil
        }
        if flags.mealsOwnershipRules, let family = plan.family {
            ensureOwnershipRules(for: plan, family: family)
            syncOwnersForAssignments(in: plan)
        }
    }

    func finalizeIfPossible(_ plan: WeeklyPlan) {
        let dinnerSlots = plan.slots.filter { $0.mealType == .dinner }
        guard dinnerSlots.count == 7 else { return }
        let pendingSlots = dinnerSlots.filter { $0.pendingSuggestion != nil }
        let unfinalizedSlots = dinnerSlots.filter { $0.finalizedSuggestion == nil }
        if pendingSlots.isEmpty && unfinalizedSlots.isEmpty {
            plan.status = .finalized
            if flags.mealsGroceryList {
                let list = createOrReplaceGroceryList(for: plan, slots: dinnerSlots)
                if let list {
                    scheduleGroceryCadenceIfEligible(for: plan, list: list)
                }
            }
            if flags.mealsBudgetStatus {
                updateBudgetStatus(for: plan)
            }
        }
    }

    func deleteMealSlot(_ slot: MealSlot) {
        deleteSuggestion(slot.pendingSuggestion)
        deleteSuggestion(slot.finalizedSuggestion)
        context.delete(slot)
    }

    private func deleteSuggestion(_ suggestion: MealSuggestion?) {
        guard let suggestion else { return }
        context.delete(suggestion)
    }

    private func isCurrentWeek(_ plan: WeeklyPlan) -> Bool {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfWeek(for: Date())
        return calendar.isDate(plan.startDate, equalTo: startOfWeek, toGranularity: .day)
    }

    private func ensureOwnershipRules(for plan: WeeklyPlan, family: Family) {
        guard flags.mealsOwnershipRules else { return }
        ensureDefaultUsers(for: family)
        if plan.ownershipRulesSnap == nil {
            plan.ownershipRulesSnap = createOwnershipRulesSnap(for: family, plan: plan)
        }
        for slot in plan.slots where slot.mealType == .dinner {
            applyOwnership(to: slot, plan: plan)
            syncOwnerWithAssignments(for: slot)
        }
    }

    private func createOwnershipRulesSnap(for family: Family, plan: WeeklyPlan) -> OwnershipRulesSnap {
        let rules = defaultOwnershipRules(for: family)
        let snap = OwnershipRulesSnap(rules: rules, fridaySimple: true, family: family, plan: plan)
        context.insert(snap)
        return snap
    }

    private func defaultOwnershipRules(for family: Family) -> [String: String] {
        let users = family.members
        guard !users.isEmpty else { return [:] }
        if users.count == 1, let only = users.first {
            return [1, 2, 3, 4, 5, 6, 7].reduce(into: [:]) { $0[String($1)] = only.id.uuidString }
        }
        let primary = users[0].id
        let secondary = users.count > 1 ? users[1].id : users[0].id
        return [
            "1": secondary.uuidString, // Sunday
            "2": primary.uuidString,   // Monday
            "3": secondary.uuidString, // Tuesday
            "4": primary.uuidString,   // Wednesday
            "5": secondary.uuidString, // Thursday
            "6": primary.uuidString,   // Friday
            "7": primary.uuidString    // Saturday
        ]
    }

    private func applyOwnership(to slot: MealSlot, plan: WeeklyPlan) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: slot.date)
        if plan.ownershipRulesSnap?.fridaySimple == true {
            slot.isSimple = (weekday == 6)
        }
        guard let ownerID = plan.ownershipRulesSnap?.rules[String(weekday)],
              let ownerUUID = UUID(uuidString: ownerID),
              let family = plan.family else {
            return
        }
        slot.owner = family.members.first(where: { $0.id == ownerUUID })
    }

    private func syncOwnerWithAssignments(for slot: MealSlot) {
        let responsibleID = slot.finalizedSuggestion?.responsibleUserID ?? slot.pendingSuggestion?.responsibleUserID
        guard let family = slot.plan?.family else {
            return
        }
        if let responsibleID {
            slot.owner = family.members.first(where: { $0.id == responsibleID })
            return
        }
        if let ownerID = slot.plan?.ownershipRulesSnap?.rules[String(slot.dayOfWeek.rawValue)],
           let ownerUUID = UUID(uuidString: ownerID) {
            slot.owner = family.members.first(where: { $0.id == ownerUUID })
        }
    }

    func reapplyOwnershipIfNeeded(for plan: WeeklyPlan) {
        guard flags.mealsOwnershipRules, let family = plan.family else { return }
        ensureOwnershipRules(for: plan, family: family)
    }

    func updateOwnershipRule(for day: DayOfWeek, owner: User?, in plan: WeeklyPlan) {
        guard flags.mealsOwnershipRules, let family = plan.family else { return }
        ensureOwnershipRules(for: plan, family: family)

        var rules = plan.ownershipRulesSnap?.rules ?? [:]
        if let owner {
            rules[String(day.rawValue)] = owner.id.uuidString
        } else {
            rules.removeValue(forKey: String(day.rawValue))
        }
        plan.ownershipRulesSnap?.rules = rules

        for slot in plan.slots where slot.mealType == .dinner && slot.dayOfWeek == day {
            if slot.pendingSuggestion == nil && slot.finalizedSuggestion == nil {
                slot.owner = owner
            } else {
                syncOwnerWithAssignments(for: slot)
            }
        }
    }

    func syncOwnersForAssignments(in plan: WeeklyPlan) {
        for slot in plan.slots {
            syncOwnerWithAssignments(for: slot)
        }
    }

    func reconcileGroceryCadence(for plan: WeeklyPlan) {
        guard let list = plan.groceryList else {
            cancelGroceryCadence(for: plan)
            return
        }
        if flags.notificationsGroceryCadence && flags.mealsGroceryList {
            scheduleGroceryCadenceIfEligible(for: plan, list: list)
        } else {
            cancelGroceryCadence(for: plan)
        }
    }

    private func ensureDefaultUsers(for family: Family) {
        guard family.members.isEmpty else { return }
        _ = addUser(name: "Partner A", to: family)
        _ = addUser(name: "Partner B", to: family)
    }

    func ensureDefaultUsersIfNeeded(for family: Family) {
        if family.members.count >= 2 { return }
        if family.members.isEmpty {
            _ = addUser(name: "Partner A", to: family)
            _ = addUser(name: "Partner B", to: family)
        } else if family.members.count == 1 {
            _ = addUser(name: "Partner B", to: family)
        }
    }

    private func createOrReplaceGroceryList(for plan: WeeklyPlan, slots: [MealSlot]) -> GroceryList? {
        if let existing = plan.groceryList {
            cancelGroceryCadence(for: plan)
            context.delete(existing)
            plan.groceryList = nil
        }
        let list = GroceryList(status: .draft, plan: plan)
        plan.groceryList = list
        context.insert(list)
        let sortedSlots = slots.sorted { $0.date < $1.date }
        for slot in sortedSlots {
            guard let finalized = slot.finalizedSuggestion else { continue }
            let trimmedName = finalized.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let dayRef = Calendar.current.startOfDay(for: slot.date)
            let item = GroceryItem(name: trimmedName, dayRef: dayRef, list: list)
            list.items.append(item)
            context.insert(item)
        }
        if list.items.isEmpty {
            context.delete(list)
            plan.groceryList = nil
            return nil
        }
        return list
    }

    private func scheduleGroceryCadenceIfEligible(for plan: WeeklyPlan, list: GroceryList) {
        guard flags.notificationsGroceryCadence else { return }
        guard isCurrentWeek(plan) else { return }
        guard !list.items.isEmpty else { return }
        groceryCadenceScheduler?.scheduleNudges(weekStart: plan.startDate, weekId: plan.id.uuidString)
    }

    private func cancelGroceryCadence(for plan: WeeklyPlan) {
        guard flags.notificationsGroceryCadence else { return }
        groceryCadenceScheduler?.cancelNudges(weekId: plan.id.uuidString)
    }

    func updateBudgetTarget(for plan: WeeklyPlan, dollars: Int) {
        plan.budgetTargetCents = max(0, dollars * 100)
        if flags.mealsBudgetStatus {
            updateBudgetStatus(for: plan)
        }
    }

    func updateObservedBudget(for plan: WeeklyPlan, dollars: Int) {
        if let list = plan.groceryList {
            list.budgetObservedCents = max(0, dollars * 100)
            if flags.mealsBudgetStatus {
                updateBudgetStatus(for: plan)
            }
        }
    }

    private func updateBudgetStatus(for plan: WeeklyPlan) {
        guard plan.budgetTargetCents > 0 else {
            plan.budgetStatus = .unset
            return
        }
        let observed = plan.groceryList?.budgetObservedCents ?? 0
        if observed == 0 {
            plan.budgetStatus = .unset
            return
        }
        let tolerance = max(1, Int(Double(plan.budgetTargetCents) * 0.05))
        if observed < plan.budgetTargetCents - tolerance {
            plan.budgetStatus = .under
        } else if observed > plan.budgetTargetCents + tolerance {
            plan.budgetStatus = .over
        } else {
            plan.budgetStatus = .on
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
    let mondayBreakfast = manager.addMealSlot(date: .now, type: .dinner, to: plan)
    _ = manager.setPendingSuggestion(mealName: "Pancakes",
                                     responsibleUser: responsible,
                                     author: author,
                                     for: mondayBreakfast)

    try? manager.save()
}
