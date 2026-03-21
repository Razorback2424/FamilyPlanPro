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

struct SuggestionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Bindable var plan: WeeklyPlan
    var currentUser: User?

    @State private var mealInputs: [UUID: String]
    @State private var responsibleSelections: [UUID: ResponsibleSelection]
    @State private var activeAlert: ActiveAlert?

    private var members: [User] {
        plan.family?.members ?? []
    }

    private var sortedSlots: [MealSlot] {
        plan.slots.sorted { $0.date < $1.date }
    }

    private var hasSuggestionsForAllSlots: Bool {
        let slots = sortedSlots
        guard !slots.isEmpty else { return false }
        return slots.allSatisfy {
            let suggestion = $0.pendingSuggestion ?? $0.finalizedSuggestion
            return !(suggestion?.mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    init(plan: WeeklyPlan, currentUser: User?) {
        self._plan = Bindable(wrappedValue: plan)
        self.currentUser = currentUser

        var initialMeals: [UUID: String] = [:]
        var initialResponsible: [UUID: ResponsibleSelection] = [:]
        for slot in plan.slots {
            initialMeals[slot.id] = slot.pendingSuggestion?.mealName ?? slot.finalizedSuggestion?.mealName ?? ""
            if let responsibleID = slot.pendingSuggestion?.responsibleUserID ?? slot.finalizedSuggestion?.responsibleUserID {
                initialResponsible[slot.id] = .user(responsibleID)
            } else {
                initialResponsible[slot.id] = .unassigned
            }
        }

        _mealInputs = State(initialValue: initialMeals)
        _responsibleSelections = State(initialValue: initialResponsible)
        _activeAlert = State(initialValue: nil)
    }

    private var cadenceScheduler: GroceryCadenceScheduler {
        GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
    }

    var body: some View {
        List {
            ForEach(sortedSlots) { slot in
                VStack(alignment: .leading, spacing: 12) {
                    if let suggestion = savedSuggestion(for: slot) {
                        Text("Suggested: \(suggestion.mealName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("suggestion-title-\(slot.id.uuidString)")
                        Text("Responsible: \(responsibleName(for: suggestion.responsibleUserID))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No saved suggestion yet")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    MealSlotEntryView(
                        slot: slot,
                        members: members,
                        mealName: Binding(
                            get: { mealInputs[slot.id, default: ""] },
                            set: { mealInputs[slot.id] = $0 }
                        ),
                        responsibleSelection: Binding(
                            get: { responsibleSelections[slot.id] ?? defaultResponsibleSelection(for: slot) },
                            set: { responsibleSelections[slot.id] = $0 }
                        ),
                        onClearSuggestion: {
                            clearSuggestion(for: slot)
                        }
                    )
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Suggestions")
        .toolbar {
            Button("Save Suggestion") {
                saveSuggestions()
            }
            Button("Submit for Review") {
                guard let user = currentUser else { return }
                guard hasSuggestionsForAllSlots else {
                    activeAlert = .incompleteSubmission
                    return
                }
                saveSuggestions()
                let manager = DataManager(context: context,
                                         flags: featureFlags,
                                         groceryCadenceScheduler: cadenceScheduler)
                manager.submitPlanForReview(plan, by: user)
                try? context.save()
            }
            .disabled(currentUser == nil)
        }
        .onAppear {
            syncStateFromPlan()
        }
        .onChange(of: plan.slots.count) { _, _ in
            syncStateFromPlan()
        }
        .alert(item: $activeAlert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
    }

    private func responsibleName(for id: UUID?) -> String {
        guard let id, let user = members.first(where: { $0.id == id }) else {
            return "Unassigned"
        }
        return user.name
    }

    private func defaultResponsibleSelection(for slot: MealSlot) -> ResponsibleSelection {
        if let responsibleID = slot.pendingSuggestion?.responsibleUserID ?? slot.finalizedSuggestion?.responsibleUserID {
            return .user(responsibleID)
        }
        return .unassigned
    }

    private func savedSuggestion(for slot: MealSlot) -> MealSuggestion? {
        slot.pendingSuggestion ?? slot.finalizedSuggestion
    }

    private func syncStateFromPlan() {
        for slot in sortedSlots {
            if mealInputs[slot.id] == nil {
                mealInputs[slot.id] = slot.pendingSuggestion?.mealName ?? slot.finalizedSuggestion?.mealName ?? ""
            }
            if responsibleSelections[slot.id] == nil {
                responsibleSelections[slot.id] = defaultResponsibleSelection(for: slot)
            }
        }
    }

    private func saveSuggestions() {
        let trimmedInputs: [(MealSlot, String)] = sortedSlots.map { slot in
            (slot, (mealInputs[slot.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard trimmedInputs.allSatisfy({ !$0.1.isEmpty }) else {
            activeAlert = .incompleteSubmission
            return
        }

        let manager = DataManager(context: context,
                                  flags: featureFlags,
                                  groceryCadenceScheduler: cadenceScheduler)

        for (slot, trimmedName) in trimmedInputs {
            let selection = responsibleSelections[slot.id] ?? defaultResponsibleSelection(for: slot)
            let responsibleUser = members.first { $0.id == selection.responsibleID }

            if let suggestion = slot.pendingSuggestion {
                suggestion.mealName = trimmedName
                suggestion.responsibleUserID = responsibleUser?.id
                suggestion.authorUserID = currentUser?.id ?? suggestion.authorUserID
                slot.owner = responsibleUser
            } else {
                _ = manager.setPendingSuggestion(mealName: trimmedName,
                                                 responsibleUser: responsibleUser,
                                                 author: currentUser,
                                                 for: slot)
            }

            mealInputs[slot.id] = trimmedName
            responsibleSelections[slot.id] = selection
        }

        plan.lastModifiedByUserID = currentUser?.id
        try? context.save()
    }

    private func clearSuggestion(for slot: MealSlot) {
        if let suggestion = slot.pendingSuggestion {
            context.delete(suggestion)
        }
        slot.pendingSuggestion = nil
        slot.owner = nil
        plan.lastModifiedByUserID = currentUser?.id
        mealInputs[slot.id] = ""
        responsibleSelections[slot.id] = .unassigned
        try? context.save()
    }

    private enum ActiveAlert: Identifiable {
        case incompleteSubmission

        var id: String { "incompleteSubmission" }
        var title: String { "Add Meal Suggestions" }
        var message: String {
            "Please add a suggestion for every meal this week before submitting for review."
        }
    }
}

struct SuggestionView_Previews: PreviewProvider {
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
        try? container.mainContext.save()

        return NavigationStack {
            SuggestionView(plan: plan, currentUser: family.members.first)
        }
        .modelContainer(container)
    }
}
