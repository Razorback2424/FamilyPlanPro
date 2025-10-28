import SwiftUI
import SwiftData
import Observation

struct MealSlotEntryView: View {
    @Environment(\.modelContext) private var context
    @Bindable var slot: MealSlot
    var members: [User]

    @State private var title: String = ""
    @State private var selectedResponsible: User?

    private var author: User? {
        slot.plan?.family?.members.first
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(slot.dayOfWeek.localizedName) \(slot.mealType.displayName)")
                .font(.headline)
            TextField("Meal name", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Responsible", selection: $selectedResponsible) {
                Text("Unassigned").tag(Optional<User>(nil))
                ForEach(members) { user in
                    Text(user.name).tag(Optional(user))
                }
            }
            .pickerStyle(.menu)
            Button("Add Suggestion") {
                guard !title.isEmpty else { return }
                let manager = DataManager(context: context)
                _ = manager.setPendingSuggestion(mealName: title,
                                                 responsibleUser: selectedResponsible,
                                                 author: author,
                                                 for: slot)
                try? context.save()
                title = ""
                selectedResponsible = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical)
    }
}

struct MealSlotEntryView_Previews: PreviewProvider {
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
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        try? container.mainContext.save()

        return MealSlotEntryView(slot: slot, members: family.members)
            .modelContainer(container)
    }
}
