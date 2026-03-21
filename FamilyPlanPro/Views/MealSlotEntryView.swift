import SwiftUI
import SwiftData
import Observation

struct MealSlotEntryView: View {
    @Bindable var slot: MealSlot
    var members: [User]
    @Binding var mealName: String
    @Binding var responsibleSelection: ResponsibleSelection
    var onClearSuggestion: (() -> Void)?

    init(slot: MealSlot,
         members: [User],
         mealName: Binding<String>,
         responsibleSelection: Binding<ResponsibleSelection>,
         onClearSuggestion: (() -> Void)? = nil) {
        self._slot = Bindable(wrappedValue: slot)
        self.members = members
        self._mealName = mealName
        self._responsibleSelection = responsibleSelection
        self.onClearSuggestion = onClearSuggestion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(slot.date, format: .dateTime.weekday(.wide)) \(slot.mealType.displayName)")
                    .font(.headline)
                Text(slot.date, format: .dateTime.month().day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let owner = slot.owner {
                    Text("Default owner: \(owner.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if slot.isSimple {
                    Text("Simple Friday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Meal name", text: $mealName)
                .textFieldStyle(.roundedBorder)

            Picker("Responsible", selection: $responsibleSelection) {
                Text("Unassigned").tag(ResponsibleSelection.unassigned)
                ForEach(members) { user in
                    Text(user.name).tag(ResponsibleSelection.user(user.id))
                }
            }
            .pickerStyle(.menu)

            if let onClearSuggestion,
               slot.pendingSuggestion != nil {
                Button("Clear Saved Suggestion") {
                    onClearSuggestion()
                }
                .buttonStyle(.bordered)
            }
        }
        .accessibilityIdentifier("slot-entry-\(slot.id.uuidString)")
    }
}

struct MealSlotEntryView_Previews: PreviewProvider {
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
        _ = manager.addUser(name: "Alice", to: family)
        let plan = manager.createCurrentWeekPlan(for: family)
        let slot = plan.slots.first!
        try? container.mainContext.save()

        struct PreviewWrapper: View {
            @State var mealName: String = ""
            @State var responsibleSelection: ResponsibleSelection = .unassigned
            var slot: MealSlot
            var members: [User]

            var body: some View {
                MealSlotEntryView(slot: slot,
                                  members: members,
                                  mealName: $mealName,
                                  responsibleSelection: $responsibleSelection)
            }
        }

        return PreviewWrapper(slot: slot, members: family.members)
            .modelContainer(container)
    }
}
