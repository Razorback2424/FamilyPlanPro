import Foundation
import SwiftData

@Model
final class Family {
    var name: String
    @Relationship(deleteRule: .cascade) var users: [User] = []
    @Relationship(deleteRule: .cascade) var plans: [WeeklyPlan] = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class User {
    var name: String
    weak var family: Family?

    init(name: String, family: Family? = nil) {
        self.name = name
        self.family = family
    }
}

@Model
final class WeeklyPlan {
    enum Status: String, Codable {
        case suggestionMode
        case reviewMode
        case finalized
    }

    var startDate: Date
    var status: Status
    weak var family: Family?
    @Relationship(deleteRule: .cascade) var slots: [MealSlot] = []

    init(startDate: Date, status: Status = .suggestionMode, family: Family? = nil) {
        self.startDate = startDate
        self.status = status
        self.family = family
    }
}

@Model
final class MealSlot {
    enum MealType: String, Codable, CaseIterable {
        case breakfast, lunch, dinner
    }

    var date: Date
    var mealType: MealType
    weak var plan: WeeklyPlan?
    @Relationship(deleteRule: .cascade) var suggestions: [MealSuggestion] = []

    init(date: Date, mealType: MealType, plan: WeeklyPlan? = nil) {
        self.date = date
        self.mealType = mealType
        self.plan = plan
    }
}

@Model
final class MealSuggestion {
    var title: String
    weak var user: User?
    weak var slot: MealSlot?

    init(title: String, user: User? = nil, slot: MealSlot? = nil) {
        self.title = title
        self.user = user
        self.slot = slot
    }
}

