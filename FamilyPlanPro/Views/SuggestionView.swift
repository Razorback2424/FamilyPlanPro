import SwiftUI
import SwiftData
import Observation

struct SuggestionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan

    var body: some View {
        List {
            ForEach(plan.mealSlots) { slot in
                MealSlotEntryView(slot: slot, members: plan.family?.members ?? [])
            }
        }
        .navigationTitle("Suggestions")
        .toolbar {
            Button("Submit for Review") {
                if let user = plan.family?.members.first { // naive current user
                    let manager = DataManager(context: context)
                    manager.submitPlanForReview(plan, by: user)
                    try? context.save()
                }
            }
        }
    }
}

struct SuggestionView_Previews: PreviewProvider {
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
        _ = manager.addUser(name: "Alice", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        _ = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        try? container.mainContext.save()

        return NavigationStack {
            SuggestionView(plan: plan)
        }
        .modelContainer(container)
    }
}
