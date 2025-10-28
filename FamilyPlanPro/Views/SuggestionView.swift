import SwiftUI
import SwiftData
import Observation

struct SuggestionView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan
    var currentUser: User?
    @State private var showIncompleteSuggestionsAlert = false

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

    var body: some View {
        List {
            if let sections = daySections {
                ForEach(sections, id: \.day.rawValue) { section in
                    Section(section.day.localizedName) {
                        ForEach(section.slots) { slot in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(slot.mealType.displayName)
                                        .font(.headline)
                                    Spacer()
                                    if let suggestion = slot.pendingSuggestion {
                                        Text("Suggested: \(suggestion.mealName)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .accessibilityIdentifier("suggestion-title-\(slot.id.uuidString)")
                                    } else {
                                        Text("No suggestion yet")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                if let suggestion = slot.pendingSuggestion {
                                    let responsibleName = members.first(where: { $0.id == suggestion.responsibleUserID })?.name
                                    Text("Responsible: \(responsibleName ?? "Unassigned")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                MealSlotEntryView(slot: slot,
                                                  members: members,
                                                  currentUser: currentUser)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
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
                    showIncompleteSuggestionsAlert = true
                    return
                }
                let manager = DataManager(context: context)
                manager.submitPlanForReview(plan, by: user)
                try? context.save()
            }
            .disabled(currentUser == nil)
        }
        .alert("Add Meal Suggestions", isPresented: $showIncompleteSuggestionsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please add a suggestion for every meal this week before submitting for review.")
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
