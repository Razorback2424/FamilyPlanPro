import SwiftUI
import SwiftData

struct ThisWeekView: View {
    @Bindable var plan: WeeklyPlan

    private var sortedSlots: [MealSlot] {
        plan.slots.sorted { $0.date < $1.date }
    }

    private var groceryGroups: [GroceryGroup] {
        guard let list = plan.groceryList else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: list.items) { item -> GroceryGroup.Key in
            if let dayRef = item.dayRef {
                return .day(calendar.startOfDay(for: dayRef))
            }
            return .unscheduled
        }

        return grouped
            .map { key, items in
                GroceryGroup(key: key,
                             label: key.label,
                             items: items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
            .sorted { lhs, rhs in
                switch (lhs.key, rhs.key) {
                case let (.day(left), .day(right)):
                    return left < right
                case (.day, .unscheduled):
                    return true
                case (.unscheduled, .day):
                    return false
                case (.unscheduled, .unscheduled):
                    return false
                }
            }
    }

    var body: some View {
        List {
            Section("Week Snapshot") {
                Text("Week of \(plan.startDate.formatted(.dateTime.month(.wide).day()))")
                Text("Status: \(plan.status.rawValue.capitalized)")
                Text("This is a read-only overview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Meal Summary") {
                ForEach(sortedSlots) { slot in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(slot.date, format: .dateTime.weekday(.wide)) \(slot.mealType.displayName)")
                            .font(.headline)
                        Text(slot.date, format: .dateTime.month().day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(slot.finalizedSuggestion?.mealName ?? slot.pendingSuggestion?.mealName ?? "No selection")
                            .accessibilityIdentifier("finalized-meal-\(slot.id.uuidString)")
                        Text("Responsible: \(slot.owner?.name ?? "Unassigned")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if slot.isSimple {
                            Text("Simple Friday")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let list = plan.groceryList, !list.items.isEmpty {
                Section("Grocery Summary") {
                    ForEach(groceryGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.label)
                                .font(.headline)
                            ForEach(group.items) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name)
                                    Spacer()
                                    if item.checked {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Budget Snapshot") {
                if plan.budgetTargetCents > 0 {
                    Text("Target: \(currencyString(from: plan.budgetTargetCents))")
                } else {
                    Text("Target: Unset")
                }
                Text("Status: \(plan.budgetStatus.rawValue.capitalized)")
                if let observed = plan.groceryList?.budgetObservedCents, observed > 0 {
                    Text("Observed spend: \(currencyString(from: observed))")
                }
            }

            Section {
                Text("Planner stays for editing meals. This Week is a read-only snapshot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("This Week")
    }

    private func currencyString(from cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return dollars.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

private struct GroceryGroup: Identifiable {
    enum Key: Hashable {
        case day(Date)
        case unscheduled

        var label: String {
            switch self {
            case .day(let date):
                return date.formatted(.dateTime.weekday(.wide))
            case .unscheduled:
                return "Unscheduled"
            }
        }
    }

    var key: Key
    var label: String
    var items: [GroceryItem]

    var id: String {
        switch key {
        case .day(let date):
            return "day-\(date.timeIntervalSince1970)"
        case .unscheduled:
            return "unscheduled"
        }
    }
}
