import Foundation
import Observation

@Observable
final class FeatureFlagsStore {
    var flags: FeatureFlags

    init(flags: FeatureFlags = FeatureFlags()) {
        self.flags = flags
    }
}
