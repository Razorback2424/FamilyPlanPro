import SwiftUI
import SwiftData
import Observation

struct MealSlotEntryView: View {
    @Environment(\.modelContext) private var context
    @Bindable var slot: MealSlot
    var members: [User]
    var currentUser: User?

    @State private var mealName: String
    @State private var selectedResponsibleID: UUID?

    init(slot: MealSlot, members: [User], currentUser: User?) {
        self._slot = Bindable(wrappedValue: slot)
        self.members = members
        self.currentUser = currentUser
        _mealName = State(initialValue: slot.pendingSuggestion?.mealName ?? "")
        _selectedResponsibleID = State(initialValue: slot.pendingSuggestion?.responsibleUserID ?? currentUser?.id)
    }

    private var pendingSuggestion: MealSuggestion? {
        slot.pendingSuggestion
    }

    private var buttonTitle: String {
        pendingSuggestion == nil ? "Save Suggestion" : "Update Suggestion"
    }

    private func syncStateWithSlot() {
        if let suggestion = slot.pendingSuggestion {
            mealName = suggestion.mealName
            selectedResponsibleID = suggestion.responsibleUserID
        } else {
            mealName = ""
            selectedResponsibleID = currentUser?.id
        }
    }

    private func saveSuggestion() {
        let trimmedName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let responsibleUser = members.first { $0.id == selectedResponsibleID }
        if let suggestion = slot.pendingSuggestion {
            suggestion.mealName = trimmedName
            suggestion.responsibleUserID = responsibleUser?.id
            suggestion.authorUserID = currentUser?.id ?? suggestion.authorUserID
        } else {
            let manager = DataManager(context: context)
            _ = manager.setPendingSuggestion(mealName: trimmedName,
                                             responsibleUser: responsibleUser,
                                             author: currentUser,
                                             for: slot)
        }
        slot.plan?.lastModifiedByUserID = currentUser?.id
        try? context.save()
        syncStateWithSlot()
    }

    private func clearSuggestion() {
        if let suggestion = slot.pendingSuggestion {
            context.delete(suggestion)
        }
        slot.pendingSuggestion = nil
        slot.plan?.lastModifiedByUserID = currentUser?.id
        mealName = ""
        selectedResponsibleID = currentUser?.id
        try? context.save()
        syncStateWithSlot()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Meal name", text: $mealName)
                .textFieldStyle(.roundedBorder)

            Picker("Responsible", selection: Binding(get: {
                selectedResponsibleID
            }, set: { newValue in
                selectedResponsibleID = newValue
            })) {
                Text("Unassigned").tag(UUID?.none)
                ForEach(members) { user in
                    Text(user.name).tag(UUID?.some(user.id))
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button(buttonTitle) {
                    saveSuggestion()
                }
                .buttonStyle(.borderedProminent)

                if pendingSuggestion != nil {
                    Button("Clear Suggestion") {
                        clearSuggestion()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: slot.pendingSuggestion?.mealName) { _ in
            syncStateWithSlot()
        }
        .onChange(of: slot.pendingSuggestion?.responsibleUserID) { _ in
            syncStateWithSlot()
        }
        .onAppear {
            syncStateWithSlot()
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

        return MealSlotEntryView(slot: slot, members: family.members, currentUser: family.members.first)
            .modelContainer(container)
    }
}
