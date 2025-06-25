import SwiftUI
import SwiftData

struct WeeklyPlannerContainerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\WeeklyPlan.startDate, order: .reverse)]) private var plans: [WeeklyPlan]

    private var currentPlan: WeeklyPlan? {
        let calendar = Calendar.current
        return plans.first { calendar.isDate($0.startDate, equalTo: Date(), toGranularity: .weekOfYear) }
    }

    var body: some View {
        Group {
            if let plan = currentPlan {
                Text("Current plan starting \(plan.startDate, format: Date.FormatStyle(date: .numeric, time: .omitted))")
            } else {
                Text("Start New Week")
            }
        }
        .navigationTitle("Weekly Planner")
    }
}

#Preview {
    WeeklyPlannerContainerView()
        .modelContainer(for: [Family.self, WeeklyPlan.self], inMemory: true)
}
