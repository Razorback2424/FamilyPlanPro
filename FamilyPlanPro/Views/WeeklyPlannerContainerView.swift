import SwiftUI
import SwiftData

struct WeeklyPlannerContainerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)]) private var plans: [WeeklyPlan]
    @Query private var families: [Family]
    @State private var showingAddFamily = false

    private var currentPlan: WeeklyPlan? {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday to match startOfWeek(for:)
        let startOfThisWeek = calendar.startOfWeek(for: Date())
        return plans.first { calendar.isDate($0.startDate, equalTo: startOfThisWeek, toGranularity: .day) }
    }

    var body: some View {
        Group {
            if families.isEmpty {
                AddFamilyView()
            } else if let plan = currentPlan {
                switch plan.status {
                case .suggestionMode:
                    SuggestionView(plan: plan)
                case .reviewMode:
                    ReviewView(plan: plan)
                case .conflict:
                    ReviewView(plan: plan) // simplified
                case .finalized:
                    FinalizedView()
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Weekly Planner")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFamily = true }) {
                    Label("New Family", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: createWeekIfNeeded)
        .sheet(isPresented: $showingAddFamily) {
            NavigationStack { AddFamilyView() }
        }
    }

    private func createWeekIfNeeded() {
        guard currentPlan == nil, let family = families.first else { return }
        let manager = DataManager(context: context)
        _ = manager.createCurrentWeekPlan(for: family)
        try? context.save()
    }
}

struct WeeklyPlannerContainerView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyPlannerContainerView()
            .modelContainer(for: [Family.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
    }
}
