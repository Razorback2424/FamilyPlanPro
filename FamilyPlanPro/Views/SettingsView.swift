import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Query private var families: [Family]
    @Query(sort: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)]) private var plans: [WeeklyPlan]

    @State private var budgetTarget: String = ""
    @State private var observedSpend: String = ""
    @State private var showingFamilySettings = false

    private var family: Family? {
        families.first
    }

    private var userA: User? {
        family?.users.first
    }

    private var userB: User? {
        guard let family else { return nil }
        return family.users.count > 1 ? family.users[1] : nil
    }

    private var currentPlan: WeeklyPlan? {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let startOfThisWeek = calendar.startOfWeek(for: Date())
        return plans.first { calendar.isDate($0.startDate, equalTo: startOfThisWeek, toGranularity: .day) }
    }

    private var canEditObservedSpend: Bool {
        currentPlan?.groceryList != nil
    }

    private var sortedMembers: [User] {
        family?.members.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending } ?? []
    }

    private var budgetStatusColor: Color {
        switch currentPlan?.budgetStatus {
        case .under:
            return .green
        case .on:
            return .blue
        case .over:
            return .red
        case .unset, .none:
            return .secondary
        }
    }

    var body: some View {
        Form {
            Section("Household members") {
                if let userA {
                    TextField("Primary member", text: Binding(
                        get: { userA.name },
                        set: { userA.name = $0 }
                    ))
                } else {
                    Text("Primary member")
                        .foregroundStyle(.secondary)
                }

                if let userB {
                    TextField("Secondary member", text: Binding(
                        get: { userB.name },
                        set: { userB.name = $0 }
                    ))
                } else {
                    Text("Secondary member")
                        .foregroundStyle(.secondary)
                }

                Button("Save household names") {
                    try? context.save()
                }

                if family != nil {
                    Button("Edit household defaults") {
                        showingFamilySettings = true
                    }
                    Text("Household defaults apply to future weeks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if featureFlags.mealsOwnershipRules, let plan = currentPlan {
                Section("This Week Meal Defaults") {
                    if sortedMembers.isEmpty {
                        Text("Add household members before assigning default owners for this week.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                            Picker(day.localizedName, selection: currentWeekOwnershipBinding(for: day, in: plan)) {
                                Text("Unassigned").tag(ResponsibleSelection.unassigned)
                                ForEach(sortedMembers) { member in
                                    Text(member.name).tag(ResponsibleSelection.user(member.id))
                                }
                            }
                            .accessibilityIdentifier("settings-ownership-rule-\(day.rawValue)")
                        }
                    }
                    Text("These defaults apply only to meals without a saved assignment in the current week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Household defaults for future weeks live in Family Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings-household-defaults-hint")
                    Text("Open Planner to update individual meals.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings-weekly-ownership-hint")
                }
            }

            if featureFlags.mealsBudgetStatus, let plan = currentPlan {
                Section("Budget") {
                    TextField("Weekly budget", text: $budgetTarget)
                        .keyboardType(.numberPad)
                    TextField("Planned spend", text: $observedSpend)
                        .keyboardType(.numberPad)
                        .disabled(!canEditObservedSpend)
                    if !canEditObservedSpend {
                        Text("Finish the week's meals to create a grocery list before entering spend.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Budget status: \(plan.budgetStatus.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(budgetStatusColor)
                    Button("Save budget") {
                        let manager = DataManager(context: context, flags: featureFlags)
                        let targetValue = Int(budgetTarget) ?? 0
                        let observedValue = Int(observedSpend) ?? 0
                        manager.updateBudgetTarget(for: plan, dollars: targetValue)
                        manager.updateObservedBudget(for: plan, dollars: observedValue)
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            let manager = DataManager(context: context)
            let family = manager.getOrCreateDefaultFamily()
            manager.ensureDefaultUsersIfNeeded(for: family)
            syncBudgetFields()
            try? context.save()
        }
        .onChange(of: currentPlan?.id) { _, _ in
            syncBudgetFields()
        }
        .onChange(of: currentPlan?.groceryList?.id) { _, _ in
            syncBudgetFields()
        }
        .sheet(isPresented: $showingFamilySettings) {
            if let family {
                NavigationStack {
                    FamilySettingsView(family: family)
                }
            }
        }
    }

    private func syncBudgetFields() {
        guard let plan = currentPlan else {
            budgetTarget = ""
            observedSpend = ""
            return
        }
        budgetTarget = plan.budgetTargetCents > 0 ? String(plan.budgetTargetCents / 100) : ""
        if let list = plan.groceryList, list.budgetObservedCents > 0 {
            observedSpend = String(list.budgetObservedCents / 100)
        } else {
            observedSpend = ""
        }
    }

    private func currentWeekOwnershipBinding(for day: DayOfWeek, in plan: WeeklyPlan) -> Binding<ResponsibleSelection> {
        Binding(
            get: { currentWeekOwnershipSelection(for: day, in: plan) },
            set: { updateCurrentWeekOwnershipRule(for: day, selection: $0, in: plan) }
        )
    }

    private func currentWeekOwnershipSelection(for day: DayOfWeek, in plan: WeeklyPlan) -> ResponsibleSelection {
        guard let ruleID = plan.ownershipRulesSnap?.rules[String(day.rawValue)],
              let ownerUUID = UUID(uuidString: ruleID) else {
            return .unassigned
        }
        return .user(ownerUUID)
    }

    private func updateCurrentWeekOwnershipRule(for day: DayOfWeek, selection: ResponsibleSelection, in plan: WeeklyPlan) {
        let manager = DataManager(context: context, flags: featureFlags)
        let owner = sortedMembers.first { $0.id == selection.responsibleID }
        manager.updateOwnershipRule(for: day, owner: owner, in: plan)
        try? context.save()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, OwnershipRulesSnap.self, MealSlot.self, MealSuggestion.self, GroceryList.self, GroceryItem.self], inMemory: true)
    }
}
