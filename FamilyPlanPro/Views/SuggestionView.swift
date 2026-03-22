import SwiftUI
import SwiftData

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
    @State private var expandedSlotID: UUID?

    private var members: [User] {
        plan.family?.members ?? []
    }

    private var sortedSlots: [MealSlot] {
        plan.slots.sorted { $0.date < $1.date }
    }

    private var completedMealCount: Int {
        sortedSlots.filter { savedSuggestion(for: $0) != nil }.count
    }

    private var remainingMealCount: Int {
        max(0, sortedSlots.count - completedMealCount)
    }

    private var firstIncompleteSlotID: UUID? {
        sortedSlots.first(where: { savedSuggestion(for: $0) == nil })?.id
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
            } else if let ownerID = slot.owner?.id {
                initialResponsible[slot.id] = .user(ownerID)
            } else {
                initialResponsible[slot.id] = .unassigned
            }
        }

        _mealInputs = State(initialValue: initialMeals)
        _responsibleSelections = State(initialValue: initialResponsible)
        _activeAlert = State(initialValue: nil)
        _expandedSlotID = State(initialValue: plan.slots.sorted { $0.date < $1.date }.first?.id)
    }

    private var cadenceScheduler: GroceryCadenceScheduler {
        GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(completedMealCount) of \(sortedSlots.count) planned")
                        .font(.headline)
                    Text(remainingMealCount == 0
                         ? "This week is ready for review."
                         : "\(remainingMealCount) left this week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let firstIncompleteSlotID {
                        Button("Open Next Meal") {
                            expandedSlotID = firstIncompleteSlotID
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

                ForEach(sortedSlots) { slot in
                    SuggestionSlotRow(
                        slot: slot,
                        members: members,
                        mealName: mealBinding(for: slot),
                        responsibleSelection: responsibleBinding(for: slot),
                        isExpanded: expandedBinding(for: slot),
                        onClearSuggestion: { clearSuggestion(for: slot) },
                        slotSummaryLabel: { slotSummaryLabel(slot) }
                    )
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Suggestions")
        .toolbar {
            Button("Save Changes") {
                _ = saveSuggestions(requireAllFilled: false)
            }
            Button("Submit for Review") {
                guard let user = currentUser else { return }
                guard saveSuggestions(requireAllFilled: true) else { return }
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
            if expandedSlotID == nil {
                expandedSlotID = firstIncompleteSlotID ?? sortedSlots.first?.id
            }
        }
        .onChange(of: plan.slots.count) { _, _ in
            syncStateFromPlan()
            if expandedSlotID == nil {
                expandedSlotID = firstIncompleteSlotID ?? sortedSlots.first?.id
            }
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

    @ViewBuilder
    private func slotSummaryLabel(_ slot: MealSlot) -> some View {
        let suggestion = savedSuggestion(for: slot)
        let isComplete = suggestion != nil

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(slot.dayOfWeek.localizedName) \(slot.mealType.displayName)")
                        .font(.headline)

                    Text(slot.date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let suggestion {
                        Text(suggestion.mealName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("suggestion-title-\(slot.id.uuidString)")
                        Text(responsibleName(for: suggestion.responsibleUserID))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(isComplete ? "Planned" : "Open")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isComplete ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12))
                    .foregroundStyle(isComplete ? .green : .secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func defaultResponsibleSelection(for slot: MealSlot) -> ResponsibleSelection {
        if let responsibleID = slot.pendingSuggestion?.responsibleUserID ?? slot.finalizedSuggestion?.responsibleUserID {
            return .user(responsibleID)
        }
        if let ownerID = slot.owner?.id {
            return .user(ownerID)
        }
        return .unassigned
    }

    private func savedSuggestion(for slot: MealSlot) -> MealSuggestion? {
        slot.pendingSuggestion ?? slot.finalizedSuggestion
    }

    private func mealBinding(for slot: MealSlot) -> Binding<String> {
        Binding(
            get: { mealInputs[slot.id, default: ""] },
            set: { mealInputs[slot.id] = $0 }
        )
    }

    private func responsibleBinding(for slot: MealSlot) -> Binding<ResponsibleSelection> {
        Binding(
            get: { responsibleSelections[slot.id] ?? defaultResponsibleSelection(for: slot) },
            set: { responsibleSelections[slot.id] = $0 }
        )
    }

    private func expandedBinding(for slot: MealSlot) -> Binding<Bool> {
        Binding(
            get: { expandedSlotID == slot.id },
            set: { expandedSlotID = $0 ? slot.id : nil }
        )
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

    private func saveSuggestions(requireAllFilled: Bool) -> Bool {
        let trimmedInputs: [(MealSlot, String)] = sortedSlots.map { slot in
            (slot, (mealInputs[slot.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if featureFlags.mealsOwnershipRules,
           !members.isEmpty,
           let blockedSlot = unassignedMealSlot(from: trimmedInputs) {
            activeAlert = .unassignedMeal(
                mealLabel: blockedSlot.mealType.displayName,
                dayLabel: blockedSlot.date.formatted(.dateTime.weekday(.wide))
            )
            return false
        }

        if requireAllFilled, !trimmedInputs.allSatisfy({ !$0.1.isEmpty }) {
            activeAlert = .incompleteSubmission
            return false
        }

        let manager = DataManager(context: context,
                                  flags: featureFlags,
                                  groceryCadenceScheduler: cadenceScheduler)

        for (slot, trimmedName) in trimmedInputs {
            if trimmedName.isEmpty {
                if slot.pendingSuggestion != nil {
                    manager.clearSuggestion(for: slot)
                }
                mealInputs[slot.id] = ""
                responsibleSelections[slot.id] = defaultResponsibleSelection(for: slot)
                if expandedSlotID == slot.id {
                    expandedSlotID = firstIncompleteSlotID ?? sortedSlots.first?.id
                }
                continue
            }
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
            if expandedSlotID == slot.id,
               let nextOpenSlotID = firstIncompleteSlotID,
               nextOpenSlotID != slot.id {
                expandedSlotID = nextOpenSlotID
            }
        }

        plan.lastModifiedByUserID = currentUser?.id
        try? context.save()
        return true
    }

    private func unassignedMealSlot(from trimmedInputs: [(MealSlot, String)]) -> MealSlot? {
        trimmedInputs.first { pair in
            let (slot, trimmedName) = pair
            return !trimmedName.isEmpty && responsibleSelection(for: slot) == .unassigned
        }?.0
    }

    private func responsibleSelection(for slot: MealSlot) -> ResponsibleSelection {
        responsibleSelections[slot.id] ?? defaultResponsibleSelection(for: slot)
    }

    private func clearSuggestion(for slot: MealSlot) {
        if let suggestion = slot.pendingSuggestion {
            context.delete(suggestion)
        }
        slot.pendingSuggestion = nil
        if let ownerID = plan.ownershipRulesSnap?.rules[String(slot.dayOfWeek.rawValue)],
           let ownerUUID = UUID(uuidString: ownerID) {
            slot.owner = members.first(where: { $0.id == ownerUUID })
        } else {
            slot.owner = nil
        }
        plan.lastModifiedByUserID = currentUser?.id
        mealInputs[slot.id] = ""
        responsibleSelections[slot.id] = defaultResponsibleSelection(for: slot)
        try? context.save()
    }

    private enum ActiveAlert: Identifiable {
        case incompleteSubmission
        case unassignedMeal(mealLabel: String, dayLabel: String)

        var id: String {
            switch self {
            case .incompleteSubmission:
                return "incompleteSubmission"
            case let .unassignedMeal(mealLabel, dayLabel):
                return "unassignedMeal-\(dayLabel)-\(mealLabel)"
            }
        }

        var title: String {
            switch self {
            case .incompleteSubmission:
                return "Add Meal Suggestions"
            case .unassignedMeal:
                return "Assign a Meal Owner"
            }
        }

        var message: String {
            switch self {
            case .incompleteSubmission:
                return "Please add a suggestion for every meal this week before submitting for review."
            case .unassignedMeal:
                return "This meal day has no owner. Choose a responsible person before saving or submitting."
            }
        }
    }
}

private struct SuggestionSlotRow<SummaryLabel: View>: View {
    let slot: MealSlot
    let members: [User]
    @Binding var mealName: String
    @Binding var responsibleSelection: ResponsibleSelection
    @Binding var isExpanded: Bool
    let onClearSuggestion: () -> Void
    let slotSummaryLabel: () -> SummaryLabel

    var body: some View {
        DisclosureGroup(
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MealSlotEntryView(
                    slot: slot,
                    members: members,
                    mealName: $mealName,
                    responsibleSelection: $responsibleSelection,
                    onClearSuggestion: onClearSuggestion
                )
            }
            .padding(.top, 8)
        } label: {
            slotSummaryLabel()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
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
