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
                let currentUser = plan.family?.members.first
                switch plan.status {
                case .suggestionMode:
                    SuggestionView(plan: plan, currentUser: currentUser)
                case .reviewMode:
                    ReviewView(plan: plan)
                case .conflict:
                    ConflictView(plan: plan)
                case .finalized:
                    FinalizedView()
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
        }
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
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
    }
}
