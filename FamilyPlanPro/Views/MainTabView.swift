import SwiftUI
import SwiftData

struct MainTabView: View {
    let debugLaunchRoute: DebugLaunchRoute?
    @State private var selectedTab: Tab

    enum Tab: Hashable {
        case planner
        case settings
    }

    init(debugLaunchRoute: DebugLaunchRoute? = nil) {
        self.debugLaunchRoute = debugLaunchRoute
        _selectedTab = State(initialValue: Self.initialTab(for: debugLaunchRoute))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WeeklyPlannerContainerView(debugLaunchRoute: debugLaunchRoute)
            }
            .tag(Tab.planner)
            .tabItem {
                Label("Planner", systemImage: "calendar")
            }

            NavigationStack {
                SettingsTabContainerView(debugLaunchRoute: debugLaunchRoute)
            }
            .tag(Tab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }

    private static func initialTab(for route: DebugLaunchRoute?) -> Tab {
        switch route {
        case .settings, .familySettings:
            return .settings
        default:
            return .planner
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .modelContainer(for: [Family.self, User.self, WeeklyPlan.self, OwnershipRulesSnap.self, MealSlot.self, MealSuggestion.self, GroceryList.self, GroceryItem.self], inMemory: true)
    }
}

private struct SettingsTabContainerView: View {
    let debugLaunchRoute: DebugLaunchRoute?
    @Query private var families: [Family]

    init(debugLaunchRoute: DebugLaunchRoute? = nil) {
        self.debugLaunchRoute = debugLaunchRoute
    }

    var body: some View {
        Group {
            if let family = families.first {
                if debugLaunchRoute == .familySettings {
                    FamilySettingsView(family: family)
                } else {
                    SettingsView()
                }
            } else {
                AddFamilyView()
            }
        }
    }
}
