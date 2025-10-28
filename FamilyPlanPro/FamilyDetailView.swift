import SwiftUI
import SwiftData
import Observation

struct FamilyDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var family: Family

    var body: some View {
        List {
            ForEach(family.weeklyPlans) { plan in
                Text(plan.startDate, format: Date.FormatStyle(date: .numeric, time: .omitted))
            }
        }
        .navigationTitle(family.name)
    }
}

struct FamilyDetailView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyDetailView(family: Family(name: "Preview"))
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
    }
}
