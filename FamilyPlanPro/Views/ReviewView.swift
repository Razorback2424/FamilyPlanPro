import SwiftUI
import SwiftData
import Observation

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Bindable var plan: WeeklyPlan

    private var cadenceScheduler: GroceryCadenceScheduler {
        GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Take one last look before you finalize the week.")
                        .font(.subheadline)
                    Text("Review each meal, make any needed adjustments, and finalize once everything feels settled.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            let pendingSlots = plan.slots
                .sorted { $0.date < $1.date }
                .filter { $0.pendingSuggestion != nil }

            if pendingSlots.isEmpty {
                Section {
                    Text("There are no meals waiting for review right now.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(pendingSlots) { slot in
                    MealSlotReviewView(slot: slot, plan: plan, members: plan.family?.members ?? [])
                }
            }
        }
        .navigationTitle("Review")
        .toolbar {
            Button("Back to Suggestions") {
                let manager = DataManager(context: context,
                                         flags: featureFlags,
                                         groceryCadenceScheduler: cadenceScheduler)
                manager.reopenPlanToSuggestion(plan)
                try? context.save()
            }
        }
    }
}

struct ReviewView_Previews: PreviewProvider {
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
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Preview")
        let userA = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)
        let slot = plan.slots.first!
        _ = manager.setPendingSuggestion(mealName: "Eggs",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try? container.mainContext.save()

        return ReviewView(plan: plan)
            .modelContainer(container)
    }
}
