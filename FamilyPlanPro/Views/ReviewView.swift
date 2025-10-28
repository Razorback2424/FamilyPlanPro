import SwiftUI
import SwiftData
import Observation

struct ReviewView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan

    var body: some View {
        List {
            ForEach(plan.mealSlots) { slot in
                if slot.pendingSuggestion != nil {
                    MealSlotReviewView(slot: slot, plan: plan, members: plan.family?.members ?? [])
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
            User.self,
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
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Eggs",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try? container.mainContext.save()

        return ReviewView(plan: plan)
            .modelContainer(container)
    }
}
