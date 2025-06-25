import SwiftUI
import SwiftData

struct FamilyDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var family: Family

    var body: some View {
        List {
            ForEach(family.plans) { plan in
                Text(plan.startDate, format: Date.FormatStyle(date: .numeric, time: .omitted))
            }
        }
        .navigationTitle(family.name)
    }
}

#Preview {
    FamilyDetailView(family: Family(name: "Preview"))
        .modelContainer(for: Family.self, inMemory: true)
}
