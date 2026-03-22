import SwiftUI
import SwiftData
import Observation

struct FamilySettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var family: Family

    @State private var newMemberName: String = ""
    @FocusState private var isAddingMember: Bool

    private var trimmedFamilyName: String {
        family.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSaveDisabled: Bool {
        trimmedFamilyName.isEmpty
    }

    private var sortedMembers: [User] {
        family.members.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section("Household") {
                TextField("Household name", text: $family.name)
                    .textInputAutocapitalization(.words)
            }

            Section("Members") {
                if family.members.isEmpty {
                    ContentUnavailableView("No household members yet", systemImage: "person.3", description: Text("Add the people in your household so the planner can assign meals cleanly."))
                } else {
                    ForEach(sortedMembers) { member in
                        Text(member.name)
                    }
                    .onDelete(perform: deleteMembers)
                }

                HStack {
                    TextField("New member name", text: $newMemberName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isAddingMember)

                    Button("Add member") {
                        addMember()
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Default weekday owners") {
                if sortedMembers.isEmpty {
                    Text("Add household members to set up the default meal owner for each day.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(DayOfWeek.allCases, id: \.rawValue) { day in
                        Picker(day.localizedName, selection: weekdayDefaultBinding(for: day)) {
                            ForEach(sortedMembers) { member in
                                Text(member.name).tag(member.id)
                            }
                        }
                    }
                }
                Text("These defaults guide the first set of meal suggestions when a new week starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Family Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveAndDismiss() }
                    .disabled(isSaveDisabled)
            }
        }
    }

    private func addMember() {
        let trimmedName = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let manager = DataManager(context: context)
        _ = manager.addUser(name: trimmedName, to: family)
        newMemberName = ""
        isAddingMember = false

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save new member: \(error)")
        }
    }

    private func deleteMembers(at offsets: IndexSet) {
        let sortedMembers = sortedMembers
        for index in offsets {
            guard sortedMembers.indices.contains(index) else { continue }
            let member = sortedMembers[index]
            context.delete(member)
        }

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to delete member: \(error)")
        }
    }

    private func cancel() {
        dismiss()
    }

    private func weekdayDefaultBinding(for day: DayOfWeek) -> Binding<UUID> {
        Binding(
            get: { weekdayDefaultOwnerID(for: day) },
            set: { updateWeekdayDefaultOwner($0, for: day) }
        )
    }

    private func weekdayDefaultOwnerID(for day: DayOfWeek) -> UUID {
        let manager = DataManager(context: context)
        let rules = manager.familyOwnershipDefaults(for: family)
        if let ownerID = rules[String(day.rawValue)],
           let ownerUUID = UUID(uuidString: ownerID) {
            return ownerUUID
        }
        return sortedMembers.first?.id ?? UUID()
    }

    private func updateWeekdayDefaultOwner(_ ownerID: UUID, for day: DayOfWeek) {
        let manager = DataManager(context: context)
        let owner = family.members.first { $0.id == ownerID }
        manager.updateFamilyOwnershipDefault(for: day, owner: owner, in: family)
    }

    private func saveAndDismiss() {
        family.name = trimmedFamilyName

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save family changes: \(error)")
        }

        dismiss()
    }
}

#Preview {
    FamilySettingsView_Preview()
}

private struct FamilySettingsView_Preview: View {
    let container: ModelContainer
    let family: Family

    init() {
        container = try! ModelContainer(
            for: Family.self, User.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let manager = DataManager(context: container.mainContext)
        let fam = manager.createFamily(name: "Preview Family")
        _ = manager.addUser(name: "Alice", to: fam)
        _ = manager.addUser(name: "Bob", to: fam)
        self.family = fam
    }

    var body: some View {
        NavigationStack {
            FamilySettingsView(family: family)
        }
        .modelContainer(container)
    }
}
