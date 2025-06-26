import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan

    var body: some View {
        List {
            ForEach(plan.slots) { slot in
                if let pending = slot.pendingSuggestion {
                    VStack(alignment: .leading) {
                        Text("\(slot.date, format: Date.FormatStyle(date: .numeric, time: .omitted)) \(slot.mealType.rawValue.capitalized)")
                            .font(.headline)
                        Text(pending.title)
                        HStack {
                            Button("Accept") {
                                let manager = DataManager(context: context)
                                manager.acceptPendingSuggestion(in: slot)
                                manager.finalizeIfPossible(plan)
                                try? context.save()
                            }
                            .buttonStyle(.bordered)
                            Button("Reject") {
                                let manager = DataManager(context: context)
                                _ = manager.rejectPendingSuggestion(in: slot, newTitle: pending.title, by: plan.family?.users.last)
                                plan.lastModifiedByUserID = plan.family?.users.last?.name
                                try? context.save()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Review")
    }
}

struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            Family.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext)
        let family = manager.createFamily(name: "Preview")
        let userA = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Eggs", user: userA, for: slot)
        try? container.mainContext.save()

        return ReviewView(plan: plan)
            .modelContainer(container)
    }
}
