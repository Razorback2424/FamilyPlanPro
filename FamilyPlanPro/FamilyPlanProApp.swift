//
//  FamilyPlanProApp.swift
//  FamilyPlanPro
//
//  Created by Sean Keller on 6/25/25.
//

import SwiftUI
import SwiftData

@main
struct FamilyPlanProApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Family.self,
            User.self,
            WeeklyPlan.self,
            MealSlot.self,
            MealSuggestion.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
