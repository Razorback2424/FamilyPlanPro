import SwiftUI
import SwiftData
import Observation

struct SuggestionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan
    var currentUser: User?
    @State private var mealInputs: [UUID: String]
    @State private var responsibleSelections: [UUID: ResponsibleSelection]
    @State private var selectedDay: DayOfWeek
    @State private var activeAlert: ActiveAlert?

    private var members: [User] {
        plan.family?.members ?? []
    }

    private var daySections: [(day: DayOfWeek, slots: [MealSlot])]? {
        guard !plan.mealSlots.isEmpty else { return nil }

        let orderedMeals = MealType.allCases
        let sections: [(DayOfWeek, [MealSlot])] = DayOfWeek.allCases.compactMap { day in
            let slotsForDay = plan.mealSlots
                .filter { $0.dayOfWeek == day }
                .sorted { lhs, rhs in
                    let lhsIndex = orderedMeals.firstIndex(of: lhs.mealType) ?? 0
                    let rhsIndex = orderedMeals.firstIndex(of: rhs.mealType) ?? 0
                    return lhsIndex < rhsIndex
                }
            guard !slotsForDay.isEmpty else { return nil }
            return (day, slotsForDay)
        }

        return sections.isEmpty ? nil : sections
    }

    private var hasSuggestionsForAllSlots: Bool {
        let slots = plan.mealSlots
        guard !slots.isEmpty else { return false }

        return slots.allSatisfy { slot in
            let suggestion = slot.pendingSuggestion ?? slot.finalizedSuggestion
            guard let suggestion else { return false }
            return !suggestion.mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    init(plan: WeeklyPlan, currentUser: User?) {
        self._plan = Bindable(wrappedValue: plan)
        self.currentUser = currentUser

        var initialMeals: [UUID: String] = [:]
        var initialResponsible: [UUID: ResponsibleSelection] = [:]
        for slot in plan.mealSlots {
            initialMeals[slot.id] = slot.pendingSuggestion?.mealName ??
                slot.finalizedSuggestion?.mealName ?? ""
            if let responsibleID = slot.pendingSuggestion?.responsibleUserID ??
                slot.finalizedSuggestion?.responsibleUserID {
                initialResponsible[slot.id] = .user(responsibleID)
            } else {
                initialResponsible[slot.id] = .unassigned
            }
        }

        _mealInputs = State(initialValue: initialMeals)
        _responsibleSelections = State(initialValue: initialResponsible)
        let initialDay = plan.mealSlots.first?.dayOfWeek ?? DayOfWeek.allCases.first ?? .monday
        _selectedDay = State(initialValue: initialDay)
        _activeAlert = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let sections = daySections {
                TabView(selection: $selectedDay) {
                    ForEach(sections, id: \.day.rawValue) { section in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(section.day.localizedName)
                                    .font(.title2.bold())

                                ForEach(section.slots) { slot in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(slot.mealType.displayName)
                                                .font(.headline)
                                            Spacer()
                                            if let suggestion = savedSuggestion(for: slot) {
                                                Text("Saved: \(suggestion.mealName)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                    .accessibilityIdentifier("suggestion-title-\(slot.id.uuidString)")
                                            } else {
                                                Text("No saved suggestion yet")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }

                                        if let suggestion = savedSuggestion(for: slot) {
                                            let responsibleName = suggestion.responsibleUserID.flatMap { id in
                                                members.first(where: { $0.id == id })?.name
                                            }
                                            Text("Responsible: \(responsibleName ?? "Unassigned")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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

                                Button("Save Suggestions") {
                                    saveSuggestions(for: section)
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 16)
                        }
                        .tag(section.day)
                        .accessibilityIdentifier("suggestion-day-\(section.day.rawValue)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            } else {
                Text("No meal slots available.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Suggestions")
        .toolbar {
            Button("Submit for Review") {
                guard let user = currentUser else { return }
                guard hasSuggestionsForAllSlots else {
                    activeAlert = .incompleteSubmission
                    return
                }
                let manager = DataManager(context: context)
                manager.submitPlanForReview(plan, by: user)
                try? context.save()
            }
            .disabled(currentUser == nil)
        }
        .onAppear {
            syncStateFromPlan()
        }
        .onChange(of: plan.mealSlots.count) { _ in
            syncStateFromPlan()
        }
        .alert(item: $activeAlert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
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
        for slot in plan.mealSlots {
            if mealInputs[slot.id] == nil {
                mealInputs[slot.id] = slot.pendingSuggestion?.mealName ??
                    slot.finalizedSuggestion?.mealName ?? ""
            }
            if responsibleSelections[slot.id] == nil {
                responsibleSelections[slot.id] = defaultResponsibleSelection(for: slot)
            }
        }
    }

    private func saveSuggestions(for section: (day: DayOfWeek, slots: [MealSlot])) {
        let trimmedInputs: [(MealSlot, String)] = section.slots.map { slot in
            let currentInput = mealInputs[slot.id] ?? ""
            return (slot, currentInput.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard trimmedInputs.allSatisfy({ !$0.1.isEmpty }) else {
            activeAlert = .incompleteDay(section.day.localizedName)
            return
        }

        let manager = DataManager(context: context)

        for (slot, trimmedName) in trimmedInputs {
            let selection = responsibleSelections[slot.id] ?? defaultResponsibleSelection(for: slot)
            let responsibleID = selection.responsibleID
            let responsibleUser = members.first { $0.id == responsibleID }

            if let suggestion = slot.pendingSuggestion {
                suggestion.mealName = trimmedName
                suggestion.responsibleUserID = responsibleUser?.id
                suggestion.authorUserID = currentUser?.id ?? suggestion.authorUserID
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
        plan.lastModifiedByUserID = currentUser?.id
        mealInputs[slot.id] = ""
        responsibleSelections[slot.id] = .unassigned
        try? context.save()
    }

    private enum ActiveAlert: Identifiable {
        case incompleteSubmission
        case incompleteDay(String)

        var id: String {
            switch self {
            case .incompleteSubmission:
                return "incompleteSubmission"
            case .incompleteDay(let name):
                return "incompleteDay-\(name)"
            }
        }

        var title: String {
            switch self {
            case .incompleteSubmission:
                return "Add Meal Suggestions"
            case .incompleteDay(let name):
                return "Complete \(name)"
            }
        }

        var message: String {
            switch self {
            case .incompleteSubmission:
                return "Please add a suggestion for every meal this week before submitting for review."
            case .incompleteDay(let name):
                return "Please add a meal suggestion for every \(name) meal before saving."
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
            SuggestionView(plan: plan, currentUser: family.members.first)
        }
        .modelContainer(container)
    }
}
