import SwiftUI
import SwiftData

struct AddFamilyView: View {
    private struct MemberDraft: Identifiable, Equatable {
        let id = UUID()
        let name: String
    }

    private enum FocusField: Hashable {
        case familyName
        case memberName
    }

    @Environment(\.modelContext) private var context
    @State private var name: String = ""
    @State private var memberName: String = ""
    @State private var members: [MemberDraft] = []
    @FocusState private var focusedField: FocusField?

    private var canCreateFamily: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        return !trimmedName.isEmpty && !members.isEmpty
    }

    private var trimmedMemberName: String {
        memberName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        Form {
            Section(header: Text("Family Details")) {
                TextField("Family Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .familyName)
            }

            Section(header: Text("Individuals Responsible for Meals")) {
                HStack {
                    TextField("Member Name", text: $memberName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .memberName)
                        .onSubmit(addMember)

                    Button(action: addMember) {
                        Label("Add Person", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(trimmedMemberName.isEmpty)
                }

                if members.isEmpty {
                    Text("Add at least one person so meals can be assigned.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("members-empty-state")
                } else {
                    ForEach(members) { member in
                        HStack {
                            Text(member.name)
                            Spacer()
                            Button(role: .destructive) {
                                removeMember(member)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Remove \(member.name)")
                        }
                    }
                }
            }

            Button(action: createFamily) {
                Label("Create", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCreateFamily)
        }
        .navigationTitle("Create a Family")
        .onAppear { focusedField = .familyName }
    }

    private func createFamily() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !members.isEmpty else { return }
        let manager = DataManager(context: context)
        let family = manager.createFamily(name: trimmed)
        for member in members {
            _ = manager.addUser(name: member.name, to: family)
        }
        _ = manager.createCurrentWeekPlan(for: family)
        try? context.save()
        name = ""
        memberName = ""
        members = []
        focusedField = .familyName
    }

    private func addMember() {
        let trimmed = trimmedMemberName
        guard !trimmed.isEmpty else { return }
        members.append(MemberDraft(name: trimmed))
        memberName = ""
        focusedField = .memberName
    }

    private func removeMember(_ member: MemberDraft) {
        members.removeAll { $0.id == member.id }
        if members.isEmpty {
            focusedField = .memberName
        }
    }
}

#Preview {
    AddFamilyView()
        .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
}
