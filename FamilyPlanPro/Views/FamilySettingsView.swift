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

    var body: some View {
        Form {
            Section("Family Details") {
                TextField("Family Name", text: $family.name)
                    .textInputAutocapitalization(.words)
            }

            Section("Members") {
                if family.members.isEmpty {
                    ContentUnavailableView("No Members", systemImage: "person.3", description: Text("Add the people in your household so you can assign meal responsibilities."))
                } else {
                    ForEach(family.members) { member in
                        Text(member.name)
                    }
                    .onDelete(perform: deleteMembers)
                }

                HStack {
                    TextField("Add Member", text: $newMemberName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isAddingMember)

                    Button("Add") {
                        addMember()
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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
        for index in offsets {
            guard family.members.indices.contains(index) else { continue }
            let member = family.members[index]
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
