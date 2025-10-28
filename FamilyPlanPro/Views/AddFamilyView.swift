import SwiftUI
import SwiftData

struct AddFamilyView: View {
    @Environment(\.modelContext) private var context
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section(header: Text("Family Details")) {
                TextField("Family Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
            }

            Button(action: createFamily) {
                Label("Create", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Create a Family")
        .onAppear { isFocused = true }
    }

    private func createFamily() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let manager = DataManager(context: context)
        _ = manager.createFamily(name: trimmed)
        try? context.save()
        name = ""
        isFocused = true
    }
}

#Preview {
    AddFamilyView()
        .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
}
