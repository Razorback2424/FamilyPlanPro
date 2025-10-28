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
                       let status = PlanStatus(rawValue: statusString) {
                        seedData(for: status)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedData(for status: PlanStatus) {
        let manager = DataManager(context: sharedModelContainer.mainContext)
        let family = manager.createFamily(name: "UITest")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.createWeeklyPlan(startDate: .now, for: family)
        let slot = manager.addMealSlot(dayOfWeek: .monday, mealType: .breakfast, to: plan)
        _ = manager.setPendingSuggestion(mealName: "Test",
                                         responsibleUser: userA,
                                         author: userA,
                                         for: slot)

        switch status {
        case .reviewMode:
            manager.submitPlanForReview(plan, by: userA)
        case .finalized:
            manager.submitPlanForReview(plan, by: userA)
            manager.acceptPendingSuggestion(in: slot)
            manager.finalizeIfPossible(plan)
        case .conflict:
            manager.submitPlanForReview(plan, by: userA)
            _ = manager.rejectPendingSuggestion(in: slot,
                                               newMealName: "Alt",
                                               author: userB,
                                               responsibleUser: userB,
                                               reasonForChange: nil,
                                               in: plan)
            _ = manager.rejectPendingSuggestion(in: slot,
                                               newMealName: "Alt2",
                                               author: userA,
                                               responsibleUser: userA,
                                               reasonForChange: nil,
                                               in: plan)
        case .suggestionMode:
            break
        }

        try? manager.save()
    }
}
