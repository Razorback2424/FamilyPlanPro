import SwiftUI
import SwiftData
import Observation

struct MealSlotReviewView: View {
    @Environment(\.modelContext) private var context
    @Bindable var slot: MealSlot
    @Bindable var plan: WeeklyPlan
    var members: [User]

    @State private var showRejectSheet = false
    @State private var newTitle: String = ""
    @State private var selectedResponsible: User?
    @State private var reason: String = ""

    private var reviewer: User? {
        if let family = plan.family {
            return family.members.last ?? family.members.first
        }
        return nil
    }

    private func userName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return members.first(where: { $0.id == id })?.name
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(slot.dayOfWeek.localizedName) \(slot.mealType.displayName)")
                .font(.headline)
            if let pending = slot.pendingSuggestion {
                Text(pending.mealName)
                if let responsibleName = userName(for: pending.responsibleUserID) {
                    Text("Responsible: \(responsibleName)")
                        .font(.caption)
                }
                HStack {
                    Button("Accept") {
                        let manager = DataManager(context: context)
                        manager.acceptPendingSuggestion(in: slot)
                        manager.finalizeIfPossible(plan)
                        try? context.save()
                    }
                    .buttonStyle(.bordered)

                    Button("Reject") {
                        newTitle = pending.mealName
                        if let id = pending.responsibleUserID {
                            selectedResponsible = members.first(where: { $0.id == id })
                        } else {
                            selectedResponsible = nil
                        }
                        showRejectSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showRejectSheet) {
            NavigationStack {
                Form {
                    Section("New Suggestion") {
                        TextField("Meal name", text: $newTitle)
                        Picker("Responsible", selection: $selectedResponsible) {
                            Text("Unassigned").tag(Optional<User>(nil))
                            ForEach(members) { user in
                                Text(user.name).tag(Optional(user))
                            }
                        }
                        TextField("Reason (optional)", text: $reason)
                    }
                    Button("Submit") {
                        let manager = DataManager(context: context)
                        _ = manager.rejectPendingSuggestion(in: slot,
                                                           newMealName: newTitle,
                                                           author: reviewer,
                                                           responsibleUser: selectedResponsible,
                                                           reasonForChange: reason.isEmpty ? nil : reason,
                                                           in: plan)
                        try? context.save()
                        newTitle = ""
                        selectedResponsible = nil
                        reason = ""
                        showRejectSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("Replace Suggestion")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showRejectSheet = false }
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

struct MealSlotReviewView_Previews: PreviewProvider {
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
        let userA = manager.addUser(name: "Alice", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Eggs",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try? container.mainContext.save()

        return MealSlotReviewView(slot: slot, plan: plan, members: family.members)
            .modelContainer(container)
    }
}

