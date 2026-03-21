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
    private let stageFeatureFlags = FeatureFlags(
        mealsOwnershipRules: true,
        mealsGroceryList: true,
        notificationsGroceryCadence: true,
        mealsBudgetStatus: true
    )

    private let notificationScheduler: NotificationScheduler = UNNotificationScheduler()
    @State private var featureFlagsStore: FeatureFlagsStore

    init() {
        _featureFlagsStore = State(initialValue: FeatureFlagsStore(flags: stageFeatureFlags))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Family.self,
            User.self,
            WeeklyPlan.self,
            OwnershipRulesSnap.self,
            MealSlot.self,
            MealSuggestion.self,
            GroceryList.self,
            GroceryItem.self,
        ])

        let fileManager = FileManager.default
        let storeURL = URL.applicationSupportDirectory.appendingPathComponent("FamilyPlanPro.sqlite")
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            assertionFailure("Unable to create application support directory: \(error)")
        }

        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [configuration])
        }

        do {
            return try makeContainer()
        } catch {
            if fileManager.fileExists(atPath: storeURL.path) {
                try? fileManager.removeItem(at: storeURL)
                try? fileManager.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
                try? fileManager.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
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
                .environment(\.featureFlags, featureFlagsStore.flags)
                .environment(featureFlagsStore)
                .environment(\.notificationScheduler, NotificationSchedulerProvider(scheduler: notificationScheduler))
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
                    if let override = environment["FEATURE_FLAGS"] {
                        applyFeatureFlagOverride(override)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func applyFeatureFlagOverride(_ override: String) {
        let pairs = override.split(separator: ",")
        for pair in pairs {
            let parts = pair.split(separator: "=")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            let enabled = value.lowercased() == "true"
            switch key {
            case "ff.meals.ownershipRules":
                featureFlagsStore.flags.mealsOwnershipRules = enabled
            case "ff.meals.groceryList":
                featureFlagsStore.flags.mealsGroceryList = enabled
            case "ff.notifications.groceryCadence":
                featureFlagsStore.flags.notificationsGroceryCadence = enabled
            case "ff.meals.budgetStatus":
                featureFlagsStore.flags.mealsBudgetStatus = enabled
            default:
                continue
            }
        }
    }

    private func resetData() {
        let context = sharedModelContainer.mainContext
        if let families = try? context.fetch(FetchDescriptor<Family>()) {
            families.forEach { context.delete($0) }
            try? context.save()
        }
    }

    private func seedData(for status: PlanStatus) {
        let cadence = GroceryCadenceScheduler(scheduler: notificationScheduler)
        let manager = DataManager(context: sharedModelContainer.mainContext,
                                  flags: featureFlagsStore.flags,
                                  groceryCadenceScheduler: cadence)
        let family = manager.createFamily(name: "UITest")
        let userA = manager.addUser(name: "Alice", to: family)
        let userB = manager.addUser(name: "Bob", to: family)
        let plan = manager.getOrCreateCurrentWeekPlan(for: family)
        guard let slot = plan.slots.first else { return }
        _ = manager.setPendingSuggestion(title: "Test", user: userA, for: slot)

        switch status {
        case .reviewMode:
            manager.submitPlanForReview(plan, by: userA)
        case .finalized:
            manager.submitPlanForReview(plan, by: userA)
            manager.acceptPendingSuggestion(in: slot)
            for remainingSlot in plan.slots.dropFirst() {
                _ = manager.setPendingSuggestion(title: "Meal \(remainingSlot.id.uuidString.prefix(4))",
                                                 user: userA,
                                                 for: remainingSlot)
                manager.acceptPendingSuggestion(in: remainingSlot)
            }
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
