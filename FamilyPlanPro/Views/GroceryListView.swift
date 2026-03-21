import SwiftUI
import SwiftData
import Observation

struct GroceryListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Bindable var list: GroceryList

    private var dataManager: DataManager {
        DataManager(context: context,
                    flags: featureFlags,
                    groceryCadenceScheduler: GroceryCadenceScheduler(scheduler: notificationScheduler.scheduler))
    }

    private var groupedItems: [(Date?, [GroceryItem])] {
        let grouped = Dictionary(grouping: list.items) { item in
            item.dayRef.map { Calendar.current.startOfDay(for: $0) }
        }
        let sortedGroups = grouped.sorted { lhs, rhs in
            switch (lhs.key, rhs.key) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return false
            }
        }
        return sortedGroups.map { (key, items) in
            (key, items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
    }

    private var availableDays: [Date] {
        let slotDates = list.plan?.slots.map { Calendar.current.startOfDay(for: $0.date) } ?? []
        return Array(Set(slotDates)).sorted()
    }

    var body: some View {
        List {
            if list.items.isEmpty {
                Text("No items yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(groupedItems, id: \.0) { (day, items) in
                Section(header: sectionHeader(for: day)) {
                    ForEach(items) { item in
                        GroceryItemRow(item: item, availableDays: availableDays)
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets, in: items)
                    }
                }
            }
        }
        .navigationTitle("Grocery List")
        .onAppear {
            reconcileCadence()
        }
        .onChange(of: list.items.count) { _, _ in
            reconcileCadence()
        }
        .onDisappear {
            try? context.save()
        }
        .toolbar {
            Button("Add Item") {
                addItem()
            }
        }
    }

    private func sectionHeader(for day: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let day {
                Text(day.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline)
                Text(day.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Unscheduled")
                    .font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(sectionAccessibilityIdentifier(for: day))
    }

    private func sectionAccessibilityIdentifier(for day: Date?) -> String {
        guard let day else {
            return "grocery-section-unscheduled"
        }
        let weekday = Calendar.current.component(.weekday, from: day)
        return "grocery-section-\(weekday)"
    }

    private func addItem() {
        let item = GroceryItem(name: "", dayRef: nil, list: list)
        list.items.append(item)
        context.insert(item)
        try? context.save()
    }

    private func deleteItems(at offsets: IndexSet, in items: [GroceryItem]) {
        for index in offsets {
            let item = items[index]
            list.items.removeAll { $0 === item }
            context.delete(item)
        }
        try? context.save()
    }

    private func reconcileCadence() {
        guard let plan = list.plan else { return }
        dataManager.reconcileGroceryCadence(for: plan)
    }
}

private struct GroceryItemRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: GroceryItem
    let availableDays: [Date]

    private var dayLabel: String {
        guard let day = item.dayRef else {
            return "Unscheduled"
        }
        return day.formatted(.dateTime.weekday(.abbreviated))
    }

    var body: some View {
        HStack {
            TextField("Item", text: $item.name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .accessibilityIdentifier(item.name.isEmpty ? "grocery-item-empty" : "grocery-item-name")
            Menu(dayLabel) {
                Button("Unscheduled") {
                    updateDay(nil)
                }
                ForEach(availableDays, id: \.self) { day in
                    Button(day.formatted(.dateTime.weekday(.wide))) {
                        updateDay(day)
                    }
                }
            }
            .accessibilityIdentifier("grocery-item-day")
            Toggle("Checked", isOn: $item.checked)
                .labelsHidden()
                .accessibilityLabel("Checked")
        }
        .onChange(of: item.name) { _, _ in
            try? context.save()
        }
        .onChange(of: item.checked) { _, _ in
            try? context.save()
        }
    }

    private func updateDay(_ day: Date?) {
        item.dayRef = day
        try? context.save()
    }
}

struct GroceryListView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            Family.self,
            WeeklyPlan.self,
            OwnershipRulesSnap.self,
            MealSlot.self,
            MealSuggestion.self,
            GroceryList.self,
            GroceryItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let manager = DataManager(context: container.mainContext,
                                  flags: FeatureFlags(mealsGroceryList: true, mealsBudgetStatus: true))
        let family = manager.createFamily(name: "Preview")
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .dinner, to: plan)
        _ = manager.setPendingSuggestion(title: "Pasta", user: nil, for: slot)
        manager.acceptPendingSuggestion(in: slot)
        manager.finalizeIfPossible(plan)
        try? container.mainContext.save()

        return NavigationStack {
            if let list = plan.groceryList {
                GroceryListView(list: list)
            }
        }
        .modelContainer(container)
    }
}
