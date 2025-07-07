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
            MainTabView()
                .onAppear {
                    if let statusString = ProcessInfo.processInfo.environment["UITEST_STATUS"],
                       let status = WeeklyPlan.Status(rawValue: statusString) {
                        seedData(for: status)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedData(for status: WeeklyPlan.Status) {
        let manager = DataManager(context: sharedModelContainer.mainContext)
        let family = manager.createFamily(name: "UITest")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(date: .now, type: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(title: "Test", user: userA, for: slot)

        switch status {
        case .reviewMode:
            manager.submitPlanForReview(plan, by: userA)
        case .finalized:
            manager.submitPlanForReview(plan, by: userA)
            manager.acceptPendingSuggestion(in: slot)
            manager.finalizeIfPossible(plan)
        case .conflict:
            manager.submitPlanForReview(plan, by: userA)
            _ = manager.rejectPendingSuggestion(in: slot, newTitle: "Alt", by: userB, reason: nil, in: plan)
            _ = manager.rejectPendingSuggestion(in: slot, newTitle: "Alt2", by: userA, reason: nil, in: plan)
        case .suggestionMode:
            break
        }

        try? manager.save()
    }
}
