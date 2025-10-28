import SwiftUI
import SwiftData
import Observation

struct FinalizedView: View {
    @Bindable var plan: WeeklyPlan

    private var members: [User] {
        plan.family?.members ?? []
    }

    private var daySections: [(day: DayOfWeek, slots: [MealSlot])] {
        let orderedMeals = MealType.allCases
        return DayOfWeek.allCases.compactMap { day in
            let slotsForDay = plan.mealSlots
                .filter { $0.dayOfWeek == day && $0.finalizedSuggestion != nil }
                .sorted { lhs, rhs in
                    let lhsIndex = orderedMeals.firstIndex(of: lhs.mealType) ?? 0
                    let rhsIndex = orderedMeals.firstIndex(of: rhs.mealType) ?? 0
                    return lhsIndex < rhsIndex
                }
            guard !slotsForDay.isEmpty else { return nil }
            return (day, slotsForDay)
        }
    }

    private func responsibleName(for suggestion: MealSuggestion?) -> String {
        guard let id = suggestion?.responsibleUserID,
              let user = members.first(where: { $0.id == id }) else {
            return "Unassigned"
        }
        return user.name
    }

    var body: some View {
        List {
            Section {
                Text("Every meal for the week has been finalized. Here's the summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if daySections.isEmpty {
                Text("No finalized meals available.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(daySections, id: \.day.rawValue) { section in
                    Section(section.day.localizedName) {
                        ForEach(section.slots) { slot in
                            if let suggestion = slot.finalizedSuggestion {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.mealType.displayName)
                                        .font(.headline)
                                    Text(suggestion.mealName)
                                        .font(.body)
                                        .accessibilityIdentifier("finalized-meal-\(slot.id.uuidString)")
                                    Text("Responsible: \(responsibleName(for: suggestion))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Finalized")
    }
}

struct FinalizedView_Previews: PreviewProvider {
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
        let alice = manager.addUser(name: "Alice", to: family)
        let bob = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)

        let mondayBreakfast = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Pancakes", responsibleUser: alice, author: alice, for: mondayBreakfast)
        manager.acceptPendingSuggestion(in: mondayBreakfast)

        let mondayDinner = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Stir Fry", responsibleUser: bob, author: bob, for: mondayDinner)
        manager.acceptPendingSuggestion(in: mondayDinner)

        manager.finalizeIfPossible(plan)
        try? container.mainContext.save()

        return NavigationStack {
            FinalizedView(plan: plan)
        }
        .modelContainer(container)
    }
}
