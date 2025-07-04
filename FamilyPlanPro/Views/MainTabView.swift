import SwiftUI

struct MainTabView: View {
    var body: some View {
        NavigationStack {
            TabView {
                WeeklyPlannerContainerView()
                    .tabItem {
                        Label("Planner", systemImage: "calendar")
                    }
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .modelContainer(for: Family.self, inMemory: true)
    }
}
