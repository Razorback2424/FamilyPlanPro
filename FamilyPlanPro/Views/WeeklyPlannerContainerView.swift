import SwiftUI
import SwiftData

struct WeeklyPlannerContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Environment(FeatureFlagsStore.self) private var featureFlagsStore
    @Query(sort: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)]) private var plans: [WeeklyPlan]
    @Query private var families: [Family]

    @State private var showingAddFamily = false
    @State private var showingFlags = false

    private var currentPlan: WeeklyPlan? {
        let startOfThisWeek = Calendar.current.startOfWeek(for: Date())
        return plans.first { Calendar.current.isDate($0.startDate, equalTo: startOfThisWeek, toGranularity: .day) }
    }

    var body: some View {
        Group {
            if families.isEmpty {
                AddFamilyView()
            } else if let plan = currentPlan {
                let currentUser = plan.family?.members.first
                switch plan.status {
                case .suggestionMode:
                    SuggestionView(plan: plan, currentUser: currentUser)
                case .reviewMode:
                    ReviewView(plan: plan)
                case .conflict:
                    ConflictView(plan: plan)
                case .finalized:
                    FinalizedView(plan: plan)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("It's time to start planning this week's meals.")
                        .multilineTextAlignment(.center)
                        .font(.title3)
                    Text("Tap below to generate a new weekly plan and start reviewing personalized suggestions right away.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button("Start New Week") {
                        createWeekIfNeeded()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .navigationTitle("Weekly Planner")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFamily = true }) {
                    Label("New Family", systemImage: "plus")
                }
            }
#if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Flags") { showingFlags = true }
            }
#endif
        }
        .onAppear {
            createWeekIfNeeded()
            reconcileCurrentPlan()
        }
        .onChange(of: families.count) { _, _ in
            createWeekIfNeeded()
        }
        .onChange(of: featureFlagsStore.flags) { _, _ in
            reconcileCurrentPlan()
        }
        .sheet(isPresented: $showingAddFamily) {
            NavigationStack { AddFamilyView() }
        }
#if DEBUG
        .sheet(isPresented: $showingFlags) {
            NavigationStack {
                Form {
                    Section("Meals") {
                        Toggle("Ownership Rules", isOn: Binding(
                            get: { featureFlagsStore.flags.mealsOwnershipRules },
                            set: { featureFlagsStore.flags.mealsOwnershipRules = $0 }
                        ))
                        Toggle("Grocery List", isOn: Binding(
                            get: { featureFlagsStore.flags.mealsGroceryList },
                            set: { featureFlagsStore.flags.mealsGroceryList = $0 }
                        ))
                        Toggle("Budget Status", isOn: Binding(
                            get: { featureFlagsStore.flags.mealsBudgetStatus },
                            set: { featureFlagsStore.flags.mealsBudgetStatus = $0 }
                        ))
                    }
                    Section("Notifications") {
                        Toggle("Grocery Cadence", isOn: Binding(
                            get: { featureFlagsStore.flags.notificationsGroceryCadence },
                            set: { featureFlagsStore.flags.notificationsGroceryCadence = $0 }
                        ))
                    }
                }
                .navigationTitle("Feature Flags")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showingFlags = false }
                    }
                }
            }
        }
#endif
    }

    private func createWeekIfNeeded() {
        let cadence = GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
        let manager = DataManager(context: context, flags: featureFlagsStore.flags, groceryCadenceScheduler: cadence)
        let family = manager.getOrCreateDefaultFamily()
        _ = manager.getOrCreateCurrentWeekPlan(for: family)
        manager.ensureDefaultUsersIfNeeded(for: family)
        try? context.save()
    }

    private func reconcileCurrentPlan() {
        guard let plan = currentPlan else { return }
        let cadence = GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
        let manager = DataManager(context: context,
                                  flags: featureFlagsStore.flags,
                                  groceryCadenceScheduler: cadence)
        manager.syncOwnersForAssignments(in: plan)
        manager.reapplyOwnershipIfNeeded(for: plan)
        manager.reconcileGroceryCadence(for: plan)
        try? context.save()
    }
}

struct WeeklyPlannerContainerView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyPlannerContainerView()
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, OwnershipRulesSnap.self, MealSlot.self, MealSuggestion.self, GroceryList.self, GroceryItem.self], inMemory: true)
    }
}
