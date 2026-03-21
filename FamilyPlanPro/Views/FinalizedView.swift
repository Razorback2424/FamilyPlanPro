import SwiftUI
import SwiftData
import Observation

struct FinalizedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Bindable var plan: WeeklyPlan
    @State private var showReopenConfirmation = false
    @State private var budgetTarget = ""
    @State private var observedSpend = ""

    private var cadenceScheduler: GroceryCadenceScheduler {
        GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
    }

    private var sortedSlots: [MealSlot] {
        plan.slots.sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section {
                Text("Every meal for the week has been finalized. Here's the summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if featureFlags.mealsGroceryList, let list = plan.groceryList {
                Section {
                    NavigationLink("Grocery List") {
                        GroceryListView(list: list)
                    }
                }
            }

            if featureFlags.mealsGroceryList && featureFlags.notificationsGroceryCadence {
                Section {
                    Text(cadenceStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if featureFlags.mealsBudgetStatus {
                Section("Budget") {
                    Text("Status: \(plan.budgetStatus.rawValue.capitalized)")
                        .font(.subheadline)
                        .accessibilityIdentifier("budget-status-label")
                    TextField("Weekly budget ($)", text: $budgetTarget)
                        .keyboardType(.numberPad)
                    TextField("Observed spend ($)", text: $observedSpend)
                        .keyboardType(.numberPad)
                    Button("Update Budget") {
                        let manager = DataManager(context: context,
                                                  flags: featureFlags,
                                                  groceryCadenceScheduler: cadenceScheduler)
                        manager.updateBudgetTarget(for: plan, dollars: Int(budgetTarget) ?? 0)
                        manager.updateObservedBudget(for: plan, dollars: Int(observedSpend) ?? 0)
                        try? context.save()
                        syncBudgetFields()
                    }
                    .disabled(plan.groceryList == nil)
                    if plan.groceryList == nil {
                        Text("Finalize meals to create a grocery list before entering spend.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(sortedSlots) { slot in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(slot.date, format: .dateTime.weekday(.wide)) \(slot.mealType.displayName)")
                        .font(.headline)
                    Text(slot.date, format: .dateTime.month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(slot.finalizedSuggestion?.mealName ?? "No selection")
                        .accessibilityIdentifier("finalized-meal-\(slot.id.uuidString)")
                    Text("Responsible: \(slot.owner?.name ?? "Unassigned")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if slot.isSimple {
                        Text("Simple Friday")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Finalized")
        .toolbar {
            Button("Reopen to Suggestions") {
                showReopenConfirmation = true
            }
        }
        .alert("Reopen to Suggestions?", isPresented: $showReopenConfirmation) {
            Button("Reopen", role: .destructive) {
                let manager = DataManager(context: context,
                                         flags: featureFlags,
                                         groceryCadenceScheduler: cadenceScheduler)
                manager.reopenPlanToSuggestion(plan)
                try? context.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will return the week to Suggestions mode.")
        }
        .onAppear {
            syncBudgetFields()
        }
        .onChange(of: plan.budgetTargetCents) { _, _ in
            syncBudgetFields()
        }
        .onChange(of: plan.groceryList?.budgetObservedCents) { _, _ in
            syncBudgetFields()
        }
    }

    private var cadenceStatusText: String {
        guard let list = plan.groceryList else {
            return "Grocery reminders not scheduled (no list)."
        }
        let startOfWeek = Calendar.current.startOfWeek(for: Date())
        guard Calendar.current.isDate(plan.startDate, equalTo: startOfWeek, toGranularity: .day) else {
            return "Grocery reminders not scheduled (not current week)."
        }
        guard !list.items.isEmpty else {
            return "Grocery reminders not scheduled (empty list)."
        }
        return "Grocery reminders scheduled (Sun/Thu)."
    }

    private func syncBudgetFields() {
        budgetTarget = plan.budgetTargetCents > 0 ? String(plan.budgetTargetCents / 100) : ""
        if let observed = plan.groceryList?.budgetObservedCents, observed > 0 {
            observedSpend = String(observed / 100)
        } else {
            observedSpend = ""
        }
    }
}

struct FinalizedView_Previews: PreviewProvider {
    static var previews: some View {
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
        let container = try! ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext,
                                  flags: FeatureFlags(mealsGroceryList: true, notificationsGroceryCadence: true))
        let family = manager.createFamily(name: "Preview")
        let alice = manager.addUser(name: "Alice", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)
        for slot in plan.slots {
            _ = manager.setPendingSuggestion(mealName: "Meal", responsibleUser: alice, author: alice, for: slot)
            manager.acceptPendingSuggestion(in: slot)
        }
        manager.finalizeIfPossible(plan)
        try? container.mainContext.save()

        return NavigationStack {
            FinalizedView(plan: plan)
        }
        .modelContainer(container)
    }
}
