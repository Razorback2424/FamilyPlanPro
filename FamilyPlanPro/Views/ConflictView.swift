import SwiftUI
import SwiftData
import Observation

struct ConflictView: View {
    @Environment(\.modelContext) private var context
    @Bindable var plan: WeeklyPlan

    @State private var activeSlot: MealSlot?
    @State private var finalMealName: String = ""
    @State private var selectedResponsible: User?
    @State private var decidingUser: User?
    @State private var resolutionNotes: String = ""

    private var members: [User] {
        plan.family?.members ?? []
    }

    private var disputedSlots: [MealSlot] {
        plan.mealSlots.filter { slot in
            guard let pending = slot.pendingSuggestion else { return false }
            return pending.authorUserID != plan.lastModifiedByUserID
        }
    }

    private func openResolution(for slot: MealSlot) {
        activeSlot = slot
        finalMealName = slot.pendingSuggestion?.mealName ?? ""
        if let responsibleID = slot.pendingSuggestion?.responsibleUserID {
            selectedResponsible = members.first(where: { $0.id == responsibleID })
        } else {
            selectedResponsible = nil
        }
        if let lastModifier = plan.lastModifiedByUserID,
           let user = members.first(where: { $0.id == lastModifier }) {
            decidingUser = user
        } else {
            decidingUser = members.first
        }
        resolutionNotes = slot.pendingSuggestion?.reasonForChange ?? ""
    }

    private func closeResolution() {
        activeSlot = nil
        finalMealName = ""
        selectedResponsible = nil
        decidingUser = nil
        resolutionNotes = ""
    }

    private func resolutionSheet() -> some View {
        NavigationStack {
            Form {
                Section("Final decision") {
                    TextField("Meal name", text: $finalMealName)
                    Picker("Responsible", selection: Binding(get: {
                        selectedResponsible
                    }, set: { newValue in
                        selectedResponsible = newValue
                    })) {
                        Text("Unassigned").tag(Optional<User>(nil))
                        ForEach(members) { user in
                            Text(user.name).tag(Optional(user))
                        }
                    }
                    if members.count > 1 {
                        Picker("Decision entered by", selection: Binding(get: {
                            decidingUser
                        }, set: { newValue in
                            decidingUser = newValue
                        })) {
                            ForEach(members) { user in
                                Text(user.name).tag(Optional(user))
                            }
                        }
                    }
                    TextField("Notes (optional)", text: $resolutionNotes)
                }
                if let current = activeSlot?.pendingSuggestion,
                   let authorName = members.first(where: { $0.id == current.authorUserID })?.name,
                   let challengerID = plan.lastModifiedByUserID,
                   let challengerName = members.first(where: { $0.id == challengerID })?.name {
                    Section("Context") {
                        Text("Last update from \(authorName).")
                        Text("Conflict raised by \(challengerName).")
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    Button("Confirm Decision") {
                        guard let slot = activeSlot else { return }
                        let manager = DataManager(context: context)
                        let reason = resolutionNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                        _ = manager.resolveConflict(for: slot,
                                                     finalMealName: finalMealName,
                                                     decidedBy: decidingUser,
                                                     responsibleUser: selectedResponsible,
                                                     reasonForChange: reason.isEmpty ? nil : reason,
                                                     in: plan)
                        try? context.save()
                        closeResolution()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(finalMealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || decidingUser == nil)
                }
            }
            .navigationTitle("Resolve Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { closeResolution() }
                }
            }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's settle these meals together")
                        .font(.title3)
                    Text("Both partners contributed different ideas. Talk it through, agree on a final meal, and record the decision below.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if disputedSlots.isEmpty {
                Text("No disputed meals remain. Return to review mode when you're ready.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(disputedSlots) { slot in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(slot.dayOfWeek.localizedName) \(slot.mealType.displayName)")
                            .font(.headline)
                        if let pending = slot.pendingSuggestion {
                            Text(pending.mealName)
                                .font(.body)
                            if let authorID = pending.authorUserID,
                               let authorName = members.first(where: { $0.id == authorID })?.name {
                                Text("Suggested by \(authorName)")
                                    .font(.caption)
                            }
                        }
                        Button("Choose Final Meal") {
                            openResolution(for: slot)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange, lineWidth: 1)
                    )
                    .accessibilityIdentifier("conflict-slot-\(slot.id.uuidString)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Resolve Conflicts")
        .sheet(isPresented: Binding(get: {
            activeSlot != nil
        }, set: { newValue in
            if !newValue {
                closeResolution()
            }
        })) {
            resolutionSheet()
        }
    }
}

struct ConflictView_Previews: PreviewProvider {
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
        let userA = manager.addUser(name: "Alex", to: family)
        let userB = manager.addUser(name: "Bailey", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        plan.status = .conflict
        plan.lastModifiedByUserID = userB.id
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .dinner, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Tacos",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)
        try? container.mainContext.save()

        return ConflictView(plan: plan)
            .modelContainer(container)
    }
}
