import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Query private var families: [Family]
    @Query(sort: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)]) private var plans: [WeeklyPlan]

    @State private var budgetTarget: String = ""
    @State private var observedSpend: String = ""

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
            Section("Household") {
                if let userA {
                    TextField("Partner A", text: Binding(
                        get: { userA.name },
                        set: { userA.name = $0 }
                    ))
                } else {
                    Text("Partner A")
                        .foregroundStyle(.secondary)
                }

                if let userB {
                    TextField("Partner B", text: Binding(
                        get: { userB.name },
                        set: { userB.name = $0 }
                    ))
                } else {
                    Text("Partner B")
                        .foregroundStyle(.secondary)
                }

                Button("Save Changes") {
                    try? context.save()
                }
            }

            if featureFlags.mealsBudgetStatus, let plan = currentPlan {
                Section("Budget") {
                    TextField("Weekly budget ($)", text: $budgetTarget)
                        .keyboardType(.numberPad)
                    TextField("Observed spend ($)", text: $observedSpend)
                        .keyboardType(.numberPad)
                        .disabled(!canEditObservedSpend)
                    if !canEditObservedSpend {
                        Text("Finalize meals to create a grocery list before entering observed spend.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Status: \(plan.budgetStatus.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(budgetStatusColor)
                    Button("Update Budget") {
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, OwnershipRulesSnap.self, MealSlot.self, MealSuggestion.self, GroceryList.self, GroceryItem.self], inMemory: true)
    }
}
