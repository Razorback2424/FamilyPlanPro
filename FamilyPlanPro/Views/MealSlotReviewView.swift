import SwiftUI
import SwiftData
import Observation

struct MealSlotReviewView: View {
    @Environment(\.modelContext) private var context
    @Bindable var slot: MealSlot
    @Bindable var plan: WeeklyPlan
    var users: [User]

    @State private var showRejectSheet = false
    @State private var newTitle: String = ""
    @State private var selectedUser: User?
    @State private var reason: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(slot.date, format: Date.FormatStyle(date: .numeric, time: .omitted)) \(slot.mealType.rawValue.capitalized)")
                .font(.headline)
            if let pending = slot.pendingSuggestion {
                Text(pending.title)
                if let user = pending.user {
                    Text("Responsible: \(user.name)")
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
                        newTitle = pending.title
                        selectedUser = pending.user
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
                        Picker("Responsible", selection: $selectedUser) {
                            Text("Unassigned").tag(Optional<User>(nil))
                            ForEach(users) { user in
                                Text(user.name).tag(Optional(user))
                            }
                        }
                        TextField("Reason (optional)", text: $reason)
                    }
                    Button("Submit") {
                        let manager = DataManager(context: context)
                        _ = manager.rejectPendingSuggestion(in: slot,
                                                           newTitle: newTitle,
                                                           by: selectedUser,
                                                           reason: reason.isEmpty ? nil : reason,
                                                           in: plan)
                        try? context.save()
                        newTitle = ""
                        selectedUser = nil
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
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Eggs", user: userA, for: slot)
        try? container.mainContext.save()

        return MealSlotReviewView(slot: slot, plan: plan, users: family.users)
            .modelContainer(container)
    }
}

