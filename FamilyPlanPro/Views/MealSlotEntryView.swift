import SwiftUI
import SwiftData
import Observation

struct MealSlotEntryView: View {
    @Environment(\.modelContext) private var context
    @Bindable var slot: MealSlot
    var users: [User]

    @State private var title: String = ""
    @State private var selectedUser: User?

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(slot.date, format: Date.FormatStyle(date: .numeric, time: .omitted)) \(slot.mealType.rawValue.capitalized)")
                .font(.headline)
            TextField("Meal name", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Responsible", selection: $selectedUser) {
                Text("Unassigned").tag(Optional<User>(nil))
                ForEach(users) { user in
                    Text(user.name).tag(Optional(user))
                }
            }
            .pickerStyle(.menu)
            Button("Add Suggestion") {
                guard !title.isEmpty else { return }
                let manager = DataManager(context: context)
                _ = manager.addSuggestion(title: title, user: selectedUser, to: slot)
                try? context.save()
                title = ""
                selectedUser = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical)
    }
}

#Preview {
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
    _ = manager.addUser(name: "Alice", to: family)
    let plan = manager.createWeeklyPlan(startDate: .now, for: family)
    let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
    try? container.mainContext.save()

    MealSlotEntryView(slot: slot, users: family.users)
        .modelContainer(container)
}
