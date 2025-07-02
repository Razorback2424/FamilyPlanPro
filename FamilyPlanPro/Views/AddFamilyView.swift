import SwiftUI
import SwiftData

struct AddFamilyView: View {
    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Create a Family")
                .font(.title)
            TextField("Family Name", text: $name)
                .textFieldStyle(.roundedBorder)
            Button("Create") {
                guard !name.isEmpty else { return }
                let manager = DataManager(context: context)
                _ = manager.createFamily(name: name)
                try? context.save()
                name = ""
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    AddFamilyView()
        .modelContainer(for: Family.self, inMemory: true)
}
