import SwiftUI
import SwiftData
import Observation

enum ResponsibleSelection: Hashable {
    case unassigned
    case user(UUID)

    var responsibleID: UUID? {
        switch self {
        case .unassigned:
            return nil
        case .user(let id):
            return id
        }
    }
}

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
