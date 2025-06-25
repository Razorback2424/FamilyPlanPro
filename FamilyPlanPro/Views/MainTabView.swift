import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            WeeklyPlannerContainerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Family.self, inMemory: true)
}
