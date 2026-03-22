import SwiftUI
import SwiftData
import Observation

struct GroceryListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.featureFlags) private var featureFlags
    @Environment(\.notificationScheduler) private var notificationScheduler
    @Bindable var list: GroceryList
    @State private var observedItemCount = 0
    @State private var pendingUndoDeletion: PendingUndoDeletion?

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

    private var totalItemCount: Int {
        list.items.count
    }

    private var checkedItemCount: Int {
        list.items.filter(\.checked).count
    }

    private var completionSummary: String {
        if totalItemCount == 0 {
            return "Start by adding the items you need for this week's meals."
        }

        if checkedItemCount == 0 {
            return "\(totalItemCount) item\(totalItemCount == 1 ? "" : "s") on your list so far."
        }

        return "\(checkedItemCount) of \(totalItemCount) item\(totalItemCount == 1 ? "" : "s") picked up."
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use this list as you shop, and move items to the right day if plans change.")
                            .font(.subheadline)
                        Text(completionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if list.items.isEmpty {
                    ContentUnavailableView(
                        "Your Grocery List Is Empty",
                        systemImage: "cart",
                        description: Text("Add the ingredients and household items you need for this week's meals.")
                    )
                }
                ForEach(groupedItems, id: \.0) { (day, items) in
                    Section(header: sectionHeader(for: day)) {
                        ForEach(items) { item in
                            GroceryItemRow(item: item,
                                           availableDays: availableDays,
                                           isNewestItem: item === list.items.last)
                                .id(ObjectIdentifier(item))
                        }
                        .onDelete { offsets in
                            deleteItems(at: offsets, in: items)
                        }
                    }
                }
            }
            .navigationTitle("Grocery List")
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                observedItemCount = list.items.count
                reconcileCadence()
            }
            .onChange(of: list.items.count) { _, newCount in
                reconcileCadence()
                guard newCount > observedItemCount, let newestItem = list.items.last else {
                    observedItemCount = newCount
                    return
                }
                observedItemCount = newCount
                withAnimation {
                    proxy.scrollTo(ObjectIdentifier(newestItem), anchor: .center)
                }
            }
            .onDisappear {
                try? context.save()
            }
            .toolbar {
                Button("Add Item") {
                    addItem()
                }
            }
            .overlay(alignment: .bottom) {
                if let pendingUndoDeletion {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Grocery item deleted")
                                .font(.subheadline.weight(.semibold))
                            Text(pendingUndoDeletion.items.count == 1 ? "Undo to restore it." : "Undo to restore them.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 12)

                        Button("Undo") {
                            restoreDeletedItems()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
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
        let deletedSnapshots = offsets.compactMap { index -> PendingUndoDeletion.ItemSnapshot? in
            guard index < items.count else { return nil }
            let item = items[index]
            let snapshot = PendingUndoDeletion.ItemSnapshot(name: item.name,
                                                            dayRef: item.dayRef,
                                                            checked: item.checked)
            list.items.removeAll { $0 === item }
            context.delete(item)
            return snapshot
        }
        pendingUndoDeletion = deletedSnapshots.isEmpty ? nil : PendingUndoDeletion(items: deletedSnapshots)
        try? context.save()
    }

    private func restoreDeletedItems() {
        guard let pendingUndoDeletion else { return }
        for snapshot in pendingUndoDeletion.items {
            let item = GroceryItem(name: snapshot.name,
                                   dayRef: snapshot.dayRef,
                                   checked: snapshot.checked,
                                   list: list)
            list.items.append(item)
            context.insert(item)
        }
        self.pendingUndoDeletion = nil
        try? context.save()
    }

    private func reconcileCadence() {
        guard let plan = list.plan else { return }
        dataManager.reconcileGroceryCadence(for: plan)
    }
}

private struct PendingUndoDeletion {
    struct ItemSnapshot {
        let name: String
        let dayRef: Date?
        let checked: Bool
    }

    let items: [ItemSnapshot]
}

private struct GroceryItemRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: GroceryItem
    let availableDays: [Date]
    let isNewestItem: Bool
    @State private var showingDayOptions = false

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
                .autocorrectionDisabled()
                .accessibilityIdentifier(item.name.isEmpty && isNewestItem ? "grocery-item-new" : (item.name.isEmpty ? "grocery-item-empty" : "grocery-item-name"))
            Button(dayLabel) {
                showingDayOptions = true
            }
            .buttonStyle(.plain)
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
        .confirmationDialog("Assign Grocery Day",
                            isPresented: $showingDayOptions,
                            titleVisibility: .visible) {
            Button("Unscheduled") {
                updateDay(nil)
            }
            ForEach(availableDays, id: \.self) { day in
                Button(day.formatted(.dateTime.weekday(.wide))) {
                    updateDay(day)
                }
            }
            Button("Cancel", role: .cancel) {}
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
