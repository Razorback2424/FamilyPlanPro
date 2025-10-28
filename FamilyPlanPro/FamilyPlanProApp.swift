//
//  FamilyPlanProApp.swift
//  FamilyPlanPro
//
//  Created by Sean Keller on 6/25/25.
//

import SwiftUI
import SwiftData
import Foundation

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

        let fileManager = FileManager.default
        let storeURL = URL.applicationSupportDirectory.appendingPathComponent("FamilyPlanPro.sqlite")
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            assertionFailure("Unable to create application support directory: \(error)")
        }

        var configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        configuration.url = storeURL

        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [configuration])
        }

        do {
            return try makeContainer()
        } catch {
            // If a migration or schema mismatch prevents loading the store, wipe and recreate it.
            if fileManager.fileExists(atPath: storeURL.path) {
                try? fileManager.removeItem(at: storeURL)
                let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
                let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
                try? fileManager.removeItem(at: shmURL)
                try? fileManager.removeItem(at: walURL)
            }

            do {
                return try makeContainer()
            } catch {
                fatalError("Could not create ModelContainer even after resetting the store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    let environment = ProcessInfo.processInfo.environment
                    if environment["UITEST_RESET"] == "1" {
                        resetData()
                    }
                    if environment["UITEST_EMPTY_STATE"] == "1" {
                        seedEmptyStateData()
                    } else if let statusString = environment["UITEST_STATUS"],
                              let status = PlanStatus(rawValue: statusString) {
                        seedData(for: status)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func resetData() {
        let context = sharedModelContainer.mainContext
        if let families = try? context.fetch(FetchDescriptor<Family>()) {
            families.forEach { context.delete($0) }
            try? context.save()
        }
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

    private func seedEmptyStateData() {
        let context = sharedModelContainer.mainContext
        if let existingFamilies = try? context.fetch(FetchDescriptor<Family>()),
           !existingFamilies.isEmpty {
            return
        }

        let manager = DataManager(context: context)
        let family = manager.createFamily(name: "UITest")
        _ = manager.addUser(name: "Alice", to: family)
        _ = manager.addUser(name: "Bob", to: family)
        try? manager.save()
    }
}
