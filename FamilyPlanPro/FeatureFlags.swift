import SwiftUI

struct FeatureFlags: Equatable {
    var mealsOwnershipRules: Bool = false
    var mealsGroceryList: Bool = false
    var notificationsGroceryCadence: Bool = false
    var mealsBudgetStatus: Bool = false
}

private struct FeatureFlagsKey: EnvironmentKey {
    static let defaultValue = FeatureFlags()
}

extension EnvironmentValues {
    var featureFlags: FeatureFlags {
        get { self[FeatureFlagsKey.self] }
        set { self[FeatureFlagsKey.self] = newValue }
    }
}
