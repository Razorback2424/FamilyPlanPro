import SwiftUI
import SwiftData

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                WeeklyPlannerContainerView()
            }
            .tabItem {
                Label("Planner", systemImage: "calendar")
            }

            NavigationStack {
                SettingsTabContainerView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, MealSlot.self, MealSuggestion.self], inMemory: true)
    }
}

private struct SettingsTabContainerView: View {
    @Query private var families: [Family]

    var body: some View {
        Group {
            if let family = families.first {
                FamilySettingsView(family: family)
            } else {
                AddFamilyView()
            }
        }
    }
}
